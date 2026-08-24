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
input int    InpImpCoolS  = 300;
input bool   InpTemprano  = true;    // aviso apenas arranca el movimiento
input double InpTempPips  = 3.0;     // pips dentro de la vela EN CURSO
input int    InpTempCoolS = 180;     // no repetir antes de N segundos     // no repetir el aviso antes de N segundos
// EVENT RISK — SPEC-FUND-001 §8. Calendario nativo de MT5, no depende de la web.
input bool   InpEventRisk    = true;  // marcar senales que caen en ventana de evento
input int    InpEventBeforeM = 15;    // minutos ANTES del evento que cuentan como ventana
input int    InpEventAfterM  = 15;    // minutos DESPUES
input bool   InpEventHighOnly= true;  // solo importancia HIGH (tier 1)
input bool   InpEventBlock   = false; // true = ademas silencia los avisos en ventana

// FINDINGS-001: hallazgos consolidados, no la senal focal refutada
#define REV_P      52.81    // P(reversion) medida, GBPUSD virgen n=108,678
#define REV_N      108678
#define EDGE_PIPS  0.562    // ventaja del efecto por operacion, carrera 10p
#define COST_REAL  0.838    // costo REAL en el instante de la senal (E-MT5-032)
#define COST_AVG   0.427    // spread promedio, el que enganaba antes

#define TA1_LOCK "TA1_OWNER_CHART"   // candado de instancia unica, ver OnInit

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
long   gLastMsc = -1;   // ultimo tick ya procesado por Pulse(), evita contarlo dos veces

// EVENT RISK — cache del calendario. Se refresca cada 5 min, no por tick.
struct EvRow { datetime t; string name; string cur; int imp; };
EvRow    gEv[];
int      gNEv = 0;
datetime gEvRefreshed = 0;
bool     gEvOk = false;         // false = el calendario no respondio; se degrada a "sin datos"
int      gEvSuppressed = 0;     // avisos silenciados por ventana de evento
string gLast = "sin senales todavia";
datetime gLastT = 0;
datetime gBannerUntil = 0;
datetime gLastBar = 0;
struct Pend { int dir; double lvl, sl, tp; datetime t0; bool open; };
Pend gPend[]; int gNP = 0;
int  gHit = 0, gMiss = 0;
long gBarsLogged = 0;
datetime gLastImp = 0;
datetime gLastTemp = 0;
int      gTempranos = 0;
double   gIntraPips = 0;
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
   // CANDADO DE INSTANCIA UNICA.
   // MT5 restaura los graficos guardados del perfil Y ADEMAS live.ini crea el
   // suyo, asi que arrancaban DOS instancias del EA sobre EURUSD M5. Las dos
   // escribian los mismos CSV: contadores mezclados, barras duplicadas y el
   // heartbeat congelado cuando una bloqueaba el archivo de la otra.
   // La global del terminal guarda el ChartID dueño y se refresca cada segundo
   // desde OnTimer; si su marca de tiempo tiene menos de 10 s, hay alguien vivo.
   long myChart = ChartID();
   if(GlobalVariableCheck(TA1_LOCK))
     {
      long     owner = (long)GlobalVariableGet(TA1_LOCK);
      datetime beat  = GlobalVariableTime(TA1_LOCK);
      if(owner != myChart && (TimeLocal() - beat) < 10)
        {
         Print("TRADER-ALERT-001: ya hay una instancia viva en el grafico ", owner,
               ". Esta se desactiva para no corromper los CSV del experimento.");
         return(INIT_FAILED);
        }
     }
   GlobalVariableSet(TA1_LOCK, (double)myChart);

   LoadGeom();
   // La ultima barra cerrada ya fue registrada antes de este arranque. Sin esto
   // cada reinicio la vuelve a escribir y el CSV queda con duplicados, que
   // sesgan el analisis; perder una barra solo reduce n, que es preferible.
   gLastBar = iTime(_Symbol, PERIOD_M5, 1);
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

void OnTimer()
  {
   GlobalVariableSet(TA1_LOCK, (double)ChartID());   // refresca el candado
   EventRefresh(); Pulse(); Draw(); Banner(); LogBar(); Heartbeat();
  }
