//+------------------------------------------------------------------+
//| E-MT5-039 — ESCANEO DE LA ESTRATEGIA SEGUN LOS VIDEOS             |
//|                                                                   |
//| Reemplaza a E-MT5-038, que midio una version simplificada mal      |
//| derivada del texto. Reglas congeladas en SPEC-STRAT-002-videos.md  |
//| ANTES de correr esto.                                             |
//|                                                                   |
//| Cambios contra 038:                                               |
//|  - liquidez = PDH/PDL + Asia High/Low  (no pivotes H1/H4)          |
//|  - tendencia NO filtra: se etiqueta (el trader opera contratendencia)|
//|  - FVG debe ser "claro": M1 + confirmacion en M3 o M5              |
//|  - stop al borde lejano del FVG (no bajo el sweep)                 |
//|  - objetivo = proxima liquidez opuesta (no 2R fijo), min R:R 1.5   |
//|  - break-even a +1R                                               |
//|  - MACD NO filtra: se etiqueta                                    |
//|                                                                   |
//| La decision en la barra i usa solo datos hasta i.                  |
//| *** NO TRADING. Sin OrderSend. Solo lectura y CSV. ***             |
//+------------------------------------------------------------------+
#property copyright "PROJECT TRADER"
#property version   "1.00"

input string InpDesde        = "2025.01.01";
input string InpHasta        = "2026.09.03";
input int    InpWinAIni      = 570;   // 09:30 NY
input int    InpWinAFin      = 645;   // 10:45
input int    InpWinBIni      = 180;   // 03:00
input int    InpWinBFin      = 250;   // 04:10
input int    InpNyOffset     = -7;    // servidor GMT+3 -> ET
input int    InpGmtOffset    = -3;    // servidor GMT+3 -> GMT
input int    InpAsiaIni      = 1380;  // 23:00 GMT (dia anterior)
input int    InpAsiaFin      = 360;   // 06:00 GMT
input double InpMinSweepP    = 1.0;
input int    InpMaxSweepChoch= 30;
input int    InpMaxChochFvg  = 20;
input int    InpMaxEsperaFvg = 20;    // min para que el precio toque el FVG
input int    InpChochPivL    = 2;
input int    InpChochPivR    = 2;
input double InpMinFvgP      = 0.5;   // gap minimo en M1
input double InpBufferP      = 0.3;   // colchon del stop mas alla del FVG
input double InpMinRR        = 1.5;   // por debajo de esto no se toma
input double InpCostPips     = 0.838;
input int    InpMaxHoldMin   = 240;
input bool   InpBreakEven    = true;  // stop a la entrada al llegar a +1R
input bool   InpExigirM3M5   = true;  // FVG "claro": confirmado en M3 o M5
input int    InpPivL         = 3;     // pivotes H1/H4: barras a izquierda
input int    InpPivR         = 3;     // pivotes H1/H4: barras a derecha
input int    InpCaducaDias   = 0;     // 0 = los niveles no caducan

int gPip = 1;
double pipSz = 0;

// embudo
int cVentana=0, cSweep=0, cChoch=0, cFvg=0, cClaro=0, cToque=0, cRR=0;

struct Liq
  {
   double   p;
   bool     isHigh;
   datetime tAlta;    // desde cuando el nivel existe
   datetime tBarrido; // 0 = todavia en pie
   string   kind;
  };
Liq L[]; int nL = 0;

//+------------------------------------------------------------------+
int MinDe(const datetime t, const int off)
  { MqlDateTime d; TimeToStruct(t + off*3600, d); return(d.hour*60 + d.min); }

bool EnVentana(const datetime t)
  { int m = MinDe(t, InpNyOffset);
    return((m>=InpWinAIni && m<=InpWinAFin) || (m>=InpWinBIni && m<=InpWinBFin)); }

// la franja de Asia cruza medianoche: 23:00 -> 06:00 GMT
bool EnAsia(const datetime t)
  { int m = MinDe(t, InpGmtOffset);
    return(m >= InpAsiaIni || m <= InpAsiaFin); }

int DiaDe(const datetime t, const int off)
  { return((int)((t + off*3600) / 86400)); }

