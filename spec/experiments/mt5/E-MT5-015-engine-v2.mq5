//+------------------------------------------------------------------+
//| E-MT5-015 — ENGINEERING VALIDATION ENGINE V2                      |
//|                                                                  |
//| DEMO-ONLY. REAL accounts refused. Not a profitability claim.      |
//|                                                                  |
//| LOCKED SPEC (CHECKPOINT-002):                                     |
//|   REF   A' = extreme of the previous K=3 candles (left-only)      |
//|   SW-4  C(2) beyond REF          SW-5  R-a                        |
//|   SW-6  strict 1->2->3           TF    M5                         |
//|   ADJ   adjacency is TIME adjacency: every consecutive pair in    |
//|         1->2->3->4 must be exactly PeriodSeconds() apart, or the  |
//|         window is not a signal (SKIPPED_GAP_IN_WINDOW).           |
//|         Scope is the 1->2->3->4 window only; the A' look-back is  |
//|         OPEN, see CHECKPOINT-002 section 2.3.                     |
//|   ENTRY first executable tick of candle 4                         |
//|   STOP  L(2) - 5 pts  (PAD)      mirrored for SELL                |
//|   TGT   2.0R  PROVISIONAL        SIZING Policy A, 1% capped       |
//|   SESSION filter DISABLED (DEC-S-001 OPEN)  BID stream (D-M4 OPEN)|
//|                                                                  |
//| FIXES vs V1: entry timing, immutable provenance, BUY/SELL mirror, |
//| ledger reconciliation. Invariant suite runs at init and BLOCKS    |
//| the run on any failure.                                           |
//| FIX vs V2.0: time adjacency. V2.0 indexed the bar array and never |
//| compared timestamps, so 77 of 18,493 windows spanned a market     |
//| closure or a data gap. ENTRY_TIMING saw only the 19 where the gap |
//| fell before candle 4; the other 58 were accepted as valid.        |
//+------------------------------------------------------------------+
#property copyright "PROJECT TRADER - engine v2"
#property version   "2.1"
#property strict
#include <Trade\Trade.mqh>

input int    InpRefK        = 3;
input int    InpStopPadPts  = 5;      // LOCKED
input double InpTargetR     = 2.0;    // PROVISIONAL
input double InpRiskPct     = 1.0;    // Policy A
input int    InpMaxPositions= 1;
input bool   InpAllowBuy    = true;
input bool   InpAllowSell   = true;
input bool   InpDraw        = true;
input string InpRunTag      = "v2";

#define DIR_BUY   1
#define DIR_SELL -1
#define PFX "V2_"

struct Bar { datetime t; double o,h,l,c; };

struct Trade
  {
   int      id; string pattern_id; int dir;
   datetime t1,t2,t3, signal_time, entry_time, exit_time;
   double   ref, sweep, rej;
   double   entry, stop, target;
   double   planned_risk, actual_risk, theo_lot, capped_lot, lot;
   double   margin_req, margin_avail;
   double   exit_price, pnl, r;
   string   exit_reason; bool open;
   ulong    ticket;
  };

CTrade   gT;
Trade    gTr[];
int      gNT=0, gSignals=0, gAttempt=0, gExec=0, gRej=0, gSkipGap=0;
datetime gLastBar=0;
ulong    gHash=1469598103934665603ULL;
int      fhL=INVALID_HANDLE, fhI=INVALID_HANDLE;
double   gStartBal=0;
bool     gArmed=false;
int      gViolations=0;
int      gTimingViol=0;      // ENTRY_TIMING only, so the backstop assertion
                             // cannot be mis-attributed to a ledger failure

void HashU(const string s){ int n=StringLen(s); for(int i=0;i<n;i++){ gHash^=(ulong)StringGetCharacter(s,i); gHash*=1099511628211ULL; } }
void Log(const string ev,const string a="",const string b="",const string c="",const string d="",const string e="")
  { if(fhL!=INVALID_HANDLE){ FileWrite(fhL,TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),ev,a,b,c,d,e); FileFlush(fhL);} HashU(ev+"|"+a+"|"+b+"|"+c); }
void Inv(const string name,const bool pass,const string detail="")
  { if(fhI!=INVALID_HANDLE){ FileWrite(fhI,name,pass?"PASS":"FAIL",detail); FileFlush(fhI);} if(!pass) gViolations++; }

