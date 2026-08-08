//+------------------------------------------------------------------+
//| E-MT5-OBS-002 — Strategy Tester visual replay + determinism      |
//|                                                                  |
//| *** THIS IS NOT THE TRADING DETECTOR ***                         |
//|                                                                  |
//| It contains NO liquidity, sweep, MSS, FVG, displacement,          |
//| retracement, reaction or confirmation logic. The events it emits  |
//| come from a SYNTHETIC GENERATOR whose only property is that it is |
//| deterministic. It makes no claim about any market.                |
//|                                                                  |
//| IT NEVER TRADES. No trade function is referenced anywhere.        |
//|                                                                  |
//| WHAT IT MEASURES                                                  |
//|   1. Does the renderer work inside the Strategy Tester (visual)?  |
//|   2. Do all object classes render and stay anchored to their      |
//|      timestamps/prices under replay?                              |
//|   3. Is the event stream deterministic across identical runs?     |
//|      (FNV-1a hash chain over every emitted event)                 |
//|   4. Do the PART VII safety invariants actually hold, verified by |
//|      reading the rendered text back off the chart?                |
//|   5. Can screenshots be captured from the tester?                 |
//|                                                                  |
//| SAFETY INVARIANT, ENFORCED STRUCTURALLY                           |
//|   Verdict() is INCAPABLE of returning BUY or SELL. Those strings  |
//|   do not exist as reachable return values. The specification has  |
//|   not defined the verdict, so the code cannot express one.        |
//|   This is deliberate and is tested by IT-4.                       |
//|                                                                  |
//| OUTPUT (Common/Files/)                                            |
//|   E-MT5-OBS-002-<tag>-events.csv      event log + rolling hash    |
//|   E-MT5-OBS-002-<tag>-report.csv      env, invariants, final hash |
//|   E-MT5-OBS-002-<tag>-<n>.png         chart captures              |
//+------------------------------------------------------------------+
#property copyright "PROJECT TRADER - observability experiment"
#property version   "1.0"
#property strict

input string InpRunTag        = "run1";   // distinguishes repeated runs
input int    InpEventEveryBar = 5;        // synthetic event cadence (bars)
input int    InpShotEveryBar  = 60;       // screenshot cadence (bars)
input int    InpMaxObjects    = 400;      // retention cap
input bool   InpDrawObjects   = true;

#define PFX "OBS2_"

//--- engine state vocabulary. NOT truth values: see MT5-OBS-001 §2 ---
#define ST_PASS    0
#define ST_FAIL    1
#define ST_WAITING 2
#define ST_UNKNOWN 3
#define ST_BLOCKED 4

string StateName(const int s)
  {
   switch(s){
     case ST_PASS:    return("PASS");
     case ST_FAIL:    return("FAIL");
     case ST_WAITING: return("WAITING");
     case ST_UNKNOWN: return("UNKNOWN");
     default:         return("BLOCKED");
   }
  }
color StateColor(const int s)
  {
   switch(s){
     case ST_PASS:    return(clrLime);
     case ST_FAIL:    return(clrTomato);
     case ST_WAITING: return(clrGold);
     case ST_UNKNOWN: return(clrSilver);
     default:         return(clrMediumOrchid);
   }
  }

string  STAGE[9] = {"CONTEXT","LIQUIDITY","SWEEP","DISPLACEMENT","STRUCTURE",
                    "FVG","RETRACEMENT","CONFIRMATION","VERDICT"};
int     gStage[9];

int      fhE = INVALID_HANDLE, fhR = INVALID_HANDLE;
ulong    gHash = 1469598103934665603ULL;   // FNV-1a offset basis
long     gEvents = 0, gBars = 0, gShots = 0;
datetime gLastBar = 0;
string   gObjNames[];
int      gObjCount = 0;

//+------------------------------------------------------------------+
//| FNV-1a over a string — the determinism instrument                 |
//+------------------------------------------------------------------+
void HashUpdate(const string s)
  {
   int n = StringLen(s);
   for(int i = 0; i < n; i++)
     {
      gHash ^= (ulong)StringGetCharacter(s, i);
      gHash *= 1099511628211ULL;
     }
  }

void Rep(const string cat, const string item, const string res,
         const string d1 = "", const string d2 = "")
  { if(fhR != INVALID_HANDLE){ FileWrite(fhR, cat, item, res, d1, d2); FileFlush(fhR); } }

