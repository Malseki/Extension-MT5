//+------------------------------------------------------------------+
//| E-MT5-038 — BACKTEST DE LA ESTRATEGIA DEL TRADER                  |
//|                                                                   |
//| Implementa SPEC-STRAT-001 tal como el trader la describio:        |
//|   sweep de liquidez H1/H4 a favor de tendencia, dentro de ventana |
//|   -> CHoCH en M1 -> FVG en el sentido -> histograma MACD -> R:R 1:2|
//|                                                                   |
//| OBSERVADOR PURO. No envia ordenes: simula la carrera entre stop y |
//| objetivo sobre las barras M1 siguientes. Es como se midio todo lo |
//| demas en este proyecto y evita depender del motor de ordenes.     |
//|                                                                   |
//| Correr sobre M1. Reporta bruto Y neto de costo (E-MT5-032).       |
//+------------------------------------------------------------------+
#property copyright "PROJECT TRADER"
#property version   "1.00"
#property strict

input int    InpWinAIni     = 570;   // ventana A inicio, minutos NY (09:30)
input int    InpWinAFin     = 645;   // ventana A fin (10:45)
input int    InpWinBIni     = 180;   // ventana B inicio (03:00)
input int    InpWinBFin     = 250;   // ventana B fin (04:10)
input int    InpNyOffset    = -7;    // horas: server(GMT+3) -> NY(EDT)
input int    InpPivL        = 3;     // pivotes H1/H4: barras izquierda
input int    InpPivR        = 3;     // pivotes H1/H4: barras derecha
input double InpMinSweepP   = 1.0;   // penetracion minima del sweep (pips)
input int    InpMaxSweepChoch = 30;  // minutos maximos sweep -> CHoCH
input int    InpMaxChochFvg = 20;    // minutos maximos CHoCH -> FVG
input int    InpChochPivL   = 2;     // pivotes M1 para el CHoCH
input int    InpChochPivR   = 2;
input double InpRR          = 2.0;   // riesgo:recompensa
input bool   InpUseTrend    = true;  // exigir tendencia H1/H4 a favor
input bool   InpUseMacd     = true;  // exigir histograma a favor
input bool   InpUseFvg      = true;  // exigir FVG
input double InpCostPips    = 0.838; // costo real en la senal (E-MT5-032)
input int    InpMaxHoldMin  = 240;   // minutos maximos antes de descartar

int      gPip = 1;
int      hMacd = INVALID_HANDLE;
int      gFile = INVALID_HANDLE;

// --- niveles de liquidez H1/H4 pendientes
#define MAXLIQ 400
double   gLiqP[MAXLIQ]; bool gLiqHigh[MAXLIQ]; bool gLiqUsed[MAXLIQ];
datetime gLiqT[MAXLIQ]; string gLiqTF[MAXLIQ];
int      gNLiq = 0;
datetime gLastLiqScan = 0;

// --- maquina de estados del setup
#define S_IDLE   0
#define S_SWEEP  1
#define S_CHOCH  2
int      gState = S_IDLE;
int      gDir = 0;              // +1 compra, -1 venta
double   gSweepExtreme = 0;     // minimo/maximo del barrido -> stop
datetime gSweepT = 0, gChochT = 0;
double   gLiqLevel = 0; string gLiqSrc = "";

// --- estadisticas
int gN = 0, gWin = 0, gLoss = 0, gNone = 0;
double gRgross = 0, gRnet = 0;

//+------------------------------------------------------------------+
int NyMinutes(const datetime t)
  {
   MqlDateTime d; TimeToStruct(t + InpNyOffset * 3600, d);
   return(d.hour * 60 + d.min);
  }
bool EnVentana(const datetime t)
  {
   int m = NyMinutes(t);
   return((m >= InpWinAIni && m <= InpWinAFin) || (m >= InpWinBIni && m <= InpWinBFin));
  }