//+------------------------------------------------------------------+
//| tendencia por dos maximos y dos minimos de swing anteriores a t   |
//| NO filtra: solo se registra como etiqueta                          |
//+------------------------------------------------------------------+
int TrendAt(const MqlRates &r[], const int n, const datetime t)
  {
   int last = -1;
   for(int i=0;i<n;i++){ if(r[i].time<=t) last=i; else break; }
   if(last < 30) return(0);
   double h1=0,h2=0,l1=0,l2=0; int nh=0,nl=0;
   for(int p=last-3; p>=3 && (nh<2||nl<2); p--)
     {
      bool ih=true, il=true;
      for(int j=p-3;j<p;j++)    { if(r[j].high>=r[p].high) ih=false; if(r[j].low<=r[p].low) il=false; }
      for(int j=p+1;j<=p+3;j++) { if(r[j].high>=r[p].high) ih=false; if(r[j].low<=r[p].low) il=false; }
      if(ih && nh<2) { if(nh==0) h1=r[p].high; else h2=r[p].high; nh++; }
      if(il && nl<2) { if(nl==0) l1=r[p].low;  else l2=r[p].low;  nl++; }
     }
   if(nh<2||nl<2) return(0);
   if(h1>h2 && l1>l2) return(1);
   if(h1<h2 && l1<l2) return(-1);
   return(0);
  }

//+------------------------------------------------------------------+
//| FVG del mismo sentido en M3 o M5 que solape en precio con el de M1|
//+------------------------------------------------------------------+
bool FvgConfirmado(const MqlRates &r[], const int n, const int dir,
                   const datetime tRef, const double z1, const double z2)
  {
   double lo = MathMin(z1,z2), hi = MathMax(z1,z2);
   for(int k=2; k<n; k++)
     {
      if(r[k].time < tRef - 1800) continue;
      if(r[k].time > tRef + 1800) break;
      double g1=0, g2=0;
      if(dir>0 && r[k].low > r[k-2].high) { g1=r[k-2].high; g2=r[k].low; }
      else if(dir<0 && r[k].high < r[k-2].low) { g1=r[k].high; g2=r[k-2].low; }
      else continue;
      if(MathMax(g1,g2) >= lo && MathMin(g1,g2) <= hi) return(true);
     }
   return(false);
  }