// Pulse() carries the detection. It runs from OnTick() when the terminal
// delivers tick events, and from OnTimer() when it does not: under Wine a
// chart that never renders gets no OnTick at all, and the detector sat blind
// from 2026-08-10 to 2026-08-11 with ticks=0 while the panel kept updating.
// OnTimer is a system timer, independent of the chart, so it always fires.
// Cost of the fallback: detection resolves to 1 s instead of per tick, so a
// level touched and reverted inside the same second is missed. Both hits and
// misses are lost the same way, so it does not bias direction.

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
       StringFormat("medido: tras un movimiento asi, %.2f%% REVIERTE  (n=%d)",
                    REV_P, REV_N), br, 10, "Arial");
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
//+------------------------------------------------------------------+
//| EVENT RISK — SPEC-FUND-001 §8                                     |
//|                                                                   |
//| Why it exists: E-MT5-032 measured the spread at the instant of a  |
//| signal at 1.96x its own average on EURUSD, against an edge of     |
//| 0.562 pips. An event window is the strongest form of that effect. |
//| This module predicts nothing. It marks when a signal was born      |
//| somewhere the execution cost is known to explode.                 |
//|                                                                   |
//| It MARKS by default and blocks only under InpEventBlock. Marking   |
//| keeps both arms of E-MT5-036 Test A in the sample; blocking would  |
//| destroy the very data that decides whether the filter is worth     |
//| having. Reads the native MT5 calendar, so it needs no web access.  |
//+------------------------------------------------------------------+
void EventRefresh()
  {
   if(!InpEventRisk) return;
   if(gEvRefreshed > 0 && TimeCurrent() - gEvRefreshed < 300) return;
   gEvRefreshed = TimeCurrent();

   ArrayResize(gEv, 0); gNEv = 0; gEvOk = false;

   datetime from = TimeCurrent() - 12 * 3600;
   datetime to   = TimeCurrent() + 36 * 3600;
   string cur[2]; cur[0] = "USD"; cur[1] = "EUR";

   for(int c = 0; c < 2; c++)
     {
      MqlCalendarValue v[];
      int n = CalendarValueHistory(v, from, to, NULL, cur[c]);
      if(n <= 0) continue;
      gEvOk = true;                     // el calendario respondio al menos una vez
      for(int i = 0; i < n; i++)
        {
         MqlCalendarEvent ev;
         if(!CalendarEventById(v[i].event_id, ev)) continue;
         if(ev.importance == CALENDAR_IMPORTANCE_NONE) continue;
         if(InpEventHighOnly && ev.importance != CALENDAR_IMPORTANCE_HIGH) continue;
         int k = gNEv;
         ArrayResize(gEv, k + 1);
         gEv[k].t    = v[i].time;
         gEv[k].name = ev.name;
         gEv[k].cur  = cur[c];
         gEv[k].imp  = (int)ev.importance;
         gNEv = k + 1;
        }
     }
   CalendarDump();
  }

//| Los valores del calendario vienen multiplicados por 1e6, y LONG_MIN
//| significa "no hay valor". Sin esa distincion un dato ausente se leeria
//| como cero, que es un numero perfectamente creible y completamente falso.
bool   CalHas(const long v) { return(v != LONG_MIN); }
string CalTxt(const long v)
  {
   if(v == LONG_MIN) return("");           // vacio, NUNCA cero
   return(DoubleToString((double)v / 1000000.0, 3));
  }

//| Vuelca el calendario a CSV para que el reporte fundamental lo lea de una
//| fuente verificable. Existe porque las paginas de calendario consultadas por
//| web devolvieron valores "actual" para eventos que todavia no ocurrieron.
//| Aqui el actual esta vacio hasta que el terminal lo recibe del proveedor.
void CalendarDump()
  {
   int fh = FileOpen("TRADER-CALENDAR.csv",
                     FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON
                     | FILE_SHARE_READ | FILE_SHARE_WRITE, ',');
   if(fh == INVALID_HANDLE) return;
   FileWrite(fh, "event_time_server", "currency", "importance", "event",
             "actual", "forecast", "previous", "has_actual", "dumped_at");

   datetime from = TimeCurrent() - 48 * 3600;
   datetime to   = TimeCurrent() + 96 * 3600;
   string cur[2]; cur[0] = "USD"; cur[1] = "EUR";
   string now = TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS);

   for(int c = 0; c < 2; c++)
     {
      MqlCalendarValue v[];
      int n = CalendarValueHistory(v, from, to, NULL, cur[c]);
      for(int i = 0; i < n; i++)
        {
         MqlCalendarEvent ev;
         if(!CalendarEventById(v[i].event_id, ev)) continue;
         if(ev.importance == CALENDAR_IMPORTANCE_NONE) continue;
         if(ev.importance == CALENDAR_IMPORTANCE_LOW)  continue;
         string nm = ev.name; StringReplace(nm, ",", " ");
         string imp = (ev.importance == CALENDAR_IMPORTANCE_HIGH) ? "HIGH" : "MODERATE";
         FileWrite(fh, TimeToString(v[i].time, TIME_DATE | TIME_MINUTES),
                   cur[c], imp, nm,
                   CalTxt(v[i].actual_value), CalTxt(v[i].forecast_value),
                   CalTxt(v[i].prev_value),
                   (CalHas(v[i].actual_value) ? "YES" : "NO"), now);
        }
     }
   FileClose(fh);
  }

