//+------------------------------------------------------------------+
//| E-MT5-004 — Multi-timeframe synchronisation and unsynced reads   |
//|                                                                  |
//| OBJECTIVE                                                        |
//|   Determine what a read of a not-yet-synchronised series returns,|
//|   and how long synchronisation takes after a cold start. This    |
//|   decides whether MT5 gives us a usable NOT-AVAILABLE value      |
//|   distinct from a legitimate absence of events.                  |
//|                                                                  |
//| HYPOTHESIS (to be falsified)                                     |
//|   H1: CopyRates returns -1 (with a last-error) while a series is |
//|       unsynchronised, and Bars() returns 0 — so "not available"  |
//|       IS observable and distinct from "no event".                |
//|   H2: The first request for a non-chart timeframe triggers an    |
//|       asynchronous download; the same call succeeds moments      |
//|       later with identical arguments. Reads are therefore NOT    |
//|       referentially transparent until synchronised.              |
//|   H3: iHigh()/iLow() silently return 0.0 rather than an error    |
//|       when data is missing, making them strictly more dangerous  |
//|       than CopyRates for causal code.                            |
//|                                                                  |
//| SETUP                                                            |
//|   Restart the terminal, then attach immediately to an M1 chart   |
//|   of a symbol you have NOT recently opened. Run ~10 minutes.     |
//|   Run a second time on a warm terminal to compare.               |
//|                                                                  |
//| OUTPUT  Common/Files/E-MT5-004-<symbol>.csv                      |
//|                                                                  |
//| NOT PRODUCTION CODE. NO DETECTOR LOGIC. DISPOSABLE.              |
//+------------------------------------------------------------------+
#property copyright "PROJECT TRADER - feasibility experiment"
#property version   "1.0"
#property strict

#define NTF 6
ENUM_TIMEFRAMES TFS[NTF] = {PERIOD_M1, PERIOD_M5, PERIOD_M15,
                            PERIOD_M30, PERIOD_H1, PERIOD_H4};
string NAMES[NTF] = {"M1","M5","M15","M30","H1","H4"};

int    fh = INVALID_HANDLE;
int    probe = 0;
uint   t0;

int OnInit()
  {
   string fn = "E-MT5-004-" + _Symbol + ".csv";
   fh = FileOpen(fn, FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON, ',');
   if(fh == INVALID_HANDLE) return(INIT_FAILED);

   FileWrite(fh, "probe","ms_since_attach","tf","copyrates_ret","last_error",
      "bars","synced","series_firstdate","series_lastbar_date",
      "ihigh_0","ihigh_1","itime_0","itime_1","terminal_connected");

   t0 = GetTickCount();
   EventSetTimer(1);
   Probe();
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason) { EventKillTimer(); if(fh != INVALID_HANDLE) FileClose(fh); }

void OnTimer() { Probe(); }

void Probe()
  {
   probe++;
   uint dt = GetTickCount() - t0;

   for(int i = 0; i < NTF; i++)
     {
      MqlRates r[];
      ResetLastError();
      int ret = CopyRates(_Symbol, TFS[i], 0, 3, r);
      int err = GetLastError();

      datetime first = (datetime)SeriesInfoInteger(_Symbol, TFS[i], SERIES_FIRSTDATE);
      datetime lastb = (datetime)SeriesInfoInteger(_Symbol, TFS[i], SERIES_LASTBAR_DATE);

      FileWrite(fh, probe, dt, NAMES[i], ret, err,
         Bars(_Symbol, TFS[i]),
         SeriesInfoInteger(_Symbol, TFS[i], SERIES_SYNCHRONIZED),
         TimeToString(first, TIME_DATE|TIME_SECONDS),
         TimeToString(lastb, TIME_DATE|TIME_SECONDS),
         DoubleToString(iHigh(_Symbol, TFS[i], 0), _Digits),   // tests H3
         DoubleToString(iHigh(_Symbol, TFS[i], 1), _Digits),
         TimeToString(iTime(_Symbol, TFS[i], 0), TIME_DATE|TIME_SECONDS),
         TimeToString(iTime(_Symbol, TFS[i], 1), TIME_DATE|TIME_SECONDS),
         TerminalInfoInteger(TERMINAL_CONNECTED));
     }

   if(probe >= 600) EventKillTimer();   // ~10 minutes
  }
//+------------------------------------------------------------------+
