//+------------------------------------------------------------------+
//| TRADER-STRUCTURE-001 — HTF MARKET STRUCTURE TREND                 |
//|                                                                   |
//| Port a MQL5 del indicador Pine v6 "HTF Market Structure Trend"    |
//| aportado por el trader el 2026-08-25.                             |
//|                                                                   |
//| QUE ES: lectura VISUAL de estructura de mercado (BOS / CHoCH /    |
//| HH-LH-HL-LL) en varias temporalidades a la vez. Sirve para leer   |
//| contexto con criterio propio.                                     |
//|                                                                   |
//| QUE NO ES: una senal validada. Este proyecto refuto "sweep +      |
//| rechazo" a -7 sigma (E-MT5-022), que es de la misma familia que   |
//| BOS/CHoCH. Nada aqui fue medido ni pre-registrado. No se afirma   |
//| ninguna ventaja estadistica, y no debe leerse como si la tuviera. |
//|                                                                   |
//| NO ESCRIBE NINGUN ARCHIVO. No puede contaminar la muestra de      |
//| E-MT5-036 ni interferir con TRADER-ALERT-001.                     |
//+------------------------------------------------------------------+
#property copyright "PROJECT TRADER"
#property version   "1.00"
#property strict
#property indicator_chart_window
#property indicator_plots 0

input int    InpAtrPeriod    = 14;    // ATR period
input double InpMinDispATR   = 1.0;   // desplazamiento minimo (x ATR)
input int    InpMaxCandles   = 8;     // velas maximas para validar el candidato
input int    InpBosConfirm   = 1;     // cierres para confirmar ruptura (1 o 2)
input int    InpEmaPeriod    = 50;    // EMA de contexto
input int    InpBarsBack     = 400;   // barras a procesar por temporalidad
input bool   InpShowStruct   = true;  // dibujar etiquetas de estructura
input bool   InpShowPanel    = true;  // panel de tendencia
input bool   InpUseW         = true;  // usar 1 semana
input bool   InpUseD         = true;  // usar 1 dia
input bool   InpUse4H        = true;  // usar 4 horas
input bool   InpUse1H        = true;  // usar 1 hora
input int    InpPanelX       = 12;    // panel: x
input int    InpPanelY       = 436;   // panel: y (el detector ocupa 48..428)

#define PFX "TS1_"
#define MAXEV 400

//--- codigos: 1=HH/HL  2=LH/LL  3=primer nivel (bootstrap)
struct Ev
  {
   datetime t;        // momento del swing (donde se ancla la etiqueta)
   double   price;
   int      code;     // 1,2,3
   bool     isHigh;
  };

struct Brk
  {
   datetime t;
   double   price;
   int      kind;     // 1=BOS alcista 2=BOS bajista 3=CHoCH alcista 4=CHoCH bajista
  };