//| "" si t no cae en ventana de evento; si cae, el rotulo del evento
string EventWindow(const datetime t, int &minsTo)
  {
   minsTo = 0;
   if(!InpEventRisk || gNEv <= 0) return("");
   for(int i = 0; i < gNEv; i++)
     {
      long d = (long)(gEv[i].t - t);        // >0 falta, <0 ya ocurrio
      if(d <= (long)InpEventBeforeM * 60 && d >= -(long)InpEventAfterM * 60)
        {
         minsTo = (int)(d / 60);
         return(gEv[i].cur + " " + gEv[i].name);
        }
     }
   return("");
  }

//| campo para CSV. NOCAL distingue "no hay evento" de "no hubo calendario":
//| sin esa distincion una falla del calendario se leeria como ausencia de
//| riesgo, que es el error que este proyecto ya cometio con ticks=0.
string EventTag(const datetime t)
  {
   if(!InpEventRisk) return("OFF");
   if(!gEvOk)        return("NOCAL");
   int m; string e = EventWindow(t, m);
   if(e == "") return("NONE");
   StringReplace(e, ",", " ");            // la coma rompe el CSV
   return(StringFormat("%s@%+dmin", e, m));
  }

//| proximo evento futuro, para el panel
string EventNext(int &minsTo)
  {
   minsTo = -1;
   if(gNEv <= 0) return("");
   long best = 0; string bn = "";
   for(int i = 0; i < gNEv; i++)
     {
      long d = (long)(gEv[i].t - TimeCurrent());
      if(d < 0) continue;
      if(bn == "" || d < best) { best = d; bn = gEv[i].cur + " " + gEv[i].name; }
     }
   if(bn != "") minsTo = (int)(best / 60);
   return(bn);
  }

//| true si hay que silenciar el aviso (solo con InpEventBlock)
bool EventBlocked()
  {
   if(!InpEventRisk || !InpEventBlock) return(false);
   int m; return(EventWindow(TimeCurrent(), m) != "");
  }

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
                "tick_volume", "spread_pips", "alerts_so_far",
                "range_pips", "event");
   FileSeek(fb, 0, SEEK_END);
   // range_pips y event alimentan el control positivo de E-MT5-036 Test A:
   // el rango M5 DEBE ser mayor dentro de ventana de evento. Si no lo es,
   // el problema esta en el pipeline, no en la hipotesis.
   FileWrite(fb, TimeToString(bt, TIME_DATE | TIME_SECONDS), _Symbol,
             DoubleToString(o, _Digits), DoubleToString(h, _Digits),
             DoubleToString(l, _Digits), DoubleToString(c, _Digits),
             (string)v,
             DoubleToString((t.ask - t.bid) / (gPip * _Point), 3),
             (string)gAlerts,
             DoubleToString((h - l) / (gPip * _Point), 1),
             EventTag(bt));
   FileClose(fb);
   gBarsLogged++;
  }

