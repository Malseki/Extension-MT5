//+------------------------------------------------------------------+
//| E-MT5-026 — TICK ORDER-FLOW IMBALANCE OBSERVER                    |
//|                                                                  |
//| PURE OBSERVER. No orders, no account, no costs.                   |
//|                                                                  |
//| Motivation [EVIDENCE: PRIMARY]: Evans & Lyons (JPE 2002) obtain   |
//| R^2 > 50% for daily FX returns using signed order flow, versus    |
//| ~10% being rare for macro models. True signed interdealer flow is |
//| not available on a retail MT5 feed, but the SIGN of consecutive   |
//| tick changes is the closest observable proxy to that mechanism —  |
//| and it is a property of the tick stream, not a technical          |
//| indicator.                                                        |
//|                                                                  |
//| Question: does tick-direction imbalance over a fixed window carry |
//| directional information about the NEXT symmetric excursion?       |
//|                                                                  |
//| Design: at every sampling instant, record the imbalance, then run |
//| a SYMMETRIC race of +/- D pips. Structural null = 50%, because a  |
//| symmetric race on a driftless walk is a coin flip. No threshold,  |
//| no parameter chosen against results: the imbalance is recorded as |
//| a continuous value and binned only at analysis time, with bins    |
//| declared before measuring.                                        |
//|                                                                  |
//| EXPLORATORY on EURUSD (contaminated sample). Any signal found here|
//| must be preregistered and confirmed on virgin GBPUSD/USDJPY.      |
//+------------------------------------------------------------------+
#property copyright "PROJECT TRADER"
#property version   "1.00"

input int    InpWindow   = 100;    // ticks in the imbalance window
input int    InpSample   = 1000;   // start a race every N ticks (no overlap)
input int    InpRacePips = 20;     // symmetric race distance, both sides
input int    InpHorizonS = 86400;  // race timeout, seconds
input string InpRunTag   = "e26";

int    gPip = 1;
double gD;
int    fh = INVALID_HANDLE;

// circular buffer of tick directions: +1 up, -1 down, 0 unchanged
int    gDir[];
int    gHead = 0;
long   gSeen = 0;
double gPrevBid = 0;

// active race
bool     gActive = false;
double   gRef = 0;
datetime gT0 = 0;
double   gImb = 0;

long gUp = 0, gDown = 0, gTimeout = 0;

//+------------------------------------------------------------------+
int OnInit()
  {
   gPip = (_Digits == 3 || _Digits == 5) ? 10 : 1;
   gD   = InpRacePips * gPip * _Point;
   ArrayResize(gDir, InpWindow);
   ArrayInitialize(gDir, 0);

   fh = FileOpen("E-MT5-026-" + InpRunTag + "-flow.csv",
                 FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON, ',');
   if(fh == INVALID_HANDLE) return(INIT_FAILED);
   FileWrite(fh, "t", "imbalance", "n_up", "n_down", "outcome");  // outcome 1=up 2=down 3=timeout
   PrintFormat("E-MT5-026 start window=%d sample=%d race=%dpips",
               InpWindow, InpSample, InpRacePips);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   MqlTick tk; if(!SymbolInfoTick(_Symbol, tk)) return;
   double b = tk.bid;

   // ---- update the tick-direction window ---------------------------
   if(gPrevBid > 0)
     {
      int d = (b > gPrevBid) ? 1 : ((b < gPrevBid) ? -1 : 0);
      gDir[gHead] = d;
      gHead = (gHead + 1) % InpWindow;
      gSeen++;
     }
   gPrevBid = b;

   // ---- resolve an active race -------------------------------------
   if(gActive)
     {
      int outcome = 0;
      if(b >= gRef + gD)      outcome = 1;
      else if(b <= gRef - gD) outcome = 2;
      else if(TimeCurrent() - gT0 > InpHorizonS) outcome = 3;

      if(outcome > 0)
        {
         int nu = 0, nd = 0;
         for(int i = 0; i < InpWindow; i++)
           { if(gDir[i] > 0) nu++; else if(gDir[i] < 0) nd++; }
         FileWrite(fh, (string)gT0, DoubleToString(gImb, 4),
                   (string)nu, (string)nd, (string)outcome);
         if(outcome == 1) gUp++; else if(outcome == 2) gDown++; else gTimeout++;
         gActive = false;
        }
      return;                                  // one race at a time, no overlap
     }

   // ---- start a new race every InpSample ticks ---------------------
   if(gSeen < InpWindow) return;
   if((gSeen % InpSample) != 0) return;

   int nu = 0, nd = 0;
   for(int i = 0; i < InpWindow; i++)
     { if(gDir[i] > 0) nu++; else if(gDir[i] < 0) nd++; }
   if(nu + nd == 0) return;

   gImb    = (double)(nu - nd) / (double)(nu + nd);   // in [-1, +1]
   gRef    = b;
   gT0     = TimeCurrent();
   gActive = true;
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   long n = gUp + gDown;
   double p = (n > 0) ? 100.0 * gUp / n : 0;
   if(fh != INVALID_HANDLE) FileClose(fh);
   PrintFormat("E-MT5-026 done races=%I64d up=%I64d down=%I64d timeout=%I64d "
               "P(up)=%.2f%% (null 50%%)", n + gTimeout, gUp, gDown, gTimeout, p);
  }
//+------------------------------------------------------------------+