//+------------------------------------------------------------------+
//| Motor de estructura sobre un timeframe. Replica el Pine paso a    |
//| paso: leg tracking -> candidato -> validacion por desplazamiento  |
//| -> ruptura por cierres -> maquina de estados de tendencia.        |
//| Devuelve el trend final y llena los arrays de eventos a dibujar.  |
//+------------------------------------------------------------------+
int StructureScan(const string sym, const ENUM_TIMEFRAMES tf,
                  Ev &evs[], int &nEv, Brk &brks[], int &nBrk)
  {
   nEv = 0; nBrk = 0;

   MqlRates r[];
   ArraySetAsSeries(r, false);                 // indice 0 = mas antigua
   int need = InpBarsBack + InpAtrPeriod + 2;
   int got  = CopyRates(sym, tf, 0, need, r);
   if(got < InpAtrPeriod + 20) return(0);      // historia insuficiente

   // ---- ATR (media simple del true range, como ta.atr con RMA aproximada) --
   double atr[]; ArrayResize(atr, got); ArrayInitialize(atr, 0.0);
   double sumTR = 0;
   for(int i = 1; i < got; i++)
     {
      double tr = MathMax(r[i].high - r[i].low,
                  MathMax(MathAbs(r[i].high - r[i-1].close),
                          MathAbs(r[i].low  - r[i-1].close)));
      if(i <= InpAtrPeriod) { sumTR += tr; atr[i] = sumTR / i; }
      else                  atr[i] = (atr[i-1] * (InpAtrPeriod - 1) + tr) / InpAtrPeriod;
     }

   // ---- estado del motor (equivale a las var de Pine) ---------------------
   int      legDir = 0;
   double   legExtreme = 0, legAnchor = 0;
   datetime legExtremeTime = 0;

   double   candHigh = 0;      datetime candHighTime = 0;
   double   postCandHighLow = 0; bool candHighDispOK = false, candHighExpired = false;
   int      barsSinceCandHigh = 0;

   double   candLow = 0;       datetime candLowTime = 0;
   double   postCandLowHigh = 0; bool candLowDispOK = false, candLowExpired = false;
   int      barsSinceCandLow = 0;

   double   structHigh = 0, structLow = 0;
   int      aboveHighCount = 0, belowLowCount = 0;
   int      trendCode = 0, transState = 0;

   int start = MathMax(1, got - InpBarsBack);

   for(int i = start; i < got; i++)
     {
      double hi = r[i].high, lo = r[i].low, cl = r[i].close;
      datetime tt = r[i].time;
      double a = atr[i];

      int      hEventCode = 0; datetime hEventTime = 0;
      int      lEventCode = 0; datetime lEventTime = 0;
      int      bosCode = 0, chochCode = 0;

      // ============ 1) LEG TRACKING ============
      if(legDir == 0)
        {
         if(cl > r[i-1].close) { legDir = 1;  legExtreme = hi; legAnchor = lo; }
         else                  { legDir = -1; legExtreme = lo; legAnchor = hi; }
         legExtremeTime = tt;
        }
      else if(legDir == 1)
        {
         if(hi >= legExtreme) { legExtreme = hi; legAnchor = lo; legExtremeTime = tt; }
         else if(lo < legAnchor)
           {
            candHigh = legExtreme; candHighTime = legExtremeTime;
            postCandHighLow = lo; candHighDispOK = false; candHighExpired = false;
            barsSinceCandHigh = 0;
            legDir = -1; legExtreme = lo; legAnchor = hi; legExtremeTime = tt;
           }
        }
      else
        {
         if(lo <= legExtreme) { legExtreme = lo; legAnchor = hi; legExtremeTime = tt; }
         else if(hi > legAnchor)
           {
            candLow = legExtreme; candLowTime = legExtremeTime;
            postCandLowHigh = hi; candLowDispOK = false; candLowExpired = false;
            barsSinceCandLow = 0;
            legDir = 1; legExtreme = hi; legAnchor = lo; legExtremeTime = tt;
           }
        }

      // ============ 2) DESPLAZAMIENTO ============
      // El candidato solo se vuelve estructura si el precio se ALEJA lo
      // suficiente. Es el filtro que descarta los swings insignificantes.
      if(candHigh > 0 && !candHighExpired && !candHighDispOK)
        {
         postCandHighLow = MathMin(postCandHighLow, lo);
         barsSinceCandHigh++;
         if((candHigh - postCandHighLow) >= InpMinDispATR * a) candHighDispOK = true;
         else if(barsSinceCandHigh > InpMaxCandles)            candHighExpired = true;
        }
      if(candLow > 0 && !candLowExpired && !candLowDispOK)
        {
         postCandLowHigh = MathMax(postCandLowHigh, hi);
         barsSinceCandLow++;
         if((postCandLowHigh - candLow) >= InpMinDispATR * a) candLowDispOK = true;
         else if(barsSinceCandLow > InpMaxCandles)            candLowExpired = true;
        }

      // ============ 3) BOOTSTRAP ============
      if(structHigh == 0 && candHighDispOK && candHigh > 0)
        {
         structHigh = candHigh; hEventCode = 3; hEventTime = candHighTime;
         candHigh = 0; aboveHighCount = 0;
        }
      if(structLow == 0 && candLowDispOK && candLow > 0)
        {
         structLow = candLow; lEventCode = 3; lEventTime = candLowTime;
         candLow = 0; belowLowCount = 0;
        }

      // ============ 4) CONTEO DE CIERRES ============
      aboveHighCount = (structHigh > 0 && cl > structHigh) ? aboveHighCount + 1 : 0;
      belowLowCount  = (structLow  > 0 && cl < structLow)  ? belowLowCount  + 1 : 0;
      bool bullishBreak = (structHigh > 0 && aboveHighCount == InpBosConfirm);
      bool bearishBreak = (structLow  > 0 && belowLowCount  == InpBosConfirm);

      // ============ 5) RUPTURA ALCISTA ============
      if(bullishBreak)
        {
         if(candLow > 0 && candLowDispOK && !candLowExpired && structLow > 0)
           {
            lEventCode = (candLow > structLow) ? 1 : 2;   // HL o LL
            lEventTime = candLowTime;
            structLow = candLow; candLow = 0; belowLowCount = 0;
           }
         if(trendCode == 1)
           {
            if(transState == 1)
              {
               if(lEventCode == 2) { trendCode = -1; transState = 0; bosCode = 2; }
               else                { transState = 0; bosCode = 1; }
              }
            else bosCode = 1;
           }
         else if(trendCode == -1)
           {
            if(transState == 0) { chochCode = 1; transState = 2; }
            else if(transState == 2)
              {
               if(lEventCode == 1) { trendCode = 1; transState = 0; bosCode = 1; }
               else                { transState = 0; bosCode = 2; }
              }
           }
         else { trendCode = 1; bosCode = 1; }
        }

      // ============ 6) RUPTURA BAJISTA ============
      if(bearishBreak)
        {
         if(candHigh > 0 && candHighDispOK && !candHighExpired && structHigh > 0)
           {
            hEventCode = (candHigh > structHigh) ? 1 : 2;  // HH o LH
            hEventTime = candHighTime;
            structHigh = candHigh; candHigh = 0; aboveHighCount = 0;
           }
         if(trendCode == -1)
           {
            if(transState == 2)
              {
               if(hEventCode == 1) { trendCode = 1; transState = 0; bosCode = 1; }
               else                { transState = 0; bosCode = 2; }
              }
            else bosCode = 2;
           }
         else if(trendCode == 1)
           {
            if(transState == 0) { chochCode = 2; transState = 1; }
            else if(transState == 1)
              {
               if(hEventCode == 2) { trendCode = -1; transState = 0; bosCode = 2; }
               else                { transState = 0; bosCode = 1; }
              }
           }
         else { trendCode = -1; bosCode = 2; }
        }

      // ---- registrar lo que haya que dibujar ----
      if(hEventCode != 0 && nEv < MAXEV)
        { evs[nEv].t = hEventTime; evs[nEv].price = structHigh;
          evs[nEv].code = hEventCode; evs[nEv].isHigh = true;  nEv++; }
      if(lEventCode != 0 && nEv < MAXEV)
        { evs[nEv].t = lEventTime; evs[nEv].price = structLow;
          evs[nEv].code = lEventCode; evs[nEv].isHigh = false; nEv++; }
      if(bosCode != 0 && nBrk < MAXEV)
        { brks[nBrk].t = tt; brks[nBrk].kind = bosCode;
          brks[nBrk].price = (bosCode == 1 ? structHigh : structLow); nBrk++; }
      if(chochCode != 0 && nBrk < MAXEV)
        { brks[nBrk].t = tt; brks[nBrk].kind = (chochCode == 1 ? 3 : 4);
          brks[nBrk].price = (chochCode == 1 ? structLow : structHigh); nBrk++; }
     }

   return(trendCode);
  }