//+------------------------------------------------------------------+
//| Tendencia de un TF por estructura de pivotes: compara el ultimo   |
//| maximo y minimo de swing con los previos. Alcista = HH y HL.      |
//+------------------------------------------------------------------+
int TrendTF(const ENUM_TIMEFRAMES tf)
  {
   MqlRates r[]; ArraySetAsSeries(r, false);
   int n = CopyRates(_Symbol, tf, 0, 160, r);
   if(n < 40) return(0);
   double h1v=0,h2v=0,l1v=0,l2v=0; int nh=0,nl=0;
   for(int p = n - InpPivR - 1; p >= InpPivL && (nh < 2 || nl < 2); p--)
     {
      bool ih = true, il = true;
      for(int j = p - InpPivL; j < p; j++)      { if(r[j].high >= r[p].high) ih = false; if(r[j].low <= r[p].low) il = false; }
      for(int j = p + 1; j <= p + InpPivR; j++) { if(r[j].high >= r[p].high) ih = false; if(r[j].low <= r[p].low) il = false; }
      if(ih && nh < 2) { if(nh == 0) h1v = r[p].high; else h2v = r[p].high; nh++; }
      if(il && nl < 2) { if(nl == 0) l1v = r[p].low;  else l2v = r[p].low;  nl++; }
     }
   if(nh < 2 || nl < 2) return(0);
   if(h1v > h2v && l1v > l2v) return(1);
   if(h1v < h2v && l1v < l2v) return(-1);
   return(0);
  }

//+------------------------------------------------------------------+
void ScanLiquidez()
  {
   if(gLastLiqScan > 0 && TimeCurrent() - gLastLiqScan < 3600) return;
   gLastLiqScan = TimeCurrent();
   gNLiq = 0;
   ENUM_TIMEFRAMES tfs[2]; tfs[0] = PERIOD_H1; tfs[1] = PERIOD_H4;
   string tags[2]; tags[0] = "H1"; tags[1] = "H4";
   for(int k = 0; k < 2; k++)
     {
      MqlRates r[]; ArraySetAsSeries(r, false);
      int n = CopyRates(_Symbol, tfs[k], 0, 200, r);
      if(n < 20) continue;
      for(int p = InpPivL; p < n - InpPivR && gNLiq < MAXLIQ; p++)
        {
         bool ih = true, il = true;
         for(int j = p - InpPivL; j < p; j++)      { if(r[j].high >= r[p].high) ih = false; if(r[j].low <= r[p].low) il = false; }
         for(int j = p + 1; j <= p + InpPivR; j++) { if(r[j].high >= r[p].high) ih = false; if(r[j].low <= r[p].low) il = false; }
         if(!ih && !il) continue;
         // solo niveles NO tocados posteriormente
         double lvl = ih ? r[p].high : r[p].low; bool tocado = false;
         for(int q = p + InpPivR + 1; q < n; q++)
           { if(ih && r[q].high > lvl) { tocado = true; break; }
             if(!ih && r[q].low  < lvl) { tocado = true; break; } }
         if(tocado) continue;
         gLiqP[gNLiq] = lvl; gLiqHigh[gNLiq] = ih; gLiqT[gNLiq] = r[p].time;
         gLiqTF[gNLiq] = tags[k]; gLiqUsed[gNLiq] = false; gNLiq++;
        }
     }
  }

//+------------------------------------------------------------------+
//| CHoCH simple en M1: ruptura del ultimo pivote opuesto.            |
//+------------------------------------------------------------------+
bool ChochM1(const int dir, const datetime desde)
  {
   MqlRates r[]; ArraySetAsSeries(r, false);
   int n = CopyRates(_Symbol, PERIOD_M1, 0, 90, r);
   if(n < 20) return(false);
   double ref = 0;
   for(int p = n - InpChochPivR - 2; p >= InpChochPivL; p--)
     {
      if(r[p].time < desde) break;
      bool ok = true;
      if(dir > 0) { for(int j=p-InpChochPivL;j<p;j++) if(r[j].high>=r[p].high) ok=false;
                    for(int j=p+1;j<=p+InpChochPivR;j++) if(r[j].high>=r[p].high) ok=false;
                    if(ok) { ref = r[p].high; break; } }
      else        { for(int j=p-InpChochPivL;j<p;j++) if(r[j].low<=r[p].low) ok=false;
                    for(int j=p+1;j<=p+InpChochPivR;j++) if(r[j].low<=r[p].low) ok=false;
                    if(ok) { ref = r[p].low; break; } }
     }
   if(ref <= 0) return(false);
   double c = r[n-1].close;
   return(dir > 0 ? (c > ref) : (c < ref));
  }

