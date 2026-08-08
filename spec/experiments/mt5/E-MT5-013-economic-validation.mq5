//+------------------------------------------------------------------+
//| E-MT5-013 — ENGINEERING VALIDATION BACKTEST                       |
//|             1-2-3 PATTERN + MINIMUM ECONOMIC WRAPPER              |
//|                                                                  |
//| *** NOT THE COMPLETED TRADING METHODOLOGY ***                     |
//| *** NOT A PROFITABILITY CLAIM ***                                 |
//| *** DEMO ONLY — REAL ACCOUNTS REFUSED ***                         |
//|                                                                  |
//| Locked configuration (DEC-LOCK-001 §9). Every value below is a    |
//| PROVISIONAL engineering parameter, not a validated trading rule.  |
//|                                                                  |
//| STILL BLOCKED, rendered as such, never silently satisfied:        |
//|   CONFIRMATION MSS FVG RETRACEMENT HTF_CONTEXT SESSION            |
//|   ACCUMULATION DPMO                                               |
//|                                                                  |
//| THREE STRICTLY SEPARATED LAYERS (DEC-LOCK / request §3):          |
//|   A DetectPattern()  REF -> BREAK -> REJECTION      (geometry)    |
//|   B DecideSignal()   pattern -> signal              (decision)    |
//|   C ManagePosition() entry -> stop/target -> P&L    (execution)   |
//| They never call each other's internals and never share state      |
//| except through the explicit signal record.                        |
//+------------------------------------------------------------------+
#property copyright "PROJECT TRADER - engineering validation"
#property version   "1.0"
#property strict

//--- LOCKED pattern parameters (DEC-LOCK-001 §9) --------------------
input int    InpRefK          = 3;      // A' left-only extreme, K=3
input int    InpDeltaPoints   = 0;      // SW-3 minimum penetration
//--- LOCKED economic parameters — ALL PROVISIONAL --------------------
input double InpTargetR       = 2.0;    // PROVISIONAL / ENGINEERING VALIDATION
input double InpRiskPct       = 1.0;    // % of balance risked per trade
input int    InpStopPadPoints = 1;      // SL = L(2) - this many points
input int    InpMaxPositions  = 1;
//--- scope switches, all recorded in the log ------------------------
input bool   InpSessionFilter = false;  // DISABLED — DEC-S-001 OPEN
input string InpRunTag        = "v1";
input bool   InpDraw          = true;

#define PFX "EV_"
#define REF_RULE "A_prime_K3_strict_left"
#define SPEC_ID  "DEC-LOCK-001/SPEC-SW-001"

int      fhT = INVALID_HANDLE, fhE = INVALID_HANDLE, fhR = INVALID_HANDLE;
ulong    gHash = 1469598103934665603ULL;
bool     gTradingEnabled = false;
datetime gLastBar = 0;
long     gBars = 0, gPatterns = 0, gSignals = 0, gSkipped = 0;
int      gSeq = 0;

//--- pending signal produced by layer B, consumed by layer C
bool     gPending = false;
double   pRef, pSweepLow, pSweepClose, pRejClose, pC3Close;
datetime pT1, pT2, pT3;

//--- open trade bookkeeping
ulong    gTicket = 0;
int      gTradeId = 0;
double   gEntry, gStop, gTarget, gVol, gRiskMoney;
datetime gEntryTime;
double   gC3CloseOfTrade;

//--- ledger accumulators
double   gGrossProfit=0, gGrossLoss=0, gLargestWin=0, gLargestLoss=0;
double   gTotalR=0, gPeak=0, gMaxDD=0, gMaxDDPct=0;
int      gWins=0, gLosses=0, gTrades=0;
int      gBuyTrades=0, gBuyWins=0, gSellTrades=0, gSellWins=0;
double   gBuyPnL=0, gSellPnL=0, gInitialBalance=0;

void HashUpdate(const string s)
  { int n=StringLen(s); for(int i=0;i<n;i++){ gHash^=(ulong)StringGetCharacter(s,i); gHash*=1099511628211ULL; } }
void Rep(const string c,const string i,const string r,const string d1="",const string d2="")
  { if(fhR!=INVALID_HANDLE){ FileWrite(fhR,c,i,r,d1,d2); FileFlush(fhR);} }
