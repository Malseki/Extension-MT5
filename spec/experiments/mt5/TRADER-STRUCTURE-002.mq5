//+------------------------------------------------------------------+
//| TRADER-STRUCTURE-002 — BOS / CHoCH POR PIVOTES (ORIGEN DIRECTO)   |
//|                                                                   |
//| Port a MQL5 del Pine v6 "Market Structure BOS/CHoCH - Origen      |
//| Directo [Scalping]" aportado por el trader el 2026-08-25.         |
//|                                                                   |
//| DIFERENCIA CON TRADER-STRUCTURE-001, y por que conviven:          |
//|   001 -> leg tracking secuencial + filtro de desplazamiento ATR   |
//|   002 -> pivotes clasicos 5/5, sin filtro, CHoCH por "origen"     |
//| Son dos definiciones INDEPENDIENTES de estructura. Coincidencia   |
//| entre ambas = confluencia; divergencia = estructura ambigua. Ese  |
//| contraste es informacion, y se pierde si se unifican.             |
//|                                                                   |
//| LA REGLA DE ORIGEN, que es lo propio de este indicador:           |
//|   originHigh = ultimo Pivot High que PRECEDIO al ultimo Pivot Low |
//|                romperlo al alza  -> CHoCH alcista                 |
//|   originLow  = ultimo Pivot Low que PRECEDIO al ultimo Pivot High |
//|                romperlo a la baja -> CHoCH bajista                |
//| A diferencia del extremo estructural (keyHigh/keyLow, que solo se |
//| mueve ante un extremo mayor), los origen se recalculan con CADA   |
//| pivote del tipo opuesto.                                          |
//|                                                                   |
//| REGISTRA los eventos en TRADER-STRUCT2-EVENTS.csv. Ese archivo es |
//| un dataset APARTE: no toca ninguno de TRADER-ALERT-001 y no entra |
//| en E-MT5-036. Existe para que algun dia se pueda MEDIR si estos   |
//| eventos anticipan algo, cosa que hoy NO esta establecida.         |
//|                                                                   |
//| NO ES UNA SENAL VALIDADA. E-MT5-022 refuto "sweep + rechazo" a    |
//| -7 sigma y esto es de la misma familia. Dibuja y registra; no     |
//| afirma ventaja alguna.                                            |
//+------------------------------------------------------------------+
#property copyright "PROJECT TRADER"
#property version   "1.00"
#property strict
#property indicator_chart_window
#property indicator_plots 0

input int    InpLeftBars   = 5;      // barras a la izquierda del pivote
input int    InpRightBars  = 5;      // barras a la derecha (retardo de confirmacion)
input bool   InpUseWick    = false;  // true = confirma con mecha; false = con cierre
input int    InpBarsBack   = 600;    // barras a procesar
input int    InpMaxKeep    = 40;     // objetos historicos a conservar
input int    InpExtendBars = 5;      // prolongar la linea tras la ruptura
input bool   InpShowLines  = true;
input bool   InpShowLabels = true;
input bool   InpShowPanel  = true;
input bool   InpLogCsv     = true;   // registrar eventos en CSV
input bool   InpPanelAuto  = true;  // ubicar solo, al costado del panel del detector
input int    InpPanelX     = 124;   // panel: x (solo si InpPanelAuto=false)
input int    InpPanelY     = 436;   // panel: y (solo si InpPanelAuto=false)

#define PFX "TS2_"
#define MAXEV 300

struct S2Event
  {
   datetime t;        // vela que confirma la ruptura
   double   level;    // nivel roto
   datetime levelT;   // vela donde se formo ese nivel
   int      kind;     // 1=BOS alcista 2=BOS bajista 3=CHoCH alcista 4=CHoCH bajista
   double   price;    // cierre (o mecha) que confirmo
  };

S2Event  gEvs[];
int      gNEv = 0;
int      gTrend = 0;
double   gKeyHigh = 0, gKeyLow = 0;
double   gOriginHigh = 0, gOriginLow = 0;
datetime gLastLogged = 0;

//+------------------------------------------------------------------+
//| Un pivote alto en p exige que su maximo supere ESTRICTAMENTE a    |
//| los left anteriores y a los right siguientes. El estricto en los  |
//| dos lados evita que una meseta genere varios pivotes seguidos.    |
//+------------------------------------------------------------------+
bool IsPivotHigh(const MqlRates &r[], const int p, const int n)
  {
   if(p - InpLeftBars < 0 || p + InpRightBars >= n) return(false);
   double v = r[p].high;
   for(int j = p - InpLeftBars; j < p; j++)          if(r[j].high >= v) return(false);
   for(int j = p + 1; j <= p + InpRightBars; j++)    if(r[j].high >= v) return(false);
   return(true);
  }

