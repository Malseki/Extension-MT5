//+------------------------------------------------------------------+
//| E-MT5-010 — 1-2-3 sweep/rejection PATTERN OBSERVER                |
//|                                                                  |
//| *** NOT A TRADING DETECTOR. NEVER TRADES. NO TRADE FUNCTIONS. *** |
//|                                                                  |
//| It detects a GEOMETRIC PATTERN under an EXPLICITLY DECLARED       |
//| reading of every unresolved ambiguity in SPEC-SW-001 §4.          |
//| It does not decide that the pattern means anything.               |
//|                                                                  |
//| Verdict() is structurally incapable of returning BUY or SELL.     |
//| Detecting a pattern does not change that (SPEC-SW-001 §7).        |
//|                                                                  |
//| EVERY AMBIGUITY IS AN INPUT. Changing an input changes the        |
//| reading, and the reading id is written into every event and       |
//| rendered on the chart. Nothing is silently chosen.                |
//|                                                                  |
//| OUTPUT (Common/Files/)                                            |
//|   E-MT5-010-<tag>-patterns.csv   one row per candidate            |
//|   E-MT5-010-<tag>-report.csv     env, guard, counts, final hash   |
//+------------------------------------------------------------------+
#property copyright "PROJECT TRADER - pattern observer"
#property version   "1.0"
#property strict

//--- SW-1 : what makes Candle 1 a valid reference (SPEC-SW-001 §4.1)
input int    InpRefMode      = 1;      // 0=prev candle(A) 1=n-bar pivot(B)
input int    InpPivotK       = 2;      // pivot half-width when RefMode=1
//--- SW-3 : penetration strictness / minimum excursion (§4.3)
input int    InpDeltaPoints  = 0;      // 0 = any strict penetration
//--- SW-4 : must the sweep candle CLOSE beyond the level? (§4.4)
input int    InpSweepClose   = 2;      // 0=required 1=forbidden 2=either
//--- SW-5 : rejection condition (§4.5)  <-- HIGHEST IMPACT
input int    InpRejectMode   = 2;      // 0=R-a 1=R-b 2=R-c 3=R-d
//--- SW-6 : adjacency (§4.6)
input int    InpMaxGap       = 0;      // extra candles allowed between S and J
//--- SW-8 : boundary equality (§4.8)
input bool   InpBoundaryIn   = false;  // close exactly on level counts as reject
//--- session (DEC-S-001 / D-M6) - DISPLAY ONLY, never gates in this build
input int    InpNYOffsetH    = -4;     // ASSUMED. DEC-S-001 A-2 UNRESOLVED.
input string InpRunTag       = "r1";
input bool   InpDraw         = true;
input int    InpMaxPatterns  = 300;
//--- history scan: removes the Strategy Tester from the evidence path
input int    InpHistoryBars  = 0;      // >0 = scan N closed bars at init
input bool   InpSweepReadings= false;  // true = count detections for EVERY reading

#define PFX "SW_"

int    fhP = INVALID_HANDLE, fhR = INVALID_HANDLE;
ulong  gHash = 1469598103934665603ULL;
long   gBars = 0, gDetect = 0, gArmed = 0, gInvalid = 0;
datetime gLastBar = 0;
int    gDrawn = 0;

string ReadingId()
  {
   return(StringFormat("SW1=%d,K=%d,SW3=%d,SW4=%d,SW5=%d,SW6=%d,SW8=%d",
          InpRefMode,InpPivotK,InpDeltaPoints,InpSweepClose,
          InpRejectMode,InpMaxGap,(int)InpBoundaryIn));
  }
string RejName()
  { return(InpRejectMode==0?"R-a close>=L(S)":InpRejectMode==1?"R-b close>C(S)":
           InpRejectMode==2?"R-c close>ref(reclaim)":"R-d close>H(S)"); }

void HashUpdate(const string s)
  { int n=StringLen(s); for(int i=0;i<n;i++){ gHash^=(ulong)StringGetCharacter(s,i); gHash*=1099511628211ULL; } }
