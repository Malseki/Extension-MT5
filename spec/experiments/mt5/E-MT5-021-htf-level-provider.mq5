//+------------------------------------------------------------------+
//| E-MT5-021 — HTF LEVEL PROVIDER OBSERVER                           |
//|                                                                  |
//| *** NO TRADING. No <Trade\Trade.mqh>, no OrderSend, no account.   |
//|                                                                  |
//| WHAT THIS TESTS, AND WHY IT IS NOT A PARAMETER SEARCH             |
//| E-MT5-018 measured the 1-2-3 pattern with a LOCAL M5 reference    |
//| (SW-1 = A' K=3) and found 26.27% against a 33.333% null. That     |
//| falsified one operationalisation, not the market hypothesis: the  |
//| corpus's actual hypothesis is a sweep of a SIGNIFICANT H1/H4       |
//| level (CN-11 source_tf, CN-12 "significant H1 and H4 highs/lows"),|
//| and no experiment has ever supplied one.                          |
//|                                                                  |
//| This run changes exactly ONE thing: where the reference level     |
//| comes from. Execution series stays M5 so the comparison against   |
//| E-MT5-018 is controlled.                                          |
//|                                                                  |
//| Three providers are observed SIMULTANEOUSLY and NONE is selected: |
//|   P0  A' K=3 on M5          — the baseline, reproduces E-MT5-018  |
//|   P1  confirmed pivot on H1, (k,m) = (2,2)   — CN-03 / CN-12 G1   |
//|   P2  confirmed pivot on H4, (k,m) = (2,2)   — CN-03 / CN-12 G1   |
//| The -1R/+2R null is 33.333% for every provider and every X, so    |
//| observing several is a test of the hypothesis class, not a sweep. |
//|                                                                  |
//| PRE-REGISTERED BEFORE ANY RESULT WAS SEEN:                        |
//|   - (k,m) = (2,2). Arbitrary. provenance: arbitrary (SPEC-000 7.2)|
//|   - a level is CONSUMED on its first penetration, resolved or not |
//|   - a level is usable only from t_known = pivot bar + m HTF bars  |
//|   - X observed over {1, 5, 15}. No X is selected by this file.    |
//|                                                                  |
//| DECLARED VIOLATION — A-6. H1/H4 bars are taken from the platform, |
//| not aggregated from M1 with a declared anchor. SPEC-000 4.5 says  |
//| platform HTF boundaries are broker- and DST-dependent. Therefore  |
//| this result is BROKER-DEPENDENT and exploratory. A validated      |
//| version requires DEC-004 and DEC-005, both OPEN. Stated up front  |
//| rather than discovered later.                                     |
//|                                                                  |
//| Pattern rules unchanged from the locked set: SW-3 delta=0,        |
//| SW-4 REQUIRED, wick beyond close, SW-5 R-a, S->J and J->E strictly|
//| adjacent on M5, entry at the first tick of E, TARGET_R = 2.0.     |
//| Under an external provider there is no candle 1 in the M5 series, |
//| so SW-6's candle1->candle2 clause has no referent; the S->J->E    |
//| adjacency is preserved. Recorded, not resolved.                   |
//+------------------------------------------------------------------+
#property copyright "PROJECT TRADER - HTF level provider observer"
#property version   "1.0"
#property strict

input int    InpRefK      = 3;      // A' K for the M5 baseline provider
input int    InpPivK      = 2;      // pivot left width,  pre-registered
input int    InpPivM      = 2;      // pivot right width, pre-registered
input double InpTargetR   = 2.0;    // LOCKED
input int    InpHorizon   = 500;    // M5 bars before UNRESOLVED
input string InpRunTag    = "e21";

#define NX 3
int   XS[NX] = {1, 5, 15};          // observed, never selected
#define NPROV 3                     // 0 = A' M5, 1 = H1 pivot, 2 = H4 pivot
#define MAXLVL 4096
#define MAXOPEN 8192

struct Bar { datetime t; double o,h,l,c; };

