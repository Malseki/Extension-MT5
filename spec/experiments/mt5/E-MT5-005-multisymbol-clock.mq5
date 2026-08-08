//+------------------------------------------------------------------+
//| E-MT5-005 — Can two symbols share a causal clock?                |
//|                                                                  |
//| OBJECTIVE                                                        |
//|   Determine whether a common causal clock exists across symbols. |
//|   This decides whether the foundation can support cross-symbol   |
//|   reasoning (SMT) later without redesign — RT-12 / MF-6 / H-04.  |
//|                                                                  |
//| HYPOTHESIS (to be falsified)                                     |
//|   H1: OnTick fires ONLY for the chart symbol. The second symbol  |
//|       must be polled, so a tick-driven clock is per-symbol and   |
//|       cannot order events across symbols.                        |
//|   H2: An exogenous clock (OnTimer + TimeTradeServer) DOES order  |
//|       them, at the cost of instants carrying no new data — which |
//|       is exactly the bottom/UNKNOWN value the language needs.    |
//|   H3: The two symbols' M1 bar sets differ (different missing     |
//|       minutes), so bar-index alignment across symbols is unsafe  |
//|       and only timestamp alignment is sound.                     |
//|                                                                  |
//| SETUP                                                            |
//|   Attach to an M1 chart of SYMBOL A. Set input SymbolB to a      |
//|   correlated instrument (e.g. chart EURUSD, SymbolB GBPUSD).     |
//|   Ensure SymbolB is visible in Market Watch. Run >= 1 hour.      |
//|                                                                  |
//| OUTPUT  Common/Files/E-MT5-005.csv                               |
//|   event=TICK_A   chart symbol tick (OnTick)                      |
//|   event=POLL     1s timer snapshot of both symbols               |
//|   event=BARDIFF  minutes where one symbol has a bar and the      |
//|                  other does not                                  |
//|                                                                  |
//| NOT PRODUCTION CODE. NO DETECTOR LOGIC. DISPOSABLE.              |
//+------------------------------------------------------------------+
#property copyright "PROJECT TRADER - feasibility experiment"
#property version   "1.0"
#property strict

input string SymbolB = "GBPUSD";

int      fh = INVALID_HANDLE;
long     lastA = 0, lastB = 0;
datetime lastMinuteChecked = 0;

int OnInit()
  {
   fh = FileOpen("E-MT5-005.csv", FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON, ',');
   if(fh == INVALID_HANDLE) return(INIT_FAILED);
   if(!SymbolSelect(SymbolB, true))
      Print("E-MT5-005: cannot select ", SymbolB);

   FileWrite(fh, "event","time_trade_server","symA","symB",
      "A_tick_msc","B_tick_msc","A_minus_B_ms",
      "A_bid","B_bid","A_m1_open","B_m1_open","same_minute",
      "A_bars_m1","B_bars_m1","A_synced","B_synced");

   EventSetTimer(1);
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason) { EventKillTimer(); if(fh != INVALID_HANDLE) FileClose(fh); }

//--- fires for the chart symbol only: that is the finding, not a bug
void OnTick() { Row("TICK_A"); }

void OnTimer()
  {
   Row("POLL");

   datetime m = iTime(_Symbol, PERIOD_M1, 0);
   if(m != lastMinuteChecked && lastMinuteChecked != 0)
     {
      datetime a1 = iTime(_Symbol, PERIOD_M1, 1);
      datetime b1 = iTime(SymbolB, PERIOD_M1, 1);
      if(a1 != b1) Row("BARDIFF");      // tests H3
     }
   lastMinuteChecked = m;
  }

void Row(const string ev)
  {
   MqlTick a, b;
   bool oka = SymbolInfoTick(_Symbol, a);
   bool okb = SymbolInfoTick(SymbolB, b);
   if(oka) lastA = a.time_msc;
   if(okb) lastB = b.time_msc;

   datetime am = iTime(_Symbol, PERIOD_M1, 0);
   datetime bm = iTime(SymbolB, PERIOD_M1, 0);

   FileWrite(fh, ev,
      TimeToString(TimeTradeServer(), TIME_DATE|TIME_SECONDS),
      _Symbol, SymbolB,
      oka ? (string)a.time_msc : "NA",
      okb ? (string)b.time_msc : "NA",
      (oka && okb) ? (string)(a.time_msc - b.time_msc) : "NA",
      oka ? DoubleToString(a.bid, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)) : "NA",
      okb ? DoubleToString(b.bid, (int)SymbolInfoInteger(SymbolB, SYMBOL_DIGITS)) : "NA",
      TimeToString(am, TIME_DATE|TIME_SECONDS),
      TimeToString(bm, TIME_DATE|TIME_SECONDS),
      (am == bm) ? 1 : 0,
      Bars(_Symbol, PERIOD_M1), Bars(SymbolB, PERIOD_M1),
      SeriesInfoInteger(_Symbol, PERIOD_M1, SERIES_SYNCHRONIZED),
      SeriesInfoInteger(SymbolB, PERIOD_M1, SERIES_SYNCHRONIZED));
  }
//+------------------------------------------------------------------+
