//+------------------------------------------------------------------+
//| E-MT5-001 — M1 bar formation                                     |
//|                                                                  |
//| OBJECTIVE                                                        |
//|   Determine when an M1 bar actually closes, and whether closure  |
//|   is driven by the clock or by tick arrival.                     |
//|                                                                  |
//| HYPOTHESIS (to be falsified)                                     |
//|   H1: A bar with open time T closes only when the first tick     |
//|       with time >= T+60 arrives. Wall-clock passage alone does   |
//|       NOT close it.                                              |
//|   H2: Therefore the delay between nominal close (T+60) and       |
//|       knowable close is unbounded, not a constant.               |
//|   H3: TimeCurrent() advances only on ticks, so it is a           |
//|       per-symbol clock, not an exogenous one.                    |
//|                                                                  |
//| SETUP                                                            |
//|   Attach to any M1 chart. Let it run >= 30 minutes during an     |
//|   active session, ideally also across a quiet period.            |
//|                                                                  |
//| OUTPUT  Common/Files/E-MT5-001-<symbol>.csv                      |
//|   event=TICK  one row per tick                                   |
//|   event=CLOSE one row at each detected bar transition            |
//|                                                                  |
//| READ THE RESULT AS                                               |
//|   H1 holds if every CLOSE row has first_tick_after_boundary_ms   |
//|     > 0 and equals the first tick observed at/after the boundary. |
//|   H2 holds if that value varies (and is large across quiet gaps). |
//|   H3 holds if timecurrent_vs_tradeserver_s is non-zero and grows |
//|     during quiet periods.                                        |
//|                                                                  |
//| NOT PRODUCTION CODE. NO DETECTOR LOGIC. DISPOSABLE.              |
//+------------------------------------------------------------------+
#property copyright "PROJECT TRADER - feasibility experiment"
#property version   "1.0"
#property strict

int      fh          = INVALID_HANDLE;
datetime cur_bar     = 0;      // open time of the bar we believe is forming
long     tick_no     = 0;
long     ticks_in_bar= 0;

int OnInit()
  {
   string fn = "E-MT5-001-" + _Symbol + ".csv";
   fh = FileOpen(fn, FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON, ',');
   if(fh == INVALID_HANDLE)
     {
      Print("E-MT5-001: cannot open ", fn, " err=", GetLastError());
      return(INIT_FAILED);
     }
   FileWrite(fh,
      "event","tick_no","tick_time_msc","tick_time","bid","ask","spread_pts",
      "bar_open_time","boundary_time","ms_past_boundary","ticks_in_closed_bar",
      "o","h","l","c","tick_volume","rates_spread",
      "time_current","time_trade_server","timecurrent_vs_tradeserver_s",
      "bars_m1","series_synced");

   // record the environment once, as a comment row
   FileWrite(fh, "ENV",
      (string)TerminalInfoInteger(TERMINAL_BUILD),
      AccountInfoString(ACCOUNT_SERVER),
      _Symbol,
      (string)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS),
      (string)SymbolInfoDouble(_Symbol, SYMBOL_POINT),
      (string)SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE),
      (string)SymbolInfoInteger(_Symbol, SYMBOL_CHART_MODE),
      (string)(bool)MQLInfoInteger(MQL_TESTER));

   cur_bar = iTime(_Symbol, PERIOD_M1, 0);
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   if(fh != INVALID_HANDLE) { FileClose(fh); fh = INVALID_HANDLE; }
   Print("E-MT5-001: deinit reason=", reason);
  }

void OnTick()
  {
   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t)) return;
   tick_no++;
   ticks_in_bar++;

   datetime now_bar = iTime(_Symbol, PERIOD_M1, 0);

   // ---- bar transition detected: the PREVIOUS bar is now knowably closed ----
   if(now_bar != cur_bar && cur_bar != 0)
     {
      datetime boundary = cur_bar + 60;            // nominal close of the old bar
      long     past_ms  = (long)t.time_msc - (long)boundary * 1000;

      // shift 1 is the bar that just closed
      FileWrite(fh, "CLOSE", tick_no, t.time_msc, TimeToString(t.time, TIME_DATE|TIME_SECONDS),
         DoubleToString(t.bid, _Digits), DoubleToString(t.ask, _Digits),
         (int)((t.ask - t.bid) / _Point),
         TimeToString(cur_bar, TIME_DATE|TIME_SECONDS),
         TimeToString(boundary, TIME_DATE|TIME_SECONDS),
         past_ms,                                   // <-- the key measurement
         ticks_in_bar - 1,
         DoubleToString(iOpen (_Symbol, PERIOD_M1, 1), _Digits),
         DoubleToString(iHigh (_Symbol, PERIOD_M1, 1), _Digits),
         DoubleToString(iLow  (_Symbol, PERIOD_M1, 1), _Digits),
         DoubleToString(iClose(_Symbol, PERIOD_M1, 1), _Digits),
         iVolume(_Symbol, PERIOD_M1, 1),
         RatesSpread(1),
         TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
         TimeToString(TimeTradeServer(), TIME_DATE|TIME_SECONDS),
         (long)TimeTradeServer() - (long)TimeCurrent(),
         Bars(_Symbol, PERIOD_M1),
         SeriesInfoInteger(_Symbol, PERIOD_M1, SERIES_SYNCHRONIZED));

      cur_bar      = now_bar;
      ticks_in_bar = 1;
     }

   // ---- every tick ----
   FileWrite(fh, "TICK", tick_no, t.time_msc, TimeToString(t.time, TIME_DATE|TIME_SECONDS),
      DoubleToString(t.bid, _Digits), DoubleToString(t.ask, _Digits),
      (int)((t.ask - t.bid) / _Point),
      TimeToString(now_bar, TIME_DATE|TIME_SECONDS), "", "", ticks_in_bar,
      DoubleToString(iOpen (_Symbol, PERIOD_M1, 0), _Digits),
      DoubleToString(iHigh (_Symbol, PERIOD_M1, 0), _Digits),
      DoubleToString(iLow  (_Symbol, PERIOD_M1, 0), _Digits),
      DoubleToString(iClose(_Symbol, PERIOD_M1, 0), _Digits),
      iVolume(_Symbol, PERIOD_M1, 0),
      RatesSpread(0),
      TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
      TimeToString(TimeTradeServer(), TIME_DATE|TIME_SECONDS),
      (long)TimeTradeServer() - (long)TimeCurrent(),
      Bars(_Symbol, PERIOD_M1),
      SeriesInfoInteger(_Symbol, PERIOD_M1, SERIES_SYNCHRONIZED));
  }

//--- MqlRates.spread has no i*() accessor; read it directly.
int RatesSpread(const int shift)
  {
   MqlRates r[];
   if(CopyRates(_Symbol, PERIOD_M1, shift, 1, r) != 1) return(-1);
   return((int)r[0].spread);
  }
//+------------------------------------------------------------------+