//--- a level supplied by a provider, matching the ReferenceLevel contract
struct Level
  {
   int      prov;        // provider id
   int      dir;         // +1 the level is a low  (SELL_SIDE liquidity, bullish setup)
                         // -1 the level is a high (BUY_SIDE  liquidity, bearish setup)
   double   price;
   datetime t_formed;
   datetime t_available;
   bool     alive;
  };

//--- one signal: a level that was penetrated and then resolved
struct Sig
  {
   int      prov, dir;
   datetime t_level, t_avail, t_S, t_J, t_E;
   double   level, sweep, entry;
   double   age_bars;    // M5 bars between t_available and penetration
   int      res[NX];     // 0 open 1 target-first 2 stop-first 3 unresolved 4 no-stop
   double   risk[NX];
  };

struct VT { int sid, xi, dir; double stop, target; int bars; };

Level gL[MAXLVL];  int gNL = 0;
Sig   gS[];        int gN  = 0;
VT    gO[MAXOPEN]; int gOpen = 0;

//--- pending pattern state, one slot per provider
struct Pend { bool armed; int lidx; datetime tS; double sweep; int stage; };
Pend gP[NPROV];

datetime gLastM5 = 0, gLastH1 = 0, gLastH4 = 0;
int  fh = INVALID_HANDLE;
long gPen = 0, gNoResolve = 0, gGap = 0;

//====================================================================
double Ext(const Bar &b,const int d){ return(d>0 ? b.l : b.h); }
bool   Beyond(const double x,const double y,const int d){ return(d*(x-y) < 0.0); }
bool   AtLeast(const double x,const double y,const int d){ return(d*(x-y) >= 0.0); }

void AddLevel(const int prov,const int dir,const double price,
              const datetime tf,const datetime ta)
  {
   if(gNL >= MAXLVL)
     { // drop the oldest dead slot, else the oldest slot
      int w = 0; for(int i=0;i<gNL;i++) if(!gL[i].alive){ w = i; break; }
      for(int i=w;i<gNL-1;i++) gL[i] = gL[i+1];
      gNL--;
     }
   gL[gNL].prov = prov; gL[gNL].dir = dir; gL[gNL].price = price;
   gL[gNL].t_formed = tf; gL[gNL].t_available = ta; gL[gNL].alive = true;
   gNL++;
  }

//--- confirmed pivot on an HTF, CN-03: left non-strict, right strict.
//--- Only closed bars are read; shift m+1 is the newest confirmable bar.
void ScanPivots(const ENUM_TIMEFRAMES tf,const int prov)
  {
   int k = InpPivK, m = InpPivM, i = m + 1;
   if(Bars(_Symbol,tf) < i + k + 2) return;
   double lo = iLow (_Symbol,tf,i), hi = iHigh(_Symbol,tf,i);
   bool isLow = true, isHigh = true;
   for(int j=1;j<=k;j++)
     { if(iLow (_Symbol,tf,i+j) <  lo) isLow  = false;
       if(iHigh(_Symbol,tf,i+j) >  hi) isHigh = false; }
   for(int j=1;j<=m;j++)
     { if(iLow (_Symbol,tf,i-j) <= lo) isLow  = false;
       if(iHigh(_Symbol,tf,i-j) >= hi) isHigh = false; }
   datetime tf_formed = iTime(_Symbol,tf,i);
   datetime tf_known  = iTime(_Symbol,tf,0);   // the bar that just opened: pivot is now decidable
   if(isLow)  AddLevel(prov,+1,lo,tf_formed,tf_known);
   if(isHigh) AddLevel(prov,-1,hi,tf_formed,tf_known);
  }

//====================================================================
int OnInit()
  {
   fh = FileOpen("E-MT5-021-"+InpRunTag+"-signals.csv",
                 FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON, ',');
   if(fh == INVALID_HANDLE) return(INIT_FAILED);
   ArrayResize(gS, 0, 8192);
   FileWrite(fh,"provider","dir","t_level","t_available","t_S","t_J","t_E",
             "level","sweep","entry","age_bars",
             "res_x1","res_x5","res_x15","risk_x1","risk_x5","risk_x15");
   for(int p=0;p<NPROV;p++){ gP[p].armed=false; gP[p].stage=0; }
   PrintFormat("E-MT5-021 OBSERVER — no trade function linked. trade_mode=%d",
               (int)AccountInfoInteger(ACCOUNT_TRADE_MODE));
   return(INIT_SUCCEEDED);
  }

