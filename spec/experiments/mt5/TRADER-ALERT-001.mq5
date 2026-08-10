//+------------------------------------------------------------------+
//| TRADER-ALERT-001 — LIVE DETECTOR + ALERT   (v3: movable panel)    |
//|                                                                  |
//| THE PRODUCT: it detects and it warns. It NEVER sends an order.    |
//|                                                                  |
//| Panel: drag the body to move it, drag the bottom-right grip to    |
//| resize. Fonts scale with the panel. Geometry persists across      |
//| restarts via terminal global variables.                           |
//|                                                                  |
//| DEMO MODE (InpDemoMode=true): arming distance drops to 1 pip so   |
//| alerts fire every few minutes. It exists ONLY to let a human see  |
//| the alert machinery working. It does NOT improve the signal —     |
//| the measured hit rate is unchanged and still below random.        |
//|                                                                  |
//|   focal reversal 28.90% (GBPUSD virgin, n=872) · random 31.81%    |
//|   break-even @2R 33.33%                                           |
//+------------------------------------------------------------------+
#property copyright "PROJECT TRADER"
#property version   "3.00"
#property strict

input int    InpGridPips  = 10;      // focal grid (SPEC-LVL-001)
input int    InpUPips     = 4;       // arming distance (real mode)
input int    InpStopPips  = 20;
input double InpTargetR   = 2.0;
input bool   InpDemoMode  = false;   // true -> arming 1 pip, many alerts
input bool   InpSound     = true;
input bool   InpPopup     = false;   // NUNCA true: Alert() es modal y CONGELA el EA
input int    InpMaxArrows = 200;
input int    InpBannerSec = 25;      // segundos que dura el cartel de alerta
input bool   InpImpulso   = true;    // avisar movimientos fuertes en curso
input double InpImpPips   = 5.0;     // pips de movimiento para considerarlo impulso
input int    InpImpMin    = 5;       // en cuantos minutos
input int    InpImpCoolS  = 300;     // no repetir el aviso antes de N segundos

// FINDINGS-001: hallazgos consolidados, no la senal focal refutada
#define REV_P      52.81    // P(reversion) medida, GBPUSD virgen n=108,678
#define REV_N      108678
#define EDGE_PIPS  0.562    // ventaja del efecto por operacion, carrera 10p
#define COST_REAL  0.838    // costo REAL en el instante de la senal (E-MT5-032)
#define COST_AVG   0.427    // spread promedio, el que enganaba antes

#define W_BASE 232
#define H_BASE 380
#define W_MIN  190
#define H_MIN  300
#define GRIP   12

int    gPip = 1;
double gGrid, gU, gStopD;
double gArmUp = 0, gArmDn = 0;
int    gAlerts = 0, gArrowSeq = 0;
long   gTicks = 0;
string gLast = "sin senales todavia";
datetime gLastT = 0;
datetime gBannerUntil = 0;
datetime gLastBar = 0;
struct Pend { int dir; double lvl, sl, tp; datetime t0; bool open; };
Pend gPend[]; int gNP = 0;
int  gHit = 0, gMiss = 0;
long gBarsLogged = 0;
datetime gLastImp = 0;
int      gImpDir  = 0;
int      gImpulsos = 0;
int      gBannerDir = 0;
string   gBannerTxt = "";
string gPfx = "TA1_";

// panel geometry — user-controlled, persisted
int gX = 12, gY = 48, gW = W_BASE, gH = H_BASE;   // y=48: MT5 escribe simbolo/TF arriba

//+------------------------------------------------------------------+
void SaveGeom()
  {
   GlobalVariableSet(gPfx + "x", gX); GlobalVariableSet(gPfx + "y", gY);
   GlobalVariableSet(gPfx + "w", gW); GlobalVariableSet(gPfx + "h", gH);
  }

