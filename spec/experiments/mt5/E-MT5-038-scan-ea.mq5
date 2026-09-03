//+------------------------------------------------------------------+
//| E-MT5-038-scan — ESCANEO HISTORICO DE LA ESTRATEGIA DEL TRADER    |
//|                                                                   |
//| Script, no EA. Carga todo el historico M1 de una vez y recorre las |
//| barras en orden. La DECISION en la barra i usa solo datos hasta i; |
//| la RESOLUCION busca desde i+1. Asi no mira el futuro para decidir  |
//| y a la vez puede resolver la carrera stop/objetivo, cosa que el EA |
//| dentro del tester no podia hacer: alli las barras futuras todavia  |
//| no existen y los 3 setups quedaron sin resolver.                   |
//|                                                                   |
//| Reporta un EMBUDO: cuantos candidatos sobreviven a cada filtro.    |
//| Eso es diagnostico, NO optimizacion: no se elige el mejor          |
//| parametro, se muestra donde se cae la señal.                       |
//+------------------------------------------------------------------+
#property copyright "PROJECT TRADER"
#property version   "1.00"
// EA: el trabajo va en OnInit para poder correr sin GUI

input string InpDesde       = "2025.01.01";
input string InpHasta       = "2026.08.27";
input int    InpWinAIni     = 570;   // 09:30 NY
input int    InpWinAFin     = 645;   // 10:45
input int    InpWinBIni     = 180;   // 03:00
input int    InpWinBFin     = 250;   // 04:10
input int    InpNyOffset    = -7;    // server(GMT+3) -> NY(EDT)
input int    InpPivL        = 3;
input int    InpPivR        = 3;
input double InpMinSweepP   = 1.0;
input int    InpMaxSweepChoch = 30;
input int    InpMaxChochFvg = 20;
input int    InpChochPivL   = 2;
input int    InpChochPivR   = 2;
input double InpRR          = 2.0;
input bool   InpUseTrend    = true;
input bool   InpUseMacd     = true;
input bool   InpUseFvg      = true;
input double InpCostPips    = 0.838;
input int    InpMaxHoldMin  = 240;
input bool   InpSweepCierraVuelta = true; // true: la vela cierra de vuelta (sweep clasico)
                                          // false: patron 1-2-3, la vela 2 cierra del otro lado

int gPip = 1;

// embudo
int cSweep=0, cVentana=0, cTend=0, cChoch=0, cFvg=0, cMacd=0, cEntradas=0;

struct Liq { double p; bool isHigh; datetime t; string tf; bool used; };

//+------------------------------------------------------------------+
int NyMin(const datetime t, const int off)
  { MqlDateTime d; TimeToStruct(t + off*3600, d); return(d.hour*60 + d.min); }

bool EnVentana(const datetime t)
  { int m = NyMin(t, InpNyOffset);
    return((m>=InpWinAIni && m<=InpWinAFin) || (m>=InpWinBIni && m<=InpWinBFin)); }

//+------------------------------------------------------------------+
//| Tendencia del TF en el momento t: ultimos dos maximos y minimos   |
//| de swing ANTERIORES a t. Nunca mira despues de t.                  |
//+------------------------------------------------------------------+
int TrendAt(const MqlRates &r[], const int n, const datetime t)
  {
   int last = -1;
   for(int i = 0; i < n; i++) { if(r[i].time <= t) last = i; else break; }
   if(last < 30) return(0);
   double h1=0,h2=0,l1=0,l2=0; int nh=0,nl=0;
   for(int p = last - InpPivR; p >= InpPivL && (nh<2 || nl<2); p--)
     {
      bool ih=true, il=true;
      for(int j=p-InpPivL;j<p;j++)      { if(r[j].high>=r[p].high) ih=false; if(r[j].low<=r[p].low) il=false; }
      for(int j=p+1;j<=p+InpPivR;j++)   { if(r[j].high>=r[p].high) ih=false; if(r[j].low<=r[p].low) il=false; }
      if(ih && nh<2) { if(nh==0) h1=r[p].high; else h2=r[p].high; nh++; }
      if(il && nl<2) { if(nl==0) l1=r[p].low;  else l2=r[p].low;  nl++; }
     }
   if(nh<2 || nl<2) return(0);
   if(h1>h2 && l1>l2) return(1);
   if(h1<h2 && l1<l2) return(-1);
   return(0);
  }