//====================================================================
void OnTick()
  {
   MqlTick tk; if(!SymbolInfoTick(_Symbol,tk)) return;

   //--- resolve open virtual trades on the real tick, spread paid both sides
   for(int i=gOpen-1;i>=0;i--)
     {
      int d = gO[i].dir;
      double px = (d>0 ? tk.bid : tk.ask);
      bool hitS = (d>0) ? (px <= gO[i].stop)   : (px >= gO[i].stop);
      bool hitT = (d>0) ? (px >= gO[i].target) : (px <= gO[i].target);
      if(hitS || hitT)
        { gS[gO[i].sid].res[gO[i].xi] = (hitT && !hitS) ? 1 : 2;   // stop wins a tie
          gO[i] = gO[gOpen-1]; gOpen--; }
     }

   datetime bt = iTime(_Symbol,PERIOD_M5,0);
   if(bt == gLastM5 || bt == 0) return;
   gLastM5 = bt;

   for(int i=gOpen-1;i>=0;i--)
     { gO[i].bars++;
       if(gO[i].bars > InpHorizon)
         { gS[gO[i].sid].res[gO[i].xi] = 3; gO[i] = gO[gOpen-1]; gOpen--; } }

   //--- HTF providers emit on their own new bar only
   datetime h1 = iTime(_Symbol,PERIOD_H1,0);
   if(h1 != gLastH1 && h1 != 0){ gLastH1 = h1; ScanPivots(PERIOD_H1,1); }
   datetime h4 = iTime(_Symbol,PERIOD_H4,0);
   if(h4 != gLastH4 && h4 != 0){ gLastH4 = h4; ScanPivots(PERIOD_H4,2); }

   //--- M5 baseline provider: A' K=3 left-only extreme on the just-closed bar
   int need = InpRefK + 2;
   if(Bars(_Symbol,PERIOD_M5) > need + 2)
     {
      double lo1 = iLow (_Symbol,PERIOD_M5,1), hi1 = iHigh(_Symbol,PERIOD_M5,1);
      bool okL = true, okH = true;
      for(int j=1;j<=InpRefK;j++)
        { if(iLow (_Symbol,PERIOD_M5,1+j) <= lo1) okL = false;
          if(iHigh(_Symbol,PERIOD_M5,1+j) >= hi1) okH = false; }
      datetime t1 = iTime(_Symbol,PERIOD_M5,1);
      if(okL) AddLevel(0,+1,lo1,t1,bt);
      if(okH) AddLevel(0,-1,hi1,t1,bt);
     }

   //--- the just-closed M5 bar
   Bar B; B.t=iTime(_Symbol,PERIOD_M5,1); B.o=iOpen(_Symbol,PERIOD_M5,1);
   B.h=iHigh(_Symbol,PERIOD_M5,1); B.l=iLow(_Symbol,PERIOD_M5,1);
   B.c=iClose(_Symbol,PERIOD_M5,1);
   int ps = PeriodSeconds(PERIOD_M5);

   //--- advance any provider waiting for its J bar
   for(int p=0;p<NPROV;p++)
     {
      if(!gP[p].armed) continue;
      if(B.t - gP[p].tS != ps){ gP[p].armed=false; gGap++; continue; }   // S->J must be adjacent
      int d = gL[gP[p].lidx].dir;
      if(!AtLeast(B.c, gP[p].sweep, d)){ gP[p].armed=false; gNoResolve++; continue; }  // SW-5 R-a
      Register(p, gP[p].lidx, gP[p].tS, gP[p].sweep, B.t, bt, tk);
      gP[p].armed = false;
     }

   //--- look for a penetration of any live level by the just-closed bar
   for(int p=0;p<NPROV;p++)
     {
      if(gP[p].armed) continue;
      for(int i=0;i<gNL;i++)
        {
         if(!gL[i].alive || gL[i].prov != p) continue;
         if(B.t < gL[i].t_available) continue;        // A-1: not usable yet
         int d = gL[i].dir;
         double sw = Ext(B,d);
         if(!Beyond(sw, gL[i].price, d))  continue;   // SW-3 delta = 0
         gL[i].alive = false;                          // CONSUMED on first penetration
         gPen++;
         if(!Beyond(B.c, gL[i].price, d)) break;      // SW-4 REQUIRED
         if(!Beyond(sw, B.c, d))          break;      // wick beyond close
         gP[p].armed = true; gP[p].lidx = i; gP[p].tS = B.t; gP[p].sweep = sw;
         break;
        }
     }
  }

