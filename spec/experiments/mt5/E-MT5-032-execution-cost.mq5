//+------------------------------------------------------------------+
//| E-MT5-032 — EXECUTION COST AT THE MOMENT OF SIGNAL                 |
//|                                                                  |
//| PURE OBSERVER. No orders, no account.                             |
//|                                                                  |
//| Every economic conclusion in this project used the AVERAGE spread |
//| (0.4614 EURUSD, 0.6986 GBPUSD). But signals fire when price is    |
//| moving, and that is exactly when the spread widens. If the spread |
//| AT THE SIGNAL is systematically larger than the average, every EV |
//| computed so far is optimistic.                                    |
//|                                                                  |
//| PREDICTION, recorded before measuring:                            |
//|   spread at signal > average spread of the period.                |
//|                                                                  |
//| Also measures one-tick latency slippage: the adverse price move   |
//| between the signal tick and the next tick, which is the FLOOR of  |
//| what any real execution would suffer.                             |
//+------------------------------------------------------------------+
#property copyright "PROJECT TRADER"
#property version   "1.00"
#property strict

input double InpImpPips  = 5.0;    // same impulse definition as E-MT5-030
input int    InpImpBars  = 1;
input int    InpCoolS    = 300;
input string InpRunTag   = "e32";

int    gPip = 1;
int    fh = INVALID_HANDLE;

datetime gLastTrig = 0;
bool     gPending = false;         // waiting for the next tick after a signal
int      gPendDir = 0;
double   gPendBid = 0, gPendAsk = 0;
datetime gPendT = 0;

// running average spread over ALL ticks, for the comparison
double gSpreadSum = 0;  long gSpreadN = 0;
// spread at signals
double gSigSum = 0;     long gSigN = 0;
double gSlipSum = 0;    long gSlipN = 0;

//+------------------------------------------------------------------+
int OnInit()
  {
   gPip = (_Digits == 3 || _Digits == 5) ? 10 : 1;
   fh = FileOpen("E-MT5-032-" + InpRunTag + "-cost.csv",
                 FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON, ',');
   if(fh == INVALID_HANDLE) return(INIT_FAILED);
   FileWrite(fh, "t", "dir", "spread_at_signal", "slip_1tick", "secs_to_next_tick");
   PrintFormat("E-MT5-032 start impulse=%.1fp", InpImpPips);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
double MovePips(const int bars)
  {
   double past = iClose(_Symbol, PERIOD_M5, bars);
   if(past <= 0) return(0);
   MqlTick t; if(!SymbolInfoTick(_Symbol, t)) return(0);
   return((t.bid - past) / (gPip * _Point));
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   MqlTick t; if(!SymbolInfoTick(_Symbol, t)) return;
   double sp = (t.ask - t.bid) / (gPip * _Point);

   // population spread: every tick counts
   gSpreadSum += sp; gSpreadN++;

   // ---- resolve a pending signal on the FOLLOWING tick -------------
   if(gPending)
     {
      // adverse move between signal and next tick, in pips.
      // long  -> we would buy at ask: adverse if ask rose
      // short -> we would sell at bid: adverse if bid fell
      double slip = (gPendDir > 0)
                    ? (t.ask - gPendAsk) / (gPip * _Point)
                    : (gPendBid - t.bid) / (gPip * _Point);
      FileWrite(fh, TimeToString(gPendT, TIME_DATE | TIME_SECONDS),
                (gPendDir > 0 ? "BUY" : "SELL"),
                DoubleToString((gPendAsk - gPendBid) / (gPip * _Point), 4),
                DoubleToString(slip, 4),
                (string)(int)(TimeCurrent() - gPendT));
      gSlipSum += slip; gSlipN++;
      gPending = false;
     }

   // ---- detect a signal --------------------------------------------
   if(TimeCurrent() - gLastTrig < InpCoolS) return;
   double mv = MovePips(InpImpBars);
   if(MathAbs(mv) < InpImpPips) return;

   // reversion trade: we would take the OPPOSITE side of the impulse
   gPendDir = (mv > 0) ? -1 : +1;
   gPendBid = t.bid; gPendAsk = t.ask; gPendT = TimeCurrent();
   gPending = true;
   gLastTrig = gPendT;
   gSigSum += sp; gSigN++;
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   double avgAll = (gSpreadN > 0) ? gSpreadSum / gSpreadN : 0;
   double avgSig = (gSigN > 0) ? gSigSum / gSigN : 0;
   double avgSlip = (gSlipN > 0) ? gSlipSum / gSlipN : 0;
   if(fh != INVALID_HANDLE) FileClose(fh);
   PrintFormat("E-MT5-032 done ticks=%I64d signals=%I64d "
               "avgSpreadAll=%.4f avgSpreadAtSignal=%.4f ratio=%.3f "
               "avgSlip1tick=%.4f totalCost=%.4f",
               gSpreadN, gSigN, avgAll, avgSig,
               (avgAll > 0 ? avgSig / avgAll : 0), avgSlip, avgSig + avgSlip);
  }
//+------------------------------------------------------------------+
