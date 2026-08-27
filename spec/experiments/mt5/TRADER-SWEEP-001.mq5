//+------------------------------------------------------------------+
//| TRADER-SWEEP-001 — LIQUIDEZ EN MAXIMOS/MINIMOS DE H1 Y H4         |
//|                                                                   |
//| QUE MUESTRA: donde hay liquidez acumulada (maximos y minimos de    |
//| swing sin tocar) y donde ya fue tomada. Distingue TRES estados,    |
//| porque mezclarlos es lo que vuelve inutil a la mayoria de estos    |
//| indicadores:                                                       |
//|                                                                   |
//|   PENDIENTE  el nivel sigue intacto -> ahi hay stops esperando    |
//|   SWEEP      la mecha lo atraviesa y el cuerpo cierra de vuelta   |
//|              -> liquidez tomada CON rechazo                       |
//|   RUPTURA    cierra del otro lado -> continuacion, no barrido     |
//|                                                                   |
//| ADVERTENCIA QUE NO SE PUEDE OMITIR:                                |
//| El patron "sweep + rechazo" es EXACTAMENTE el que este proyecto    |
//| refuto en E-MT5-022: -7 sigma, 12 años fuera de muestra, 12 de 12  |
//| años por debajo del nulo. Es el resultado mas contundente del      |
//| proyecto entero.                                                   |
//|                                                                   |
//| Entonces por que existe: ver donde quedo liquidez sin tomar es     |
//| informacion legitima para el criterio del operador, y el trader lo |
//| pidio para leer el mercado, no para automatizar entradas. Lo que   |
//| NO se puede hacer es tratar un SWEEP como senal: la evidencia      |
//| propia dice que no anticipa nada.                                  |
//|                                                                   |
//| Registra en TRADER-SWEEP.csv para poder medirlo algun dia. Hoy no  |
//| esta medido y no se afirma ninguna ventaja.                        |
//+------------------------------------------------------------------+
#property copyright "PROJECT TRADER"
#property version   "1.00"
#property strict
#property indicator_chart_window
#property indicator_plots 0

// Una temporalidad por bloque, con su propio left/right. El retardo de
// confirmacion es right x duracion de la vela: con right=3 en H1 un nivel
// tarda 3 HORAS en aparecer, y para operar intradia eso llega tarde. El
// 2026-08-27 el trader marco un objetivo en 1.16374 que el indicador no tenia,
// justamente por eso. M15 con right=2 lo confirma en 30 minutos.
input bool   InpUseM5      = false;  // niveles de 5 minutos
input int    InpLeftM5     = 3;
input int    InpRightM5    = 2;
input bool   InpUseM15     = true;   // niveles de 15 minutos
input int    InpLeftM15    = 3;
input int    InpRightM15   = 2;
input bool   InpUseH1      = true;   // niveles de 1 hora
input int    InpLeftH1     = 3;
input int    InpRightH1    = 2;
input bool   InpUseH4      = true;   // niveles de 4 horas
input int    InpLeftH4     = 3;
input int    InpRightH4    = 3;
input int    InpBarsBack   = 300;    // barras a procesar por TF
input int    InpMaxLevels  = 12;     // niveles a mostrar por TF y por lado
input bool   InpShowPend   = true;   // mostrar liquidez PENDIENTE
input bool   InpShowTaken  = true;   // mostrar la ya tomada
// Cupos SEPARADOS. Antes un solo contador de 6 mezclaba sweeps y rupturas, y
// como las rupturas son mas numerosas se comian el cupo: de 48 sweeps validos
// se dibujaban 6. El sweep es lo que el operador quiere ver, la ruptura es
// contexto.
input int    InpKeepSweep  = 24;     // sweeps (sobre umbral) a dibujar
input int    InpKeepBreak  = 8;      // rupturas a dibujar
input bool   InpLogCsv     = true;
// Umbral de penetracion. Medido sobre 50 sweeps de EURUSD el 2026-08-27:
// mediana 1,7 pips, y 11 de 50 (22%) penetraron MENOS que el spread real en
// el instante de la senal (0,838 p, E-MT5-032). Un barrido de 0,1 pips no es
// liquidez tomada, es ruido de cotizacion. El CSV los registra todos igual —
// el dato no se pierde — pero por debajo del umbral no se dibujan ni avisan.
input double InpMinSweepP  = 1.0;    // pips minimos de penetracion para mostrar
input bool   InpAviso      = true;   // avisar cuando ocurre un sweep nuevo
input bool   InpSonido     = true;
input int    InpPanelX     = 12;
input int    InpPanelY     = 560;