//+------------------------------------------------------------------+
int OnInit()
  {
   gPip  = (_Digits==3 || _Digits==5) ? 10 : 1;
   pipSz = gPip * _Point;
   datetime desde = StringToTime(InpDesde), hasta = StringToTime(InpHasta);

   MqlRates m1[], m3[], m5[], h1[], d1[];
   ArraySetAsSeries(m1,false); ArraySetAsSeries(m3,false); ArraySetAsSeries(m5,false);
   ArraySetAsSeries(h1,false); ArraySetAsSeries(d1,false);
   int n1  = CopyRates(_Symbol, PERIOD_M1, desde, hasta, m1);
   int n3  = CopyRates(_Symbol, PERIOD_M3, desde, hasta, m3);
   int n5  = CopyRates(_Symbol, PERIOD_M5, desde, hasta, m5);
   int nh1 = CopyRates(_Symbol, PERIOD_H1, desde, hasta, h1);
   int nd1 = CopyRates(_Symbol, PERIOD_D1, desde, hasta, d1);
   PrintFormat("E-MT5-039 barras: M1=%d M3=%d M5=%d H1=%d D1=%d  (%s a %s)",
               n1,n3,n5,nh1,nd1, InpDesde, InpHasta);
   if(n1 < 1000 || nd1 < 20) { Print("historia insuficiente"); return(INIT_FAILED); }

   // MACD sobre M1 (etiqueta, no filtro)
   int hM = iMACD(_Symbol, PERIOD_M1, 12,26,9, PRICE_CLOSE);
   double mb[], sb[];
   ArraySetAsSeries(mb,false); ArraySetAsSeries(sb,false);
   int nm = CopyBuffer(hM,0,desde,hasta,mb);
   int ns = CopyBuffer(hM,1,desde,hasta,sb);
   bool macdOk = (nm >= n1-5 && ns >= n1-5);

   //--- NIVELES: PDH / PDL, uno por dia, vigentes desde el inicio del dia
   ArrayResize(L, 8000); nL = 0;
   for(int d=1; d<nd1 && nL<7990; d++)
     {
      datetime alta = d1[d].time;   // el dia nuevo arranca: el anterior ya cerro
      L[nL].p=d1[d-1].high; L[nL].isHigh=true;  L[nL].tAlta=alta; L[nL].tBarrido=0; L[nL].kind="PDH"; nL++;
      L[nL].p=d1[d-1].low;  L[nL].isHigh=false; L[nL].tAlta=alta; L[nL].tBarrido=0; L[nL].kind="PDL"; nL++;
     }

   //--- NIVELES: Asia High / Low, cerrados a las 06:00 GMT
   int curDia = -1; double aH=0, aL=0; bool hay=false;
   for(int i=0;i<n1;i++)
     {
      if(EnAsia(m1[i].time))
        {
         // el dia de la franja se ancla al final (la parte de 23:00 pertenece al dia siguiente)
         int dd = DiaDe(m1[i].time + 3600*2, InpGmtOffset);
         if(dd != curDia) { curDia=dd; aH=m1[i].high; aL=m1[i].low; hay=true; }
         else { if(m1[i].high>aH) aH=m1[i].high; if(m1[i].low<aL) aL=m1[i].low; }
        }
      else if(hay && MinDe(m1[i].time, InpGmtOffset) > InpAsiaFin && nL<7990)
        {
         L[nL].p=aH; L[nL].isHigh=true;  L[nL].tAlta=m1[i].time; L[nL].tBarrido=0; L[nL].kind="ASIA_H"; nL++;
         L[nL].p=aL; L[nL].isHigh=false; L[nL].tAlta=m1[i].time; L[nL].tBarrido=0; L[nL].kind="ASIA_L"; nL++;
         hay=false;
        }
     }
   //--- NIVELES: maximos/minimos de swing en H1 y H4
   //    el texto del trader los pedia y v5 los confirma ("liquidez interna" en 1h).
   //    Van SUMADOS a PDH/PDL y Asia, no en su lugar.
   MqlRates h4[]; ArraySetAsSeries(h4,false);
   int nh4 = CopyRates(_Symbol, PERIOD_H4, desde, hasta, h4);
   for(int k=0;k<2;k++)
     {
      int nn = (k==0)? nh1 : nh4;
      for(int p=InpPivL; p<nn-InpPivR && nL<7990; p++)
        {
         bool ih=true, il=true;
         if(k==0){ for(int j=p-InpPivL;j<p;j++){if(h1[j].high>=h1[p].high)ih=false; if(h1[j].low<=h1[p].low)il=false;}
                   for(int j=p+1;j<=p+InpPivR;j++){if(h1[j].high>=h1[p].high)ih=false; if(h1[j].low<=h1[p].low)il=false;} }
         else    { for(int j=p-InpPivL;j<p;j++){if(h4[j].high>=h4[p].high)ih=false; if(h4[j].low<=h4[p].low)il=false;}
                   for(int j=p+1;j<=p+InpPivR;j++){if(h4[j].high>=h4[p].high)ih=false; if(h4[j].low<=h4[p].low)il=false;} }
         if(!ih && !il) continue;
         if(ih){ L[nL].p=(k==0)?h1[p].high:h4[p].high; L[nL].isHigh=true;  L[nL].kind=(k==0)?"H1_H":"H4_H"; }
         else  { L[nL].p=(k==0)?h1[p].low :h4[p].low;  L[nL].isHigh=false; L[nL].kind=(k==0)?"H1_L":"H4_L"; }
         L[nL].tAlta = (k==0)? h1[p+InpPivR].time : h4[p+InpPivR].time;  // recien cuando el pivote queda confirmado
         L[nL].tBarrido = 0;
         nL++;
        }
     }
   PrintFormat("niveles de liquidez: %d  (PDH/PDL + Asia H/L + pivotes H1/H4)", nL);

   int fh = FileOpen("E-MT5-039-setups.csv", FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON, ',');
   if(fh!=INVALID_HANDLE)
      FileWrite(fh,"entrada_t","min_ny","dir","nivel_tipo","nivel","entrada","stop","target",
                "riesgo_p","rr","tendencia_h1","macd","rejblock","resultado","R_bruto","R_neto");

   int gN=0,gW=0,gL2=0,gBE=0,gO=0; double rG=0,rN=0;

   for(int i=60; i<n1-1; i++)
     {
      datetime tb = m1[i].time;

      // marcar niveles atravesados (mantiene "en pie" al dia)
      for(int q=0;q<nL;q++)
         if(L[q].tBarrido==0 && L[q].tAlta<tb)
           {
            // mismo umbral que el sweep: un roce de 0,1 pip no mata el nivel
            if(L[q].isHigh  && (m1[i].high-L[q].p)/pipSz >= InpMinSweepP) L[q].tBarrido = tb;
            if(!L[q].isHigh && (L[q].p-m1[i].low )/pipSz >= InpMinSweepP) L[q].tBarrido = tb;
           }

      if(!EnVentana(tb)) continue;
      cVentana++;

      //--- 1) SWEEP dentro de la ventana
      int dir=0; double lvl=0, ext=0; string kind="";
      for(int q=0;q<nL;q++)
        {
         if(L[q].tAlta>=tb) continue;
         if(L[q].tBarrido!=0 && L[q].tBarrido<tb) continue;   // ya estaba barrido de antes
         if(L[q].isHigh && m1[i].high>L[q].p && m1[i].close<=L[q].p
            && (m1[i].high-L[q].p)/pipSz >= InpMinSweepP)
           { dir=-1; lvl=L[q].p; ext=m1[i].high; kind=L[q].kind; break; }
         if(!L[q].isHigh && m1[i].low<L[q].p && m1[i].close>=L[q].p
            && (L[q].p-m1[i].low)/pipSz >= InpMinSweepP)
           { dir=1; lvl=L[q].p; ext=m1[i].low; kind=L[q].kind; break; }
        }
      if(dir==0) continue;
      cSweep++;

      //--- 2) CHoCH en M1
      int iCh=-1;
      for(int j=i+1; j<n1 && (m1[j].time-tb)<=InpMaxSweepChoch*60; j++)
        {
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
         if(dir>0 ? (m1[j].close>ref) : (m1[j].close<ref)) { iCh=j; break; }
        }
      if(iCh<0) continue;
      cChoch++;

      //--- 3) FVG en el sentido, y que sea CLARO
      int iF=-1; double zEnt=0, zLej=0;
      for(int j=iCh+2; j<n1 && (m1[j].time-m1[iCh].time)<=InpMaxChochFvg*60; j++)
        {
         double g1=0,g2=0;
         if(dir>0 && m1[j].low > m1[j-2].high) { g1=m1[j-2].high; g2=m1[j].low; }
         else if(dir<0 && m1[j].high < m1[j-2].low) { g1=m1[j].high; g2=m1[j-2].low; }
         else continue;
         if(MathAbs(g2-g1)/pipSz < InpMinFvgP) continue;
         iF=j;
         zEnt = (dir>0)? g2 : g1;   // borde que el precio toca al volver
         zLej = (dir>0)? g1 : g2;   // borde lejano: ahi va el stop
         break;
        }
      if(iF<0) continue;
      cFvg++;

      if(InpExigirM3M5)
        {
         bool ok3 = FvgConfirmado(m3,n3,dir,m1[iF].time,zEnt,zLej);
         bool ok5 = FvgConfirmado(m5,n5,dir,m1[iF].time,zEnt,zLej);
         if(!ok3 && !ok5) continue;
        }
      cClaro++;

      //--- 4) el precio vuelve a tocar el FVG
      int iE=-1;
      for(int j=iF+1; j<n1 && (m1[j].time-m1[iF].time)<=InpMaxEsperaFvg*60; j++)
        {
         if(dir>0 && m1[j].low <= zEnt) { iE=j; break; }
         if(dir<0 && m1[j].high>= zEnt) { iE=j; break; }
        }
      if(iE<0) continue;
      cToque++;

      double entrada = zEnt;
      // v1 pone el stop bajo el FVG; v3 lo pone bajo el minimo del sweep
      // ("aunque son varios pips de stop"). Se toma el MAS LEJANO de los dos:
      // el borde del FVG de M1 solo mide ~1 pip, menos que el spread, y con
      // 1R por debajo del costo el marco en R deja de significar nada.
      double ancla = (dir>0)? MathMin(zLej, ext) : MathMax(zLej, ext);
      double stop    = (dir>0)? ancla - InpBufferP*pipSz : ancla + InpBufferP*pipSz;
      double riesgo  = MathAbs(entrada-stop);
      if(riesgo <= 0.5*pipSz) continue;
      // un stop por debajo del costo de ejecucion no es una operacion real
      if(riesgo < InpCostPips*pipSz) { continue; }

      //--- 5) objetivo = proxima liquidez opuesta todavia en pie
      double target=0; bool hayT=false;
      for(int q=0;q<nL;q++)
        {
         if(L[q].tAlta>=m1[iE].time) continue;
         if(L[q].tBarrido!=0 && L[q].tBarrido<m1[iE].time) continue;
         if(dir>0 && L[q].p > entrada) { if(!hayT || L[q].p<target){target=L[q].p; hayT=true;} }
         if(dir<0 && L[q].p < entrada) { if(!hayT || L[q].p>target){target=L[q].p; hayT=true;} }
        }
      if(!hayT) continue;
      double rr = MathAbs(target-entrada)/riesgo;
      if(rr < InpMinRR) continue;
      cRR++;

      //--- etiquetas (no filtran)
      int trend = TrendAt(h1,nh1,m1[iE].time);
      string etTrend = (trend==0)? "plana" : ((trend==dir)? "a_favor":"contra");
      string etMacd = "NA";
      if(macdOk && iE<nm && iE>0)
        { double h0=mb[iE]-sb[iE]; etMacd = ((dir>0 && h0>0)||(dir<0 && h0<0))? "ok":"no"; }
      double rango = m1[iF].high-m1[iF].low;
      double mecha = (dir>0)? (MathMin(m1[iF].open,m1[iF].close)-m1[iF].low)
                            : (m1[iF].high-MathMax(m1[iF].open,m1[iF].close));
      string etRej = (rango>0 && mecha/rango>=0.6)? "si":"no";

      //--- 6) resolucion, con break-even a +1R
      //    dentro de una barra no se sabe el orden: se asume lo adverso primero
      double beNivel = entrada + dir*riesgo;
      bool   beOn=false; int res=99;
      for(int j=iE+1; j<n1 && (m1[j].time-m1[iE].time)<=InpMaxHoldMin*60; j++)
        {
         double stopVigente = beOn ? entrada : stop;
         if(dir>0)
           {
            if(m1[j].low  <= stopVigente) { res = beOn? 0 : -1; break; }
            if(m1[j].high >= target)      { res = 1; break; }
            if(InpBreakEven && !beOn && m1[j].high >= beNivel) beOn=true;
           }
         else
           {
            if(m1[j].high >= stopVigente) { res = beOn? 0 : -1; break; }
            if(m1[j].low  <= target)      { res = 1; break; }
            if(InpBreakEven && !beOn && m1[j].low <= beNivel) beOn=true;
           }
        }
      gN++;
      double a = (res==1)? rr : ((res==-1)? -1.0 : 0.0);
      double costoR = (InpCostPips*pipSz)/riesgo;
      double b = a - costoR;
      if(res==1) gW++; else if(res==-1) gL2++; else if(res==0) gBE++; else gO++;
      rG += a; rN += b;

      if(fh!=INVALID_HANDLE)
         FileWrite(fh, TimeToString(m1[iE].time, TIME_DATE|TIME_MINUTES),
                   (string)MinDe(m1[iE].time,InpNyOffset), (dir>0?"BUY":"SELL"),
                   kind, DoubleToString(lvl,_Digits), DoubleToString(entrada,_Digits),
                   DoubleToString(stop,_Digits), DoubleToString(target,_Digits),
                   DoubleToString(riesgo/pipSz,1), DoubleToString(rr,2),
                   etTrend, etMacd, etRej,
                   (res==1?"GANA":(res==-1?"PIERDE":(res==0?"BREAKEVEN":"ABIERTA"))),
                   DoubleToString(a,2), DoubleToString(b,2));
      i = iE;
     }
   if(fh!=INVALID_HANDLE) FileClose(fh);

   Print("═══════════ EMBUDO ═══════════");
   PrintFormat("  barras en ventana          : %d", cVentana);
   PrintFormat("  + SWEEP de PDH/PDL/Asia    : %d", cSweep);
   PrintFormat("  + CHoCH en M1              : %d", cChoch);
   PrintFormat("  + FVG en el sentido        : %d", cFvg);
   PrintFormat("  + FVG claro (M3 o M5)      : %d", cClaro);
   PrintFormat("  + el precio toca el FVG    : %d", cToque);
   PrintFormat("  + R:R >= %.1f al objetivo   : %d", InpMinRR, cRR);
   Print("═══════════ RESULTADO ═══════════");
   int dec = gW+gL2;
   double wr = (dec>0)? 100.0*gW/dec : 0;
   PrintFormat("  operaciones %d   gana %d   pierde %d   break-even %d   sin resolver %d",
               gN,gW,gL2,gBE,gO);
   PrintFormat("  hit rate (gana/(gana+pierde)) %.2f%%", wr);
   PrintFormat("  R BRUTO %+.2f", rG);
   PrintFormat("  R NETO (costo %.3f p) %+.2f", InpCostPips, rN);
   return(INIT_SUCCEEDED);
  }

void OnTick() {}
void OnDeinit(const int reason) {}