//+------------------------------------------------------------------+
//| FVG en las ultimas velas M1, en el sentido operado.               |
//+------------------------------------------------------------------+
bool FvgM1(const int dir, double &zTop, double &zBot)
  {
   MqlRates r[]; ArraySetAsSeries(r, false);
   int n = CopyRates(_Symbol, PERIOD_M1, 0, 30, r);
   if(n < 5) return(false);
   for(int i = n - 1; i >= 2; i--)
     {
      if(dir > 0 && r[i].low > r[i-2].high) { zBot = r[i-2].high; zTop = r[i].low; return(true); }
      if(dir < 0 && r[i].high < r[i-2].low) { zTop = r[i-2].low;  zBot = r[i].high; return(true); }
     }
   return(false);
  }

//+------------------------------------------------------------------+
bool MacdOk(const int dir)
  {
   if(!InpUseMacd) return(true);
   double m[], s[];
   if(CopyBuffer(hMacd, 0, 0, 3, m) < 3) return(false);
   if(CopyBuffer(hMacd, 1, 0, 3, s) < 3) return(false);
   double h0 = m[2] - s[2], h1 = m[1] - s[1];
   // "arriba de cero, o retrocediendo hacia el sentido en el que apunto"
   if(dir > 0) return(h0 > 0 || h0 > h1);
   return(h0 < 0 || h0 < h1);
  }

//+------------------------------------------------------------------+
//| Simula la carrera stop/objetivo sobre las barras M1 siguientes.   |
//+------------------------------------------------------------------+
void Resolver(const int dir, const double entrada, const double stop,
              const datetime t0, const string liqTF, const double nivel)
  {
   double riesgo = MathAbs(entrada - stop);
   if(riesgo <= 0) return;
   double target = entrada + dir * riesgo * InpRR;

   MqlRates r[]; ArraySetAsSeries(r, false);
   int n = CopyRates(_Symbol, PERIOD_M1, t0, TimeCurrent() + InpMaxHoldMin * 60, r);
   int res = 0;   // 1 gana, -1 pierde, 0 sin resolver
   for(int i = 0; i < n; i++)
     {
      if(r[i].time <= t0) continue;
      if(dir > 0) { if(r[i].low  <= stop)   { res = -1; break; }
                    if(r[i].high >= target) { res =  1; break; } }
      else        { if(r[i].high >= stop)   { res = -1; break; }
                    if(r[i].low  <= target) { res =  1; break; } }
      if(r[i].time - t0 > InpMaxHoldMin * 60) break;
     }
   gN++;
   double rG = (res == 1) ? InpRR : ((res == -1) ? -1.0 : 0.0);
   double costoR = (InpCostPips * gPip * _Point) / riesgo;   // costo en unidades de R
   double rN = rG - costoR;
   if(res == 1) gWin++; else if(res == -1) gLoss++; else gNone++;
   gRgross += rG; gRnet += rN;

   if(gFile != INVALID_HANDLE)
      FileWrite(gFile, TimeToString(t0, TIME_DATE|TIME_MINUTES),
                (string)NyMinutes(t0), (dir > 0 ? "BUY" : "SELL"), liqTF,
                DoubleToString(nivel, _Digits), DoubleToString(entrada, _Digits),
                DoubleToString(stop, _Digits), DoubleToString(target, _Digits),
                DoubleToString(riesgo / (gPip * _Point), 1),
                (res == 1 ? "GANA" : (res == -1 ? "PIERDE" : "ABIERTA")),
                DoubleToString(rG, 2), DoubleToString(rN, 2));
  }