void Rep(const string c,const string i,const string r,const string d1="",const string d2="")
  { if(fhR!=INVALID_HANDLE){ FileWrite(fhR,c,i,r,d1,d2); FileFlush(fhR);} }

//--- PART VII: no reachable BUY/SELL. Unchanged from E-MT5-OBS-002.
string Verdict()
  { return("BLOCKED: verdict semantics undefined (SPEC-SW-001 §5, D-P1/D-P3/D-M1/DEC-S-001)"); }

//+------------------------------------------------------------------+
int OnInit()
  {
   fhP=FileOpen("E-MT5-010-"+InpRunTag+"-patterns.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',');
   fhR=FileOpen("E-MT5-010-"+InpRunTag+"-report.csv",  FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',');
   if(fhP==INVALID_HANDLE||fhR==INVALID_HANDLE) return(INIT_FAILED);

   FileWrite(fhP,"pattern_id","direction","reading",
             "ref_time","ref_level","sweep_time","sweep_low","sweep_close",
             "rej_time","rej_close","t_known","state","rule","hash");
   FileWrite(fhR,"category","item","result","detail1","detail2");

   Rep("ENV","build",(string)TerminalInfoInteger(TERMINAL_BUILD),AccountInfoString(ACCOUNT_SERVER),_Symbol);
   Rep("ENV","timeframe",EnumToString((ENUM_TIMEFRAMES)_Period),"digits="+(string)_Digits,"");
   Rep("ENV","tester",(string)(bool)MQLInfoInteger(MQL_TESTER),
       "visual="+(string)(bool)MQLInfoInteger(MQL_VISUAL_MODE),"");
   Rep("READING","id",ReadingId(),RejName(),"SPEC-SW-001 §4 - NONE OF THESE IS DECIDED");
   Rep("READING","SW-2_bid_ask","BID (chart stream)","D-M4 OPEN",
       "ask not used; cannot be settled on MetaQuotes-Demo");
   Rep("READING","SW-10_session","NOT GATED","DEC-S-001 A-1/A-2/A-3 OPEN",
       "NY offset "+(string)InpNYOffsetH+" is DISPLAY ONLY and ASSUMED");

   //--- DEMO guard (defence in depth; the stronger guard is that no
   //    trade function exists anywhere in this file)
   long tm=AccountInfoInteger(ACCOUNT_TRADE_MODE);
   string tn=(tm==ACCOUNT_TRADE_MODE_DEMO)?"DEMO":(tm==ACCOUNT_TRADE_MODE_CONTEST)?"CONTEST":
             (tm==ACCOUNT_TRADE_MODE_REAL)?"REAL":"UNKNOWN";
   Rep("GUARD","ACCOUNT_TRADE_MODE",tn,"raw="+(string)tm,"REAL refused below");
   if(tm==ACCOUNT_TRADE_MODE_REAL && !MQLInfoInteger(MQL_TESTER))
     { Rep("GUARD","REFUSED","REAL account","observer is DEMO-validation only","");
       Print("E-MT5-010 REFUSING TO RUN ON A REAL ACCOUNT"); return(INIT_FAILED); }

   BuildPanel();
   if(InpHistoryBars>0) HistoryScan();
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   Rep("RESULT","bars",(string)gBars,"detected="+(string)gDetect,
       "armed="+(string)gArmed+" invalidated="+(string)gInvalid);
   Rep("RESULT","final_hash",StringFormat("%I64u",gHash),ReadingId(),"");
   Rep("RESULT","verdict_channel",Verdict(),"no BUY/SELL path exists","");
   if(fhP!=INVALID_HANDLE) FileClose(fhP);
   if(fhR!=INVALID_HANDLE) FileClose(fhR);
   ObjectsDeleteAll(0,PFX);
  }

//+------------------------------------------------------------------+
//| Scan N closed bars using the SAME predicates as the live path.    |
//| If InpSweepReadings, evaluate every combination of the open       |
//| ambiguities and report a count matrix — exhibiting the choices    |
//| instead of resolving them (SPEC-SW-001 §8).                        |
//+------------------------------------------------------------------+
void HistoryScan()
  {
   int avail=Bars(_Symbol,_Period);
   int n=MathMin(InpHistoryBars,avail-10);
   Rep("SCAN","bars_available",(string)avail,"scanning="+(string)n,
       TimeToString(iTime(_Symbol,_Period,n),TIME_DATE|TIME_SECONDS));
   if(n<10){ Rep("SCAN","ABORT","not enough bars","",""); return; }

   if(!InpSweepReadings){ ScanRange(n,InpRefMode,InpPivotK,InpSweepClose,InpRejectMode,true); return; }

   Rep("MATRIX","header","refMode/pivotK","sweepClose","rejectMode -> detections");
   for(int rm=0;rm<2;rm++)
     for(int sc=0;sc<3;sc++)
       for(int rj=0;rj<4;rj++)
         {
          long c=ScanRange(n,rm,(rm==0?0:InpPivotK),sc,rj,false);
          Rep("MATRIX",
              (rm==0?"SW1=A_prev":"SW1=B_pivot"+(string)InpPivotK),
              (sc==0?"SW4=required":sc==1?"SW4=forbidden":"SW4=either"),
              (rj==0?"SW5=R-a":rj==1?"SW5=R-b":rj==2?"SW5=R-c":"SW5=R-d"),
              "detections="+(string)c);
         }
  }

long ScanRange(const int n,const int refMode,const int pk,
               const int sweepClose,const int rejMode,const bool emit)
  {
   long cnt=0;
   double delta=InpDeltaPoints*_Point;
   double eps=InpBoundaryIn?_Point*0.5:0.0;
   for(int j=1;j+3<n;j++)
     {
      int s=j+1, r=j+2;
      if(iTime(_Symbol,_Period,r)==0) continue;
      if(!ValidRefAt(r,refMode,pk)) continue;
      double refLo=iLow(_Symbol,_Period,r);
      double sLo=iLow(_Symbol,_Period,s), sCl=iClose(_Symbol,_Period,s), sHi=iHigh(_Symbol,_Period,s);
      if(!(sLo<refLo-delta)) continue;
      if(!(sLo<sCl)) continue;
      if(sweepClose==0 && !(sCl<refLo)) continue;
      if(sweepClose==1 && !(sCl>=refLo)) continue;
      double jCl=iClose(_Symbol,_Period,j);
      bool rej=false;
      if(rejMode==0) rej=(jCl>=sLo-eps);
      else if(rejMode==1) rej=(jCl>sCl-eps);
      else if(rejMode==2) rej=(jCl>refLo-eps);
      else               rej=(jCl>sHi-eps);
      if(!rej) continue;
      cnt++;
      if(emit) Emit("BULLISH_CANDIDATE",r,s,j,refLo,sLo,sCl,jCl);
     }
   return(cnt);
  }

bool ValidRefAt(const int r,const int refMode,const int pk)
  {
   if(refMode==0) return(true);
   double lo=iLow(_Symbol,_Period,r);
   for(int k=1;k<=pk;k++)
     {
      if(iTime(_Symbol,_Period,r+k)==0) return(false);
      if(iLow(_Symbol,_Period,r+k)<=lo) return(false);
      if(iLow(_Symbol,_Period,r-k)< lo) return(false);
     }
   return(true);
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   datetime bt=iTime(_Symbol,_Period,0);
   if(bt==gLastBar||bt==0) return;
   gLastBar=bt; gBars++;
   Scan();
   UpdatePanel();
   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| Strict/near-adjacent scan on CLOSED bars only.                    |
//| shift 1 = rejection J, shift 2+gap = sweep S, next = reference R  |
//+------------------------------------------------------------------+
void Scan()
  {
   for(int gap=0; gap<=InpMaxGap; gap++)
     {
      int j=1, s=2+gap, r=3+gap;
      if(iTime(_Symbol,_Period,r)==0) continue;

      double refLo=iLow(_Symbol,_Period,r);
      if(!ValidReference(r)) continue;
      gArmed++;

      double delta=InpDeltaPoints*_Point;
      double sLo=iLow(_Symbol,_Period,s), sCl=iClose(_Symbol,_Period,s);
      double sHi=iHigh(_Symbol,_Period,s);

      // P2 penetration (SW-2 = BID stream: bars are Bid, chart_mode=0)
      if(!(sLo < refLo-delta)) continue;
      // P4 lower wick
      if(!(sLo < sCl)) continue;
      // P3/SW-4 sweep-candle close
      if(InpSweepClose==0 && !(sCl<refLo)) continue;
      if(InpSweepClose==1 && !(sCl>=refLo)) continue;

      double jCl=iClose(_Symbol,_Period,j);
      double eps=InpBoundaryIn?_Point*0.5:0.0;
      bool rej=false;
      if(InpRejectMode==0) rej=(jCl>=sLo-eps);
      else if(InpRejectMode==1) rej=(jCl> sCl-eps);
      else if(InpRejectMode==2) rej=(jCl> refLo-eps);
      else                      rej=(jCl> sHi-eps);

      if(!rej){ gInvalid++; continue; }

      Emit("BULLISH_CANDIDATE",r,s,j,refLo,sLo,sCl,jCl);
      return;   // one candidate per bar
     }
  }

bool ValidReference(const int r)
  {
   if(InpRefMode==0) return(true);                       // SW-1 option A
   double lo=iLow(_Symbol,_Period,r);                    // SW-1 option B: pivot
   for(int k=1;k<=InpPivotK;k++)
     {
      if(iTime(_Symbol,_Period,r+k)==0) return(false);
      if(iLow(_Symbol,_Period,r+k) <= lo) return(false); // strictly lowest left
      if(iLow(_Symbol,_Period,r-k) <  lo) return(false); // and right
     }
   return(true);
  }

//+------------------------------------------------------------------+
void Emit(const string dir,const int r,const int s,const int j,
          const double refLo,const double sLo,const double sCl,const double jCl)
  {
   gDetect++;
   datetime tr=iTime(_Symbol,_Period,r), ts=iTime(_Symbol,_Period,s), tj=iTime(_Symbol,_Period,j);
   datetime tKnown=iTime(_Symbol,_Period,0);   // knowable only once J closed

   string pid=StringFormat("SW123_%s_%d_%d",_Symbol,(int)_Period,(long)tr);
   string rec=StringFormat("%s|%s|%d|%d|%d|%s|%s|%s|%s",pid,dir,(long)tr,(long)ts,(long)tj,
              DoubleToString(refLo,_Digits),DoubleToString(sLo,_Digits),
              DoubleToString(sCl,_Digits),DoubleToString(jCl,_Digits));
   HashUpdate(rec);

   FileWrite(fhP,pid,dir,ReadingId(),
     TimeToString(tr,TIME_DATE|TIME_SECONDS),DoubleToString(refLo,_Digits),
     TimeToString(ts,TIME_DATE|TIME_SECONDS),DoubleToString(sLo,_Digits),DoubleToString(sCl,_Digits),
     TimeToString(tj,TIME_DATE|TIME_SECONDS),DoubleToString(jCl,_Digits),
     TimeToString(tKnown,TIME_DATE|TIME_SECONDS),
     "PATTERN_DETECTED","SPEC-SW-001/"+RejName(),StringFormat("%I64u",gHash));
   FileFlush(fhP);

   Print("PATTERN_CANDIDATE ",pid," ref=",DoubleToString(refLo,_Digits),
         " sweepLow=",DoubleToString(sLo,_Digits)," rejClose=",DoubleToString(jCl,_Digits),
         " reading=",ReadingId()," | NOT A SIGNAL");

   if(InpDraw && gDrawn<InpMaxPatterns) DrawPattern(pid,tr,ts,tj,refLo,sLo,jCl);
  }

//+------------------------------------------------------------------+
void DrawPattern(const string pid,const datetime tr,const datetime ts,const datetime tj,
                 const double refLo,const double sLo,const double jCl)
  {
   gDrawn++;
   int ps=PeriodSeconds();
   string n;

   n=PFX+pid+"_lvl";                                     // reference level
   if(ObjectCreate(0,n,OBJ_TREND,0,tr,refLo,tj+ps*3,refLo))
     { ObjectSetInteger(0,n,OBJPROP_COLOR,clrDeepSkyBlue);
       ObjectSetInteger(0,n,OBJPROP_RAY_RIGHT,false);
       ObjectSetInteger(0,n,OBJPROP_WIDTH,2);
       ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false); }

   Tag(PFX+pid+"_1",tr,refLo,"1 REF",clrDeepSkyBlue,ANCHOR_LOWER);
   Tag(PFX+pid+"_2",ts,sLo,  "2 SWEEP",clrOrange,ANCHOR_UPPER);
   Tag(PFX+pid+"_3",tj,jCl,  "3 REJECT",clrLime,ANCHOR_LOWER);

   n=PFX+pid+"_arr";                                     // sweep marker
   if(ObjectCreate(0,n,OBJ_ARROW,0,ts,sLo))
     { ObjectSetInteger(0,n,OBJPROP_ARROWCODE,234);
       ObjectSetInteger(0,n,OBJPROP_COLOR,clrOrange);
       ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false); }

   n=PFX+pid+"_rej";                                     // rejection marker
   if(ObjectCreate(0,n,OBJ_ARROW,0,tj,jCl))
     { ObjectSetInteger(0,n,OBJPROP_ARROWCODE,233);
       ObjectSetInteger(0,n,OBJPROP_COLOR,clrLime);
       ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false); }
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
   Bg(PFX+"bg",8,18,430,236);
   L(PFX+"t1",16,24,"1-2-3 SWEEP/REJECTION - PATTERN OBSERVER",clrWhite,9);
   L(PFX+"t2",16,38,"PATTERN ONLY - NOT A TRADE SIGNAL - SPEC-SW-001 UNFROZEN",clrOrangeRed,7);
   for(int i=0;i<11;i++) L(PFX+"k"+(string)i,16,56+i*16,"",clrLightGray,8);
   L(PFX+"vd",16,236,"",clrMediumOrchid,8);
  }