void LoadGeom()
  {
   if(GlobalVariableCheck(gPfx + "x")) gX = (int)GlobalVariableGet(gPfx + "x");
   if(GlobalVariableCheck(gPfx + "y")) gY = (int)GlobalVariableGet(gPfx + "y");
   if(GlobalVariableCheck(gPfx + "w")) gW = (int)GlobalVariableGet(gPfx + "w");
   if(GlobalVariableCheck(gPfx + "h")) gH = (int)GlobalVariableGet(gPfx + "h");
   if(gW < W_MIN) gW = W_MIN;
   if(gH < H_MIN) gH = H_MIN;
  }

//+------------------------------------------------------------------+
void Box(const string name, const int x, const int y, const int w, const int h,
         const color bg, const color border, const bool draggable)
  {
   string n = gPfx + name;
   if(ObjectFind(0, n) < 0)
     {
      ObjectCreate(0, n, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, n, OBJPROP_BACK, false);
      ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
     }
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, draggable);
   ObjectSetInteger(0, n, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, n, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, n, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, n, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, n, OBJPROP_COLOR, border);
  }

void Txt(const string name, const int x, const int y, const string text,
         const color c, const int size, const string font)
  {
   string n = gPfx + name;
   if(ObjectFind(0, n) < 0)
     {
      ObjectCreate(0, n, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
     }
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, n, OBJPROP_COLOR, c);
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE, size);
   ObjectSetString(0, n, OBJPROP_FONT, font);
   ObjectSetString(0, n, OBJPROP_TEXT, text);
  }

//+------------------------------------------------------------------+
int OnInit()
  {
   gPip   = (_Digits == 3 || _Digits == 5) ? 10 : 1;
   gGrid  = InpGridPips * gPip * _Point;
   gU     = (InpDemoMode ? 1 : InpUPips) * gPip * _Point;
   gStopD = InpStopPips * gPip * _Point;
   LoadGeom();
   ChartSetInteger(0, CHART_EVENT_OBJECT_DELETE, true);
   EventSetTimer(1);
   Draw();
   Print("TRADER-ALERT-001 v3 activo en ", _Symbol, " ", EnumToString(_Period),
         (InpDemoMode ? "  [MODO DEMO: armado 1 pip]" : ""));
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   SaveGeom();
   ObjectsDeleteAll(0, gPfx);
  }

void OnTimer() { Draw(); Banner(); LogBar(); Heartbeat(); }
// Track() runs on ticks, where price actually moves

//+------------------------------------------------------------------+
//| user dragged the panel body or the resize grip                    |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam,
                  const string &sparam)
  {
   if(id != CHARTEVENT_OBJECT_DRAG) return;

   if(sparam == gPfx + "bg")
     {
      gX = (int)ObjectGetInteger(0, sparam, OBJPROP_XDISTANCE);
      gY = (int)ObjectGetInteger(0, sparam, OBJPROP_YDISTANCE);
      if(gX < 0) gX = 0;
      if(gY < 0) gY = 0;
      SaveGeom(); Draw();
     }
   else if(sparam == gPfx + "grip")
     {
      int gx = (int)ObjectGetInteger(0, sparam, OBJPROP_XDISTANCE);
      int gy = (int)ObjectGetInteger(0, sparam, OBJPROP_YDISTANCE);
      gW = gx + GRIP - gX;
      gH = gy + GRIP - gY;
      if(gW < W_MIN) gW = W_MIN;
      if(gH < H_MIN) gH = H_MIN;
      SaveGeom(); Draw();
     }
  }

//+------------------------------------------------------------------+
double MovePips(const int bars)
  {
   double past = iClose(_Symbol, PERIOD_M5, bars);
   if(past <= 0) return(0);
   MqlTick t; if(!SymbolInfoTick(_Symbol, t)) return(0);
   return((t.bid - past) / (gPip * _Point));
  }