//+------------------------------------------------------------------+
void DrawTxt(const string name, const datetime t, const double p,
             const string txt, const color c, const int anchor)
  {
   if(t <= 0 || p <= 0) return;
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_TEXT, 0, t, p);
   ObjectSetInteger(0, name, OBJPROP_TIME, 0, t);
   ObjectSetDouble (0, name, OBJPROP_PRICE, 0, p);
   ObjectSetString (0, name, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, name, OBJPROP_COLOR, c);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetString (0, name, OBJPROP_FONT, "Arial");   // Consolas no existe en Wine
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
  }

//+------------------------------------------------------------------+
void RenderTF(const string tag, const ENUM_TIMEFRAMES tf, const bool use,
              int &trendOut)
  {
   trendOut = 0;
   if(!use) return;

   Ev  evs[];  ArrayResize(evs,  MAXEV);
   Brk brks[]; ArrayResize(brks, MAXEV);
   int nEv = 0, nBrk = 0;

   trendOut = StructureScan(_Symbol, tf, evs, nEv, brks, nBrk);
   if(!InpShowStruct) return;

   for(int i = 0; i < nEv; i++)
     {
      string txt = "";
      color  c   = clrGray;
      if(evs[i].isHigh)
        {
         if(evs[i].code == 1)      { txt = tag + " HH"; c = clrLimeGreen; }
         else if(evs[i].code == 2) { txt = tag + " LH"; c = clrOrange;    }
         else                      { txt = tag + " High"; c = clrGray;    }
        }
      else
        {
         if(evs[i].code == 1)      { txt = tag + " HL"; c = clrLimeGreen; }
         else if(evs[i].code == 2) { txt = tag + " LL"; c = clrRed;       }
         else                      { txt = tag + " Low"; c = clrGray;     }
        }
      DrawTxt(StringFormat("%s%s_e%d", PFX, tag, i), evs[i].t, evs[i].price, txt, c,
              evs[i].isHigh ? ANCHOR_LOWER : ANCHOR_UPPER);
     }

   for(int i = 0; i < nBrk; i++)
     {
      string txt; color c;
      if(brks[i].kind == 1)      { txt = tag + " BOS";   c = clrDodgerBlue; }
      else if(brks[i].kind == 2) { txt = tag + " BOS";   c = clrDodgerBlue; }
      else                       { txt = tag + " CHoCH"; c = clrMagenta;    }
      DrawTxt(StringFormat("%s%s_b%d", PFX, tag, i), brks[i].t, brks[i].price, txt, c,
              (brks[i].kind == 1 || brks[i].kind == 4) ? ANCHOR_LOWER : ANCHOR_UPPER);
     }
  }

