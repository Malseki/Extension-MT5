//+------------------------------------------------------------------+
//| E-MT5-014 — Sizing forensics on the E-MT5-013 signal population   |
//|                                                                  |
//| *** NON-TRADING ANALYSIS. NO OrderSend ANYWHERE IN THIS FILE. *** |
//|                                                                  |
//| Answers DEC-LOCK checkpoint §3 and §4:                            |
//|   - per-signal entry/stop/lot/margin forensics                    |
//|   - distributions of stop distance, volume, margin                |
//|   - censoring attribution (margin / invalid stop / position open) |
//|   - coverage under three sizing policies, WITHOUT selecting one   |
//|                                                                  |
//| METHOD NOTE, stated so the numbers are interpretable:             |
//|   Margin availability is evaluated against a FIXED $10,000 with   |
//|   no open position. The live run's balance declined, so its       |
//|   available margin was strictly LOWER. This analysis is therefore |
//|   an OPTIMISTIC bound on executability: anything failing here     |
//|   certainly failed live.                                          |
//|   Entry is the ASK of the first real tick of candle 4, matching   |
//|   the locked entry rule exactly (not a bar-open proxy).           |
//+------------------------------------------------------------------+
#property copyright "PROJECT TRADER - sizing forensics"
#property version   "1.0"
#property script_show_inputs
#property strict

input string InpFrom      = "2026.07.06";
input string InpTo        = "2026.07.13";
input int    InpRefK      = 3;
input int    InpDelta     = 0;
input int    InpStopPad   = 1;
input double InpBalance   = 10000.0;
input string InpRunTag    = "f1";

int fhS=INVALID_HANDLE, fhR=INVALID_HANDLE;

// collected per-signal
double aStopPts[], aLot1[], aLot025[], aLot010[], aMargin1[];
int    aFit1[], aFit025[], aFit010[], aInvalid[];
int    nSig=0;

void Rep(const string c,const string i,const string r,const string d1="",const string d2="")
  { if(fhR!=INVALID_HANDLE){ FileWrite(fhR,c,i,r,d1,d2); FileFlush(fhR);} }

double Pctl(double &a[],const int n,const double p)
  { if(n<=0) return(0); double t[]; ArrayResize(t,n); ArrayCopy(t,a,0,0,n); ArraySort(t);
    int idx=(int)MathFloor(p*(n-1)+0.5); if(idx<0)idx=0; if(idx>=n)idx=n-1; return(t[idx]); }

