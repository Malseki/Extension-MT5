//+------------------------------------------------------------------+
//| E-MT5-OBS-001 — OBSERVABILITY PROTOTYPE                          |
//|                                                                  |
//| *** THIS IS NOT THE TRADING DETECTOR ***                         |
//|                                                                  |
//| Every value drawn here is SYNTHETIC and hard-coded. It contains   |
//| no liquidity logic, no sweep logic, no MSS, no FVG, no           |
//| retracement, no confirmation. It cannot and does not decide      |
//| anything about the market.                                       |
//|                                                                  |
//| PURPOSE                                                          |
//|   Empirically establish what MT5 build 6096 can actually render   |
//|   and signal, so the observability architecture is designed on    |
//|   measurements instead of documentation.                          |
//|                                                                  |
//| IT NEVER TRADES. No OrderSend, no trade functions, no includes    |
//|   that perform trading. Observation and rendering only.           |
//|                                                                  |
//| OUTPUT  Common/Files/E-MT5-OBS-001-capabilities.csv               |
//|         MQL5/Files/E-MT5-OBS-001-chart.png  (ChartScreenShot)     |
//+------------------------------------------------------------------+
#property copyright "PROJECT TRADER - observability prototype"
#property version   "1.0"
#property strict

input bool InpTestModalAlert = false;  // Alert() opens a MODAL dialog - off by default
input int  InpStressObjects  = 500;    // object-count stress test
input int  InpScreenshotW    = 1400;
input int  InpScreenshotH    = 800;

#define PFX "OBS001_"

int fh = INVALID_HANDLE;
int gRow = 0;

//--- state vocabulary the real engine will need. SYNTHETIC values here.
string StateName(const int s)
  { return(s==0?"PASS":(s==1?"FAIL":(s==2?"WAITING":"UNKNOWN"))); }
color  StateColor(const int s)
  { return(s==0?clrLime:(s==1?clrTomato:(s==2?clrGold:clrGray))); }

void Cap(const string category, const string item, const string result,
         const string detail = "", const string note = "")
  { if(fh!=INVALID_HANDLE){ FileWrite(fh,category,item,result,detail,note); FileFlush(fh);} }

//+------------------------------------------------------------------+
int OnInit()
  {
   fh = FileOpen("E-MT5-OBS-001-capabilities.csv",
                 FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON, ',');
   if(fh==INVALID_HANDLE){ Print("OBS001: cannot open output"); return(INIT_FAILED); }
   FileWrite(fh,"category","item","result","detail","note");

   Cap("ENV","build",(string)TerminalInfoInteger(TERMINAL_BUILD),
       AccountInfoString(ACCOUNT_SERVER),_Symbol);
   Cap("ENV","timeframe",EnumToString((ENUM_TIMEFRAMES)_Period),"","");
   Cap("ENV","max_bars_setting",(string)TerminalInfoInteger(TERMINAL_MAXBARS),"","");
   Cap("ENV","memory_used_mb",(string)TerminalInfoInteger(TERMINAL_MEMORY_USED),
       "avail="+(string)TerminalInfoInteger(TERMINAL_MEMORY_AVAILABLE),"");
   Cap("ENV","is_tester",(string)(bool)MQLInfoInteger(MQL_TESTER),
       "visual="+(string)(bool)MQLInfoInteger(MQL_VISUAL_MODE),"");
   Cap("ENV","chart_bars",(string)Bars(_Symbol,_Period),"","");

   TestObjects();
   TestPanel();
   TestSignalChannels();
   TestStress();
   TestScreenshot();

   ChartRedraw();
   EventSetTimer(5);
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   Cap("LIFECYCLE","deinit_reason",(string)reason,
       "4=CHARTCHANGE 3=RECOMPILE 1=REMOVE 0=PROGRAM","");
   ObjectsDeleteAll(0,PFX);
   if(fh!=INVALID_HANDLE){ FileClose(fh); fh=INVALID_HANDLE; }
  }

void OnTick(){}                      // deliberately empty: no logic, no trading
void OnTimer(){ ChartRedraw(); }

