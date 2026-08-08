//+------------------------------------------------------------------+
//| E-MT5-016 — Structural stop analysis (pre-registered candidates)  |
//|                                                                  |
//| *** NON-TRADING ANALYSIS. NO OrderSend. NO P&L COMPUTED. ***      |
//|                                                                  |
//| CHECKPOINT-002 §6. Candidates pre-registered BEFORE running:      |
//|   1, 3, 5, 10, 15, 20 points                                      |
//|                                                                  |
//| TWO INTERPRETATIONS, both reported, neither chosen:               |
//|   PAD   : stop = L(2) - X points        (widens every stop)       |
//|   FLOOR : stop = L(2) - 1 point, and a signal is EXCLUDED when    |
//|           its stop distance < X points  (changes which signals    |
//|           qualify — the reading §7 points at)                     |
//|                                                                  |
//| Sizing is Policy A throughout: 1% risk, volume capped by margin,  |
//| clamped to volume min/step/max. Stop definition and sizing are    |
//| reported separately, never conflated (§7).                        |
//+------------------------------------------------------------------+
#property copyright "PROJECT TRADER - stop structure"
#property version   "1.0"
#property script_show_inputs
#property strict

input string InpFrom     = "2026.07.06";
input string InpTo       = "2026.07.13";
input int    InpRefK     = 3;
input double InpBalance  = 10000.0;
input double InpRiskPct  = 1.0;
input int    InpMicroPts = 5;      // "micro-stop" threshold for reporting
input string InpRunTag   = "s1";

int fhR=INVALID_HANDLE;
double gEntry[], gL2[];
int    gN=0;

void Rep(const string c,const string i,const string r,const string d1="",const string d2="",const string d3="")
  { if(fhR!=INVALID_HANDLE){ FileWrite(fhR,c,i,r,d1,d2,d3); FileFlush(fhR);} }

double Pctl(double &a[],const int n,const double p)
  { if(n<=0) return(0); double t[]; ArrayResize(t,n); ArrayCopy(t,a,0,0,n); ArraySort(t);
    int i=(int)MathFloor(p*(n-1)+0.5); if(i<0)i=0; if(i>=n)i=n-1; return(t[i]); }

//--- Policy A: theoretical lot, then cap by margin, then clamp
double PolicyA(const double entry,const double stop,const double bal,
               double &theo,double &marginTheo,double &marginUsed,double &riskActual)
  {
   double vmin=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double vmax=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double vstep=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double ts=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double tv=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   if(ts<=0||tv<=0){ ts=_Point; tv=ts*SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE); }

   double lossPerLot=((entry-stop)/ts)*tv;
   if(lossPerLot<=0){ theo=0; marginTheo=0; marginUsed=0; riskActual=0; return(0); }

   theo=MathFloor((bal*InpRiskPct/100.0/lossPerLot)/vstep)*vstep;
   if(theo>vmax) theo=vmax;
   marginTheo=0; if(theo>0) OrderCalcMargin(ORDER_TYPE_BUY,_Symbol,theo,entry,marginTheo);

   double lot=theo;
   if(marginTheo>bal && marginTheo>0)
     {
      double mPerLot=marginTheo/theo;
      lot=MathFloor((bal/mPerLot)/vstep)*vstep;   // cap by available margin
     }
   if(lot<vmin) lot=0;                            // below min lot -> not executable
   if(lot>vmax) lot=vmax;
   marginUsed=0; if(lot>0) OrderCalcMargin(ORDER_TYPE_BUY,_Symbol,lot,entry,marginUsed);
   riskActual=lot*lossPerLot;
   return(lot);
  }

