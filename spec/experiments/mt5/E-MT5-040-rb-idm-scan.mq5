//+------------------------------------------------------------------+
//| E-MT5-040 — DETECTOR DE REJECTION BLOCK E INDUCEMENT              |
//|                                                                   |
//| Reglas: SPEC-RB-IDM-001.md, congelada antes de correr esto.        |
//|                                                                   |
//| NO evalua si ganan. Solo detecta y cuenta. El objetivo es medir    |
//| FRECUENCIA (setups por dia) y producir una lista de candidatos con |
//| fecha, hora y precio para que el trader marque si / no.            |
//|                                                                   |
//| Medir resultado aca seria contaminar: primero hay que saber si la  |
//| definicion identifica lo mismo que el ojo del trader.              |
//|                                                                   |
//| *** NO TRADING. Sin OrderSend. Solo lectura y CSV. ***             |
//+------------------------------------------------------------------+
#property copyright "PROJECT TRADER"
#property version   "1.00"

input string InpDesde       = "2026.06.01";
input string InpHasta       = "2026.09.04";
input int    InpNyOffset    = -7;     // servidor GMT+3 -> ET
input int    InpGmtOffset   = -3;
input int    InpAsiaIni     = 1380;   // 23:00 GMT
input int    InpAsiaFin     = 360;    // 06:00 GMT
input double InpMinSweepP   = 1.0;    // penetracion minima del nivel
input double InpMechaPct    = 50.0;   // mecha >= % del rango  (eleccion mia)
input int    InpRetestMin   = 60;     // minutos para volver a la zona (eleccion mia)
input bool   InpExigirM3M5  = true;   // confirmacion multi-TF (v2: "tambien en dos minutos")
input int    InpPivL        = 3;
input int    InpPivR        = 3;
input int    InpIdmPiv      = 2;      // pivote menor para el inducement
input double InpIdmMinP     = 0.3;    // penetracion minima del inducement
input bool   InpSoloVentana = false;  // false = todo el dia (para medir frecuencia real)
input int    InpWinAIni     = 570, InpWinAFin = 645;
input int    InpWinBIni     = 180, InpWinBFin = 250;

int gPip = 1; double pipSz = 0;
int cSweep=0, cRB=0, cRBmtf=0, cRetest=0;
int cIdmTomado=0, cIdmNo=0, cIdmNoHabia=0;

struct Liq { double p; bool isHigh; datetime tAlta, tBarrido; string kind; };
Liq L[]; int nL=0;

int MinDe(const datetime t,const int off)
  { MqlDateTime d; TimeToStruct(t+off*3600,d); return(d.hour*60+d.min); }
bool EnAsia(const datetime t)
  { int m=MinDe(t,InpGmtOffset); return(m>=InpAsiaIni || m<=InpAsiaFin); }
int DiaDe(const datetime t,const int off){ return((int)((t+off*3600)/86400)); }
bool EnVentana(const datetime t)
  { if(!InpSoloVentana) return(true);
    int m=MinDe(t,InpNyOffset);
    return((m>=InpWinAIni&&m<=InpWinAFin)||(m>=InpWinBIni&&m<=InpWinBFin)); }

//--- misma forma de RB en M3 o M5, con zona solapada
bool RBConfirmado(const MqlRates &r[],const int n,const int dir,
                  const datetime tRef,const double z1,const double z2)
  {
   double lo=MathMin(z1,z2), hi=MathMax(z1,z2);
   for(int k=1;k<n;k++)
     {
      if(r[k].time < tRef-1800) continue;
      if(r[k].time > tRef+1800) break;
      double rango=r[k].high-r[k].low; if(rango<=0) continue;
      double mecha,a,b;
      if(dir<0){ mecha=r[k].high-MathMax(r[k].open,r[k].close);
                 a=MathMax(r[k].open,r[k].close); b=r[k].high; }
      else     { mecha=MathMin(r[k].open,r[k].close)-r[k].low;
                 a=r[k].low; b=MathMin(r[k].open,r[k].close); }
      if(100.0*mecha/rango < InpMechaPct) continue;
      if(MathMax(a,b) >= lo && MathMin(a,b) <= hi) return(true);
     }
   return(false);
  }