//+------------------------------------------------------------------+
void Draw()
  {
   MqlTick t; if(!SymbolInfoTick(_Symbol, t)) return;

   double sp    = (t.ask - t.bid) / (gPip * _Point);
   double tax   = (InpStopPips > 0) ? 100.0 * sp / (3.0 * InpStopPips) : 0;
   double lvlDn = MathFloor(t.bid / gGrid) * gGrid;
   double lvlUp = lvlDn + gGrid;
   double m5    = MovePips(1), m15 = MovePips(3), m60 = MovePips(12);

   // scale fonts with the panel, keep proportions
   double k = MathMin((double)gW / W_BASE, (double)gH / H_BASE);
   if(k < 0.75) k = 0.75;
   if(k > 2.50) k = 2.50;
#define FS(n) (int)MathMax(7, MathRound((n) * k))
#define SP(n) (int)MathRound((n) * k)

   Box("bg", gX, gY, gW, gH, C'18,20,26', C'70,78,95', true);
   Box("grip", gX + gW - GRIP, gY + gH - GRIP, GRIP, GRIP, C'70,78,95', C'120,130,150', true);

   int x = gX + SP(12), y = gY + SP(14);

   Txt("h1", x, y, "PROJECT TRADER", clrWhite, FS(9), "Arial");   y += SP(15);
   Txt("h2", x, y, (InpDemoMode ? "MODO DEMO — armado 1 pip"
                                : "detector + alerta  ·  nunca opera solo"),
       (InpDemoMode ? C'250,200,80' : C'130,140,160'), FS(7), "Arial");  y += SP(12);

   Txt("p1", x, y, _Symbol + "  " + EnumToString(_Period), C'150,160,180', FS(8), "Arial"); y += SP(12);
   Txt("p2", x, y, DoubleToString(t.bid, _Digits), clrWhite, FS(11), "Arial");           y += SP(16);
   Txt("p3", x, y, StringFormat("spread %.2f pips  ·  impuesto %.2f pp", sp, tax),
       (sp > 1.5 ? clrOrange : C'130,140,160'), FS(8), "Arial");                          y += SP(12);

   Txt("d0", x, y, "YA PASO  (hecho)", C'110,120,140', FS(7), "Arial");                     y += SP(15);
   string dir = (m15 > 0.5) ? "SUBIENDO" : ((m15 < -0.5) ? "BAJANDO" : "LATERAL");
   color  cd  = (m15 > 0.5) ? C'80,220,120' : ((m15 < -0.5) ? C'240,90,90' : C'170,170,170');
   Txt("d1", x, y, dir, cd, FS(9), "Arial");                                          y += SP(12);
   Txt("d2", x, y, StringFormat("15min %+.1f   1h %+.1f pips", m15, m60),
       cd, FS(8), "Arial");                                                               y += SP(12);

   // ---- vela por vela: las ultimas 8 velas M5 cerradas ----------------
   Txt("c0", x, y, "VELA POR VELA  (M5)", C'110,120,140', FS(7), "Arial");                   y += SP(15);
   for(int i = 6; i >= 1; i--)
     {
      double o = iOpen(_Symbol, PERIOD_M5, i);
      double c = iClose(_Symbol, PERIOD_M5, i);
      datetime bt = iTime(_Symbol, PERIOD_M5, i);
      if(o <= 0 || c <= 0) continue;
      double dp = (c - o) / (gPip * _Point);
      string mark = (dp > 0) ? "SUBE " : ((dp < 0) ? "BAJA " : "IGUAL");
      color  cc   = (dp > 0) ? C'80,220,120' : ((dp < 0) ? C'240,90,90' : C'150,150,150');
      Txt("c" + IntegerToString(i), x, y,
          StringFormat("%s  %s %+6.1f", TimeToString(bt, TIME_MINUTES), mark, dp),
          cc, FS(8), "Arial");                                                            y += SP(12);
     }
   y += SP(12);

   bool armDn = (gArmDn > 0 && MathAbs(gArmDn - lvlDn) < gGrid / 2);
   Txt("n0", x, y, "NIVELES FOCALES", C'110,120,140', FS(7), "Arial");                       y += SP(15);
   Txt("n1", x, y, StringFormat("%s  %5.1f pips  %s", DoubleToString(lvlUp, _Digits),
       (lvlUp - t.bid) / (gPip * _Point), (gArmUp > 0 ? "ARMADO" : "esperando")),
       (gArmUp > 0 ? C'90,200,255' : C'110,120,140'), FS(8), "Arial");                   y += SP(12);
   Txt("n2", x, y, StringFormat("%s  %5.1f pips  %s", DoubleToString(lvlDn, _Digits),
       (t.bid - lvlDn) / (gPip * _Point), (armDn ? "ARMADO" : "esperando")),
       (armDn ? C'90,200,255' : C'110,120,140'), FS(8), "Arial");                        y += SP(12);

   Txt("f0", x, y, "LO QUE SABEMOS (medido)", C'110,120,140', FS(7), "Arial");             y += SP(15);
   Txt("f1", x, y, StringFormat("reversion  %.2f %%  n=%d", REV_P, REV_N),
       C'110,220,140', FS(8), "Arial");                                                   y += SP(16);
   Txt("f2", x, y, StringFormat("ventaja    %.3f pips/op", EDGE_PIPS),
       C'150,160,180', FS(8), "Arial");                                                   y += SP(16);
   Txt("f3", x, y, StringFormat("costo real %.3f p = %.1fx", COST_REAL, COST_REAL/EDGE_PIPS),
       C'240,110,110', FS(8), "Arial");                                                   y += SP(12);
   Txt("f4", x, y, "EL COSTO SUPERA LA VENTAJA", C'255,70,70', FS(8), "Arial");y += SP(12);

   Txt("a1", x, y, StringFormat("alertas %d   acerto %d   fallo %d", gAlerts, gHit, gMiss),
       C'130,140,160', FS(8), "Arial");                                                   y += SP(12);
   Txt("a2", x, y, "ultima: " + gLast, C'220,200,120', FS(8), "Arial");

   ChartRedraw();
  }