//+------------------------------------------------------------------+
void Analyse(const string mode,const int X)
  {
   double sd[],lots[],theos[],risks[],mgs[]; int m=0,excl=0,exec=0,micro=0;
   ArrayResize(sd,gN); ArrayResize(lots,gN); ArrayResize(theos,gN);
   ArrayResize(risks,gN); ArrayResize(mgs,gN);

   for(int i=0;i<gN;i++)
     {
      double stop = (mode=="PAD") ? gL2[i]-X*_Point : gL2[i]-1*_Point;
      double dist = (gEntry[i]-stop)/_Point;
      if(dist<=0){ excl++; continue; }
      if(mode=="FLOOR" && dist<X){ excl++; continue; }   // signal disqualified

      double theo,mT,mU,rA;
      double lot=PolicyA(gEntry[i],stop,InpBalance,theo,mT,mU,rA);
      if(dist<InpMicroPts) micro++;
      if(lot>0) exec++;
      sd[m]=dist; theos[m]=theo; lots[m]=lot; risks[m]=rA; mgs[m]=mU; m++;
     }

   Rep(mode,"X="+(string)X+"pts",
       "qualifying="+(string)m,
       "excluded="+(string)excl,
       "executable="+(string)exec+" ("+DoubleToString(100.0*exec/MathMax(m,1),1)+"%)",
       "micro<"+(string)InpMicroPts+"pts="+(string)micro);
   Rep(mode,"X="+(string)X+"_stopdist",
       "p10="+DoubleToString(Pctl(sd,m,0.10),1),
       "median="+DoubleToString(Pctl(sd,m,0.50),1),
       "p90="+DoubleToString(Pctl(sd,m,0.90),1),
       "max="+DoubleToString(Pctl(sd,m,1.0),1));
   Rep(mode,"X="+(string)X+"_lot",
       "theo_median="+DoubleToString(Pctl(theos,m,0.50),2),
       "theo_max="+DoubleToString(Pctl(theos,m,1.0),2),
       "capped_median="+DoubleToString(Pctl(lots,m,0.50),2),
       "capped_max="+DoubleToString(Pctl(lots,m,1.0),2));
   Rep(mode,"X="+(string)X+"_risk",
       "actual_risk_median=$"+DoubleToString(Pctl(risks,m,0.50),2),
       "actual_risk_min=$"+DoubleToString(Pctl(risks,m,0.0),2),
       "planned=$"+DoubleToString(InpBalance*InpRiskPct/100.0,2),
       "margin_median=$"+DoubleToString(Pctl(mgs,m,0.50),2));
  }

//+------------------------------------------------------------------+
void OnStart()
  {
   fhR=FileOpen("E-MT5-016-"+InpRunTag+"-stopstructure.csv",
                FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',');
   if(fhR==INVALID_HANDLE) return;
   FileWrite(fhR,"mode","item","v1","v2","v3","v4");

   datetime from=StringToTime(InpFrom), to=StringToTime(InpTo);
   MqlRates r[];
   int n=CopyRates(_Symbol,PERIOD_M5,from,to,r);
   Rep("ENV","range",InpFrom,InpTo,"bars="+(string)n,_Symbol);
   Rep("ENV","policy","A: "+DoubleToString(InpRiskPct,2)+"% risk, capped by margin",
       "balance=$"+DoubleToString(InpBalance,2),"NO P&L COMPUTED","");
   Rep("ENV","candidates","1,3,5,10,15,20 pts","PRE-REGISTERED",
       "PAD and FLOOR both reported","neither selected");
   if(n<10){ Rep("ABORT","bars",(string)n,"","",""); FileClose(fhR); return; }

   ArrayResize(gEntry,n); ArrayResize(gL2,n);
   for(int i=InpRefK+2;i+1<n;i++)
     {
      int i1=i-2,i2=i-1,i3=i;
      double ref=r[i1].low; bool ok=true;
      for(int k=1;k<=InpRefK;k++){ if(i1-k<0){ok=false;break;} if(r[i1-k].low<=ref){ok=false;break;} }
      if(!ok) continue;
      if(!(r[i2].low<ref))         continue;
      if(!(r[i2].low<r[i2].close)) continue;
      if(!(r[i2].close<ref))       continue;
      if(!(r[i3].close>=r[i2].low))continue;
      gEntry[gN]=r[i3+1].open;    // candle-4 open proxy (E-MT5-014 rev 1.1)
      gL2[gN]=r[i2].low; gN++;
     }
   Rep("POPULATION","signals",(string)gN,"same population as E-MT5-013/014","","");

   int cand[6]={1,3,5,10,15,20};
   for(int c=0;c<6;c++) Analyse("PAD",cand[c]);
   for(int c=0;c<6;c++) Analyse("FLOOR",cand[c]);

   Rep("NOTE","selection","NONE","stop candidate NOT chosen",
       "P&L deliberately not computed","CHECKPOINT-002 §6");
   FileClose(fhR);
   Print("E-MT5-016 done. signals=",gN);
  }
//+------------------------------------------------------------------+