#define PFX  "TSW_"
// 200 quedaba corto con tres temporalidades activas: el 2026-08-27 se lleno
// exacto (M15 72 + H1 66 + H4 62) y como el escaneo va en orden, H4 quedaba
// truncado a la mitad. Un tope que se alcanza en silencio es peor que uno alto.
#define MAXL 600

//--- estado del nivel
#define ST_PEND   0
#define ST_SWEEP  1
#define ST_BREAK  2

struct Liq
  {
   datetime t;        // vela donde se formo el swing
   double   price;    // el nivel
   bool     isHigh;   // true = maximo (liquidez de compradores arriba)
   int      state;    // ST_*
   datetime tHit;     // cuando fue tomado (0 si sigue pendiente)
   double   wickBeyond; // cuanto lo penetro la mecha, en pips
   string   tf;
   int      perSec;     // duracion de la vela de ese TF, para la guarda de frescura
  };

Liq      gL[];
int      gNL = 0;
datetime gLastAviso = 0;
int      gPip = 1;

//+------------------------------------------------------------------+
bool PivHigh(const MqlRates &r[], const int p, const int n,
             const int left, const int right)
  {
   if(p - left < 0 || p + right >= n) return(false);
   double v = r[p].high;
   for(int j = p - left; j < p; j++)       if(r[j].high >= v) return(false);
   for(int j = p + 1; j <= p + right; j++) if(r[j].high >= v) return(false);
   return(true);
  }

bool PivLow(const MqlRates &r[], const int p, const int n,
            const int left, const int right)
  {
   if(p - left < 0 || p + right >= n) return(false);
   double v = r[p].low;
   for(int j = p - left; j < p; j++)       if(r[j].low <= v) return(false);
   for(int j = p + 1; j <= p + right; j++) if(r[j].low <= v) return(false);
   return(true);
  }

//+------------------------------------------------------------------+
//| Recorre un TF, junta sus swings y decide el estado de cada uno.   |
//|                                                                   |
//| La distincion clave esta aca: sobre un maximo, si una vela        |
//| posterior lo penetra con la mecha pero CIERRA por debajo, es un   |
//| SWEEP — se llevo los stops y el precio volvio. Si cierra por      |
//| encima, es RUPTURA: el nivel cedio y no hay rechazo que leer.     |
//+------------------------------------------------------------------+
void ScanTF(const ENUM_TIMEFRAMES tf, const string tag,
            const int left, const int right)
  {
   MqlRates r[]; ArraySetAsSeries(r, false);
   int n = CopyRates(_Symbol, tf, 0, InpBarsBack + left + right + 5, r);
   if(n < left + right + 10) return;

   double pipSz = gPip * _Point;

   for(int p = left; p < n - right; p++)
     {
      bool isH = PivHigh(r, p, n, left, right);
      bool isL = PivLow(r, p, n, left, right);
      if(!isH && !isL) continue;

      double lvl = isH ? r[p].high : r[p].low;
      int    st  = ST_PEND;
      datetime tHit = 0;
      double wick = 0;

      // El estado se decide mirando SOLO velas posteriores al swing, y desde
      // que quedo confirmado (p + right). Antes de eso el nivel no existia.
      for(int k = p + right + 1; k < n; k++)
        {
         if(isH && r[k].high > lvl)
           {
            wick = (r[k].high - lvl) / pipSz;
            st   = (r[k].close <= lvl) ? ST_SWEEP : ST_BREAK;
            tHit = r[k].time;
            break;
           }
         if(!isH && r[k].low < lvl)
           {
            wick = (lvl - r[k].low) / pipSz;
            st   = (r[k].close >= lvl) ? ST_SWEEP : ST_BREAK;
            tHit = r[k].time;
            break;
           }
        }

      if(gNL >= MAXL)
        {
         Print("TRADER-SWEEP-001: tope de ", MAXL, " niveles alcanzado en ", tag,
               ". Los TF siguientes quedan sin escanear — subi MAXL o baja InpBarsBack.");
         return;
        }
      gL[gNL].t = r[p].time; gL[gNL].price = lvl; gL[gNL].isHigh = isH;
      gL[gNL].state = st; gL[gNL].tHit = tHit; gL[gNL].wickBeyond = wick;
      gL[gNL].tf = tag; gL[gNL].perSec = PeriodSeconds(tf);
      gNL++;
     }
  }