//+------------------------------------------------------------------+
//| 1. Which object types can actually be created and read back?      |
//+------------------------------------------------------------------+
void TestObjects()
  {
   double px = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(px<=0) px = iClose(_Symbol,_Period,0);
   double rng = 30*_Point;
   datetime t0 = iTime(_Symbol,_Period,20);
   datetime t1 = iTime(_Symbol,_Period,5);
   if(t0==0) t0 = TimeCurrent()-1200;
   if(t1==0) t1 = TimeCurrent()-300;

   Try(OBJ_HLINE,      PFX+"hline",  t0, px+rng,      0,0,        "liquidity level (synthetic)");
   Try(OBJ_RECTANGLE,  PFX+"rect",   t0, px+rng*0.6,  t1, px+rng*0.3,"FVG box (synthetic)");
   Try(OBJ_TREND,      PFX+"trend",  t0, px-rng*0.2,  t1, px+rng*0.2,"MSS break level (synthetic)");
   Try(OBJ_VLINE,      PFX+"vline",  t1, 0,           0,0,        "event time marker");
   Try(OBJ_ARROW,      PFX+"arrow",  t1, px-rng*0.5,  0,0,        "sweep marker");
   Try(OBJ_TEXT,       PFX+"text",   t1, px+rng*0.8,  0,0,        "anchored text");
   Try(OBJ_ARROWED_LINE,PFX+"aline", t0, px-rng*0.8,  t1, px-rng*0.6,"impulse arrow");
   Try(OBJ_CHANNEL,    PFX+"chan",   t0, px-rng,      t1, px-rng*0.7,"retracement band");
   Try(OBJ_FIBO,       PFX+"fibo",   t0, px-rng,      t1, px+rng,   "50/70.5 retracement");
   Try(OBJ_RECTANGLE_LABEL,PFX+"panelbg",0,0,0,0,               "panel background (pixel-anchored)");
   Try(OBJ_LABEL,      PFX+"lbl",    0, 0, 0, 0,                 "pixel-anchored label");
   Try(OBJ_BUTTON,     PFX+"btn",    0, 0, 0, 0,                 "interactive control");
   Try(OBJ_EDIT,       PFX+"edit",   0, 0, 0, 0,                 "text input (labeling UI?)");
  }

void Try(const ENUM_OBJECT type, const string name,
         const datetime t1, const double p1,
         const datetime t2, const double p2, const string purpose)
  {
   ObjectDelete(0,name);
   ResetLastError();
   bool ok = ObjectCreate(0,name,type,0,t1,p1,t2,p2);
   int  err = GetLastError();
   bool found = (ObjectFind(0,name) >= 0);
   Cap("OBJECT",EnumToString(type), ok&&found ? "OK":"FAIL",
       "err="+(string)err+" found="+(string)found, purpose);
   if(!ok) return;

   // properties every renderer needs
   ObjectSetInteger(0,name,OBJPROP_COLOR,clrDodgerBlue);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,name,OBJPROP_BACK,true);
   if(type==OBJ_RECTANGLE){ ObjectSetInteger(0,name,OBJPROP_FILL,true); }
   if(type==OBJ_TEXT||type==OBJ_LABEL||type==OBJ_BUTTON||type==OBJ_EDIT)
      ObjectSetString(0,name,OBJPROP_TEXT,"OBS PROTOTYPE");
   if(type==OBJ_LABEL||type==OBJ_BUTTON||type==OBJ_EDIT||type==OBJ_RECTANGLE_LABEL)
     { ObjectSetInteger(0,name,OBJPROP_XDISTANCE,20);
       ObjectSetInteger(0,name,OBJPROP_YDISTANCE,300); }
   // read a property back: proves the object is real, not just accepted
   long c = ObjectGetInteger(0,name,OBJPROP_COLOR);
   Cap("OBJECT_RW",EnumToString(type), (c==clrDodgerBlue)?"READBACK_OK":"READBACK_MISMATCH",
       "color="+(string)c,"");
  }

//+------------------------------------------------------------------+
//| 2. The debug panel the project actually wants.                    |
//|    Values are SYNTHETIC placeholders, not detector output.        |
//+------------------------------------------------------------------+
void TestPanel()
  {
   string stages[9] = {"LIQUIDITY","SWEEP","IMPULSE","MSS","FVG",
                       "RETRACEMENT","REACTION","CONFIRMATION","VERDICT"};
   int    demo[9]   = {0,0,0,2,3,2,3,3,2};   // PASS,PASS,PASS,WAITING,UNKNOWN,...

   Bg(PFX+"pbg",10,20,260,20+9*18+34);
   Lbl(PFX+"ptitle",18,26,"OBSERVABILITY PROTOTYPE",clrWhite,10);
   Lbl(PFX+"psub",18,42,"SYNTHETIC VALUES - NOT A SIGNAL",clrSilver,7);

   for(int i=0;i<9;i++)
     {
      Lbl(PFX+"st"+(string)i, 18, 62+i*18, stages[i], clrLightGray, 8);
      Lbl(PFX+"sv"+(string)i,170, 62+i*18, StateName(demo[i]), StateColor(demo[i]), 8);
     }
   Cap("PANEL","pipeline_9_stages","OK","PASS/FAIL/WAITING/UNKNOWN rendered",
       "synthetic values only");
  }