//| estado del filtro de eventos, para el panel                       |
string EventStatusTxt()
  {
   if(!InpEventRisk) return("filtro apagado");
   if(!gEvOk)        return("calendario SIN DATOS");
   int m; string w = EventWindow(TimeCurrent(), m);
   if(w != "")
      return(StringFormat("VENTANA >>> %s (%+d min)%s", w, m,
                          (InpEventBlock ? "  [SILENCIA]" : "  [marca]")));
   int mn; string nx = EventNext(mn);
   if(nx == "")
      return(StringFormat("sin eventos proximos  (%d en cache)", gNEv));
   return(StringFormat("proximo %s en %d min  (%d en cache)", nx, mn, gNEv));
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
      "impulsos        %d   tempranos %d\n"
      "evento          %s\n"
      "vela_en_curso   %+.1f pips (umbral %.1f)\n"
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
      gX, gY, gW, gH, VelasTxt(), gTicks, gBarsLogged, gAlerts, gHit, gMiss, gImpulsos, gTempranos, EventStatusTxt(), gIntraPips, InpTempPips, gLast, REV_P, REV_N, EDGE_PIPS, COST_REAL, COST_REAL/EDGE_PIPS));
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
   string d = (dir > 0) ? "BUY / COMPRA" : "SELL / VENTA";
   gAlerts++; gLastT = TimeCurrent();
   gLast = StringFormat("%s %s %s", TimeToString(gLastT, TIME_MINUTES), d,
                        DoubleToString(level, _Digits));
   Arrow(dir, level);
   ArrayResize(gPend, gNP + 1);
   gPend[gNP].dir = dir; gPend[gNP].lvl = level;
   gPend[gNP].sl = level - dir * gStopD;
   gPend[gNP].tp = level + dir * gStopD * InpTargetR;
   gPend[gNP].t0 = TimeCurrent(); gPend[gNP].open = true; gNP++;
   MqlTick tk; SymbolInfoTick(_Symbol, tk);
   bool blk = EventBlocked();
   if(blk) gEvSuppressed++;
   string etag = EventTag(gLastT);
   double spr  = (tk.ask - tk.bid) / (gPip * _Point);

   string msg = StringFormat("%s %s | %s en %s | stop %s objetivo %s | "
      "ventaja %.3fp vs costo real %.3fp -> NO OPERABLE",
      _Symbol, EnumToString(_Period), d, DoubleToString(level, _Digits),
      DoubleToString(stop, _Digits), DoubleToString(target, _Digits),
      EDGE_PIPS, COST_REAL);

   if(!blk)
     {
      gBannerDir = dir;
      gBannerUntil = TimeCurrent() + InpBannerSec;
      gBannerTxt = StringFormat("%s  %s  en %s", _Symbol, d, DoubleToString(level, _Digits));
      if(etag != "NONE" && etag != "OFF" && etag != "NOCAL")
         gBannerTxt = gBannerTxt + "   [EVENTO: " + etag + "]";
      Banner();
      Print("ALERTA >>> ", msg, (etag == "NONE" ? "" : "  [" + etag + "]"));
      if(InpSound) PlaySound("alert.wav");
      // Alert() es modal en MT5 y bloquea el hilo del experto bajo Wine.
      // El aviso va por sonido + cartel en el grafico, que no bloquean.
      if(false) Alert(msg);
     }
   else
      Print("ALERTA silenciada por ventana de evento: ", etag, " | ", msg);

   int fh = FileOpen("TRADER-ALERT-001-live.csv",
                     FILE_READ | FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON, ',');
   if(fh != INVALID_HANDLE)
     {
      FileSeek(fh, 0, SEEK_END);
      FileWrite(fh, TimeToString(gLastT, TIME_DATE | TIME_SECONDS), _Symbol, d,
                DoubleToString(level, _Digits), DoubleToString(stop, _Digits),
                DoubleToString(target, _Digits), DoubleToString(EDGE_PIPS, 3),
                "NO_OPERABLE",
                DoubleToString(spr, 2), etag, (blk ? "SILENCIADO" : "AVISADO"));
      FileClose(fh);
     }
   Draw();
  }