//+------------------------------------------------------------------+
string StateTxt(const int s)
  {
   if(s == ST_PEND)  return("PENDIENTE");
   if(s == ST_SWEEP) return("SWEEP");
   return("RUPTURA");
  }

//+------------------------------------------------------------------+
void LogCsv()
  {
   if(!InpLogCsv || gNL <= 0) return;
   int fh = FileOpen("TRADER-SWEEP.csv", FILE_WRITE | FILE_CSV | FILE_ANSI
                     | FILE_COMMON | FILE_SHARE_READ | FILE_SHARE_WRITE, ',');
   if(fh == INVALID_HANDLE) return;
   FileWrite(fh, "swing_time", "tf", "tipo", "nivel", "estado",
             "tomado_en", "penetracion_pips", "dumped_at");
   string now = TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS);
   for(int i = 0; i < gNL; i++)
      FileWrite(fh, TimeToString(gL[i].t, TIME_DATE | TIME_MINUTES), gL[i].tf,
                (gL[i].isHigh ? "MAXIMO" : "MINIMO"),
                DoubleToString(gL[i].price, _Digits), StateTxt(gL[i].state),
                (gL[i].tHit > 0 ? TimeToString(gL[i].tHit, TIME_DATE | TIME_MINUTES) : "NA"),
                (gL[i].tHit > 0 ? DoubleToString(gL[i].wickBeyond, 1) : "NA"),
                now);
   FileClose(fh);
  }

//+------------------------------------------------------------------+
void Aviso()
  {
   if(!InpAviso || gNL <= 0) return;
   // el sweep mas reciente
   datetime best = 0; int idx = -1;
   for(int i = 0; i < gNL; i++)
      if(gL[i].state == ST_SWEEP && gL[i].wickBeyond >= InpMinSweepP
         && gL[i].tHit > best) { best = gL[i].tHit; idx = i; }
   if(idx < 0 || best == gLastAviso) return;

   // solo si es fresco: dentro de las ultimas 2 velas del TF de ese nivel
   int per = gL[idx].perSec;
   if(TimeCurrent() - best > 2 * per) { gLastAviso = best; return; }

   gLastAviso = best;
   string d = gL[idx].isHigh ? "ARRIBA (stops de compradores)"
                             : "ABAJO (stops de vendedores)";
   Print("SWEEP >>> liquidez tomada ", d, " | ", gL[idx].tf, " ",
         DoubleToString(gL[idx].price, _Digits), " | penetro ",
         DoubleToString(gL[idx].wickBeyond, 1), " pips y cerro de vuelta",
         "  [E-MT5-022 refuto este patron a -7 sigma: NO es senal]");
   if(InpSonido) PlaySound("tick.wav");
  }

//+------------------------------------------------------------------+
void DrawLvl(const string nm, const datetime t1, const datetime t2,
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
   ObjectSetInteger(0, nm, OBJPROP_BACK, true);
  }

void DrawTag(const string nm, const datetime t, const double p,
             const string s, const color c, const bool up)
  {
   if(ObjectFind(0, nm) < 0) ObjectCreate(0, nm, OBJ_TEXT, 0, t, p);
   ObjectSetInteger(0, nm, OBJPROP_TIME, 0, t);
   ObjectSetDouble (0, nm, OBJPROP_PRICE, 0, p);
   ObjectSetString (0, nm, OBJPROP_TEXT, s);
   ObjectSetInteger(0, nm, OBJPROP_COLOR, c);
   ObjectSetInteger(0, nm, OBJPROP_FONTSIZE, 7);
   ObjectSetString (0, nm, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, nm, OBJPROP_ANCHOR, up ? ANCHOR_LOWER : ANCHOR_UPPER);
   ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
  }