//+------------------------------------------------------------------+
//| Big centred banner over the chart. Impossible to miss.            |
//+------------------------------------------------------------------+
void Banner()
  {
   string b1 = gPfx + "bnbg", b2 = gPfx + "bntx", b3 = gPfx + "bnsub";
   if(TimeCurrent() >= gBannerUntil)
     { ObjectDelete(0, b1); ObjectDelete(0, b2); ObjectDelete(0, b3); return; }

   int cw = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int bw = 460, bh = 92;
   int bx = (cw - bw) / 2; if(bx < 8) bx = 8;
   int by = 56;
   color bg = (gBannerDir > 0) ? C'20,90,45' : C'110,25,30';
   color br = (gBannerDir > 0) ? C'80,230,130' : C'255,90,90';

   if(ObjectFind(0, b1) < 0)
     {
      ObjectCreate(0, b1, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, b1, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, b1, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, b1, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, b1, OBJPROP_BACK, false);
     }
   ObjectSetInteger(0, b1, OBJPROP_XDISTANCE, bx);
   ObjectSetInteger(0, b1, OBJPROP_YDISTANCE, by);
   ObjectSetInteger(0, b1, OBJPROP_XSIZE, bw);
   ObjectSetInteger(0, b1, OBJPROP_YSIZE, bh);
   ObjectSetInteger(0, b1, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, b1, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, b1, OBJPROP_COLOR, br);

   Txt("bntx", bx + 18, by + 12, gBannerTxt, clrWhite, 22, "Arial");
   Txt("bnsub", bx + 18, by + 52,
       StringFormat("ventaja %.3f pips  vs  costo real %.3f pips   ->   NO OPERABLE",
                    EDGE_PIPS, COST_REAL), br, 10, "Arial");
  }


//+------------------------------------------------------------------+
string VelasTxt()
  {
   string r = "velas_M5        ";
   for(int i = 6; i >= 1; i--)
     {
      double o = iOpen(_Symbol, PERIOD_M5, i);
      double c = iClose(_Symbol, PERIOD_M5, i);
      if(o <= 0 || c <= 0) continue;
      double dp = (c - o) / (gPip * _Point);
      r += StringFormat("%s%+.1f  ", (dp > 0 ? "S" : (dp < 0 ? "B" : "=")), dp);
     }
   return(r + "\n");
  }