bool IsPivotLow(const MqlRates &r[], const int p, const int n)
  {
   if(p - InpLeftBars < 0 || p + InpRightBars >= n) return(false);
   double v = r[p].low;
   for(int j = p - InpLeftBars; j < p; j++)          if(r[j].low <= v) return(false);
   for(int j = p + 1; j <= p + InpRightBars; j++)    if(r[j].low <= v) return(false);
   return(true);
  }

//+------------------------------------------------------------------+
int Scan()
  {
   gNEv = 0; ArrayResize(gEvs, MAXEV);

   MqlRates r[]; ArraySetAsSeries(r, false);
   int n = CopyRates(_Symbol, _Period, 0, InpBarsBack + InpLeftBars + InpRightBars + 5, r);
   if(n < InpLeftBars + InpRightBars + 20) return(0);

   double   lastPH = 0, lastPL = 0;
   datetime lastPHt = 0, lastPLt = 0;
   double   keyHigh = 0, keyLow = 0;
   datetime keyHighT = 0, keyLowT = 0;
   bool     keyHighBroken = false, keyLowBroken = false;
   double   originHigh = 0, originLow = 0;
   datetime originHighT = 0, originLowT = 0;
   bool     originHighBroken = false, originLowBroken = false;
   int      trend = 0;

   for(int i = InpLeftBars + InpRightBars; i < n; i++)
     {
      // El pivote se confirma InpRightBars barras despues de formarse: en la
      // barra i solo podemos saber de la barra i-InpRightBars. Ese retardo es
      // real y hay que respetarlo, o el indicador estaria mirando el futuro.
      int p = i - InpRightBars;

      if(IsPivotHigh(r, p, n))
        {
         lastPH = r[p].high; lastPHt = r[p].time;
         if(keyHigh == 0 || lastPH > keyHigh)
           { keyHigh = lastPH; keyHighT = lastPHt; keyHighBroken = false; }
         // el origen bajista se recalcula SIEMPRE con el pivote bajo previo
         if(lastPL > 0)
           { originLow = lastPL; originLowT = lastPLt; originLowBroken = false; }
        }

      if(IsPivotLow(r, p, n))
        {
         lastPL = r[p].low; lastPLt = r[p].time;
         if(keyLow == 0 || lastPL < keyLow)
           { keyLow = lastPL; keyLowT = lastPLt; keyLowBroken = false; }
         if(lastPH > 0)
           { originHigh = lastPH; originHighT = lastPHt; originHighBroken = false; }
        }

      double srcUp   = InpUseWick ? r[i].high : r[i].close;
      double srcDown = InpUseWick ? r[i].low  : r[i].close;

      if(trend == 0)
        {
         if(!originHighBroken && originHigh > 0 && srcUp > originHigh)
           {
            if(gNEv < MAXEV) { gEvs[gNEv].t=r[i].time; gEvs[gNEv].level=originHigh;
                               gEvs[gNEv].levelT=originHighT; gEvs[gNEv].kind=3;
                               gEvs[gNEv].price=srcUp; gNEv++; }
            originHighBroken = true;
            keyHigh = originHigh; keyHighT = originHighT; keyHighBroken = true;
            trend = 1;
           }
         else if(!originLowBroken && originLow > 0 && srcDown < originLow)
           {
            if(gNEv < MAXEV) { gEvs[gNEv].t=r[i].time; gEvs[gNEv].level=originLow;
                               gEvs[gNEv].levelT=originLowT; gEvs[gNEv].kind=4;
                               gEvs[gNEv].price=srcDown; gNEv++; }
            originLowBroken = true;
            keyLow = originLow; keyLowT = originLowT; keyLowBroken = true;
            trend = -1;
           }
        }
      else if(trend == 1)
        {
         if(!keyHighBroken && keyHigh > 0 && srcUp > keyHigh)
           {
            if(gNEv < MAXEV) { gEvs[gNEv].t=r[i].time; gEvs[gNEv].level=keyHigh;
                               gEvs[gNEv].levelT=keyHighT; gEvs[gNEv].kind=1;
                               gEvs[gNEv].price=srcUp; gNEv++; }
            keyHighBroken = true;
           }
         if(!originLowBroken && originLow > 0 && srcDown < originLow)
           {
            if(gNEv < MAXEV) { gEvs[gNEv].t=r[i].time; gEvs[gNEv].level=originLow;
                               gEvs[gNEv].levelT=originLowT; gEvs[gNEv].kind=4;
                               gEvs[gNEv].price=srcDown; gNEv++; }
            originLowBroken = true;
            keyLow = originLow; keyLowT = originLowT; keyLowBroken = true;
            trend = -1;
           }
        }
      else
        {
         if(!keyLowBroken && keyLow > 0 && srcDown < keyLow)
           {
            if(gNEv < MAXEV) { gEvs[gNEv].t=r[i].time; gEvs[gNEv].level=keyLow;
                               gEvs[gNEv].levelT=keyLowT; gEvs[gNEv].kind=2;
                               gEvs[gNEv].price=srcDown; gNEv++; }
            keyLowBroken = true;
           }
         if(!originHighBroken && originHigh > 0 && srcUp > originHigh)
           {
            if(gNEv < MAXEV) { gEvs[gNEv].t=r[i].time; gEvs[gNEv].level=originHigh;
                               gEvs[gNEv].levelT=originHighT; gEvs[gNEv].kind=3;
                               gEvs[gNEv].price=srcUp; gNEv++; }
            originHighBroken = true;
            keyHigh = originHigh; keyHighT = originHighT; keyHighBroken = true;
            trend = 1;
           }
        }
     }

   gTrend = trend; gKeyHigh = keyHigh; gKeyLow = keyLow;
   gOriginHigh = originHigh; gOriginLow = originLow;
   return(trend);
  }