//====================================================================
void Register(const int prov,const int lidx,const datetime tS,const double sweep,
              const datetime tJ,const datetime tE,const MqlTick &tk)
  {
   int d = gL[lidx].dir;
   double entry = (d>0 ? tk.ask : tk.bid);
   ArrayResize(gS, gN+1, 8192);
   gS[gN].prov=prov; gS[gN].dir=d;
   gS[gN].t_level=gL[lidx].t_formed; gS[gN].t_avail=gL[lidx].t_available;
   gS[gN].t_S=tS; gS[gN].t_J=tJ; gS[gN].t_E=tE;
   gS[gN].level=gL[lidx].price; gS[gN].sweep=sweep; gS[gN].entry=entry;
   gS[gN].age_bars=(double)(tS - gL[lidx].t_available)/PeriodSeconds(PERIOD_M5);
   for(int x=0;x<NX;x++)
     {
      double stop = sweep - d*XS[x]*_Point;
      if(!Beyond(stop, entry, d)){ gS[gN].res[x]=4; gS[gN].risk[x]=0; continue; }
      double risk = MathAbs(entry-stop);
      gS[gN].res[x]=0; gS[gN].risk[x]=risk/_Point;
      if(gOpen < MAXOPEN)
        { gO[gOpen].sid=gN; gO[gOpen].xi=x; gO[gOpen].dir=d;
          gO[gOpen].stop=stop; gO[gOpen].target=entry + d*risk*InpTargetR;
          gO[gOpen].bars=0; gOpen++; }
      else gS[gN].res[x]=3;
     }
   gN++;
  }

//====================================================================
void OnDeinit(const int reason)
  {
   for(int i=0;i<gOpen;i++) gS[gO[i].sid].res[gO[i].xi] = 3;
   for(int i=0;i<gN;i++)
      FileWrite(fh,(string)gS[i].prov,(gS[i].dir>0?"BUY":"SELL"),
        TimeToString(gS[i].t_level,TIME_DATE|TIME_SECONDS),
        TimeToString(gS[i].t_avail,TIME_DATE|TIME_SECONDS),
        TimeToString(gS[i].t_S,TIME_DATE|TIME_SECONDS),
        TimeToString(gS[i].t_J,TIME_DATE|TIME_SECONDS),
        TimeToString(gS[i].t_E,TIME_DATE|TIME_SECONDS),
        DoubleToString(gS[i].level,_Digits),DoubleToString(gS[i].sweep,_Digits),
        DoubleToString(gS[i].entry,_Digits),DoubleToString(gS[i].age_bars,1),
        (string)gS[i].res[0],(string)gS[i].res[1],(string)gS[i].res[2],
        DoubleToString(gS[i].risk[0],1),DoubleToString(gS[i].risk[1],1),
        DoubleToString(gS[i].risk[2],1));
   if(fh != INVALID_HANDLE) FileClose(fh);
   PrintFormat("E-MT5-021 done: %d signals, %I64d penetrations, %I64d no-resolve, %I64d gap, %d levels",
               gN, gPen, gNoResolve, gGap, gNL);
  }
//+------------------------------------------------------------------+