//+------------------------------------------------------------------+
//| IMPULSE DETECTOR — observation, not prediction.                   |
//| Fires anywhere in price, not only on focal levels. It reports what|
//| the market IS doing. It makes no claim about what comes next.     |
//+------------------------------------------------------------------+
//| AVISO TEMPRANO — mide el movimiento DENTRO de la vela en curso.   |
//| El detector de impulso compara contra la vela ya cerrada, o sea   |
//| contra un punto de hasta 10 min atras. Este mira el open de la    |
//| vela viva, asi avisa apenas el movimiento arranca.                |
//| Sigue siendo OBSERVACION: dice lo que esta pasando, no predice.   |
//+------------------------------------------------------------------+
void CheckTemprano()
  {
   if(!InpTemprano) return;
   MqlTick t; if(!SymbolInfoTick(_Symbol, t)) return;

   double op = iOpen(_Symbol, PERIOD_M5, 0);      // vela EN FORMACION
   if(op <= 0) return;
   gIntraPips = (t.bid - op) / (gPip * _Point);

   if(TimeCurrent() - gLastTemp < InpTempCoolS) return;
   if(MathAbs(gIntraPips) < InpTempPips) return;

   int dir = (gIntraPips > 0) ? +1 : -1;
   gLastTemp = TimeCurrent();
   gTempranos++;

   // El registro se escribe SIEMPRE, tambien cuando el aviso se silencia:
   // E-MT5-036 Test A necesita las dos ramas para poder compararlas.
   bool blk = EventBlocked();
   if(blk) gEvSuppressed++;
   string etag = EventTag(TimeCurrent());
   double spr  = (t.ask - t.bid) / (gPip * _Point);

   string d = (dir > 0) ? "SUBIENDO  ->  COMPRA / BUY" : "BAJANDO  ->  VENTA / SELL";
   if(!blk)
     {
      gBannerDir   = dir;
      gBannerTxt   = StringFormat("%s   %+.1f pips en la vela", d, gIntraPips);
      if(etag != "NONE" && etag != "OFF" && etag != "NOCAL")
         gBannerTxt = gBannerTxt + "   [EVENTO: " + etag + "]";
      gBannerUntil = TimeCurrent() + InpBannerSec;
      Print("AVISO TEMPRANO >>> ", gBannerTxt, "  precio ",
            DoubleToString(t.bid, _Digits), "  [observacion en curso]");
      if(InpSound) PlaySound("tick.wav");
     }
   else
      Print("AVISO TEMPRANO silenciado por ventana de evento: ", etag);

   gLast = StringFormat("%s %s %+.1f p", TimeToString(TimeCurrent(), TIME_MINUTES),
                        (dir > 0 ? "TEMPRANO+" : "TEMPRANO-"), gIntraPips);

   int fh2 = FileOpen("TRADER-TEMPRANO.csv",
                      FILE_READ | FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON, ',');
   if(fh2 != INVALID_HANDLE)
     {
      FileSeek(fh2, 0, SEEK_END);
      FileWrite(fh2, TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS), _Symbol,
                (dir > 0 ? "SUBE" : "BAJA"), DoubleToString(gIntraPips, 1),
                DoubleToString(t.bid, _Digits), "TEMPRANO",
                DoubleToString(spr, 2), etag, (blk ? "SILENCIADO" : "AVISADO"));
      FileClose(fh2);
     }
   Draw();
  }

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
   bool blk = EventBlocked();
   if(blk) gEvSuppressed++;
   string etag = EventTag(TimeCurrent());
   double spr  = (t.ask - t.bid) / (gPip * _Point);

   string d = (dir > 0) ? "SUBE FUERTE  ->  BUY" : "BAJA FUERTE  ->  SELL";
   if(!blk)
     {
      gBannerDir   = dir;
      gBannerTxt   = StringFormat("%s   %+.1f pips en %d min", d, mv, InpImpMin);
      if(etag != "NONE" && etag != "OFF" && etag != "NOCAL")
         gBannerTxt = gBannerTxt + "   [EVENTO: " + etag + "]";
      gBannerUntil = TimeCurrent() + InpBannerSec;
      Print("IMPULSO >>> ", gBannerTxt, "  precio ", DoubleToString(t.bid, _Digits),
            "  [observacion, no prediccion]");
      if(InpSound) PlaySound("news.wav");
     }
   else
      Print("IMPULSO silenciado por ventana de evento: ", etag);

   gLast = StringFormat("%s %s %+.1f p", TimeToString(TimeCurrent(), TIME_MINUTES),
                        (dir > 0 ? "IMPULSO+" : "IMPULSO-"), mv);

   int fh = FileOpen("TRADER-IMPULSO.csv",
                     FILE_READ | FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON, ',');
   if(fh != INVALID_HANDLE)
     {
      FileSeek(fh, 0, SEEK_END);
      FileWrite(fh, TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS), _Symbol,
                (dir > 0 ? "SUBE" : "BAJA"), DoubleToString(mv, 1),
                (string)InpImpMin, DoubleToString(t.bid, _Digits), "OBSERVACION",
                DoubleToString(spr, 2), etag, (blk ? "SILENCIADO" : "AVISADO"));
      FileClose(fh);
     }
   Draw();
  }

//+------------------------------------------------------------------+
void Pulse()
  {
   MqlTick t; if(!SymbolInfoTick(_Symbol, t)) return;
   if(t.time_msc == gLastMsc) return;   // ya procesado: llego por la otra via
   gLastMsc = t.time_msc;
   gTicks++;
   Track();
   double b = t.bid;
   CheckTemprano();
   CheckImpulso();

   if(gArmUp > 0 && b >= gArmUp) { Fire(-1, gArmUp); gArmUp = 0; }
   if(gArmDn > 0 && b <= gArmDn) { Fire(+1, gArmDn); gArmDn = 0; }
   double lvlDn = MathFloor(b / gGrid) * gGrid;
   double lvlUp = lvlDn + gGrid;
   if(gArmUp <= 0 || b <= gArmUp - gU) { if(b <= lvlUp - gU) gArmUp = lvlUp; }
   if(gArmDn <= 0 || b >= gArmDn + gU) { if(b >= lvlDn + gU) gArmDn = lvlDn; }
  }

//+------------------------------------------------------------------+
void OnTick() { Pulse(); }
//+------------------------------------------------------------------+
