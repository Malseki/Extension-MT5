//+------------------------------------------------------------------+
//| E-MT5-008 — Tester model fidelity: is intrabar order fabricated? |
//|                                                                  |
//| *** NOT THE TRADING DETECTOR. NO TRADING LOGIC. NEVER TRADES. *** |
//|                                                                  |
//| QUESTION (closes D-M5 with evidence instead of documentation)     |
//|   E-MT5-007 proved on live history that M1 OHLC does not          |
//|   determine intrabar order, and that real ticks resolve it.       |
//|   The Strategy Tester can also SYNTHESISE ticks. Do the generated |
//|   models reproduce the real intrabar order, or invent one?        |
//|                                                                  |
//| METHOD                                                            |
//|   Run the identical symbol/timeframe/date range under each tester |
//|   model. For every bar, record — from the tick stream the tester  |
//|   actually delivers — the index of the tick that established the  |
//|   bar's high and the bar's low, and therefore which came first.   |
//|   Hash the whole sequence. Compare hashes across models.          |
//|                                                                  |
//| WHY THIS IS THE RIGHT MEASUREMENT                                 |
//|   Bar-level facts (O,H,L,C) are built from the same M1 data in    |
//|   every model, so a bar-level probe would return identical logs   |
//|   and prove nothing. Only an ORDER-SENSITIVE probe can separate   |
//|   the models. That is the defect this file exists to avoid.       |
//|                                                                  |
//| ALSO MEASURED                                                     |
//|   Environment discrimination for the DEMO/REAL guard:             |
//|   ACCOUNT_TRADE_MODE, MQL_TESTER, ACCOUNT_SERVER, ACCOUNT_LOGIN.  |
//|                                                                  |
//| OUTPUT (Common/Files/)                                            |
//|   E-MT5-008-<tag>-bars.csv     one row per bar                    |
//|   E-MT5-008-<tag>-report.csv   env, guard probe, final hash       |
//+------------------------------------------------------------------+
#property copyright "PROJECT TRADER - feasibility experiment"
#property version   "1.0"
#property strict

input string InpRunTag = "m4";     // one tag per tester model

int      fhB = INVALID_HANDLE, fhR = INVALID_HANDLE;
ulong    gHash = 1469598103934665603ULL;
long     gBars = 0, gTicksTotal = 0;
long     gHiFirst = 0, gLoFirst = 0, gUndet = 0;

datetime gBarTime  = 0;
int      gTickIdx  = 0;
double   gHi = 0, gLo = 0;
int      gHiIdx = -1, gLoIdx = -1;
double   gOpen = 0;

void HashUpdate(const string s)
  {
   int n = StringLen(s);
   for(int i = 0; i < n; i++){ gHash ^= (ulong)StringGetCharacter(s,i); gHash *= 1099511628211ULL; }
  }

void Rep(const string c,const string i,const string r,const string d1="",const string d2="")
  { if(fhR!=INVALID_HANDLE){ FileWrite(fhR,c,i,r,d1,d2); FileFlush(fhR); } }

//+------------------------------------------------------------------+
int OnInit()
  {
   fhB = FileOpen("E-MT5-008-"+InpRunTag+"-bars.csv",
                  FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON, ',');
   fhR = FileOpen("E-MT5-008-"+InpRunTag+"-report.csv",
                  FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON, ',');
   if(fhB==INVALID_HANDLE || fhR==INVALID_HANDLE) return(INIT_FAILED);

   FileWrite(fhB,"bar_time","ticks_in_bar","open","high","low",
                 "idx_high","idx_low","order","running_hash");
   FileWrite(fhR,"category","item","result","detail1","detail2");

   Rep("ENV","build",(string)TerminalInfoInteger(TERMINAL_BUILD),
       AccountInfoString(ACCOUNT_SERVER),_Symbol);
   Rep("ENV","run_tag",InpRunTag,EnumToString((ENUM_TIMEFRAMES)_Period),"");
   Rep("ENV","tester",(string)(bool)MQLInfoInteger(MQL_TESTER),
       "visual="+(string)(bool)MQLInfoInteger(MQL_VISUAL_MODE),"");

   //--- ENVIRONMENT GUARD PROBE (design input, not an implementation)
   long tm = AccountInfoInteger(ACCOUNT_TRADE_MODE);
   string tmName = (tm==ACCOUNT_TRADE_MODE_DEMO)   ? "DEMO"
                 : (tm==ACCOUNT_TRADE_MODE_CONTEST)? "CONTEST"
                 : (tm==ACCOUNT_TRADE_MODE_REAL)   ? "REAL" : "UNKNOWN";
   Rep("GUARD","ACCOUNT_TRADE_MODE",tmName,"raw="+(string)tm,
       "REAL=2 must be refused by any future guard");
   Rep("GUARD","account",(string)AccountInfoInteger(ACCOUNT_LOGIN),
       AccountInfoString(ACCOUNT_SERVER),AccountInfoString(ACCOUNT_COMPANY));
   Rep("GUARD","trade_allowed_terminal",
       (string)(bool)TerminalInfoInteger(TERMINAL_TRADE_ALLOWED),
       "expert="+(string)(bool)MQLInfoInteger(MQL_TRADE_ALLOWED),
       "observability EA never trades regardless");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   FinalizeBar();
   Rep("RESULT","bars",(string)gBars,"ticks="+(string)gTicksTotal,"");
   Rep("RESULT","order_counts","hi_first="+(string)gHiFirst,
       "lo_first="+(string)gLoFirst,"undetermined="+(string)gUndet);
   Rep("RESULT","final_hash",StringFormat("%I64u",gHash),
       "FNV-1a over per-bar intrabar order","");
   if(fhB!=INVALID_HANDLE) FileClose(fhB);
   if(fhR!=INVALID_HANDLE) FileClose(fhR);
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   MqlTick t;
   if(!SymbolInfoTick(_Symbol,t)) return;
   datetime bt = iTime(_Symbol,_Period,0);
   if(bt==0) return;

   if(bt != gBarTime)
     {
      FinalizeBar();
      gBarTime = bt; gTickIdx = 0;
      gOpen = t.bid; gHi = t.bid; gLo = t.bid; gHiIdx = 0; gLoIdx = 0;
     }

   gTickIdx++; gTicksTotal++;
   // the tick that ESTABLISHES the extreme is the last one to extend it
   if(t.bid > gHi){ gHi = t.bid; gHiIdx = gTickIdx; }
   if(t.bid < gLo){ gLo = t.bid; gLoIdx = gTickIdx; }
  }

//+------------------------------------------------------------------+
void FinalizeBar()
  {
   if(gBarTime==0 || gTickIdx==0) return;
   gBars++;

   string order;
   if(gHiIdx == gLoIdx)      { order = "UNDETERMINED"; gUndet++; }
   else if(gHiIdx < gLoIdx)  { order = "HIGH_FIRST";   gHiFirst++; }
   else                      { order = "LOW_FIRST";    gLoFirst++; }

   string rec = StringFormat("%d|%d|%d|%d|%s",(long)gBarTime,gTickIdx,
                             gHiIdx,gLoIdx,order);
   HashUpdate(rec);

   FileWrite(fhB,TimeToString(gBarTime,TIME_DATE|TIME_SECONDS),(string)gTickIdx,
             DoubleToString(gOpen,_Digits),DoubleToString(gHi,_Digits),
             DoubleToString(gLo,_Digits),(string)gHiIdx,(string)gLoIdx,order,
             StringFormat("%I64u",gHash));
   FileFlush(fhB);
  }
//+------------------------------------------------------------------+