void UpdatePanel()
  {
   MqlTick tk; SymbolInfoTick(_Symbol,tk);
   datetime srv=TimeTradeServer();
   int srvUTC=(int)MathRound(((double)srv-(double)TimeGMT())/3600.0);
   datetime ny=srv-(datetime)((srvUTC-InpNYOffsetH)*3600);

   SetL(0,"symbol/tf   "+_Symbol+" "+EnumToString((ENUM_TIMEFRAMES)_Period));
   SetL(1,"server time "+TimeToString(srv,TIME_DATE|TIME_SECONDS));
   SetL(2,"NY time     "+TimeToString(ny,TIME_DATE|TIME_SECONDS)+"  (ASSUMED "+(string)InpNYOffsetH+")");
   SetL(3,"session     BLOCKED  (DEC-S-001 A-1/A-2/A-3)");
   SetL(4,"stream      BID      (SW-2 / D-M4 OPEN)");
   SetL(5,"reference   "+(InpRefMode==0?"prev candle (SW-1 A)":"pivot k="+(string)InpPivotK+" (SW-1 B)"));
   SetL(6,"sweep close "+(InpSweepClose==0?"REQUIRED":InpSweepClose==1?"FORBIDDEN":"EITHER")+"  (SW-4)");
   SetL(7,"rejection   "+RejName()+"  (SW-5)");
   SetL(8,"adjacency   maxgap="+(string)InpMaxGap+"  (SW-6)");
   SetL(9,"bars="+(string)gBars+"  armed="+(string)gArmed+
          "  DETECTED="+(string)gDetect+"  rejected="+(string)gInvalid);
   SetL(10,"run="+InpRunTag+"  model="+(MQLInfoInteger(MQL_TESTER)?"TESTER":"LIVE")+
           "  spec=SPEC-SW-001 (unfrozen)");
   ObjectSetString(0,PFX+"vd",OBJPROP_TEXT,"VERDICT: "+Verdict());
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