void Bg(const string n,const int x,const int y,const int w,const int h)
  {
   ObjectDelete(0,n);
   if(!ObjectCreate(0,n,OBJ_RECTANGLE_LABEL,0,0,0)) return;
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,w);       ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,C'20,24,32');
   ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,n,OBJPROP_COLOR,clrDimGray);
   ObjectSetInteger(0,n,OBJPROP_BACK,false);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
  }

void Lbl(const string n,const int x,const int y,const string txt,
         const color c,const int size)
  {
   ObjectDelete(0,n);
   if(!ObjectCreate(0,n,OBJ_LABEL,0,0,0)) return;
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetString (0,n,OBJPROP_TEXT,txt);    ObjectSetInteger(0,n,OBJPROP_COLOR,c);
   ObjectSetString (0,n,OBJPROP_FONT,"Consolas");
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,size);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
  }

//+------------------------------------------------------------------+
//| 3. Signal channels — WITHOUT firing anything trade-related.       |
//+------------------------------------------------------------------+
void TestSignalChannels()
  {
   Print("OBS001: journal channel test - explainable line follows");
   Print("OBS001: [SYNTHETIC] BUY OPPORTUNITY | liquidity=PASS sweep=PASS ",
         "mss=WAITING fvg=UNKNOWN | NOT A REAL SIGNAL");
   Cap("SIGNAL","Print_journal","OK","always available","carries full explanation text");

   ResetLastError();
   bool sn = SendNotification("OBS001 prototype test - not a signal");
   Cap("SIGNAL","SendNotification", sn?"OK":"FAIL",
       "err="+(string)GetLastError(),"needs MetaQuotes ID in terminal settings");

   ResetLastError();
   bool sm = SendMail("OBS001 test","prototype - not a signal");
   Cap("SIGNAL","SendMail", sm?"OK":"FAIL",
       "err="+(string)GetLastError(),"needs SMTP configured");

   Cap("SIGNAL","Alert_modal", InpTestModalAlert?"TESTED":"SKIPPED",
       "Alert() opens a MODAL dialog","deliberately not fired by default");
   if(InpTestModalAlert) Alert("OBS001 prototype - not a signal");

   ResetLastError();
   bool ps = PlaySound("alert.wav");
   Cap("SIGNAL","PlaySound", ps?"OK":"FAIL","err="+(string)GetLastError(),"");
  }

//+------------------------------------------------------------------+
//| 4. How many objects before rendering degrades?                    |
//+------------------------------------------------------------------+
void TestStress()
  {
   uint t0 = GetTickCount();
   int created = 0;
   double px = iClose(_Symbol,_Period,0);
   for(int i=0;i<InpStressObjects;i++)
     {
      string n = PFX+"s"+(string)i;
      if(ObjectCreate(0,n,OBJ_HLINE,0,0,px+(i-InpStressObjects/2)*_Point))
        { created++; ObjectSetInteger(0,n,OBJPROP_COLOR,C'30,30,30');
          ObjectSetInteger(0,n,OBJPROP_HIDDEN,true); }
      else break;
     }
   uint dt = GetTickCount()-t0;
   Cap("STRESS","objects_created",(string)created,"requested="+(string)InpStressObjects,
       "ms="+(string)dt);
   Cap("STRESS","total_on_chart",(string)ObjectsTotal(0),"","");
   for(int i=0;i<created;i++) ObjectDelete(0,PFX+"s"+(string)i);
   Cap("STRESS","after_cleanup",(string)ObjectsTotal(0),"","");
  }

//+------------------------------------------------------------------+
//| 5. Can the chart be captured programmatically? (evidence)         |
//+------------------------------------------------------------------+
void TestScreenshot()
  {
   ChartRedraw();
   ResetLastError();
   bool ok = ChartScreenShot(0,"E-MT5-OBS-001-chart.png",
                             InpScreenshotW,InpScreenshotH,ALIGN_RIGHT);
   Cap("RENDER","ChartScreenShot", ok?"OK":"FAIL",
       "err="+(string)GetLastError(),"MQL5/Files/E-MT5-OBS-001-chart.png");
  }
//+------------------------------------------------------------------+