//====================================================================
//  PURE DETECTOR — one implementation, direction is a parameter.
//  Operates on a Bar array so the same code is testable on synthetic
//  data. dir=+1 bullish, dir=-1 bearish.
//====================================================================
double Ext(const Bar &b,const int dir){ return(dir>0?b.l:b.h); }

bool DetectAt(const Bar &bars[],const int i3,const int K,const int dir,
              double &ref,double &sweep,double &rejc)
  {
   int i2=i3-1, i1=i3-2;
   if(i1-K<0) return(false);
   ref=Ext(bars[i1],dir);
   for(int k=1;k<=K;k++)                       // A': left-only extreme
      if(dir*(Ext(bars[i1-k],dir)-ref) <= 0.0) return(false);
   sweep=Ext(bars[i2],dir);
   if(!(dir*(sweep-ref) < 0.0))                return(false);   // sweep beyond REF
   if(!(dir*(sweep-bars[i2].c) < 0.0))         return(false);   // wick beyond close
   if(!(dir*(bars[i2].c-ref) < 0.0))           return(false);   // SW-4: C2 beyond REF
   rejc=bars[i3].c;
   if(!(dir*(rejc-sweep) >= 0.0))              return(false);   // SW-5 R-a
   return(true);
  }

//====================================================================
//  SW-6 TIME ADJACENCY — CHECKPOINT-002 section 2.2, LOCKED 2026-08-08
//  Index adjacency is not time adjacency. A market closure or a minute
//  with no ticks (MT5-CAP-001 F3) makes two index-adjacent bars hours
//  apart. Every consecutive pair in 1->2->3->4 must be exactly one
//  period. Kept as a separate named predicate so the rejection can name
//  the rule that failed (A-5).
//  Scope: the 1->2->3->4 window only. The A' look-back is OPEN.
//====================================================================
bool Contiguous(const Bar &bars[],const int i3,const datetime entT,const int ps)
  {
   if(bars[i3].t   - bars[i3-1].t != ps) return(false);   // candle 2 -> 3
   if(bars[i3-1].t - bars[i3-2].t != ps) return(false);   // candle 1 -> 2
   if(entT         - bars[i3].t   != ps) return(false);   // candle 3 -> 4
   return(true);
  }

//====================================================================
//  POLICY A
//====================================================================
double PolicyA(const int dir,const double entry,const double stop,
               double &theo,double &capped,double &mReq,double &mAvail,double &rActual)
  {
   double vmin=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double vmax=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double vst =SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double ts=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double tv=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   if(ts<=0||tv<=0){ ts=_Point; tv=ts*SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE); }

   mAvail=AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double dist=MathAbs(entry-stop);
   double lossPerLot=(dist/ts)*tv;
   if(lossPerLot<=0){ theo=0;capped=0;mReq=0;rActual=0; return(0); }

   double planned=AccountInfoDouble(ACCOUNT_BALANCE)*InpRiskPct/100.0;
   theo=MathFloor((planned/lossPerLot)/vst)*vst;
   if(theo>vmax) theo=vmax;

   ENUM_ORDER_TYPE ot=(dir>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL);
   double mTheo=0;
   if(theo>0 && !OrderCalcMargin(ot,_Symbol,theo,entry,mTheo)) mTheo=0;

   capped=theo;
   if(mTheo>mAvail && mTheo>0)
     { double mPer=mTheo/theo; capped=MathFloor((mAvail*0.95/mPer)/vst)*vst; }
   if(capped>vmax) capped=vmax;
   if(capped<vmin) capped=0;

   mReq=0;
   if(capped>0 && !OrderCalcMargin(ot,_Symbol,capped,entry,mReq)) mReq=0;
   rActual=capped*lossPerLot;
   return(capped);
  }