void Panel(const string nm, const int x, const int y, const string s,
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

//+------------------------------------------------------------------+
void Render()
  {
   gNL = 0; ArrayResize(gL, MAXL);
   if(InpUseM5)  ScanTF(PERIOD_M5,  "M5",  InpLeftM5,  InpRightM5);
   if(InpUseM15) ScanTF(PERIOD_M15, "M15", InpLeftM15, InpRightM15);
   if(InpUseH1)  ScanTF(PERIOD_H1,  "H1",  InpLeftH1,  InpRightH1);
   if(InpUseH4)  ScanTF(PERIOD_H4,  "H4",  InpLeftH4,  InpRightH4);

   LogCsv();
   Aviso();

   ObjectsDeleteAll(0, PFX + "n");

   datetime ahora = TimeCurrent();
   int drawnP = 0, drawnS = 0, drawnB = 0;
   int nPend = 0, nSweep = 0, nBreak = 0, nRuido = 0;

   // los mas recientes primero: la liquidez vieja importa menos
   for(int i = gNL - 1; i >= 0; i--)
     {
      if(gL[i].state == ST_PEND)  nPend++;
      if(gL[i].state == ST_SWEEP) { if(gL[i].wickBeyond >= InpMinSweepP) nSweep++; else nRuido++; }
      if(gL[i].state == ST_BREAK) nBreak++;

      bool pend  = (gL[i].state == ST_PEND);
      bool sweep = (gL[i].state == ST_SWEEP && gL[i].wickBeyond >= InpMinSweepP);
      bool ruido = (gL[i].state == ST_SWEEP && gL[i].wickBeyond <  InpMinSweepP);
      if(pend && (!InpShowPend || drawnP >= InpMaxLevels)) continue;
      if(!pend && !InpShowTaken) continue;
      if(sweep && drawnS >= InpKeepSweep) continue;
      if(!pend && !sweep && drawnB >= InpKeepBreak) continue;
      if(ruido) continue;                 // el ruido no se dibuja, solo se cuenta
      if(pend) drawnP++; else if(sweep) drawnS++; else drawnB++;

      color c; int w; int style; string tag;
      if(gL[i].state == ST_PEND)
        { c = (gL[i].isHigh ? C'120,140,170' : C'120,140,170'); w = 1; style = STYLE_DOT;
          tag = gL[i].tf + " liq"; }
      else if(gL[i].state == ST_SWEEP && gL[i].wickBeyond >= InpMinSweepP)
        { c = C'255,160,40'; w = 2; style = STYLE_SOLID;
          tag = gL[i].tf + " SWEEP " + DoubleToString(gL[i].wickBeyond, 1) + "p"; }
      else if(gL[i].state == ST_SWEEP)
        { c = C'90,100,120'; w = 1; style = STYLE_DOT;   // por debajo del umbral: ruido
          tag = gL[i].tf + " ruido " + DoubleToString(gL[i].wickBeyond, 1) + "p"; }
      else
        { c = C'90,110,140'; w = 1; style = STYLE_DASH; tag = gL[i].tf + " roto"; }

      datetime t2 = (gL[i].tHit > 0) ? gL[i].tHit : ahora;
      DrawLvl(StringFormat("%sn_l%d", PFX, i), gL[i].t, t2, gL[i].price, c, w, style);
      DrawTag(StringFormat("%sn_t%d", PFX, i), t2, gL[i].price, tag, c, gL[i].isHigh);
     }

   int y = InpPanelY;
   Panel(PFX+"h", InpPanelX, y, "LIQUIDEZ H1/H4", clrWhite, 10);
   Panel(PFX+"a", InpPanelX, y+18,
         StringFormat("pendiente %d   sweep %d   ruido %d   roto %d",
                      nPend, nSweep, nRuido, nBreak),
         clrSilver, 9);
   Panel(PFX+"b", InpPanelX, y+34, "sweep = mecha paso y cerro de vuelta", C'255,160,40', 8);
   Panel(PFX+"c", InpPanelX, y+48, "E-MT5-022 refuto este patron: NO es senal", C'200,120,120', 8);
   ChartRedraw();
  }

//+------------------------------------------------------------------+
int OnInit()
  {
   gPip = (_Digits == 3 || _Digits == 5) ? 10 : 1;
   ObjectsDeleteAll(0, PFX);
   EventSetTimer(5);
   Print("TRADER-SWEEP-001 activo en ", _Symbol,
         "  [liquidez H1/H4, visual + CSV, NO es senal validada]");
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

// Bajo Wine un grafico que no se renderiza no recibe ticks (FINDINGS-001 §4.7).
void OnTimer() { Render(); }
//+------------------------------------------------------------------+