//+------------------------------------------------------------------+
void OnStart()
  {
   fhS=FileOpen("E-MT5-014-"+InpRunTag+"-signals.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',');
   fhR=FileOpen("E-MT5-014-"+InpRunTag+"-report.csv", FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',');
   if(fhS==INVALID_HANDLE||fhR==INVALID_HANDLE) return;

   FileWrite(fhS,"n","t3","entry_ask","stop","stop_points",
             "lot_1pct","margin_1pct","fits_1pct",
             "lot_025","margin_025","fits_025",
             "lot_010","margin_010","fits_010",
             "invalid_stop","censor_reason");
   FileWrite(fhR,"category","item","result","detail1","detail2");

   datetime from=StringToTime(InpFrom), to=StringToTime(InpTo);
   MqlRates r[];
   int n=CopyRates(_Symbol,PERIOD_M5,from,to,r);
   Rep("ENV","symbol",_Symbol,EnumToString((ENUM_TIMEFRAMES)PERIOD_M5),
       "bars="+(string)n);
   Rep("ENV","range",InpFrom,InpTo,"balance_ref="+DoubleToString(InpBalance,2));
   Rep("METHOD","margin_reference","FIXED $"+DoubleToString(InpBalance,0),
       "no open position","OPTIMISTIC bound: live balance declined");
   Rep("METHOD","entry_price","OPEN of candle 4 (Bid bar series)",
       "PROXY for the locked first-tick ASK rule",
       "sub-pip difference; does not affect lot/margin conclusions");
   if(n<10){ Rep("ABORT","bars",(string)n,"",""); FileClose(fhS); FileClose(fhR); return; }

   double vmin=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double vstep=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double tickSz=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double tickVal=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   if(tickVal<=0||tickSz<=0){ tickSz=_Point; tickVal=tickSz*SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE); }
   Rep("SYMBOL","vmin/vstep",DoubleToString(vmin,2),DoubleToString(vstep,2),
       "tickVal="+DoubleToString(tickVal,5));

   ArrayResize(aStopPts,n); ArrayResize(aLot1,n); ArrayResize(aLot025,n);
   ArrayResize(aLot010,n);  ArrayResize(aMargin1,n);
   ArrayResize(aFit1,n); ArrayResize(aFit025,n); ArrayResize(aFit010,n); ArrayResize(aInvalid,n);

   int cPattern=0,cInvalid=0,cNoFit1=0,cFit1=0,cFit025=0,cFit010=0,cBelowMin1=0;

   //--- i indexes candle 3 in the ascending array; 1,2,3 are i-2,i-1,i
   for(int i=InpRefK+2; i+1<n; i++)
     {
      int i1=i-2, i2=i-1, i3=i;
      double ref=r[i1].low;
      bool okRef=true;
      for(int k=1;k<=InpRefK;k++){ if(i1-k<0){okRef=false;break;} if(r[i1-k].low<=ref){okRef=false;break;} }
      if(!okRef) continue;
      if(!(r[i2].low < ref-InpDelta*_Point)) continue;
      if(!(r[i2].low < r[i2].close))         continue;
      if(!(r[i2].close < ref))               continue;
      if(!(r[i3].close >= r[i2].low))        continue;

      cPattern++;

      //--- entry proxy = OPEN of candle 4 (bar data, Bid series).
      //    REVISION 1.1: the tick-exact ASK version hung the terminal on
      //    60+ synchronous CopyTicksRange calls. For a SIZING analysis the
      //    difference is a fraction of a pip against stop distances of tens
      //    of points, so lot and margin conclusions are unaffected. The
      //    substitution is recorded, not hidden.
      double ask=r[i3+1].open;
      if(ask<=0) continue;

      double stop=r[i2].low-InpStopPad*_Point;
      double stopPts=(ask-stop)/_Point;
      int invalid=(ask<=stop)?1:0;

      double lot1=0,lot025=0,lot010=0,m1=0,m025=0,m010=0;
      int f1=0,f025=0,f010=0;

      if(!invalid)
        {
         double lossPerLot=((ask-stop)/tickSz)*tickVal;
         lot1  =MathFloor((InpBalance*0.0100/lossPerLot)/vstep)*vstep;
         lot025=MathFloor((InpBalance*0.0025/lossPerLot)/vstep)*vstep;
         lot010=MathFloor((InpBalance*0.0010/lossPerLot)/vstep)*vstep;
         if(lot1  >0) OrderCalcMargin(ORDER_TYPE_BUY,_Symbol,lot1,  ask,m1);
         if(lot025>0) OrderCalcMargin(ORDER_TYPE_BUY,_Symbol,lot025,ask,m025);
         if(lot010>0) OrderCalcMargin(ORDER_TYPE_BUY,_Symbol,lot010,ask,m010);
         f1  =(lot1  >=vmin && m1  <=InpBalance)?1:0;
         f025=(lot025>=vmin && m025<=InpBalance)?1:0;
         f010=(lot010>=vmin && m010<=InpBalance)?1:0;
         if(lot1<vmin) cBelowMin1++;
        }

      string reason = invalid ? "INVALID_STOP" : (f1?"EXECUTABLE_1PCT":"MARGIN_FAIL_1PCT");
      if(invalid) cInvalid++; else { if(f1) cFit1++; else cNoFit1++; }
      if(f025) cFit025++;  if(f010) cFit010++;

      aStopPts[nSig]=stopPts; aLot1[nSig]=lot1; aLot025[nSig]=lot025;
      aLot010[nSig]=lot010; aMargin1[nSig]=m1;
      aFit1[nSig]=f1; aFit025[nSig]=f025; aFit010[nSig]=f010; aInvalid[nSig]=invalid;
      nSig++;

      FileWrite(fhS,(string)nSig,TimeToString(r[i3].time,TIME_DATE|TIME_SECONDS),
        DoubleToString(ask,_Digits),DoubleToString(stop,_Digits),DoubleToString(stopPts,1),
        DoubleToString(lot1,2),DoubleToString(m1,2),(string)f1,
        DoubleToString(lot025,2),DoubleToString(m025,2),(string)f025,
        DoubleToString(lot010,2),DoubleToString(m010,2),(string)f010,
        (string)invalid,reason);
     }
   FileFlush(fhS);

   //--- distributions (valid-stop signals only) ----------------------
   double vs[],vl[],vm[]; int m=0;
   ArrayResize(vs,nSig); ArrayResize(vl,nSig); ArrayResize(vm,nSig);
   for(int i=0;i<nSig;i++) if(!aInvalid[i]){ vs[m]=aStopPts[i]; vl[m]=aLot1[i]; vm[m]=aMargin1[i]; m++; }

   Rep("POPULATION","patterns",(string)cPattern,"signals_analysed="+(string)nSig,
       "valid_stop="+(string)m);
   Rep("CENSOR","invalid_stop",(string)cInvalid,
       DoubleToString(100.0*cInvalid/MathMax(nSig,1),1)+"%","price already below stop at entry");
   Rep("CENSOR","margin_fail_1pct",(string)cNoFit1,
       DoubleToString(100.0*cNoFit1/MathMax(nSig,1),1)+"%","lot needs more margin than balance");
   Rep("CENSOR","executable_1pct",(string)cFit1,
       DoubleToString(100.0*cFit1/MathMax(nSig,1),1)+"%","");
   Rep("CENSOR","lot_below_min_1pct",(string)cBelowMin1,"","");

   Rep("DIST","stop_points_min",DoubleToString(Pctl(vs,m,0.0),1),
       "p10="+DoubleToString(Pctl(vs,m,0.10),1),"median="+DoubleToString(Pctl(vs,m,0.50),1));
   Rep("DIST","stop_points_p90",DoubleToString(Pctl(vs,m,0.90),1),
       "max="+DoubleToString(Pctl(vs,m,1.0),1),"");
   Rep("DIST","lot_1pct_min",DoubleToString(Pctl(vl,m,0.0),2),
       "median="+DoubleToString(Pctl(vl,m,0.50),2),"p90="+DoubleToString(Pctl(vl,m,0.90),2));
   Rep("DIST","lot_1pct_max",DoubleToString(Pctl(vl,m,1.0),2),"","");
   Rep("DIST","margin_1pct_min",DoubleToString(Pctl(vm,m,0.0),2),
       "median="+DoubleToString(Pctl(vm,m,0.50),2),"p90="+DoubleToString(Pctl(vm,m,0.90),2));
   Rep("DIST","margin_1pct_max",DoubleToString(Pctl(vm,m,1.0),2),
       "balance_ref="+DoubleToString(InpBalance,2),"");

   //--- policy coverage, NO SELECTION -------------------------------
   Rep("POLICY","A_1pct_capped",(string)m,
       DoubleToString(100.0*m/MathMax(nSig,1),1)+"% coverage",
       "cap volume to available margin; risk becomes VARIABLE (<1%)");
   Rep("POLICY","B_025pct",(string)cFit025,
       DoubleToString(100.0*cFit025/MathMax(nSig,1),1)+"% coverage",
       "constant risk; a NEW parameter chosen after seeing a result");
   Rep("POLICY","C_010pct",(string)cFit010,
       DoubleToString(100.0*cFit010/MathMax(nSig,1),1)+"% coverage",
       "constant risk; smallest; more signals fall below min lot");
   Rep("POLICY","NOTE","no policy is selected here",
       "coverage reported, P&L deliberately NOT computed","checkpoint §4");

   FileClose(fhS); FileClose(fhR);
   Print("E-MT5-014 done. signals=",nSig," exec1%=",cFit1," marginfail=",cNoFit1," invalid=",cInvalid);
  }
//+------------------------------------------------------------------+