//+------------------------------------------------------------------+
string KindTxt(const int k)
  {
   if(k == 1) return("BOS_ALCISTA");
   if(k == 2) return("BOS_BAJISTA");
   if(k == 3) return("CHOCH_ALCISTA");
   return("CHOCH_BAJISTA");
  }

//+------------------------------------------------------------------+
//| Registra los eventos nuevos. Reescribe el archivo entero en cada  |
//| pasada: el motor recalcula todo el historico, asi que un append   |
//| duplicaria cada evento en cada refresco.                          |
//+------------------------------------------------------------------+
void LogEvents()
  {
   if(!InpLogCsv || gNEv <= 0) return;
   if(gEvs[gNEv-1].t == gLastLogged) return;      // nada nuevo desde la ultima
   gLastLogged = gEvs[gNEv-1].t;

   string fn = StringFormat("TRADER-STRUCT2-%s-%s.csv", _Symbol, EnumToString(_Period));
   int fh = FileOpen(fn, FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON
                     | FILE_SHARE_READ | FILE_SHARE_WRITE, ',');
   if(fh == INVALID_HANDLE) return;
   FileWrite(fh, "confirm_time", "symbol", "timeframe", "event", "level",
             "level_time", "confirm_price", "left_bars", "right_bars", "use_wick");
   for(int i = 0; i < gNEv; i++)
      FileWrite(fh, TimeToString(gEvs[i].t, TIME_DATE | TIME_MINUTES), _Symbol,
                EnumToString(_Period), KindTxt(gEvs[i].kind),
                DoubleToString(gEvs[i].level, _Digits),
                TimeToString(gEvs[i].levelT, TIME_DATE | TIME_MINUTES),
                DoubleToString(gEvs[i].price, _Digits),
                (string)InpLeftBars, (string)InpRightBars,
                (InpUseWick ? "wick" : "close"));
   FileClose(fh);
  }