//+------------------------------------------------------------------+
//| VERDICT — structurally incapable of BUY/SELL (PART VII)           |
//| There is no code path returning "BUY" or "SELL". When the         |
//| specification defines them, this is the single place to change.   |
//+------------------------------------------------------------------+
string Verdict(int &st[])
  {
   for(int i = 0; i < 8; i++) if(st[i] == ST_BLOCKED) return("BLOCKED");
   for(int i = 0; i < 8; i++) if(st[i] == ST_UNKNOWN) return("UNKNOWN");
   for(int i = 0; i < 8; i++) if(st[i] == ST_WAITING) return("WAITING");
   for(int i = 0; i < 8; i++) if(st[i] == ST_FAIL)    return("NO OPPORTUNITY");
   // All prerequisites PASS. A real system would consult the decision
   // layer here. It does not exist, so the only honest answer is:
   return("BLOCKED: verdict semantics undefined (D-P1/D-P3/D-M1/DEC-S-001)");
  }

//+------------------------------------------------------------------+
int OnInit()
  {
   string tag = InpRunTag;
   fhE = FileOpen("E-MT5-OBS-002-" + tag + "-events.csv",
                  FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON, ',');
   fhR = FileOpen("E-MT5-OBS-002-" + tag + "-report.csv",
                  FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON, ',');
   if(fhE == INVALID_HANDLE || fhR == INVALID_HANDLE)
     { Print("OBS2: cannot open output"); return(INIT_FAILED); }

   FileWrite(fhE, "seq","event_id","kind","t_occurred","t_known",
                  "price1","price2","running_hash");
   FileWrite(fhR, "category","item","result","detail1","detail2");

   Rep("ENV","build",(string)TerminalInfoInteger(TERMINAL_BUILD),
       AccountInfoString(ACCOUNT_SERVER), _Symbol);
   Rep("ENV","timeframe",EnumToString((ENUM_TIMEFRAMES)_Period),
       "digits="+(string)_Digits, "point="+DoubleToString(_Point,8));
   Rep("ENV","tester",(string)(bool)MQLInfoInteger(MQL_TESTER),
       "visual="+(string)(bool)MQLInfoInteger(MQL_VISUAL_MODE),
       "optimization="+(string)(bool)MQLInfoInteger(MQL_OPTIMIZATION));
   Rep("ENV","run_tag",tag,"ea_version=1.0","spec_snapshot=unfrozen");
   Rep("ENV","inputs","eventEveryBar="+(string)InpEventEveryBar,
       "shotEveryBar="+(string)InpShotEveryBar,"maxObjects="+(string)InpMaxObjects);

   RunInvariantTests();
   BuildPanel();
   ChartRedraw();
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   Rep("RESULT","bars_seen",(string)gBars,"events="+(string)gEvents,
       "screenshots="+(string)gShots);
   Rep("RESULT","final_hash",StringFormat("%I64u", gHash),
       "FNV-1a over all emitted events","");
   Rep("LIFECYCLE","deinit_reason",(string)reason,"","");
   Shot("final");
   if(fhE != INVALID_HANDLE){ FileClose(fhE); fhE = INVALID_HANDLE; }
   if(fhR != INVALID_HANDLE){ FileClose(fhR); fhR = INVALID_HANDLE; }
   ObjectsDeleteAll(0, PFX);
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   datetime bt = iTime(_Symbol, _Period, 0);
   if(bt == gLastBar || bt == 0) return;      // bar-close driven
   gLastBar = bt;
   gBars++;

   // deterministic stage states so every one of the five renders
   for(int i = 0; i < 9; i++)
      gStage[i] = (int)((gBars / (i + 1)) % 5);
   gStage[8] = ST_BLOCKED;                     // verdict stage: spec undefined

   if(gBars % InpEventEveryBar == 0) EmitSynthetic(bt);

   UpdatePanel();
   if(InpShotEveryBar > 0 && gBars % InpShotEveryBar == 0) Shot((string)gBars);
   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| SYNTHETIC event generator. Deterministic function of bar data.    |
//| NOT a market claim. NOT a trading rule.                           |
//+------------------------------------------------------------------+
void EmitSynthetic(const datetime bt)
  {
   MqlRates r[];
   if(CopyRates(_Symbol, _Period, 1, 1, r) != 1) return;   // last CLOSED bar

   string kinds[4] = {"LEVEL","ZONE","LINE","MARK"};
   string kind = kinds[(int)((gBars / InpEventEveryBar) % 4)];

   // identity mirrors REDTEAM-002 §2.2: (kind, symbol, tf, birth_instant)
   string eid = kind + "_" + _Symbol + "_" + (string)_Period + "_" + (string)(long)r[0].time;

   datetime t_occurred = r[0].time;            // the bar it describes
   datetime t_known    = bt;                   // when it became knowable
   double   p1 = r[0].high, p2 = r[0].low;

   gEvents++;
   string rec = StringFormat("%d|%s|%s|%d|%d|%s|%s", gEvents, eid, kind,
                             (long)t_occurred, (long)t_known,
                             DoubleToString(p1,_Digits), DoubleToString(p2,_Digits));
   HashUpdate(rec);

   FileWrite(fhE, (string)gEvents, eid, kind,
             TimeToString(t_occurred, TIME_DATE|TIME_SECONDS),
             TimeToString(t_known,    TIME_DATE|TIME_SECONDS),
             DoubleToString(p1,_Digits), DoubleToString(p2,_Digits),
             StringFormat("%I64u", gHash));
   FileFlush(fhE);

   if(InpDrawObjects) Draw(kind, eid, t_occurred, t_known, p1, p2);
  }

//+------------------------------------------------------------------+
//| Renderer: pure function of the emitted event. No interpretation.  |
//+------------------------------------------------------------------+
void Draw(const string kind, const string eid,
          const datetime t_occ, const datetime t_kn,
          const double p1, const double p2)
  {
   string n = PFX + eid;
   ObjectDelete(0, n);
   bool ok = false;

   if(kind == "LEVEL")
     { ok = ObjectCreate(0,n,OBJ_TREND,0,t_occ,p1,t_kn+PeriodSeconds()*10,p1);
       ObjectSetInteger(0,n,OBJPROP_RAY_RIGHT,false); }
   else if(kind == "ZONE")
     { ok = ObjectCreate(0,n,OBJ_RECTANGLE,0,t_occ,p1,t_kn+PeriodSeconds()*8,p2);
       ObjectSetInteger(0,n,OBJPROP_FILL,true); }
   else if(kind == "LINE")
     { ok = ObjectCreate(0,n,OBJ_TREND,0,t_occ,p2,t_kn,p1); }
   else
     { ok = ObjectCreate(0,n,OBJ_ARROW,0,t_kn,p2);
       ObjectSetInteger(0,n,OBJPROP_ARROWCODE,159); }

   if(!ok) return;
   ObjectSetInteger(0,n,OBJPROP_COLOR,
      kind=="LEVEL"?clrDeepSkyBlue:(kind=="ZONE"?C'20,60,90':(kind=="LINE"?clrOrange:clrWhite)));
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,n,OBJPROP_BACK,kind=="ZONE");
   Track(n);
  }