void Ev(const string kind,const string detail)
  { if(fhE!=INVALID_HANDLE){ FileWrite(fhE,(string)gSeq,TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),kind,detail);
      FileFlush(fhE);} gSeq++; HashUpdate(kind+"|"+detail); }

//+------------------------------------------------------------------+
int OnInit()
  {
   fhT=FileOpen("E-MT5-013-"+InpRunTag+"-trades.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',');
   fhE=FileOpen("E-MT5-013-"+InpRunTag+"-events.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',');
   fhR=FileOpen("E-MT5-013-"+InpRunTag+"-report.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',');
   if(fhT==INVALID_HANDLE||fhE==INVALID_HANDLE||fhR==INVALID_HANDLE) return(INIT_FAILED);

   FileWrite(fhT,"signal_id","direction","reference_price","candle_1","candle_2","candle_3",
             "sweep_price","rejection_price","confirmation_status",
             "c3_close","entry_time","entry_price","exec_gap_points",
             "stop_price","target_price","volume","risk_money","planned_R",
             "exit_time","exit_price","exit_reason","realized_PnL","R_multiple",
             "ref_rule","spec_id");
   FileWrite(fhE,"seq","time","event","detail");
   FileWrite(fhR,"category","item","result","detail1","detail2");

   //--- ENVIRONMENT GUARD -------------------------------------------
   long tm=AccountInfoInteger(ACCOUNT_TRADE_MODE);
   string tn=(tm==ACCOUNT_TRADE_MODE_DEMO)?"DEMO":(tm==ACCOUNT_TRADE_MODE_CONTEST)?"CONTEST":
             (tm==ACCOUNT_TRADE_MODE_REAL)?"REAL":"UNKNOWN";
   Rep("GUARD","ACCOUNT_TRADE_MODE",tn,"raw="+(string)tm,"REAL is refused");
   if(tm==ACCOUNT_TRADE_MODE_REAL)
     {
      Rep("GUARD","REFUSED_INIT","REAL account","trading layer not initialised","");
      Print("E-MT5-013 REFUSING TO INITIALISE ON A REAL ACCOUNT");
      return(INIT_FAILED);
     }
   gTradingEnabled=true;

   gInitialBalance=AccountInfoDouble(ACCOUNT_BALANCE);
   gPeak=gInitialBalance;

   Rep("ENV","build",(string)TerminalInfoInteger(TERMINAL_BUILD),AccountInfoString(ACCOUNT_SERVER),_Symbol);
   Rep("ENV","account",(string)AccountInfoInteger(ACCOUNT_LOGIN),
       AccountInfoString(ACCOUNT_CURRENCY),"leverage="+(string)AccountInfoInteger(ACCOUNT_LEVERAGE));
   Rep("ENV","timeframe",EnumToString((ENUM_TIMEFRAMES)_Period),
       "tester="+(string)(bool)MQLInfoInteger(MQL_TESTER),
       "visual="+(string)(bool)MQLInfoInteger(MQL_VISUAL_MODE));
   Rep("ENV","initial_balance",DoubleToString(gInitialBalance,2),"","");
   Rep("CONFIG","REF_RULE",REF_RULE,"K="+(string)InpRefK,"SW-1 A-prime LOCKED");
   Rep("CONFIG","SW-4","C(2)<REF REQUIRED","SW-5=R-a C(3)>=L(2)","SW-6=strict adjacency");
   Rep("CONFIG","TARGET_R",DoubleToString(InpTargetR,2),
       "STATUS=PROVISIONAL / ENGINEERING VALIDATION","NOT an optimised rule");
   Rep("CONFIG","RISK",DoubleToString(InpRiskPct,2)+"% per trade",
       "stop=L(2)-"+(string)InpStopPadPoints+"pt","no spread padding");
   Rep("CONFIG","SESSION_FILTER",InpSessionFilter?"ENABLED":"DISABLED",
       "STATUS=OPEN DEC-S-001","not resolved by this run");
   Rep("CONFIG","BID_ASK","pattern=BID (SYMBOL_CHART_MODE=0)","D-M4=OPEN",
       "execution: BUY fills at Ask, closes at Bid");
   Rep("BLOCKED","stages","CONFIRMATION MSS FVG RETRACEMENT HTF_CONTEXT SESSION ACCUMULATION DPMO",
       "unimplemented — no approved rule exists","never silently satisfied");
   Rep("SCOPE","label","ENGINEERING VALIDATION BACKTEST","NOT A PROFITABILITY CLAIM",
       "1-2-3 PATTERN + MINIMUM ECONOMIC WRAPPER");

   if(InpDraw) BuildPanel();
   Ev("INIT","tradingEnabled="+(string)gTradingEnabled+" balance="+DoubleToString(gInitialBalance,2));
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   WriteSummary();
   if(fhT!=INVALID_HANDLE) FileClose(fhT);
   if(fhE!=INVALID_HANDLE) FileClose(fhE);
   if(fhR!=INVALID_HANDLE) FileClose(fhR);
   ObjectsDeleteAll(0,PFX);
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   //--- LAYER C first: an open position must be settled before anything else
   ManagePosition();

   datetime bt=iTime(_Symbol,_Period,0);
   bool newBar=(bt!=gLastBar && bt!=0);

   //--- consume a pending signal on the FIRST TICK OF CANDLE 4 -------
   if(gPending && newBar) ExecutePending();

   if(newBar)
     {
      gLastBar=bt; gBars++;
      if(DetectPattern()) DecideSignal();
     }

   if(InpDraw) UpdatePanel();
  }

//+------------------------------------------------------------------+
//| LAYER A — PATTERN DETECTION. Geometry only. No trading concepts.  |
//| Evaluated on CLOSED bars: 3=shift1, 2=shift2, 1=shift3.           |
//+------------------------------------------------------------------+
bool DetectPattern()
  {
   int i3=1, i2=2, i1=3;
   if(iTime(_Symbol,_Period,i1+InpRefK)==0) return(false);

   //--- SW-1 A' : L(1) strictly lower than each of the K candles before it
   double ref=iLow(_Symbol,_Period,i1);
   for(int k=1;k<=InpRefK;k++)
      if(iLow(_Symbol,_Period,i1+k) <= ref) return(false);

   double delta=InpDeltaPoints*_Point;
   double l2=iLow(_Symbol,_Period,i2), c2=iClose(_Symbol,_Period,i2);
   double c3=iClose(_Symbol,_Period,i3);

   if(!(l2 < ref-delta)) return(false);   // VELA 2 rompe el mínimo
   if(!(l2 < c2))        return(false);   // VELA 2 deja mecha inferior
   if(!(c2 < ref))       return(false);   // SW-4 cierra por debajo
   if(!(c3 >= l2))       return(false);   // SW-5 R-a rechazo

   gPatterns++;
   pRef=ref; pSweepLow=l2; pSweepClose=c2; pRejClose=c3; pC3Close=c3;
   pT1=iTime(_Symbol,_Period,i1); pT2=iTime(_Symbol,_Period,i2); pT3=iTime(_Symbol,_Period,i3);

   Ev("PATTERN_DETECTED",StringFormat("ref=%s l2=%s c2=%s c3=%s t3=%s rule=%s",
      DoubleToString(ref,_Digits),DoubleToString(l2,_Digits),DoubleToString(c2,_Digits),
      DoubleToString(c3,_Digits),TimeToString(pT3,TIME_DATE|TIME_SECONDS),REF_RULE));
   if(InpDraw) DrawPattern();
   return(true);
  }

//+------------------------------------------------------------------+
//| LAYER B — TRADING DECISION. Pattern -> signal. No order calls.    |
//+------------------------------------------------------------------+
void DecideSignal()
  {
   if(!gTradingEnabled){ Ev("SIGNAL_SUPPRESSED","trading layer disabled"); return; }
   if(PositionsTotal()>=InpMaxPositions)
     { gSkipped++; Ev("SKIPPED_POSITION_OPEN","max positions="+(string)InpMaxPositions); return; }
   if(InpSessionFilter){ Ev("SESSION_FILTER","enabled but DEC-S-001 unresolved — refusing"); return; }

   gSignals++;
   gPending=true;
   Ev("SIGNAL","direction=BUY_CANDIDATE pending execution at first tick of candle 4");
  }

//+------------------------------------------------------------------+
//| LAYER C — EXECUTION AND POSITION MANAGEMENT                       |
//+------------------------------------------------------------------+
void ExecutePending()
  {
   gPending=false;
   if(PositionsTotal()>=InpMaxPositions){ gSkipped++; Ev("SKIPPED_POSITION_OPEN","at execution time"); return; }

   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double sl =pSweepLow - InpStopPadPoints*_Point;
   if(!(ask>sl)){ Ev("SKIPPED_INVALID_STOP","ask<=sl"); return; }

   double risk=ask-sl;
   double tp  =ask + InpTargetR*risk;

   double bal =AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney=bal*InpRiskPct/100.0;

   double tickVal=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double tickSz =SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   string tvSrc="SYMBOL_TRADE_TICK_VALUE";
   if(tickVal<=0.0 || tickSz<=0.0)
     { tickSz=_Point; tickVal=tickSz*SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE);
       tvSrc="derived from contract size"; }

   double lossPerLot=(risk/tickSz)*tickVal;
   if(lossPerLot<=0.0){ Ev("SKIPPED_SIZING","lossPerLot<=0"); return; }

   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double vmin=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double vol =MathFloor((riskMoney/lossPerLot)/step)*step;
   if(vol<vmin){ gSkipped++; Ev("SKIPPED_LOT_BELOW_MIN",
        "computed="+DoubleToString(riskMoney/lossPerLot,4)+" min="+DoubleToString(vmin,2)); return; }

   double fill=0; ulong ord=0; string err="";
   if(!RawBuy(vol,sl,tp,fill,ord,err))
     { Ev("ORDER_FAILED",err); return; }

   gTicket=ord;
   if(PositionSelect(_Symbol)) gTicket=PositionGetInteger(POSITION_TICKET);

   gTradeId++;
   gEntry=fill; if(gEntry<=0) gEntry=ask;
   gStop=sl; gTarget=tp; gVol=vol; gEntryTime=TimeCurrent();
   gRiskMoney=(gEntry-sl)/tickSz*tickVal*vol;
   gC3CloseOfTrade=pC3Close;

   Ev("ENTRY",StringFormat("id=%d entry=%s c3close=%s gap_pts=%.1f sl=%s tp=%s vol=%s risk=%s tv=%s",
      gTradeId,DoubleToString(gEntry,_Digits),DoubleToString(pC3Close,_Digits),
      (gEntry-pC3Close)/_Point,DoubleToString(sl,_Digits),DoubleToString(tp,_Digits),
      DoubleToString(vol,2),DoubleToString(gRiskMoney,2),tvSrc));
   if(InpDraw) DrawTrade();
  }

//+------------------------------------------------------------------+
//| Raw OrderSend. No library include — the Wine compiler truncates    |
//| /inc: paths containing spaces, so the dependency is removed.        |
//+------------------------------------------------------------------+
bool RawBuy(const double vol,const double sl,const double tp,
            double &fillPrice,ulong &ticket,string &err)
  {
   MqlTradeRequest req; MqlTradeResult res;
   ZeroMemory(req); ZeroMemory(res);
   req.action   = TRADE_ACTION_DEAL;
   req.symbol   = _Symbol;
   req.volume   = vol;
   req.type     = ORDER_TYPE_BUY;
   req.price    = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   req.sl       = NormalizeDouble(sl,_Digits);
   req.tp       = NormalizeDouble(tp,_Digits);
   req.deviation= 10;
   req.magic    = 20260807;
   req.comment  = "EV123";

   long fm=SymbolInfoInteger(_Symbol,SYMBOL_FILLING_MODE);
   if((fm&SYMBOL_FILLING_FOK)!=0)      req.type_filling=ORDER_FILLING_FOK;
   else if((fm&SYMBOL_FILLING_IOC)!=0) req.type_filling=ORDER_FILLING_IOC;
   else                                req.type_filling=ORDER_FILLING_RETURN;

   if(!OrderSend(req,res))
     { err="OrderSend=false retcode="+(string)res.retcode+" err="+(string)GetLastError(); return(false); }
   if(res.retcode!=TRADE_RETCODE_DONE && res.retcode!=TRADE_RETCODE_PLACED)
     { err="retcode="+(string)res.retcode; return(false); }

   fillPrice=res.price;
   ticket   =res.order;
   return(true);
  }

//+------------------------------------------------------------------+
void ManagePosition()
  {
   if(gTicket==0) return;
   if(PositionSelectByTicket(gTicket)) return;      // still open

   //--- closed: reconstruct from deal history
   double pnl=0, exitPrice=0; datetime exitTime=0;
   if(HistorySelectByPosition(gTicket))
     {
      int n=HistoryDealsTotal();
      for(int i=0;i<n;i++)
        {
         ulong d=HistoryDealGetTicket(i);
         if(d==0) continue;
         if(HistoryDealGetInteger(d,DEAL_ENTRY)==DEAL_ENTRY_OUT)
           {
            pnl += HistoryDealGetDouble(d,DEAL_PROFIT)
                 + HistoryDealGetDouble(d,DEAL_SWAP)
                 + HistoryDealGetDouble(d,DEAL_COMMISSION);
            exitPrice=HistoryDealGetDouble(d,DEAL_PRICE);
            exitTime =(datetime)HistoryDealGetInteger(d,DEAL_TIME);
           }
        }
     }

   string reason="UNKNOWN";
   if(exitPrice>0)
     { if(MathAbs(exitPrice-gTarget)<=MathAbs(exitPrice-gStop)) reason="TARGET"; else reason="STOP"; }

   double rMult=(gRiskMoney>0.0)?pnl/gRiskMoney:0.0;

   gTrades++; gTotalR+=rMult;
   if(pnl>=0){ gWins++; gGrossProfit+=pnl; if(pnl>gLargestWin) gLargestWin=pnl; }
   else      { gLosses++; gGrossLoss+=MathAbs(pnl); if(pnl<gLargestLoss) gLargestLoss=pnl; }
   gBuyTrades++; gBuyPnL+=pnl; if(pnl>=0) gBuyWins++;

   double bal=AccountInfoDouble(ACCOUNT_BALANCE);
   if(bal>gPeak) gPeak=bal;
   double dd=gPeak-bal;
   if(dd>gMaxDD){ gMaxDD=dd; gMaxDDPct=(gPeak>0)?100.0*dd/gPeak:0.0; }

   FileWrite(fhT,(string)gTradeId,"BUY",
     DoubleToString(pRef,_Digits),
     TimeToString(pT1,TIME_DATE|TIME_SECONDS),TimeToString(pT2,TIME_DATE|TIME_SECONDS),
     TimeToString(pT3,TIME_DATE|TIME_SECONDS),
     DoubleToString(pSweepLow,_Digits),DoubleToString(pRejClose,_Digits),
     "BLOCKED(DEC-044)",
     DoubleToString(gC3CloseOfTrade,_Digits),
     TimeToString(gEntryTime,TIME_DATE|TIME_SECONDS),DoubleToString(gEntry,_Digits),
     DoubleToString((gEntry-gC3CloseOfTrade)/_Point,1),
     DoubleToString(gStop,_Digits),DoubleToString(gTarget,_Digits),
     DoubleToString(gVol,2),DoubleToString(gRiskMoney,2),DoubleToString(InpTargetR,2),
     TimeToString(exitTime,TIME_DATE|TIME_SECONDS),DoubleToString(exitPrice,_Digits),reason,
     DoubleToString(pnl,2),DoubleToString(rMult,3),REF_RULE,SPEC_ID);
   FileFlush(fhT);

   Ev("EXIT",StringFormat("id=%d reason=%s exit=%s pnl=%.2f R=%.3f bal=%.2f",
      gTradeId,reason,DoubleToString(exitPrice,_Digits),pnl,rMult,bal));

   gTicket=0;
  }

//+------------------------------------------------------------------+
void WriteSummary()
  {
   double finalBal=AccountInfoDouble(ACCOUNT_BALANCE);
   double net=finalBal-gInitialBalance;
   double pf=(gGrossLoss>0.0)?gGrossProfit/gGrossLoss:0.0;
   double winRate=(gTrades>0)?100.0*(double)gWins/(double)gTrades:0.0;
   double avgWin=(gWins>0)?gGrossProfit/gWins:0.0;
   double avgLoss=(gLosses>0)?gGrossLoss/gLosses:0.0;
   double avgR=(gTrades>0)?gTotalR/gTrades:0.0;

   Rep("LABEL","scope","ENGINEERING VALIDATION BACKTEST","NOT A PROFITABILITY CLAIM","");
   Rep("RESULT","bars",(string)gBars,"patterns="+(string)gPatterns,
       "signals="+(string)gSignals+" skipped="+(string)gSkipped);
   Rep("MONEY","initial_balance",DoubleToString(gInitialBalance,2),"USD","");
   Rep("MONEY","final_balance",DoubleToString(finalBal,2),"USD","");
   Rep("MONEY","net_profit",DoubleToString(net,2),"USD",
       (gInitialBalance>0)?DoubleToString(100.0*net/gInitialBalance,2)+"%":"");
   Rep("MONEY","gross_profit",DoubleToString(gGrossProfit,2),"gross_loss="+DoubleToString(gGrossLoss,2),"");
   Rep("MONEY","profit_factor",DoubleToString(pf,3),"","");
   Rep("TRADES","total",(string)gTrades,"wins="+(string)gWins,"losses="+(string)gLosses);
   Rep("TRADES","win_rate",DoubleToString(winRate,2)+"%","","");
   Rep("TRADES","avg_win",DoubleToString(avgWin,2),"avg_loss="+DoubleToString(avgLoss,2),"");
   Rep("TRADES","largest_win",DoubleToString(gLargestWin,2),
       "largest_loss="+DoubleToString(gLargestLoss,2),"");
   Rep("RISK","max_drawdown",DoubleToString(gMaxDD,2),
       DoubleToString(gMaxDDPct,2)+"%","peak="+DoubleToString(gPeak,2));
   Rep("R","total_R",DoubleToString(gTotalR,3),"avg_R="+DoubleToString(avgR,3),"");
   Rep("SPLIT","BUY",(string)gBuyTrades,"wins="+(string)gBuyWins,
       "pnl="+DoubleToString(gBuyPnL,2));
   Rep("SPLIT","SELL",(string)gSellTrades,"wins="+(string)gSellWins,
       "pnl="+DoubleToString(gSellPnL,2)+" (bearish mirror NOT implemented this run)");
   Rep("HASH","event_log",StringFormat("%I64u",gHash),"FNV-1a over all events","");
  }

//+------------------------------------------------------------------+
//| RENDERING — downstream of the event log. Invents nothing.         |
//+------------------------------------------------------------------+
void DrawPattern()
  {
   string id=PFX+"p"+(string)gPatterns;
   int ps=PeriodSeconds();
   if(ObjectCreate(0,id+"_ref",OBJ_TREND,0,pT1,pRef,pT3+ps*4,pRef))
     { ObjectSetInteger(0,id+"_ref",OBJPROP_COLOR,clrDeepSkyBlue);
       ObjectSetInteger(0,id+"_ref",OBJPROP_RAY_RIGHT,false);
       ObjectSetInteger(0,id+"_ref",OBJPROP_WIDTH,2);
       ObjectSetInteger(0,id+"_ref",OBJPROP_SELECTABLE,false); }
   Tag(id+"_1",pT1,pRef,"1 REF",clrDeepSkyBlue,ANCHOR_LOWER);
   Tag(id+"_2",pT2,pSweepLow,"2 SWEEP",clrOrange,ANCHOR_UPPER);
   Tag(id+"_3",pT3,pRejClose,"3 REJECT",clrLime,ANCHOR_LOWER);
  }

void DrawTrade()
  {
   string id=PFX+"t"+(string)gTradeId;
   int ps=PeriodSeconds();
   datetime e=gEntryTime, r=e+ps*30;
   if(ObjectCreate(0,id+"_e",OBJ_ARROW,0,e,gEntry))
     { ObjectSetInteger(0,id+"_e",OBJPROP_ARROWCODE,233);
       ObjectSetInteger(0,id+"_e",OBJPROP_COLOR,clrAqua);
       ObjectSetInteger(0,id+"_e",OBJPROP_WIDTH,2);
       ObjectSetInteger(0,id+"_e",OBJPROP_SELECTABLE,false); }
   Line(id+"_sl",e,gStop,r,clrTomato,"SL "+DoubleToString(gStop,_Digits));
   Line(id+"_tp",e,gTarget,r,clrLime,"TP "+DoubleToString(gTarget,_Digits));
   Tag(id+"_lbl",e,gEntry,StringFormat("BUY #%d  %s lots  risk $%s",
       gTradeId,DoubleToString(gVol,2),DoubleToString(gRiskMoney,2)),clrAqua,ANCHOR_LOWER);
  }

void Line(const string n,const datetime t1,const double p,const datetime t2,
          const color c,const string txt)
  {
   if(!ObjectCreate(0,n,OBJ_TREND,0,t1,p,t2,p)) return;
   ObjectSetInteger(0,n,OBJPROP_COLOR,c);
   ObjectSetInteger(0,n,OBJPROP_STYLE,STYLE_DOT);
   ObjectSetInteger(0,n,OBJPROP_RAY_RIGHT,false);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   ObjectSetString (0,n,OBJPROP_TEXT,txt);
  }

void Tag(const string n,const datetime t,const double p,const string txt,
         const color c,const ENUM_ANCHOR_POINT a)
  {
   if(!ObjectCreate(0,n,OBJ_TEXT,0,t,p)) return;
   ObjectSetString (0,n,OBJPROP_TEXT,txt);
   ObjectSetInteger(0,n,OBJPROP_COLOR,c);
   ObjectSetString (0,n,OBJPROP_FONT,"Consolas");
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,8);
   ObjectSetInteger(0,n,OBJPROP_ANCHOR,a);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
  }

//+------------------------------------------------------------------+
void BuildPanel()
  {
   Bg(PFX+"bg",8,18,470,290);
   L(PFX+"h1",16,24,"ENGINEERING VALIDATION BACKTEST",clrWhite,9);
   L(PFX+"h2",16,38,"NOT A PROFITABILITY CLAIM - 1-2-3 PATTERN + MIN ECONOMIC WRAPPER",clrOrangeRed,7);
   L(PFX+"h3",16,52,"MODE: BACKTEST   ENVIRONMENT: DEMO   LIVE TRADING: DISABLED",clrGold,8);
   for(int i=0;i<15;i++) L(PFX+"k"+(string)i,16,70+i*15,"",clrLightGray,8);
  }

void UpdatePanel()
  {
   double bal=AccountInfoDouble(ACCOUNT_BALANCE);
   double eq =AccountInfoDouble(ACCOUNT_EQUITY);
   SetL(0, "symbol/tf    "+_Symbol+" "+EnumToString((ENUM_TIMEFRAMES)_Period)+"   model=REAL TICKS");
   SetL(1, "REFERENCE    PASS   rule="+REF_RULE);
   SetL(2, "SWEEP/BREAK  PASS   C(2)<REF required (SW-4)");
   SetL(3, "REJECTION    PASS   C(3)>=L(2) (SW-5 R-a)");
   SetL(4, "CONFIRMATION BLOCKED  DEC-044 unresolved");
   SetL(5, "STRUCTURE    BLOCKED  DEC-029      FVG BLOCKED DEC-036");
   SetL(6, "RETRACEMENT  BLOCKED  DEC-030      HTF BLOCKED D-M1");
   SetL(7, "SESSION      DISABLED STATUS=OPEN DEC-S-001");
   SetL(8, "ACCUMULATION BLOCKED  DPMO BLOCKED");
   SetL(9, "TARGET_R     "+DoubleToString(InpTargetR,2)+"  PROVISIONAL/ENGINEERING");
   SetL(10,"risk         "+DoubleToString(InpRiskPct,2)+"% per trade   D-M4=OPEN");
   SetL(11,"bars="+(string)gBars+"  patterns="+(string)gPatterns+
           "  signals="+(string)gSignals+"  skipped="+(string)gSkipped);
   SetL(12,"trades="+(string)gTrades+"  W="+(string)gWins+"  L="+(string)gLosses+
           "  totalR="+DoubleToString(gTotalR,2));
   SetL(13,"balance $"+DoubleToString(bal,2)+"   equity $"+DoubleToString(eq,2));
   SetL(14,"net $"+DoubleToString(bal-gInitialBalance,2)+
           "   maxDD $"+DoubleToString(gMaxDD,2));
  }

void SetL(const int i,const string s){ ObjectSetString(0,PFX+"k"+(string)i,OBJPROP_TEXT,s); }

void Bg(const string n,const int x,const int y,const int w,const int h)
  {
   if(ObjectFind(0,n)<0 && !ObjectCreate(0,n,OBJ_RECTANGLE_LABEL,0,0,0)) return;
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,w);     ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,C'16,20,28');
   ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,n,OBJPROP_COLOR,clrDimGray);
   ObjectSetInteger(0,n,OBJPROP_BACK,false);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
  }
void L(const string n,const int x,const int y,const string t,const color c,const int s)
  {
   if(ObjectFind(0,n)<0 && !ObjectCreate(0,n,OBJ_LABEL,0,0,0)) return;
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetString (0,n,OBJPROP_TEXT,t);      ObjectSetInteger(0,n,OBJPROP_COLOR,c);
   ObjectSetString (0,n,OBJPROP_FONT,"Consolas"); ObjectSetInteger(0,n,OBJPROP_FONTSIZE,s);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
  }
//+------------------------------------------------------------------+