//+------------------------------------------------------------------+
void DrawLine(const string nm, const datetime t1, const datetime t2,
              const double p, const color c, const int w, const int style)
  {
   if(ObjectFind(0, nm) < 0) ObjectCreate(0, nm, OBJ_TREND, 0, t1, p, t2, p);
   ObjectSetInteger(0, nm, OBJPROP_TIME, 0, t1);
   ObjectSetDouble (0, nm, OBJPROP_PRICE, 0, p);
   ObjectSetInteger(0, nm, OBJPROP_TIME, 1, t2);
   ObjectSetDouble (0, nm, OBJPROP_PRICE, 1, p);
   ObjectSetInteger(0, nm, OBJPROP_COLOR, c);
   ObjectSetInteger(0, nm, OBJPROP_WIDTH, w);
   ObjectSetInteger(0, nm, OBJPROP_STYLE, style);
   ObjectSetInteger(0, nm, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
  }

void DrawLbl(const string nm, const datetime t, const double p,
             const string txt, const color c, const bool up)
  {
   if(ObjectFind(0, nm) < 0) ObjectCreate(0, nm, OBJ_TEXT, 0, t, p);
   ObjectSetInteger(0, nm, OBJPROP_TIME, 0, t);
   ObjectSetDouble (0, nm, OBJPROP_PRICE, 0, p);
   ObjectSetString (0, nm, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, nm, OBJPROP_COLOR, c);
   ObjectSetInteger(0, nm, OBJPROP_FONTSIZE, 8);
   ObjectSetString (0, nm, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, nm, OBJPROP_ANCHOR, up ? ANCHOR_LOWER : ANCHOR_UPPER);
   ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
  }

void PanelTxt(const string nm, const int x, const int y, const string s,
              const color c, const int sz)
  {
   if(ObjectFind(0, nm) < 0) ObjectCreate(0, nm, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, nm, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, nm, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, nm, OBJPROP_YDISTANCE, y);
   ObjectSetString (0, nm, OBJPROP_TEXT, s);
   ObjectSetInteger(0, nm, OBJPROP_COLOR, c);
   ObjectSetInteger(0, nm, OBJPROP_FONTSIZE, sz);
   ObjectSetString (0, nm, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
  }

// El detector (TRADER-ALERT-001) publica la geometria de su cuadro en variables
// globales del terminal. Leerlas deja este panel SIEMPRE fuera del cuadro, y lo
// hace seguir al cuadro si el usuario lo arrastra o lo redimensiona.
int DetectorRightX()
  {
   int bx = 12, bw = 232;
   if(GlobalVariableCheck("TA1_x")) bx = (int)GlobalVariableGet("TA1_x");
   if(GlobalVariableCheck("TA1_w")) bw = (int)GlobalVariableGet("TA1_w");
   return(bx + bw + 16);
  }

int DetectorTopY()
  {
   int by = 48;
   if(GlobalVariableCheck("TA1_y")) by = (int)GlobalVariableGet("TA1_y");
   return(by);
  }

//+------------------------------------------------------------------+
void Render()
  {
   Scan();
   LogEvents();

   ObjectsDeleteAll(0, PFX + "e");
   int first = MathMax(0, gNEv - InpMaxKeep);
   int per = PeriodSeconds(_Period);

   for(int i = first; i < gNEv; i++)
     {
      bool bull = (gEvs[i].kind == 1 || gEvs[i].kind == 3);
      bool choch = (gEvs[i].kind >= 3);
      color c = bull ? C'8,153,129' : C'242,54,69';
      if(InpShowLines)
         DrawLine(StringFormat("%se_l%d", PFX, i), gEvs[i].levelT,
                  gEvs[i].t + per * InpExtendBars, gEvs[i].level, c, 2, STYLE_SOLID);
      if(InpShowLabels)
         DrawLbl(StringFormat("%se_t%d", PFX, i), gEvs[i].t, gEvs[i].level,
                 (choch ? "CHoCH" : "BOS"), c, bull);
     }

   if(InpShowPanel)
     {
      int x = InpPanelX, y = InpPanelY;
      if(InpPanelAuto) { x = DetectorRightX(); y = DetectorTopY() + 140; }
      PanelTxt(PFX+"h", x, y, "BOS/CHoCH  (pivotes " +
               (string)InpLeftBars + "/" + (string)InpRightBars + ")", clrWhite, 10);
      string tt = (gTrend == 1 ? "ALCISTA" : (gTrend == -1 ? "BAJISTA" : "--"));
      color  tc = (gTrend == 1 ? clrLimeGreen : (gTrend == -1 ? clrRed : clrGray));
      PanelTxt(PFX+"t", x, y+18, EnumToString(_Period) + "   " + tt, tc, 10);
      int nB = 0, nC = 0;
      for(int i = 0; i < gNEv; i++) { if(gEvs[i].kind <= 2) nB++; else nC++; }
      PanelTxt(PFX+"c", x, y+36, StringFormat("BOS %d   CHoCH %d", nB, nC), clrSilver, 9);
      if(gNEv > 0)
         PanelTxt(PFX+"u", x, y+54, "ultimo: " + KindTxt(gEvs[gNEv-1].kind), clrSilver, 9);
      PanelTxt(PFX+"f", x, y+72, "lectura visual - no validada", C'130,140,160', 8);
     }
   ChartRedraw();
  }

//+------------------------------------------------------------------+
int OnInit()
  {
   ObjectsDeleteAll(0, PFX);
   EventSetTimer(5);
   Print("TRADER-STRUCTURE-002 activo en ", _Symbol, " ", EnumToString(_Period),
         "  [pivotes ", InpLeftBars, "/", InpRightBars,
         ", registra en CSV, NO es senal validada]");
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   if(reason == REASON_REMOVE) ObjectsDeleteAll(0, PFX);
  }

int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime &time[], const double &open[], const double &high[],
                const double &low[], const double &close[], const long &tick_volume[],
                const long &volume[], const int &spread[])
  {
   static datetime lastBar = 0;
   datetime cur = (rates_total > 0) ? time[rates_total-1] : 0;
   if(cur != lastBar) { lastBar = cur; Render(); }
   return(rates_total);
  }

// Bajo Wine un grafico que no se renderiza no recibe ticks y OnCalculate deja
// de llamarse (FINDINGS-001 §4.7). El temporizador no depende del grafico.
void OnTimer() { Render(); }
//+------------------------------------------------------------------+