void Track(const string n)
  {
   ArrayResize(gObjNames, gObjCount + 1);
   gObjNames[gObjCount++] = n;
   if(gObjCount > InpMaxObjects)                 // retention policy (D-V5)
     {
      ObjectDelete(0, gObjNames[0]);
      for(int i = 1; i < gObjCount; i++) gObjNames[i-1] = gObjNames[i];
      gObjCount--; ArrayResize(gObjNames, gObjCount);
     }
  }

//+------------------------------------------------------------------+
//| PART VII invariants, verified by reading rendered text back       |
//+------------------------------------------------------------------+
void RunInvariantTests()
  {
   // IT-1 BLOCKED must render as BLOCKED, never as BUY/SELL
   Lbl(PFX+"it", 10, 600, StateName(ST_BLOCKED), StateColor(ST_BLOCKED), 8);
   string got = ObjectGetString(0, PFX+"it", OBJPROP_TEXT);
   Rep("INVARIANT","IT-1 BLOCKED renders as BLOCKED",
       (got=="BLOCKED")?"PASS":"FAIL", "rendered="+got, "");
   Rep("INVARIANT","IT-1b BLOCKED never renders BUY/SELL",
       (StringFind(got,"BUY")<0 && StringFind(got,"SELL")<0)?"PASS":"FAIL","rendered="+got,"");

   // IT-2 UNKNOWN must not become FAIL
   Lbl(PFX+"it", 10, 600, StateName(ST_UNKNOWN), StateColor(ST_UNKNOWN), 8);
   got = ObjectGetString(0, PFX+"it", OBJPROP_TEXT);
   Rep("INVARIANT","IT-2 UNKNOWN not silently FAIL",
       (got=="UNKNOWN")?"PASS":"FAIL","rendered="+got,"");

   // IT-3 WAITING must not become UNKNOWN
   Lbl(PFX+"it", 10, 600, StateName(ST_WAITING), StateColor(ST_WAITING), 8);
   got = ObjectGetString(0, PFX+"it", OBJPROP_TEXT);
   Rep("INVARIANT","IT-3 WAITING not silently UNKNOWN",
       (got=="WAITING")?"PASS":"FAIL","rendered="+got,"");
   ObjectDelete(0, PFX+"it");

   // IT-4 Verdict() cannot emit BUY/SELL under ANY stage combination.
   // Exhaustive over 5^8 would be 390,625; sample the structured cases
   // plus the all-PASS case which is the only one that could tempt it.
   int st[9]; bool leaked = false; int cases = 0;
   for(int a = 0; a < 5; a++)
     for(int b = 0; b < 5; b++)
       for(int c = 0; c < 5; c++)
         {
          for(int i = 0; i < 9; i++) st[i] = ST_PASS;
          st[0]=a; st[3]=b; st[7]=c; cases++;
          string v = Verdict(st);
          if(StringFind(v,"BUY")>=0 || StringFind(v,"SELL")>=0) leaked = true;
         }
   for(int i = 0; i < 9; i++) st[i] = ST_PASS;       // the all-PASS case
   string vAll = Verdict(st); cases++;
   if(StringFind(vAll,"BUY")>=0 || StringFind(vAll,"SELL")>=0) leaked = true;

   Rep("INVARIANT","IT-4 Verdict() cannot emit BUY/SELL",
       leaked?"FAIL":"PASS", "cases="+(string)cases, "all_pass_returns="+vAll);

   // IT-5 a BLOCKED prerequisite must block the verdict
   for(int i = 0; i < 9; i++) st[i] = ST_PASS;
   st[4] = ST_BLOCKED;
   string vB = Verdict(st);
   Rep("INVARIANT","IT-5 BLOCKED prerequisite blocks verdict",
       (vB=="BLOCKED")?"PASS":"FAIL","returned="+vB,"");
  }

