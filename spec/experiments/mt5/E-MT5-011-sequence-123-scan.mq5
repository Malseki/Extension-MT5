//+------------------------------------------------------------------+
//| E-MT5-011 — SECUENCIA 1-2-3 history scan (reading matrix)         |
//|                                                                  |
//| *** PATTERN COUNTER ONLY. NEVER TRADES. NO TRADE FUNCTIONS. ***   |
//|                                                                  |
//| Implements the pattern EXACTLY as the reference graphic states it |
//| ("RESUMEN DE LA SECUENCIA"), and also every competing reading of  |
//| the ambiguities the graphic does NOT settle, so their effect on   |
//| the detection count is measured rather than assumed.              |
//|                                                                  |
//| GRAPHIC (authoritative text, verbatim):                           |
//|   1. VELA 1: define el mínimo con liquidez                        |
//|   2. VELA 2: rompe el mínimo, cierra por debajo y deja mecha      |
//|   3. VELA 3: rechaza, no cierra por debajo del mínimo de vela 2   |
//|                                                                  |
//| => SW-4 = REQUIRED (cierra por debajo) — settled by the graphic   |
//| => SW-5 = R-a (no cierra por debajo del mínimo de vela 2)         |
//| => SW-6 = strict adjacency 1→2→3                                  |
//| Still open: SW-1 (what makes vela 1 valid), SW-3, SW-7, SW-8.     |
//+------------------------------------------------------------------+
#property copyright "PROJECT TRADER - pattern counter"
#property version   "1.0"
#property script_show_inputs
#property strict

input int  InpHistoryBars = 40000;   // closed bars to scan
input int  InpPivotK      = 2;       // pivot half-width for SW-1 option B
input int  InpDeltaPoints = 0;       // SW-3 minimum penetration
input string InpRunTag    = "graphic";

int fh = INVALID_HANDLE;

void Rep(const string c,const string i,const string r,const string d1="",const string d2="")
  { if(fh!=INVALID_HANDLE){ FileWrite(fh,c,i,r,d1,d2); FileFlush(fh);} }

//+------------------------------------------------------------------+
//| One evaluation of the sequence under a declared reading.          |
//| refMode : 0 = any preceding candle (SW-1 A)                       |
//|           1 = n-bar pivot low      (SW-1 B)                       |
//| sweepCl : 0 = must close beyond (GRAPHIC) 1 = must not 2 = either |
//| rejMode : 0 = R-a (graphic) 1 = R-b 2 = R-c 3 = R-d               |
//+------------------------------------------------------------------+
long ScanRange(const int n,const int refMode,const int pk,
               const int sweepCl,const int rejMode,long &armed)
  {
   long cnt=0; armed=0;
   double delta=InpDeltaPoints*_Point;
   for(int j=1;j+pk+4<n;j++)
     {
      int s=j+1, r=j+2;
      if(iTime(_Symbol,_Period,r)==0) continue;

      //--- SW-1 : is vela 1 a valid reference?
      double refLo=iLow(_Symbol,_Period,r);
      if(refMode==1)
        {
         bool piv=true;
         for(int k=1;k<=pk && piv;k++)
           {
            if(iTime(_Symbol,_Period,r+k)==0){ piv=false; break; }
            if(iLow(_Symbol,_Period,r+k)<=refLo) piv=false;
            if(iLow(_Symbol,_Period,r-k)< refLo) piv=false;
           }
         if(!piv) continue;
        }
      armed++;

      double sLo=iLow(_Symbol,_Period,s);
      double sCl=iClose(_Symbol,_Period,s);
      double sHi=iHigh(_Symbol,_Period,s);

      //--- VELA 2 : rompe el mínimo
      if(!(sLo < refLo-delta)) continue;
      //--- VELA 2 : deja mecha inferior
      if(!(sLo < sCl)) continue;
      //--- VELA 2 : cierra por debajo  (SW-4)
      if(sweepCl==0 && !(sCl <  refLo)) continue;
      if(sweepCl==1 && !(sCl >= refLo)) continue;

      //--- VELA 3 : rechazo (SW-5)
      double jCl=iClose(_Symbol,_Period,j);
      bool rej=false;
      if(rejMode==0)      rej=(jCl >= sLo);    // graphic: no cierra bajo min(V2)
      else if(rejMode==1) rej=(jCl >  sCl);
      else if(rejMode==2) rej=(jCl >  refLo);  // reclaim
      else                rej=(jCl >  sHi);
      if(!rej) continue;

      cnt++;
     }
   return(cnt);
  }

//+------------------------------------------------------------------+
void OnStart()
  {
   fh=FileOpen("E-MT5-011-"+InpRunTag+"-matrix.csv",
               FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',');
   if(fh==INVALID_HANDLE){ Print("cannot open output"); return; }
   FileWrite(fh,"category","item","result","detail1","detail2");

   Rep("ENV","build",(string)TerminalInfoInteger(TERMINAL_BUILD),
       AccountInfoString(ACCOUNT_SERVER),_Symbol);
   Rep("ENV","timeframe",EnumToString((ENUM_TIMEFRAMES)_Period),
       "digits="+(string)_Digits,"");
   Rep("GUARD","ACCOUNT_TRADE_MODE",
       (AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_DEMO)?"DEMO":"NOT_DEMO",
       "no trade function exists in this file","");

   int avail=Bars(_Symbol,_Period);
   int n=MathMin(InpHistoryBars,avail-InpPivotK-6);
   Rep("SCAN","bars_available",(string)avail,"scanned="+(string)n,
       (n>0?TimeToString(iTime(_Symbol,_Period,n),TIME_DATE|TIME_SECONDS):""));
   if(n<50){ Rep("SCAN","ABORT","not enough bars","",""); FileClose(fh); return; }

   string rnames[4]={"R-a GRAPHIC close>=low(V2)","R-b close>close(V2)",
                     "R-c close>reference","R-d close>high(V2)"};
   string snames[3]={"SW4=REQUIRED (GRAPHIC)","SW4=FORBIDDEN","SW4=EITHER"};

   for(int rm=0;rm<2;rm++)
     for(int sc=0;sc<3;sc++)
       for(int rj=0;rj<4;rj++)
         {
          long armed=0;
          long c=ScanRange(n,rm,InpPivotK,sc,rj,armed);
          double pct=(armed>0)?100.0*(double)c/(double)armed:0.0;
          Rep("MATRIX",
              (rm==0?"SW1=A any-candle":"SW1=B pivot k="+(string)InpPivotK),
              snames[sc], rnames[rj],
              "detections="+(string)c+"  refs_armed="+(string)armed+
              "  rate="+DoubleToString(pct,3)+"%");
         }

   //--- the graphic's own reading, isolated
   long armedG=0;
   long g0=ScanRange(n,0,InpPivotK,0,0,armedG);
   Rep("GRAPHIC","SW1=A_any + SW4=REQUIRED + SW5=R-a",(string)g0,
       "refs="+(string)armedG,"literal reading of RESUMEN DE LA SECUENCIA");
   long armedG2=0;
   long g1=ScanRange(n,1,InpPivotK,0,0,armedG2);
   Rep("GRAPHIC","SW1=B_pivot + SW4=REQUIRED + SW5=R-a",(string)g1,
       "refs="+(string)armedG2,"same, with a pivot reference");

   FileClose(fh);
   Print("E-MT5-011 done. graphic reading (any-candle ref) detections=",g0);
  }
//+------------------------------------------------------------------+
