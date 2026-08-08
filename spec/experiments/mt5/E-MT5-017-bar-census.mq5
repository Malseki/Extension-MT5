//+------------------------------------------------------------------+
//| E-MT5-017 — BAR CENSUS                                            |
//|                                                                  |
//| Observation only. Places no orders, links no trade function.     |
//| Purpose: dump the exact M5 bar stream that E-MT5-015 consumed,   |
//| so the SW-6 adjacency question can be answered over the WHOLE    |
//| signal population offline instead of only over executed trades.  |
//|                                                                  |
//| Must run with the SAME Model=4 real ticks and the SAME range as  |
//| the hist1 run, otherwise the bar set is not the one under test.  |
//+------------------------------------------------------------------+
#property copyright "PROJECT TRADER - bar census"
#property version   "1.0"
#property strict

input string InpRunTag = "census";

int fh = INVALID_HANDLE;
datetime gLastBar = 0;
long gBars = 0;

int OnInit()
  {
   fh = FileOpen("E-MT5-017-" + InpRunTag + "-bars.csv",
                 FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON, ',');
   if(fh == INVALID_HANDLE) return(INIT_FAILED);
   FileWrite(fh, "bar_time", "open", "high", "low", "close", "spread", "volume");
   return(INIT_SUCCEEDED);
  }

void OnTick()
  {
   datetime bt = iTime(_Symbol, _Period, 0);
   if(bt == gLastBar || bt == 0) return;
   gLastBar = bt;
   //--- shift 1 is the bar that just closed; that is what DetectAt consumed
   datetime t = iTime(_Symbol, _Period, 1);
   if(t == 0) return;
   FileWrite(fh, TimeToString(t, TIME_DATE | TIME_SECONDS),
             DoubleToString(iOpen (_Symbol, _Period, 1), _Digits),
             DoubleToString(iHigh (_Symbol, _Period, 1), _Digits),
             DoubleToString(iLow  (_Symbol, _Period, 1), _Digits),
             DoubleToString(iClose(_Symbol, _Period, 1), _Digits),
             (string)iSpread(_Symbol, _Period, 1),
             (string)iVolume(_Symbol, _Period, 1));
   gBars++;
  }

void OnDeinit(const int reason)
  {
   if(fh != INVALID_HANDLE)
     {
      FileFlush(fh);
      FileClose(fh);
     }
   PrintFormat("E-MT5-017 census complete: %I64d closed bars written", gBars);
  }
//+------------------------------------------------------------------+