//+------------------------------------------------------------------+
void BuildPanel()
  {
   Bg(PFX+"bg", 8, 18, 330, 250);
   Lbl(PFX+"t1", 16, 24, "OBSERVABILITY PROTOTYPE - E-MT5-OBS-002", clrWhite, 9);
   Lbl(PFX+"t2", 16, 38, "SYNTHETIC EVENTS - NOT A SIGNAL", clrOrangeRed, 7);
   Lbl(PFX+"hdr",16, 52, "", clrLightGray, 8);
   for(int i = 0; i < 9; i++)
     {
      Lbl(PFX+"s"+(string)i,  16, 72+i*18, STAGE[i], clrLightGray, 8);
      Lbl(PFX+"v"+(string)i, 150, 72+i*18, "UNKNOWN", clrSilver, 8);
      Lbl(PFX+"r"+(string)i, 232, 72+i*18, "", clrDimGray, 7);
     }
   Lbl(PFX+"vd", 16, 236, "", clrWhite, 8);
  }

void UpdatePanel()
  {
   MqlTick tk; SymbolInfoTick(_Symbol, tk);
   int sp = (int)MathRound((tk.ask - tk.bid)/_Point);
   ObjectSetString(0, PFX+"hdr", OBJPROP_TEXT,
      _Symbol+" "+EnumToString((ENUM_TIMEFRAMES)_Period)+"  "+
      DoubleToString(tk.bid,_Digits)+"  sp="+(string)sp+"  bars="+(string)gBars);

   string rule[9] = {"D-M1","DEC-020","DEC-023","DEC-026","DEC-029",
                     "DEC-036","DEC-030","DEC-044","D-P3"};
   for(int i = 0; i < 9; i++)
     {
      ObjectSetString (0, PFX+"v"+(string)i, OBJPROP_TEXT,  StateName(gStage[i]));
      ObjectSetInteger(0, PFX+"v"+(string)i, OBJPROP_COLOR, StateColor(gStage[i]));
      ObjectSetString (0, PFX+"r"+(string)i, OBJPROP_TEXT,  rule[i]);
     }
   string v = Verdict(gStage);
   ObjectSetString (0, PFX+"vd", OBJPROP_TEXT, "VERDICT: " + v);
   ObjectSetInteger(0, PFX+"vd", OBJPROP_COLOR,
      (StringFind(v,"BLOCKED")>=0) ? clrMediumOrchid : clrSilver);
  }

//+------------------------------------------------------------------+
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

void Lbl(const string n,const int x,const int y,const string txt,
         const color c,const int size)
  {
   if(ObjectFind(0,n)<0 && !ObjectCreate(0,n,OBJ_LABEL,0,0,0)) return;
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetString (0,n,OBJPROP_TEXT,txt);    ObjectSetInteger(0,n,OBJPROP_COLOR,c);
   ObjectSetString (0,n,OBJPROP_FONT,"Consolas");
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,size);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
  }

void Shot(const string tag)
  {
   ChartRedraw();
   string f = "E-MT5-OBS-002-" + InpRunTag + "-" + tag + ".png";
   if(ChartScreenShot(0, f, 1400, 800, ALIGN_RIGHT)) gShots++;
   Rep("RENDER","screenshot_"+tag, "attempted", f, "");
  }
//+------------------------------------------------------------------+