//+------------------------------------------------------------------+
//| Forward data collection. Every closed M5 bar is appended with its |
//| spread and the detector state at close. From the moment this runs |
//| it accumulates a sample nobody has looked at — the only genuinely |
//| virgin data the project can still obtain.                         |

//+------------------------------------------------------------------+
//| Live self-scoring. Every alert is followed until it reaches its   |
//| target or its stop, and the running hit rate is shown on screen.  |
//| The detector grades itself in public — no way to look better than |
//| it is.                                                            |
//+------------------------------------------------------------------+
void Track()
  {
   MqlTick t; if(!SymbolInfoTick(_Symbol, t)) return;
   double b = t.bid;
   for(int i = 0; i < gNP; i++)
     {
      if(!gPend[i].open) continue;
      bool hit = false, miss = false;
      if(gPend[i].dir > 0) { hit = (b >= gPend[i].tp); miss = (b <= gPend[i].sl); }
      else                 { hit = (b <= gPend[i].tp); miss = (b >= gPend[i].sl); }
      if(!hit && !miss) continue;
      gPend[i].open = false;
      if(hit) gHit++; else gMiss++;
      int fr = FileOpen("TRADER-ALERT-001-results.csv",
                        FILE_READ | FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON
                        | FILE_SHARE_READ | FILE_SHARE_WRITE, ',');
      if(fr != INVALID_HANDLE)
        {
         if(FileSize(fr) == 0)
            FileWrite(fr, "alerta_t", "cierre_t", "dir", "nivel", "resultado");
         FileSeek(fr, 0, SEEK_END);
         FileWrite(fr, TimeToString(gPend[i].t0, TIME_DATE|TIME_SECONDS),
                   TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
                   (gPend[i].dir > 0 ? "SUBE" : "BAJA"),
                   DoubleToString(gPend[i].lvl, _Digits),
                   (hit ? "ACERTO" : "FALLO"));
         FileClose(fr);
        }
     }
  }

//+------------------------------------------------------------------+
void LogBar()
  {
   datetime bt = iTime(_Symbol, PERIOD_M5, 1);
   if(bt == 0 || bt == gLastBar) return;
   gLastBar = bt;

   MqlTick t; if(!SymbolInfoTick(_Symbol, t)) return;
   double o = iOpen (_Symbol, PERIOD_M5, 1);
   double h = iHigh (_Symbol, PERIOD_M5, 1);
   double l = iLow  (_Symbol, PERIOD_M5, 1);
   double c = iClose(_Symbol, PERIOD_M5, 1);
   long   v = iTickVolume(_Symbol, PERIOD_M5, 1);
   if(o <= 0) return;

   int fb = FileOpen("TRADER-FORWARD-M5.csv",
                     FILE_READ | FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON
                     | FILE_SHARE_READ | FILE_SHARE_WRITE, ',');
   if(fb == INVALID_HANDLE) return;
   if(FileSize(fb) == 0)
      FileWrite(fb, "time", "symbol", "open", "high", "low", "close",
                "tick_volume", "spread_pips", "alerts_so_far");
   FileSeek(fb, 0, SEEK_END);
   FileWrite(fb, TimeToString(bt, TIME_DATE | TIME_SECONDS), _Symbol,
             DoubleToString(o, _Digits), DoubleToString(h, _Digits),
             DoubleToString(l, _Digits), DoubleToString(c, _Digits),
             (string)v,
             DoubleToString((t.ask - t.bid) / (gPip * _Point), 3),
             (string)gAlerts);
   FileClose(fb);
   gBarsLogged++;
  }

