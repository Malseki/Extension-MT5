//+------------------------------------------------------------------+
//| E-MT5-003 — Sparse activity and missing bars                     |
//|                                                                  |
//| OBJECTIVE                                                        |
//|   Determine what MT5 does across an interval with no ticks, and  |
//|   whether the engine can distinguish "nothing happened" from     |
//|   "no data". This is the raw material for the UNKNOWN / bottom   |
//|   value in the formal language (H-02, DEC-012, DEC-006).         |
//|                                                                  |
//| HYPOTHESIS (to be falsified)                                     |
//|   H1: A minute with no ticks produces NO M1 bar. Bars are not    |
//|       contiguous in time, so Bars(sym,M1) counts existing bars,  |
//|       never elapsed minutes.                                     |
//|   H2: Consequently a window of "n bars" and a window of "n       |
//|       minutes" are different sets, and the difference is         |
//|       data-dependent (H-09 is not academic).                     |
//|   H3: TimeCurrent() freezes during the gap while                 |
//|       TimeTradeServer() keeps advancing — proving TimeCurrent    |
//|       is a per-symbol tick clock (RT-12).                        |
//|                                                                  |
//| SETUP                                                            |
//|   Best on a low-liquidity symbol, or any symbol overnight /      |
//|   across the weekend break. Uses a 5-second timer, so it         |
//|   observes the gap even when no ticks arrive.                    |
//|                                                                  |
//| OUTPUT  Common/Files/E-MT5-003-<symbol>.csv                      |
//|   event=TIMER   every 5s, tick or no tick                        |
//|   event=GAP     when consecutive M1 bars differ by > 60s         |
//|                                                                  |
//| READ THE RESULT AS                                               |
//|   H1 holds if any GAP row appears with gap_seconds > 60.         |
//|   H3 holds if timer rows show server_minus_current_s growing     |
//|   monotonically while last_tick_time_msc stays constant.         |
//|                                                                  |
//| NOT PRODUCTION CODE. NO DETECTOR LOGIC. DISPOSABLE.              |
//+------------------------------------------------------------------+
#property copyright "PROJECT TRADER - feasibility experiment"
#property version   "1.0"
#property strict

int      fh = INVALID_HANDLE;
datetime prev_m1 = 0;
long     last_seen_tick_msc = 0;

int OnInit()
  {
   string fn = "E-MT5-003-" + _Symbol + ".csv";
   fh = FileOpen(fn, FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON, ',');
   if(fh == INVALID_HANDLE) return(INIT_FAILED);

   FileWrite(fh, "event","wall_local","time_current","time_trade_server",
      "server_minus_current_s","last_tick_time_msc","seconds_since_last_tick",
      "m1_bar_open","prev_m1_bar_open","gap_seconds","bars_m1","synced",
      "session_quote_open","session_quote_close");

   EventSetTimer(5);
   prev_m1 = iTime(_Symbol, PERIOD_M1, 0);
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason) { EventKillTimer(); if(fh != INVALID_HANDLE) FileClose(fh); }

void OnTimer() { Snapshot("TIMER"); }

void OnTick()
  {
   MqlTick t;
   if(SymbolInfoTick(_Symbol, t)) last_seen_tick_msc = t.time_msc;

   datetime m1 = iTime(_Symbol, PERIOD_M1, 0);
   if(m1 != prev_m1 && prev_m1 != 0)
     {
      long gap = (long)m1 - (long)prev_m1;
      if(gap > 60) Snapshot("GAP");     // a minute (or more) produced no bar
      prev_m1 = m1;
     }
  }

void Snapshot(const string ev)
  {
   MqlTick t;
   bool ok = SymbolInfoTick(_Symbol, t);
   datetime m1 = iTime(_Symbol, PERIOD_M1, 0);

   datetime so = 0, sc = 0;
   MqlDateTime dt; TimeToStruct(TimeTradeServer(), dt);
   SymbolInfoSessionQuote(_Symbol, (ENUM_DAY_OF_WEEK)dt.day_of_week, 0, so, sc);

   FileWrite(fh, ev,
      TimeToString(TimeLocal(),       TIME_DATE|TIME_SECONDS),
      TimeToString(TimeCurrent(),     TIME_DATE|TIME_SECONDS),
      TimeToString(TimeTradeServer(), TIME_DATE|TIME_SECONDS),
      (long)TimeTradeServer() - (long)TimeCurrent(),
      ok ? (string)t.time_msc : "NO_TICK",
      ok ? (string)((long)TimeTradeServer() - (long)t.time) : "NA",
      TimeToString(m1,      TIME_DATE|TIME_SECONDS),
      TimeToString(prev_m1, TIME_DATE|TIME_SECONDS),
      (long)m1 - (long)prev_m1,
      Bars(_Symbol, PERIOD_M1),
      SeriesInfoInteger(_Symbol, PERIOD_M1, SERIES_SYNCHRONIZED),
      TimeToString(so, TIME_MINUTES),
      TimeToString(sc, TIME_MINUTES));
  }
//+------------------------------------------------------------------+