int OnInit()
  {
   gPip=(_Digits==3||_Digits==5)?10:1; pipSz=gPip*_Point;
   datetime desde=StringToTime(InpDesde), hasta=StringToTime(InpHasta);

   MqlRates m1[],m3[],m5[],h1[],h4[],d1[];
   ArraySetAsSeries(m1,false); ArraySetAsSeries(m3,false); ArraySetAsSeries(m5,false);
   ArraySetAsSeries(h1,false); ArraySetAsSeries(h4,false); ArraySetAsSeries(d1,false);
   int n1=CopyRates(_Symbol,PERIOD_M1,desde,hasta,m1);
   int n3=CopyRates(_Symbol,PERIOD_M3,desde,hasta,m3);
   int n5=CopyRates(_Symbol,PERIOD_M5,desde,hasta,m5);
   int nh1=CopyRates(_Symbol,PERIOD_H1,desde,hasta,h1);
   int nh4=CopyRates(_Symbol,PERIOD_H4,desde,hasta,h4);
   int nd1=CopyRates(_Symbol,PERIOD_D1,desde,hasta,d1);
   PrintFormat("E-MT5-040 barras: M1=%d M3=%d M5=%d H1=%d H4=%d D1=%d (%s a %s)",
               n1,n3,n5,nh1,nh4,nd1,InpDesde,InpHasta);
   if(n1<1000||nd1<5){ Print("historia insuficiente"); return(INIT_FAILED); }

   //--- niveles: PDH/PDL + Asia + pivotes H1/H4
   ArrayResize(L,8000); nL=0;
   for(int d=1; d<nd1 && nL<7990; d++)
     {
      L[nL].p=d1[d-1].high; L[nL].isHigh=true;  L[nL].tAlta=d1[d].time; L[nL].tBarrido=0; L[nL].kind="PDH"; nL++;
      L[nL].p=d1[d-1].low;  L[nL].isHigh=false; L[nL].tAlta=d1[d].time; L[nL].tBarrido=0; L[nL].kind="PDL"; nL++;
     }
   int cur=-1; double aH=0,aL=0; bool hay=false;
   for(int i=0;i<n1;i++)
     {
      if(EnAsia(m1[i].time))
        { int dd=DiaDe(m1[i].time+7200,InpGmtOffset);
          if(dd!=cur){cur=dd; aH=m1[i].high; aL=m1[i].low; hay=true;}
          else { if(m1[i].high>aH)aH=m1[i].high; if(m1[i].low<aL)aL=m1[i].low; } }
      else if(hay && MinDe(m1[i].time,InpGmtOffset)>InpAsiaFin && nL<7990)
        { L[nL].p=aH; L[nL].isHigh=true;  L[nL].tAlta=m1[i].time; L[nL].tBarrido=0; L[nL].kind="ASIA_H"; nL++;
          L[nL].p=aL; L[nL].isHigh=false; L[nL].tAlta=m1[i].time; L[nL].tBarrido=0; L[nL].kind="ASIA_L"; nL++;
          hay=false; }
     }
   for(int k=0;k<2;k++)
     {
      int nn=(k==0)?nh1:nh4;
      for(int p=InpPivL;p<nn-InpPivR&&nL<7990;p++)
        {
         bool ih=true,il=true;
         if(k==0){for(int j=p-InpPivL;j<p;j++){if(h1[j].high>=h1[p].high)ih=false; if(h1[j].low<=h1[p].low)il=false;}
                  for(int j=p+1;j<=p+InpPivR;j++){if(h1[j].high>=h1[p].high)ih=false; if(h1[j].low<=h1[p].low)il=false;}}
         else    {for(int j=p-InpPivL;j<p;j++){if(h4[j].high>=h4[p].high)ih=false; if(h4[j].low<=h4[p].low)il=false;}
                  for(int j=p+1;j<=p+InpPivR;j++){if(h4[j].high>=h4[p].high)ih=false; if(h4[j].low<=h4[p].low)il=false;}}
         if(!ih&&!il) continue;
         if(ih){L[nL].p=(k==0)?h1[p].high:h4[p].high; L[nL].isHigh=true;  L[nL].kind=(k==0)?"H1_H":"H4_H";}
         else  {L[nL].p=(k==0)?h1[p].low :h4[p].low;  L[nL].isHigh=false; L[nL].kind=(k==0)?"H1_L":"H4_L";}
         L[nL].tAlta=(k==0)?h1[p+InpPivR].time:h4[p+InpPivR].time; L[nL].tBarrido=0; nL++;
        }
     }
   PrintFormat("niveles: %d", nL);

   int fh=FileOpen("E-MT5-040-candidatos.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',');
   if(fh!=INVALID_HANDLE)
      FileWrite(fh,"#","fecha_hora_servidor","hora_ET","hora_grafico_trader","dir",
                "nivel_tipo","nivel","rb_zona_desde","rb_zona_hasta","mecha_pct",
                "mtf_ok","retest_min","inducement","idm_precio","ES_RB?","ES_IDM?");

   int idcand=0;
   datetime tIni=0, tFin=0;
   for(int i=5;i<n1-1;i++)
     {
      datetime tb=m1[i].time;
      if(tIni==0) tIni=tb; tFin=tb;
      for(int q=0;q<nL;q++)
         if(L[q].tBarrido==0 && L[q].tAlta<tb)
           { if(L[q].isHigh  && (m1[i].high-L[q].p)/pipSz>=InpMinSweepP) L[q].tBarrido=tb;
             if(!L[q].isHigh && (L[q].p-m1[i].low )/pipSz>=InpMinSweepP) L[q].tBarrido=tb; }
      if(!EnVentana(tb)) continue;

      //--- 1) sweep
      int dir=0; double lvl=0; string kind="";
      for(int q=0;q<nL;q++)
        {
         if(L[q].tAlta>=tb) continue;
         if(L[q].tBarrido!=0 && L[q].tBarrido<tb) continue;
         if(L[q].isHigh && m1[i].high>L[q].p && m1[i].close<=L[q].p
            && (m1[i].high-L[q].p)/pipSz>=InpMinSweepP)
           { dir=-1; lvl=L[q].p; kind=L[q].kind; break; }
         if(!L[q].isHigh && m1[i].low<L[q].p && m1[i].close>=L[q].p
            && (L[q].p-m1[i].low)/pipSz>=InpMinSweepP)
           { dir=1; lvl=L[q].p; kind=L[q].kind; break; }
        }
      if(dir==0) continue;
      cSweep++;

      //--- 2) la vela del sweep, es Rejection Block?
      double rango=m1[i].high-m1[i].low; if(rango<=0) continue;
      double mecha, zA, zB;
      if(dir<0){ mecha=m1[i].high-MathMax(m1[i].open,m1[i].close);
                 zA=MathMax(m1[i].open,m1[i].close); zB=m1[i].high; }
      else     { mecha=MathMin(m1[i].open,m1[i].close)-m1[i].low;
                 zA=m1[i].low; zB=MathMin(m1[i].open,m1[i].close); }
      double pct=100.0*mecha/rango;
      if(pct < InpMechaPct) continue;
      cRB++;

      bool mtf = (!InpExigirM3M5) ||
                 RBConfirmado(m3,n3,dir,m1[i].time,zA,zB) ||
                 RBConfirmado(m5,n5,dir,m1[i].time,zA,zB);
      if(InpExigirM3M5 && !mtf) continue;
      cRBmtf++;

      //--- 3) el precio vuelve a la zona
      int iR=-1;
      double zLo=MathMin(zA,zB), zHi=MathMax(zA,zB);
      for(int j=i+2;j<n1 && (m1[j].time-m1[i].time)<=InpRetestMin*60;j++)
        { if(m1[j].high>=zLo && m1[j].low<=zHi){ iR=j; break; } }
      if(iR<0) continue;
      cRetest++;
      int minsRetest=(int)((m1[iR].time-m1[i].time)/60);

      //--- 4) inducement entre el sweep y el retest
      //    pivote menor en direccion contraria al trade, dentro del tramo
      double idm=0; string idmEst="no_habia";
      for(int p=iR-InpIdmPiv-1; p>i+InpIdmPiv; p--)
        {
         bool ok=true;
         if(dir>0){ for(int z=p-InpIdmPiv;z<p;z++) if(m1[z].high>=m1[p].high) ok=false;
                    for(int z=p+1;z<=p+InpIdmPiv;z++) if(m1[z].high>=m1[p].high) ok=false;
                    if(ok){ idm=m1[p].high; break; } }
         else     { for(int z=p-InpIdmPiv;z<p;z++) if(m1[z].low<=m1[p].low) ok=false;
                    for(int z=p+1;z<=p+InpIdmPiv;z++) if(m1[z].low<=m1[p].low) ok=false;
                    if(ok){ idm=m1[p].low; break; } }
        }
      if(idm>0)
        {
         idmEst="no_tomado";
         for(int j=i+1;j<=iR;j++)
           { if(dir>0 && (m1[j].high-idm)/pipSz>=InpIdmMinP){ idmEst="tomado"; break; }
             if(dir<0 && (idm-m1[j].low )/pipSz>=InpIdmMinP){ idmEst="tomado"; break; } }
        }
      if(idmEst=="tomado") cIdmTomado++;
      else if(idmEst=="no_tomado") cIdmNo++;
      else cIdmNoHabia++;

      idcand++;
      if(fh!=INVALID_HANDLE)
         FileWrite(fh,(string)idcand,
                   TimeToString(m1[i].time,TIME_DATE|TIME_MINUTES),
                   TimeToString(m1[i].time+InpNyOffset*3600,TIME_DATE|TIME_MINUTES),
                   TimeToString(m1[i].time+(InpNyOffset-1)*3600,TIME_DATE|TIME_MINUTES),
                   (dir>0?"COMPRA":"VENTA"), kind, DoubleToString(lvl,_Digits),
                   DoubleToString(zLo,_Digits), DoubleToString(zHi,_Digits),
                   DoubleToString(pct,1), (mtf?"si":"no"), (string)minsRetest,
                   idmEst, (idm>0?DoubleToString(idm,_Digits):"-"), "", "");
      i = iR;
     }
   if(fh!=INVALID_HANDLE) FileClose(fh);

   double dias=(double)(tFin-tIni)/86400.0;
   Print("═══════════ EMBUDO ═══════════");
   PrintFormat("  sweeps de liquidez            : %d", cSweep);
   PrintFormat("  + mecha >= %.0f%% (Rejection)   : %d", InpMechaPct, cRB);
   PrintFormat("  + confirmado en M3 o M5       : %d", cRBmtf);
   PrintFormat("  + el precio vuelve a la zona  : %d", cRetest);
   Print("═══════════ INDUCEMENT ═══════════");
   PrintFormat("  tomado antes de la zona : %d", cIdmTomado);
   PrintFormat("  no tomado               : %d", cIdmNo);
   PrintFormat("  no habia                : %d", cIdmNoHabia);
   Print("═══════════ FRECUENCIA ═══════════");
   PrintFormat("  periodo: %.1f dias corridos", dias);
   PrintFormat("  candidatos: %d  ->  %.2f por dia corrido", cRetest,
               (dias>0? cRetest/dias : 0));
   PrintFormat("  (SPEC-RB-IDM-001 §3.3: <0,3 estricta · 0,5-3 compatible · >6 laxa)");
   return(INIT_SUCCEEDED);
  }

void OnTick() {}
void OnDeinit(const int reason) {}