//+------------------------------------------------------------------+
void Heartbeat()
  {
   MqlTick t; if(!SymbolInfoTick(_Symbol, t)) return;
   double lvlDn = MathFloor(t.bid / gGrid) * gGrid;
   double lvlUp = lvlDn + gGrid;
   double m15 = MovePips(3);
   int fh = FileOpen("TRADER-ALERT-001-state.txt",
                     FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON
                     | FILE_SHARE_READ | FILE_SHARE_WRITE);
   if(fh == INVALID_HANDLE) return;   // reader holds it; retry next second
   FileWriteString(fh, StringFormat(
      "hora            %s%s\n"
      "simbolo         %s %s\n"
      "precio          %s   spread %.2f pips\n"
      "movimiento      %s   5min %+.1f   15min %+.1f   1h %+.1f\n"
      "nivel_arriba    %s  (a %.1f pips)  %s\n"
      "nivel_abajo     %s  (a %.1f pips)  %s\n"
      "panel           x=%d y=%d  %dx%d\n"
      "%s"
      "ticks           %I64d\n"
      "barras_forward  %I64d\n"
      "alertas         %d   acerto %d   fallo %d\n"
      "impulsos        %d\n"
      "ultima_alerta   %s\n"
      "hallazgo        reversion %.2f%% (n=%d)  ventaja %.3f p/op\n"
      "costo real      %.3f p en la senal = %.1fx la ventaja -> NO OPERABLE\n",
      TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
      (InpDemoMode ? "   [MODO DEMO]" : ""),
      _Symbol, EnumToString(_Period),
      DoubleToString(t.bid, _Digits), (t.ask - t.bid) / (gPip * _Point),
      (m15 > 0.5 ? "SUBIENDO" : (m15 < -0.5 ? "BAJANDO" : "LATERAL")),
      MovePips(1), m15, MovePips(12),
      DoubleToString(lvlUp, _Digits), (lvlUp - t.bid) / (gPip * _Point),
      (gArmUp > 0 ? "ARMADO" : "esperando"),
      DoubleToString(lvlDn, _Digits), (t.bid - lvlDn) / (gPip * _Point),
      ((gArmDn > 0 && MathAbs(gArmDn - lvlDn) < gGrid / 2) ? "ARMADO" : "esperando"),
      gX, gY, gW, gH, VelasTxt(), gTicks, gBarsLogged, gAlerts, gHit, gMiss, gImpulsos, gLast, REV_P, REV_N, EDGE_PIPS, COST_REAL, COST_REAL/EDGE_PIPS));
   FileClose(fh);
  }

//+------------------------------------------------------------------+
void Arrow(const int dir, const double price)
  {
   string n = StringFormat("%sarr%d", gPfx, gArrowSeq++);
   ObjectCreate(0, n, dir > 0 ? OBJ_ARROW_UP : OBJ_ARROW_DOWN, 0, TimeCurrent(), price);
   ObjectSetInteger(0, n, OBJPROP_COLOR, dir > 0 ? clrLime : clrRed);
   ObjectSetInteger(0, n, OBJPROP_WIDTH, 4);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   if(gArrowSeq > InpMaxArrows)
      ObjectDelete(0, StringFormat("%sarr%d", gPfx, gArrowSeq - InpMaxArrows - 1));
  }

//+------------------------------------------------------------------+
void Fire(const int dir, const double level)
  {
   double stop   = level - dir * gStopD;
   double target = level + dir * gStopD * InpTargetR;
   string d = (dir > 0) ? "SUBE" : "BAJA";
   gAlerts++; gLastT = TimeCurrent();
   gLast = StringFormat("%s %s %s", TimeToString(gLastT, TIME_MINUTES), d,
                        DoubleToString(level, _Digits));
   Arrow(dir, level);
   ArrayResize(gPend, gNP + 1);
   gPend[gNP].dir = dir; gPend[gNP].lvl = level;
   gPend[gNP].sl = level - dir * gStopD;
   gPend[gNP].tp = level + dir * gStopD * InpTargetR;
   gPend[gNP].t0 = TimeCurrent(); gPend[gNP].open = true; gNP++;
   gBannerDir = dir;
   gBannerUntil = TimeCurrent() + InpBannerSec;
   gBannerTxt = StringFormat("%s  %s  en %s", _Symbol, d, DoubleToString(level, _Digits));
   Banner();
   string msg = StringFormat("%s %s | %s en %s | stop %s objetivo %s | "
      "ventaja %.3fp vs costo real %.3fp -> NO OPERABLE",
      _Symbol, EnumToString(_Period), d, DoubleToString(level, _Digits),
      DoubleToString(stop, _Digits), DoubleToString(target, _Digits),
      EDGE_PIPS, COST_REAL);
   Print("ALERTA >>> ", msg);
   if(InpSound) PlaySound("alert.wav");
   // Alert() es modal en MT5 y bloquea el hilo del experto bajo Wine.
   // El aviso va por sonido + cartel en el grafico, que no bloquean.
   if(false) Alert(msg);
   int fh = FileOpen("TRADER-ALERT-001-live.csv",
                     FILE_READ | FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON, ',');
   if(fh != INVALID_HANDLE)
     {
      FileSeek(fh, 0, SEEK_END);
      FileWrite(fh, TimeToString(gLastT, TIME_DATE | TIME_SECONDS), _Symbol, d,
                DoubleToString(level, _Digits), DoubleToString(stop, _Digits),
                DoubleToString(target, _Digits), DoubleToString(EDGE_PIPS, 3),
                "NO_OPERABLE");
      FileClose(fh);
     }
   Draw();
  }