//+------------------------------------------------------------------+
void PanelCell(const string name, const int x, const int y, const string txt,
               const color c, const int size)
  {
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString (0, name, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, name, OBJPROP_COLOR, c);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
   ObjectSetString (0, name, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
  }

string TrendTxt(const int c) { return(c == 1 ? "ALCISTA" : (c == -1 ? "BAJISTA" : "--")); }
color  TrendCol(const int c) { return(c == 1 ? clrLimeGreen : (c == -1 ? clrRed : clrGray)); }

//+------------------------------------------------------------------+
int OnInit()
  {
   ObjectsDeleteAll(0, PFX);
   EventSetTimer(5);
   Print("TRADER-STRUCTURE-001 activo en ", _Symbol,
         "  [lectura visual, NO escribe archivos, NO es senal validada]");
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   ObjectsDeleteAll(0, PFX);
  }

void Refresh()
  {
   int tw = 0, td = 0, t4 = 0, t1 = 0;
   RenderTF("1W", PERIOD_W1,  InpUseW,  tw);
   RenderTF("1D", PERIOD_D1,  InpUseD,  td);
   RenderTF("4H", PERIOD_H4,  InpUse4H, t4);
   RenderTF("1H", PERIOD_H1,  InpUse1H, t1);

   if(!InpShowPanel) return;
   int x = InpPanelX, y = InpPanelY;
   PanelCell(PFX + "hdr", x, y, "ESTRUCTURA HTF", clrWhite, 9);
   int row = 1;
   if(InpUseW)  { PanelCell(PFX+"rW", x, y+15*row, "1W   " + TrendTxt(tw), TrendCol(tw), 9); row++; }
   if(InpUseD)  { PanelCell(PFX+"rD", x, y+15*row, "1D   " + TrendTxt(td), TrendCol(td), 9); row++; }
   if(InpUse4H) { PanelCell(PFX+"r4", x, y+15*row, "4H   " + TrendTxt(t4), TrendCol(t4), 9); row++; }
   if(InpUse1H) { PanelCell(PFX+"r1", x, y+15*row, "1H   " + TrendTxt(t1), TrendCol(t1), 9); row++; }
   PanelCell(PFX + "ftr", x, y+15*row, "lectura visual - no validada", clrSilver, 8);
   ChartRedraw();
  }

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime &time[], const double &open[], const double &high[],
                const double &low[], const double &close[], const long &tick_volume[],
                const long &volume[], const int &spread[])
  {
   static datetime lastBar = 0;
   datetime cur = (rates_total > 0) ? time[rates_total-1] : 0;
   if(cur != lastBar) { lastBar = cur; Refresh(); }
   return(rates_total);
  }

// OnTimer cubre el caso conocido de este entorno: bajo Wine, un grafico que no
// se renderiza no recibe eventos de tick, y OnCalculate deja de llamarse. El
// temporizador del sistema es independiente del grafico (FINDINGS-001 §4.7).
void OnTimer() { Refresh(); }
//+------------------------------------------------------------------+