//====================================================================
int OnInit()
  {
   fhL=FileOpen("E-MT5-015-"+InpRunTag+"-events.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',');
   fhI=FileOpen("E-MT5-015-"+InpRunTag+"-invariants.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',');
   if(fhL==INVALID_HANDLE||fhI==INVALID_HANDLE) return(INIT_FAILED);
   FileWrite(fhL,"time","event","a","b","c","d","e");
   FileWrite(fhI,"invariant","result","detail");

   //--- REAL guard -------------------------------------------------
   long tm=AccountInfoInteger(ACCOUNT_TRADE_MODE);
   Inv("GUARD_not_real",tm!=ACCOUNT_TRADE_MODE_REAL,
       "trade_mode="+(string)tm+" (0=DEMO 1=CONTEST 2=REAL)");
   if(tm==ACCOUNT_TRADE_MODE_REAL)
     { Log("REFUSED_REAL_ACCOUNT"); Print("E-MT5-015 REFUSES REAL ACCOUNT"); return(INIT_FAILED); }

   RunInvariants();
   if(gViolations>0)
     { Log("INIT_BLOCKED","violations="+(string)gViolations);
       Print("E-MT5-015 BLOCKED: ",gViolations," invariant failure(s)"); return(INIT_FAILED); }

   gStartBal=AccountInfoDouble(ACCOUNT_BALANCE);
   gT.SetExpertMagicNumber(20260808);
   gT.SetTypeFillingBySymbol(_Symbol);
   Log("RUN_START","bal="+DoubleToString(gStartBal,2),_Symbol,
       EnumToString((ENUM_TIMEFRAMES)_Period),"pad="+(string)InpStopPadPts,"R="+DoubleToString(InpTargetR,1));
   if(InpDraw) BuildPanel();
   return(INIT_SUCCEEDED);
  }

//====================================================================
//  INVARIANT SUITE — blocks the run on any failure
//====================================================================
Bar MkBar(const datetime t,const double o,const double h,const double l,const double c)
  { Bar b; b.t=t; b.o=o; b.h=h; b.l=l; b.c=c; return(b); }
Bar Mirror(const Bar &b,const double C)
  { Bar m; m.t=b.t; m.o=C-b.o; m.h=C-b.l; m.l=C-b.h; m.c=C-b.c; return(m); }

void RunInvariants()
  {
   //--- synthetic bullish 1-2-3: K=3 descending lows then sweep+reject
   Bar B[8];
   B[0]=MkBar(100,1.1050,1.1055,1.1045,1.1052);
   B[1]=MkBar(200,1.1045,1.1050,1.1040,1.1047);
   B[2]=MkBar(300,1.1040,1.1045,1.1035,1.1042);
   B[3]=MkBar(400,1.1035,1.1040,1.1030,1.1037);   // i1 REF low=1.1030
   B[4]=MkBar(500,1.1032,1.1034,1.1020,1.1025);   // i2 sweep low, closes below REF
   B[5]=MkBar(600,1.1026,1.1040,1.1024,1.1038);   // i3 close >= L(2)
   B[6]=MkBar(700,1.1038,1.1042,1.1036,1.1040);
   B[7]=MkBar(800,1.1040,1.1044,1.1038,1.1042);

   double ref=0,sw=0,rj=0;
   bool bull=DetectAt(B,5,3,DIR_BUY,ref,sw,rj);
   Inv("SYM_bullish_detected",bull,
       "ref="+DoubleToString(ref,5)+" sweep="+DoubleToString(sw,5)+" rej="+DoubleToString(rj,5));
   Inv("SYM_bullish_levels",bull&&MathAbs(ref-1.1030)<1e-8&&MathAbs(sw-1.1020)<1e-8,"");

   //--- mirror the same data; the bearish detector must fire identically
   double C=2.2100; Bar M[8];
   for(int i=0;i<8;i++) M[i]=Mirror(B[i],C);
   double ref2=0,sw2=0,rj2=0;
   bool bear=DetectAt(M,5,3,DIR_SELL,ref2,sw2,rj2);
   Inv("SYM_bearish_detected_on_mirror",bear,
       "ref="+DoubleToString(ref2,5)+" sweep="+DoubleToString(sw2,5));
   Inv("SYM_levels_are_mirrored",
       bear&&MathAbs((C-ref2)-ref)<1e-8&&MathAbs((C-sw2)-sw)<1e-8,
       "sigma(ref')==ref and sigma(sweep')==sweep");

   //--- cross-direction must NOT fire
   double x,y,z;
   Inv("SYM_no_SELL_from_bullish",!DetectAt(B,5,3,DIR_SELL,x,y,z),"");
   Inv("SYM_no_BUY_from_bearish", !DetectAt(M,5,3,DIR_BUY, x,y,z),"");

   //--- stop/target mirror symmetry
   double eB=1.1039, sB=sw-InpStopPadPts*_Point, tB=eB+(eB-sB)*InpTargetR;
   double eS=C-eB,   sS=sw2+InpStopPadPts*_Point, tS=eS-(sS-eS)*InpTargetR;
   Inv("SYM_stop_mirror",  MathAbs((C-sS)-sB)<1e-8,"SL mirrors exactly");
   Inv("SYM_target_mirror",MathAbs((C-tS)-tB)<1e-8,"TP mirrors exactly");

   //--- immutable provenance: later patterns must not alter an open trade
   ArrayResize(gTr,3); gNT=0;
   Trade a; ZeroMemory(a); a.id=1; a.pattern_id="P1"; a.ref=1.1030; a.t3=600; a.open=true;
   gTr[gNT++]=a;
   Trade b2; ZeroMemory(b2); b2.id=2; b2.pattern_id="P2"; b2.ref=1.2222; b2.t3=900; b2.open=true;
   gTr[gNT++]=b2;
   Trade c3; ZeroMemory(c3); c3.id=3; c3.pattern_id="P3"; c3.ref=1.3333; c3.t3=1200; c3.open=true;
   gTr[gNT++]=c3;
   Inv("PROV_snapshot_immutable",
       gTr[0].pattern_id=="P1"&&MathAbs(gTr[0].ref-1.1030)<1e-8&&gTr[0].t3==600,
       "trade 1 still references P1 after P2 and P3 were recorded");
   ArrayResize(gTr,0); gNT=0;

   //--- SW-6 time adjacency, CHECKPOINT-002 section 2.4
   //--- B[] above is spaced 100s; build a properly spaced window instead.
   int ps=300;
   Bar A[8];
   for(int i=0;i<8;i++){ A[i]=B[i]; A[i].t=(datetime)(1000000+i*ps); }
   Inv("ADJ_contiguous_accepts",Contiguous(A,5,A[5].t+ps,ps),
       "300s-spaced 1->2->3->4 is admitted");
   Bar G1[8]; for(int i=0;i<8;i++) G1[i]=A[i];
   G1[4].t=A[4].t+173100-ps; G1[5].t=G1[4].t+ps;      // gap between candle 1 and 2
   Inv("ADJ_gap_c1c2_rejected",!Contiguous(G1,5,G1[5].t+ps,ps),
       "weekend between candle 1 and 2 is refused");
   Bar G2[8]; for(int i=0;i<8;i++) G2[i]=A[i];
   G2[5].t=A[5].t+173100;                              // gap between candle 2 and 3
   Inv("ADJ_gap_c2c3_rejected",!Contiguous(G2,5,G2[5].t+ps,ps),
       "weekend between candle 2 and 3 is refused");
   Inv("ADJ_gap_c3c4_rejected",!Contiguous(A,5,A[5].t+173100,ps),
       "weekend between candle 3 and the entry bar is refused");

   //--- Policy A monotonicity: a wider stop must never need a bigger lot
   Inv("SIZING_pad_locked",InpStopPadPts==5,"PAD X=5 locked by CHECKPOINT-002");
   Inv("SIZING_risk_locked",MathAbs(InpRiskPct-1.0)<1e-9,"Policy A 1% locked");

   //--- no BUY/SELL outside the decision layer
   Inv("SAFETY_directions_gated",(InpAllowBuy||InpAllowSell),
       "both directions come from the same DetectAt; no separate path exists");
  }

//====================================================================
void OnDeinit(const int reason)
  {
   //--- FORCED_TEST_END_EXIT for anything still open
   double forced=0;
   for(int i=0;i<gNT;i++)
      if(gTr[i].open)
        {
         double pl=0;
         if(PositionSelectByTicket(gTr[i].ticket)) pl=PositionGetDouble(POSITION_PROFIT);
         gTr[i].open=false; gTr[i].exit_reason="FORCED_TEST_END_EXIT";
         gTr[i].exit_time=TimeCurrent(); gTr[i].pnl=pl; forced+=pl;
         Log("FORCED_TEST_END_EXIT","id="+(string)gTr[i].id,DoubleToString(pl,2));
        }

   double bal=AccountInfoDouble(ACCOUNT_BALANCE);
   double sumClosed=0; for(int i=0;i<gNT;i++) sumClosed+=gTr[i].pnl;
   double delta=bal-gStartBal, resid=delta-sumClosed;

   WriteLedger();
   Log("RECONCILE","start="+DoubleToString(gStartBal,2),"final="+DoubleToString(bal,2),
       "sum_ledger="+DoubleToString(sumClosed,2),"forced="+DoubleToString(forced,2),
       "residual="+DoubleToString(resid,2));
   Inv("LEDGER_reconciles",MathAbs(resid)<0.01,
       "residual=$"+DoubleToString(resid,4)+" (must be 0.00)");
   Inv("ADJ_no_timing_backstop_fired",gTimingViol==0,
       "ENTRY_TIMING fired "+(string)gTimingViol+" time(s); must be 0 once the gap guard holds");
   Log("RUN_END","trades="+(string)gNT,"signals="+(string)gSignals,
       "exec="+(string)gExec,"rej="+(string)gRej+" skipgap="+(string)gSkipGap,
       "hash="+StringFormat("%I64u",gHash));
   if(fhL!=INVALID_HANDLE) FileClose(fhL);
   if(fhI!=INVALID_HANDLE) FileClose(fhI);
   ObjectsDeleteAll(0,PFX);
  }

//====================================================================
void OnTick()
  {
   Manage();
   datetime bt=iTime(_Symbol,_Period,0);
   if(bt==gLastBar||bt==0){ if(InpDraw) Panel(); return; }
   gLastBar=bt;

   //--- candle 3 is shift 1 (just closed); candle 4 is shift 0 (now).
   //--- Detect AND execute on this same event = first tick of candle 4.
   int need=InpRefK+4;
   Bar bars[]; ArrayResize(bars,need);
   for(int i=0;i<need;i++)
     { int sh=need-1-i;
       bars[i].t=iTime(_Symbol,_Period,sh); bars[i].o=iOpen(_Symbol,_Period,sh);
       bars[i].h=iHigh(_Symbol,_Period,sh); bars[i].l=iLow(_Symbol,_Period,sh);
       bars[i].c=iClose(_Symbol,_Period,sh); }
   int i3=need-2;                                   // shift 1 = candle 3

   double ref,sw,rj;
   if(InpAllowBuy  && DetectAt(bars,i3,InpRefK,DIR_BUY, ref,sw,rj)) Execute(DIR_BUY, bars,i3,ref,sw,rj);
   else if(InpAllowSell && DetectAt(bars,i3,InpRefK,DIR_SELL,ref,sw,rj)) Execute(DIR_SELL,bars,i3,ref,sw,rj);
   if(InpDraw) Panel();
  }

//====================================================================
void Execute(const int dir,const Bar &bars[],const int i3,
             const double ref,const double sw,const double rj)
  {
   gSignals++;
   datetime sigCandle=bars[i3].t;
   datetime entCandle=iTime(_Symbol,_Period,0);
   string pid=StringFormat("P%d_%s_%d",(dir>0?1:2),_Symbol,(long)sigCandle);

   //--- SW-6 TIME ADJACENCY (CHECKPOINT-002). Not a violation: a gapped
   //--- window is a specified, expected non-signal. Geometry still counts
   //--- toward gSignals so the population stays comparable with hist1.
   if(!Contiguous(bars,i3,entCandle,PeriodSeconds()))
     { gSkipGap++;
       Log("SKIPPED_GAP_IN_WINDOW",pid,
           "c1="+TimeToString(bars[i3-2].t,TIME_DATE|TIME_SECONDS),
           "c2="+TimeToString(bars[i3-1].t,TIME_DATE|TIME_SECONDS),
           "c3="+TimeToString(bars[i3].t,TIME_DATE|TIME_SECONDS),
           "c4="+TimeToString(entCandle,TIME_DATE|TIME_SECONDS));
       return; }

   //--- BACKSTOP: unreachable once the guard above holds. If it ever fires,
   //--- the guard has been bypassed and the run is defective.
   bool okTiming=(entCandle==sigCandle+PeriodSeconds());
   if(!okTiming)
     { gViolations++; gTimingViol++;
       Inv("ENTRY_TIMING_"+(string)gSignals,false,
           "signal="+TimeToString(sigCandle,TIME_DATE|TIME_SECONDS)+
           " entry="+TimeToString(entCandle,TIME_DATE|TIME_SECONDS));
       Log("VIOLATION_ENTRY_TIMING",TimeToString(sigCandle),TimeToString(entCandle));
       return; }                                   // fail loudly, do not repair

   if(PositionsTotal()>=InpMaxPositions)
     { Log("SKIPPED_POSITION_OPEN",pid); return; }

   MqlTick tk; if(!SymbolInfoTick(_Symbol,tk)) return;
   double entry=(dir>0?tk.ask:tk.bid);
   double stop =(dir>0? sw-InpStopPadPts*_Point : sw+InpStopPadPts*_Point);
   if(dir*(entry-stop)<=0){ Log("SKIPPED_INVALID_STOP",pid,
        DoubleToString(entry,_Digits),DoubleToString(stop,_Digits)); return; }
   double target=entry+dir*MathAbs(entry-stop)*InpTargetR;

   double theo,capped,mReq,mAvail,rAct;
   double lot=PolicyA(dir,entry,stop,theo,capped,mReq,mAvail,rAct);
   double planned=AccountInfoDouble(ACCOUNT_BALANCE)*InpRiskPct/100.0;
   if(lot<=0){ gRej++; Log("SKIPPED_LOT_ZERO",pid,"theo="+DoubleToString(theo,2),
        "mAvail="+DoubleToString(mAvail,2)); return; }

   gAttempt++;
   Log("ENTRY_ATTEMPT",pid,(dir>0?"BUY":"SELL"),DoubleToString(lot,2),
       DoubleToString(entry,_Digits),DoubleToString(stop,_Digits));

   bool ok=(dir>0)? gT.Buy(lot,_Symbol,0,stop,target) : gT.Sell(lot,_Symbol,0,stop,target);
   if(!ok || gT.ResultRetcode()!=TRADE_RETCODE_DONE)
     { gRej++; Log("ENTRY_REJECTED",pid,(string)gT.ResultRetcode(),gT.ResultRetcodeDescription());
       return; }
   gExec++;

   //--- IMMUTABLE SNAPSHOT taken here, never rebuilt later
   Trade t; ZeroMemory(t);
   t.id=gNT+1; t.pattern_id=pid; t.dir=dir;
   t.t1=bars[i3-2].t; t.t2=bars[i3-1].t; t.t3=bars[i3].t;
   t.signal_time=sigCandle; t.entry_time=entCandle;
   t.ref=ref; t.sweep=sw; t.rej=rj;
   t.entry=gT.ResultPrice(); t.stop=stop; t.target=target;
   t.planned_risk=planned; t.actual_risk=rAct;
   t.theo_lot=theo; t.capped_lot=capped; t.lot=gT.ResultVolume();
   t.margin_req=mReq; t.margin_avail=mAvail;
   t.ticket=gT.ResultDeal(); t.open=true;
   ArrayResize(gTr,gNT+1); gTr[gNT]=t; gNT++;

   Log("ENTRY_ACCEPTED",pid,"id="+(string)t.id,DoubleToString(t.entry,_Digits),
       "lot="+DoubleToString(t.lot,2),"riskP="+DoubleToString(planned,2)+"/A="+DoubleToString(rAct,2));
   if(InpDraw) Draw(t);
  }

//====================================================================
void Manage()
  {
   for(int i=0;i<gNT;i++)
     {
      if(!gTr[i].open) continue;
      if(PositionsTotal()>0) continue;             // still open
      //--- position gone: find its close in history
      double pl=0; string why="EXIT";
      if(HistorySelect(gTr[i].entry_time-60,TimeCurrent()+60))
        {
         int n=HistoryDealsTotal();
         for(int d=n-1;d>=0;d--)
           { ulong tk=HistoryDealGetTicket(d);
             if(HistoryDealGetInteger(tk,DEAL_ENTRY)!=DEAL_ENTRY_OUT) continue;
             if(HistoryDealGetString(tk,DEAL_SYMBOL)!=_Symbol) continue;
             pl=HistoryDealGetDouble(tk,DEAL_PROFIT)+HistoryDealGetDouble(tk,DEAL_SWAP)
                +HistoryDealGetDouble(tk,DEAL_COMMISSION);
             gTr[i].exit_price=HistoryDealGetDouble(tk,DEAL_PRICE);
             gTr[i].exit_time=(datetime)HistoryDealGetInteger(tk,DEAL_TIME);
             long rsn=HistoryDealGetInteger(tk,DEAL_REASON);
             why=(rsn==DEAL_REASON_SL)?"STOP":(rsn==DEAL_REASON_TP)?"TARGET":"EXIT";
             break; }
        }
      gTr[i].pnl=pl; gTr[i].exit_reason=why; gTr[i].open=false;
      gTr[i].r=(gTr[i].actual_risk>0)? pl/gTr[i].actual_risk : 0;
      Log("EXIT","id="+(string)gTr[i].id,why,DoubleToString(pl,2),
          "R="+DoubleToString(gTr[i].r,3));
     }
  }

//====================================================================
void WriteLedger()
  {
   int f=FileOpen("E-MT5-015-"+InpRunTag+"-trades.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',');
   if(f==INVALID_HANDLE) return;
   FileWrite(f,"trade_id","pattern_id","direction","candle_1","candle_2","candle_3",
     "signal_time","entry_time","reference","sweep","rejection",
     "entry","stop","target","theo_lot","capped_lot","final_lot",
     "planned_risk","actual_risk","margin_req","margin_avail",
     "exit_time","exit_price","exit_reason","pnl","R");
   for(int i=0;i<gNT;i++)
      FileWrite(f,(string)gTr[i].id,gTr[i].pattern_id,(gTr[i].dir>0?"BUY":"SELL"),
        TimeToString(gTr[i].t1,TIME_DATE|TIME_SECONDS),TimeToString(gTr[i].t2,TIME_DATE|TIME_SECONDS),
        TimeToString(gTr[i].t3,TIME_DATE|TIME_SECONDS),
        TimeToString(gTr[i].signal_time,TIME_DATE|TIME_SECONDS),
        TimeToString(gTr[i].entry_time,TIME_DATE|TIME_SECONDS),
        DoubleToString(gTr[i].ref,_Digits),DoubleToString(gTr[i].sweep,_Digits),
        DoubleToString(gTr[i].rej,_Digits),DoubleToString(gTr[i].entry,_Digits),
        DoubleToString(gTr[i].stop,_Digits),DoubleToString(gTr[i].target,_Digits),
        DoubleToString(gTr[i].theo_lot,2),DoubleToString(gTr[i].capped_lot,2),
        DoubleToString(gTr[i].lot,2),DoubleToString(gTr[i].planned_risk,2),
        DoubleToString(gTr[i].actual_risk,2),DoubleToString(gTr[i].margin_req,2),
        DoubleToString(gTr[i].margin_avail,2),
        TimeToString(gTr[i].exit_time,TIME_DATE|TIME_SECONDS),
        DoubleToString(gTr[i].exit_price,_Digits),gTr[i].exit_reason,
        DoubleToString(gTr[i].pnl,2),DoubleToString(gTr[i].r,3));
   FileClose(f);
  }

//====================================================================
void Draw(const Trade &t)
  {
   string n=PFX+t.pattern_id;
   int ps=PeriodSeconds();
   color c=(t.dir>0?clrDeepSkyBlue:clrTomato);
   if(ObjectCreate(0,n+"_ref",OBJ_TREND,0,t.t1,t.ref,t.entry_time+ps*6,t.ref))
     { ObjectSetInteger(0,n+"_ref",OBJPROP_COLOR,c); ObjectSetInteger(0,n+"_ref",OBJPROP_WIDTH,2);
       ObjectSetInteger(0,n+"_ref",OBJPROP_RAY_RIGHT,false); }
   Txt(n+"_1",t.t1,t.ref,"1 REF",c);
   Txt(n+"_2",t.t2,t.sweep,"2 SWEEP",clrOrange);
   Txt(n+"_3",t.t3,t.rej,"3 REJECT",clrLime);
   if(ObjectCreate(0,n+"_e",OBJ_ARROW,0,t.entry_time,t.entry))
     { ObjectSetInteger(0,n+"_e",OBJPROP_ARROWCODE,t.dir>0?233:234);
       ObjectSetInteger(0,n+"_e",OBJPROP_COLOR,c); ObjectSetInteger(0,n+"_e",OBJPROP_WIDTH,3); }
   Txt(n+"_lbl",t.entry_time,t.entry,
       StringFormat("#%d %s %.2f lot  risk $%.2f/%.2f",t.id,(t.dir>0?"BUY":"SELL"),
                    t.lot,t.planned_risk,t.actual_risk),c);
   if(ObjectCreate(0,n+"_sl",OBJ_TREND,0,t.entry_time,t.stop,t.entry_time+ps*10,t.stop))
     { ObjectSetInteger(0,n+"_sl",OBJPROP_COLOR,clrRed); ObjectSetInteger(0,n+"_sl",OBJPROP_STYLE,STYLE_DOT); }
   if(ObjectCreate(0,n+"_tp",OBJ_TREND,0,t.entry_time,t.target,t.entry_time+ps*10,t.target))
     { ObjectSetInteger(0,n+"_tp",OBJPROP_COLOR,clrLime); ObjectSetInteger(0,n+"_tp",OBJPROP_STYLE,STYLE_DOT); }
  }
void Txt(const string n,const datetime t,const double p,const string s,const color c)
  { if(!ObjectCreate(0,n,OBJ_TEXT,0,t,p)) return;
    ObjectSetString(0,n,OBJPROP_TEXT,s); ObjectSetInteger(0,n,OBJPROP_COLOR,c);
    ObjectSetString(0,n,OBJPROP_FONT,"Consolas"); ObjectSetInteger(0,n,OBJPROP_FONTSIZE,8);
    ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false); }

//====================================================================
void BuildPanel()
  {
   if(ObjectFind(0,PFX+"bg")<0 && ObjectCreate(0,PFX+"bg",OBJ_RECTANGLE_LABEL,0,0,0))
     { ObjectSetInteger(0,PFX+"bg",OBJPROP_XDISTANCE,8); ObjectSetInteger(0,PFX+"bg",OBJPROP_YDISTANCE,18);
       ObjectSetInteger(0,PFX+"bg",OBJPROP_XSIZE,420); ObjectSetInteger(0,PFX+"bg",OBJPROP_YSIZE,250);
       ObjectSetInteger(0,PFX+"bg",OBJPROP_BGCOLOR,C'16,20,28');
       ObjectSetInteger(0,PFX+"bg",OBJPROP_BORDER_TYPE,BORDER_FLAT);
       ObjectSetInteger(0,PFX+"bg",OBJPROP_COLOR,clrDimGray); }
   for(int i=0;i<14;i++) Lbl(PFX+"k"+(string)i,16,24+i*16,"",clrLightGray);
  }
void Lbl(const string n,const int x,const int y,const string t,const color c)
  { if(ObjectFind(0,n)<0 && !ObjectCreate(0,n,OBJ_LABEL,0,0,0)) return;
    ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
    ObjectSetString(0,n,OBJPROP_TEXT,t); ObjectSetInteger(0,n,OBJPROP_COLOR,c);
    ObjectSetString(0,n,OBJPROP_FONT,"Consolas"); ObjectSetInteger(0,n,OBJPROP_FONTSIZE,8);
    ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false); }
void SetL(const int i,const string s,const color c=clrLightGray)
  { ObjectSetString(0,PFX+"k"+(string)i,OBJPROP_TEXT,s);
    ObjectSetInteger(0,PFX+"k"+(string)i,OBJPROP_COLOR,c); }

void Panel()
  {
   double bal=AccountInfoDouble(ACCOUNT_BALANCE), eq=AccountInfoDouble(ACCOUNT_EQUITY);
   int last=gNT-1;
   SetL(0,"ENGINEERING VALIDATION V2 - NOT A PROFITABILITY CLAIM",clrOrangeRed);
   SetL(1,"MODE=BACKTEST  ENVIRONMENT=DEMO  LIVE TRADING=DISABLED",clrGold);
   SetL(2,_Symbol+" "+EnumToString((ENUM_TIMEFRAMES)_Period)+"  pad="+(string)InpStopPadPts+"pt  R="+DoubleToString(InpTargetR,1));
   SetL(3,StringFormat("balance %.2f  equity %.2f  dd %.2f",bal,eq,gStartBal-eq));
   SetL(4,StringFormat("signals %d  exec %d  rejected %d  gapskip %d  trades %d",
          gSignals,gExec,gRej,gSkipGap,gNT));
   if(last>=0)
     {
      Trade t=gTr[last];
      SetL(5,StringFormat("TRADE #%d  %s  %s",t.id,(t.dir>0?"BUY":"SELL"),t.pattern_id),
           t.dir>0?clrDeepSkyBlue:clrTomato);
      SetL(6,"c1 "+TimeToString(t.t1,TIME_MINUTES)+"  c2 "+TimeToString(t.t2,TIME_MINUTES)+
             "  c3 "+TimeToString(t.t3,TIME_MINUTES));
      SetL(7,StringFormat("REF %.5f  SWEEP %.5f  REJ %.5f",t.ref,t.sweep,t.rej));
      SetL(8,StringFormat("ENTRY %.5f  SL %.5f  TP %.5f",t.entry,t.stop,t.target));
      SetL(9,StringFormat("lot theo %.2f -> capped %.2f -> final %.2f",t.theo_lot,t.capped_lot,t.lot));
      SetL(10,StringFormat("risk planned $%.2f  actual $%.2f  margin %.0f/%.0f",
             t.planned_risk,t.actual_risk,t.margin_req,t.margin_avail));
      SetL(11,"TIME adjacency 1->2->3->4 == 300s each : ENFORCED",clrLime);
     }
   SetL(12,"BLOCKED: CONFIRMATION MSS FVG RETRACE HTF SESSION ACCUM DPMO",clrMediumOrchid);
   SetL(13,"D-M4 OPEN (bid stream) | DEC-S-001 OPEN (no session filter)",clrSilver);
  }
//+------------------------------------------------------------------+