//+------------------------------------------------------------------+
int OnInit()
  {
   gPip = (_Digits==3 || _Digits==5) ? 10 : 1;
   double pipSz = gPip * _Point;
   datetime desde = StringToTime(InpDesde), hasta = StringToTime(InpHasta);

   MqlRates m1[], h1[], h4[];
   ArraySetAsSeries(m1,false); ArraySetAsSeries(h1,false); ArraySetAsSeries(h4,false);
   int n1 = CopyRates(_Symbol, PERIOD_M1, desde, hasta, m1);
   int nh1= CopyRates(_Symbol, PERIOD_H1, desde, hasta, h1);
   int nh4= CopyRates(_Symbol, PERIOD_H4, desde, hasta, h4);
   PrintFormat("E-MT5-038 barras: M1=%d  H1=%d  H4=%d   (%s a %s)", n1, nh1, nh4, InpDesde, InpHasta);
   if(n1 < 1000 || nh1 < 100) { Print("historia insuficiente"); return(INIT_FAILED); }

   // MACD sobre M1
   int hM = iMACD(_Symbol, PERIOD_M1, 12,26,9, PRICE_CLOSE);
   double mb[], sb[];
   ArraySetAsSeries(mb,false); ArraySetAsSeries(sb,false);
   int nm = CopyBuffer(hM, 0, desde, hasta, mb);
   int ns = CopyBuffer(hM, 1, desde, hasta, sb);
   bool macdOk = (nm >= n1-5 && ns >= n1-5);
   if(!macdOk) PrintFormat("AVISO: MACD incompleto (%d/%d) -> filtro MACD desactivado", nm, n1);

   // niveles de liquidez H1 y H4 (pivotes), con su momento de confirmacion
   Liq L[]; int nL = 0; ArrayResize(L, 6000);
   for(int k=0;k<2;k++)
     {
      int nn = (k==0)? nh1 : nh4;
      for(int p=InpPivL; p<nn-InpPivR && nL<6000; p++)
        {
         bool ih=true, il=true;
         if(k==0) { for(int j=p-InpPivL;j<p;j++){if(h1[j].high>=h1[p].high)ih=false; if(h1[j].low<=h1[p].low)il=false;}
                    for(int j=p+1;j<=p+InpPivR;j++){if(h1[j].high>=h1[p].high)ih=false; if(h1[j].low<=h1[p].low)il=false;} }
         else     { for(int j=p-InpPivL;j<p;j++){if(h4[j].high>=h4[p].high)ih=false; if(h4[j].low<=h4[p].low)il=false;}
                    for(int j=p+1;j<=p+InpPivR;j++){if(h4[j].high>=h4[p].high)ih=false; if(h4[j].low<=h4[p].low)il=false;} }
         if(!ih && !il) continue;
         if(ih) { L[nL].p = (k==0)? h1[p].high : h4[p].high; L[nL].isHigh = true; }
         else   { L[nL].p = (k==0)? h1[p].low  : h4[p].low;  L[nL].isHigh = false; }
         // el nivel existe recien cuando el pivote queda confirmado
         L[nL].t  = (k==0)? h1[p+InpPivR].time : h4[p+InpPivR].time;
         L[nL].tf = (k==0)? "H1" : "H4";
         L[nL].used = false;
         nL++;
        }
     }
   PrintFormat("niveles de liquidez detectados: %d", nL);

   int fh = FileOpen("E-MT5-038-setups.csv", FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON, ',');
   if(fh!=INVALID_HANDLE)
      FileWrite(fh,"entrada_t","min_ny","dir","liq_tf","nivel","entrada","stop",
                "target","riesgo_pips","resultado","R_bruto","R_neto");

   int gN=0, gW=0, gL2=0, gO=0; double rG=0, rN=0;

   // recorrido principal
   for(int i = 60; i < n1 - 1; i++)
     {
      datetime tb = m1[i].time;
      if(!EnVentana(tb)) continue;
      cVentana++;

      // --- 1) SWEEP de un nivel vigente
      int dir = 0; double lvl=0, ext=0; string src="";
      for(int q=0; q<nL; q++)
        {
         if(L[q].used || L[q].t >= tb) continue;
         if(tb - L[q].t > 20*86400) continue;   // liquidez de mas de 20 dias: caducada
         if(L[q].isHigh && m1[i].high > L[q].p)
           {
            bool cierra = InpSweepCierraVuelta ? (m1[i].close <= L[q].p) : true;
            if(cierra && (m1[i].high - L[q].p)/pipSz >= InpMinSweepP)
              { dir=-1; lvl=L[q].p; ext=m1[i].high; src=L[q].tf; L[q].used=true; break; }
           }
         if(!L[q].isHigh && m1[i].low < L[q].p)
           {
            bool cierra = InpSweepCierraVuelta ? (m1[i].close >= L[q].p) : true;
            if(cierra && (L[q].p - m1[i].low)/pipSz >= InpMinSweepP)
              { dir=1; lvl=L[q].p; ext=m1[i].low; src=L[q].tf; L[q].used=true; break; }
           }
        }
      if(dir==0) continue;
      cSweep++;

      // --- 2) tendencia H1 y H4 a favor
      if(InpUseTrend)
        {
         if(TrendAt(h1,nh1,tb)!=dir || TrendAt(h4,nh4,tb)!=dir) continue;
        }
      cTend++;

      // --- 3) CHoCH en M1 dentro del plazo
      int iCh = -1;
      double refCh = 0;
      for(int j=i+1; j<n1 && (m1[j].time - tb) <= InpMaxSweepChoch*60; j++)
        {
         // pivote opuesto mas reciente entre el sweep y j
         double ref=0;
         for(int p=j-InpChochPivR-1; p>i && p>=InpChochPivL+1; p--)
           {
            bool ok=true;
            if(dir>0){ for(int z=p-InpChochPivL;z<p;z++) if(m1[z].high>=m1[p].high) ok=false;
                       for(int z=p+1;z<=p+InpChochPivR;z++) if(m1[z].high>=m1[p].high) ok=false;
                       if(ok){ ref=m1[p].high; break; } }
            else     { for(int z=p-InpChochPivL;z<p;z++) if(m1[z].low<=m1[p].low) ok=false;
                       for(int z=p+1;z<=p+InpChochPivR;z++) if(m1[z].low<=m1[p].low) ok=false;
                       if(ok){ ref=m1[p].low; break; } }
           }
         if(ref<=0) continue;
         if(dir>0 ? (m1[j].close>ref) : (m1[j].close<ref)) { iCh=j; refCh=ref; break; }
        }
      if(iCh<0) continue;
      cChoch++;

      // --- 4) FVG en el sentido, despues del CHoCH
      int iE = -1;
      if(InpUseFvg)
        {
         for(int j=iCh+2; j<n1 && (m1[j].time - m1[iCh].time) <= InpMaxChochFvg*60; j++)
           {
            if(dir>0 && m1[j].low  > m1[j-2].high) { iE=j; break; }
            if(dir<0 && m1[j].high < m1[j-2].low)  { iE=j; break; }
           }
         if(iE<0) continue;
        }
      else iE = iCh;
      cFvg++;

      // --- 5) histograma MACD
      if(InpUseMacd && macdOk && iE < nm && iE > 0)
        {
         double h0 = mb[iE]-sb[iE], hm1 = mb[iE-1]-sb[iE-1];
         if(dir>0 && !(h0>0 || h0>hm1)) continue;
         if(dir<0 && !(h0<0 || h0<hm1)) continue;
        }
      cMacd++;

      // --- entrada, stop, objetivo
      double entrada = m1[iE].close;
      double stop = (dir>0) ? ext - pipSz : ext + pipSz;
      double riesgo = MathAbs(entrada-stop);
      if(riesgo <= 0.5*pipSz) continue;
      double target = entrada + dir*riesgo*InpRR;
      cEntradas++;

      // --- resolucion: SOLO barras posteriores a la entrada
      int res=0;
      for(int j=iE+1; j<n1 && (m1[j].time - m1[iE].time) <= InpMaxHoldMin*60; j++)
        {
         if(dir>0){ if(m1[j].low<=stop){res=-1;break;} if(m1[j].high>=target){res=1;break;} }
         else     { if(m1[j].high>=stop){res=-1;break;} if(m1[j].low<=target){res=1;break;} }
        }
      gN++;
      double a = (res==1)? InpRR : ((res==-1)? -1.0 : 0.0);
      double costoR = (InpCostPips*pipSz)/riesgo;
      double b = a - costoR;
      if(res==1) gW++; else if(res==-1) gL2++; else gO++;
      rG += a; rN += b;
      if(fh!=INVALID_HANDLE)
         FileWrite(fh, TimeToString(m1[iE].time, TIME_DATE|TIME_MINUTES),
                   (string)NyMin(m1[iE].time,InpNyOffset), (dir>0?"BUY":"SELL"), src,
                   DoubleToString(lvl,_Digits), DoubleToString(entrada,_Digits),
                   DoubleToString(stop,_Digits), DoubleToString(target,_Digits),
                   DoubleToString(riesgo/pipSz,1),
                   (res==1?"GANA":(res==-1?"PIERDE":"ABIERTA")),
                   DoubleToString(a,2), DoubleToString(b,2));
      i = iE;   // no solapar setups
     }
   if(fh!=INVALID_HANDLE) FileClose(fh);

   Print("═══════════ EMBUDO ═══════════");
   PrintFormat("  barras en ventana horaria : %d", cVentana);
   PrintFormat("  con SWEEP de liquidez     : %d", cSweep);
   PrintFormat("  + tendencia H1/H4 a favor : %d", cTend);
   PrintFormat("  + CHoCH en M1             : %d", cChoch);
   PrintFormat("  + FVG                     : %d", cFvg);
   PrintFormat("  + histograma MACD         : %d", cMacd);
   Print("═══════════ RESULTADO ═══════════");
   double wr = (gW+gL2>0)? 100.0*gW/(gW+gL2) : 0;
   PrintFormat("  operaciones %d   gana %d   pierde %d   sin resolver %d", gN,gW,gL2,gO);
   PrintFormat("  hit rate %.2f%%    break-even a 1:%.1f = %.2f%%", wr, InpRR, 100.0/(1.0+InpRR));
   PrintFormat("  R BRUTO %+.2f", rG);
   PrintFormat("  R NETO (costo %.3f p) %+.2f", InpCostPips, rN);
   return(INIT_SUCCEEDED);
  }

//--- el analisis corre entero en OnInit; no hace falta procesar ticks
void OnTick() {}
void OnDeinit(const int reason) {}