//+------------------------------------------------------------------+
int OnInit()
  {
   gPip = (_Digits == 3 || _Digits == 5) ? 10 : 1;
   hMacd = iMACD(_Symbol, PERIOD_M1, 12, 26, 9, PRICE_CLOSE);
   if(hMacd == INVALID_HANDLE) return(INIT_FAILED);
   gFile = FileOpen("E-MT5-038-setups.csv", FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON, ',');
   if(gFile != INVALID_HANDLE)
      FileWrite(gFile, "entrada_t", "min_ny", "dir", "liq_tf", "nivel",
                "entrada", "stop", "target", "riesgo_pips", "resultado",
                "R_bruto", "R_neto");
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   if(gFile != INVALID_HANDLE) FileClose(gFile);
   double wr = (gWin + gLoss > 0) ? 100.0 * gWin / (gWin + gLoss) : 0;
   PrintFormat("E-MT5-038 RESULTADO  n=%d  gana=%d  pierde=%d  sin_resolver=%d",
               gN, gWin, gLoss, gNone);
   PrintFormat("  hit rate %.2f%%   break-even a 1:%.1f = %.2f%%",
               wr, InpRR, 100.0 / (1.0 + InpRR));
   PrintFormat("  R BRUTO %+.2f      R NETO (costo %.3f p) %+.2f",
               gRgross, InpCostPips, gRnet);
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   static datetime lastBar = 0;
   datetime bt = iTime(_Symbol, PERIOD_M1, 0);
   if(bt == lastBar) return;
   lastBar = bt;

   ScanLiquidez();
   datetime ahora = TimeCurrent();

   // caducidad de estados
   if(gState == S_SWEEP && ahora - gSweepT > InpMaxSweepChoch * 60) gState = S_IDLE;
   if(gState == S_CHOCH && ahora - gChochT > InpMaxChochFvg   * 60) gState = S_IDLE;

   MqlRates m[]; ArraySetAsSeries(m, false);
   if(CopyRates(_Symbol, PERIOD_M1, 0, 3, m) < 3) return;
   double hi = m[1].high, lo = m[1].low, cl = m[1].close;
   datetime tb = m[1].time;

   if(gState == S_IDLE)
     {
      if(!EnVentana(tb)) return;                    // el SWEEP debe caer en ventana
      int tH1 = InpUseTrend ? TrendTF(PERIOD_H1) : 0;
      int tH4 = InpUseTrend ? TrendTF(PERIOD_H4) : 0;
      for(int i = 0; i < gNLiq; i++)
        {
         if(gLiqUsed[i]) continue;
         double pen = 0; int dir = 0;
         if(gLiqHigh[i] && hi > gLiqP[i] && cl <= gLiqP[i])
           { pen = (hi - gLiqP[i]) / (gPip * _Point); dir = -1; }   // barre maximo -> venta
         else if(!gLiqHigh[i] && lo < gLiqP[i] && cl >= gLiqP[i])
           { pen = (gLiqP[i] - lo) / (gPip * _Point); dir = +1; }   // barre minimo -> compra
         if(dir == 0 || pen < InpMinSweepP) continue;
         if(InpUseTrend && !(tH1 == dir && tH4 == dir)) continue;   // a favor de tendencia
         gState = S_SWEEP; gDir = dir; gSweepT = tb;
         gSweepExtreme = (dir > 0) ? lo : hi;
         gLiqLevel = gLiqP[i]; gLiqSrc = gLiqTF[i]; gLiqUsed[i] = true;
         break;
        }
      return;
     }

   if(gState == S_SWEEP)
     {
      if(ChochM1(gDir, gSweepT)) { gState = S_CHOCH; gChochT = tb; }
      return;
     }

   if(gState == S_CHOCH)
     {
      double zT = 0, zB = 0;
      bool fvg = InpUseFvg ? FvgM1(gDir, zT, zB) : true;
      if(!fvg) return;
      if(!MacdOk(gDir)) return;
      double entrada = cl;
      double stop = (gDir > 0) ? gSweepExtreme - 1 * gPip * _Point
                               : gSweepExtreme + 1 * gPip * _Point;
      Resolver(gDir, entrada, stop, tb, gLiqSrc, gLiqLevel);
      gState = S_IDLE;
     }
  }