//+------------------------------------------------------------------+
//| IMPULSE DETECTOR — observation, not prediction.                   |
//| Fires anywhere in price, not only on focal levels. It reports what|
//| the market IS doing. It makes no claim about what comes next.     |
//+------------------------------------------------------------------+
void CheckImpulso()
  {
   if(!InpImpulso) return;
   if(TimeCurrent() - gLastImp < InpImpCoolS) return;

   int bars = (int)MathMax(1, MathRound(InpImpMin / 5.0));
   double mv = MovePips(bars);
   if(MathAbs(mv) < InpImpPips) return;

   int dir = (mv > 0) ? +1 : -1;
   gLastImp = TimeCurrent();
   gImpDir  = dir;
   gImpulsos++;

   MqlTick t; SymbolInfoTick(_Symbol, t);
   string d = (dir > 0) ? "SUBIENDO FUERTE" : "BAJANDO FUERTE";
   gBannerDir   = dir;
   gBannerTxt   = StringFormat("%s   %+.1f pips en %d min", d, mv, InpImpMin);
   gBannerUntil = TimeCurrent() + InpBannerSec;

   gLast = StringFormat("%s %s %+.1f p", TimeToString(TimeCurrent(), TIME_MINUTES),
                        (dir > 0 ? "IMPULSO+" : "IMPULSO-"), mv);

   Print("IMPULSO >>> ", gBannerTxt, "  precio ", DoubleToString(t.bid, _Digits),
         "  [observacion, no prediccion]");
   if(InpSound) PlaySound("news.wav");

   int fh = FileOpen("TRADER-IMPULSO.csv",
                     FILE_READ | FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON, ',');
   if(fh != INVALID_HANDLE)
     {
      FileSeek(fh, 0, SEEK_END);
      FileWrite(fh, TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS), _Symbol,
                (dir > 0 ? "SUBE" : "BAJA"), DoubleToString(mv, 1),
                (string)InpImpMin, DoubleToString(t.bid, _Digits), "OBSERVACION");
      FileClose(fh);
     }
   Draw();
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   MqlTick t; if(!SymbolInfoTick(_Symbol, t)) return;
   gTicks++;
   Track();
   double b = t.bid;
   CheckImpulso();

   if(gArmUp > 0 && b >= gArmUp) { Fire(-1, gArmUp); gArmUp = 0; }
   if(gArmDn > 0 && b <= gArmDn) { Fire(+1, gArmDn); gArmDn = 0; }
   double lvlDn = MathFloor(b / gGrid) * gGrid;
   double lvlUp = lvlDn + gGrid;
   if(gArmUp <= 0 || b <= gArmUp - gU) { if(b <= lvlUp - gU) gArmUp = lvlUp; }
   if(gArmDn <= 0 || b >= gArmDn + gU) { if(b >= lvlDn + gU) gArmDn = lvlDn; }
  }
//+------------------------------------------------------------------+
