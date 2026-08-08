//+------------------------------------------------------------------+
//| E-MT5-007 — History depth, gaps, tick history, availability      |
//|                                                                  |
//| TYPE: Script. Run once per symbol. Finishes in seconds.          |
//|                                                                  |
//| OBJECTIVE                                                        |
//|   Establish the real boundary of what MT5 remembers, and whether |
//|   "no event" is distinguishable from "no data". That distinction |
//|   is candidate-constitutional: it is the raw material for the    |
//|   bottom value in the formal language.                           |
//|                                                                  |
//| HYPOTHESIS (to be falsified)                                     |
//|   H1: Bar history depth differs per timeframe and per symbol,    |
//|       and is bounded by broker retention and the terminal's      |
//|       "Max bars in chart" setting.                               |
//|   H2: Real tick history (COPY_TICKS_INFO) starts far later than  |
//|       bar history — typically years later — so any spread-aware  |
//|       or intrabar-order rule has a much shorter usable history   |
//|       than a bar-only rule.                                      |
//|   H3: M1 bars are NOT contiguous. The count of missing minutes   |
//|       inside trading sessions is > 0 even on liquid FX.          |
//|   H4: An unavailable range is reported (-1 / error / 0 bars),    |
//|       never silently returned as empty-but-valid — so the        |
//|       NOT-AVAILABLE case is observable.                          |
//|                                                                  |
//| SETUP                                                            |
//|   Attach to a chart of the symbol under test. Repeat per symbol. |
//|   Run once on a cold terminal and once on a warm one.            |
//|                                                                  |
//| OUTPUT  Common/Files/E-MT5-007-<symbol>.csv                      |
//|                                                                  |
//| NOT PRODUCTION CODE. NO DETECTOR LOGIC. DISPOSABLE.              |
//+------------------------------------------------------------------+
#property copyright "PROJECT TRADER - feasibility experiment"
#property version   "1.0"
#property script_show_inputs
#property strict

input int GapScanBars = 20000;   // how many M1 bars to scan for gaps

#define NTF 7
ENUM_TIMEFRAMES TFS[NTF] = {PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_M30,
                            PERIOD_H1, PERIOD_H4, PERIOD_D1};
string NAMES[NTF] = {"M1","M5","M15","M30","H1","H4","D1"};

void OnStart()
  {
   string fn = "E-MT5-007-" + _Symbol + ".csv";
   int fh = FileOpen(fn, FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON, ',');
   if(fh == INVALID_HANDLE) { Print("cannot open ", fn); return; }

   FileWrite(fh, "section","key","value","extra1","extra2");

   //--- environment -------------------------------------------------
   FileWrite(fh, "ENV","build",  TerminalInfoInteger(TERMINAL_BUILD), "", "");
   FileWrite(fh, "ENV","server", AccountInfoString(ACCOUNT_SERVER), "", "");
   FileWrite(fh, "ENV","symbol", _Symbol,
             SymbolInfoInteger(_Symbol, SYMBOL_DIGITS),
             SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE));
   FileWrite(fh, "ENV","chart_mode", SymbolInfoInteger(_Symbol, SYMBOL_CHART_MODE), "", "");
   FileWrite(fh, "ENV","max_bars_setting", TerminalInfoInteger(TERMINAL_MAXBARS), "", "");
   FileWrite(fh, "ENV","memory_available_mb", TerminalInfoInteger(TERMINAL_MEMORY_AVAILABLE), "", "");
   FileWrite(fh, "ENV","time_trade_server", TimeToString(TimeTradeServer(), TIME_DATE|TIME_SECONDS), "", "");
   FileWrite(fh, "ENV","time_gmt_local",    TimeToString(TimeGMT(),         TIME_DATE|TIME_SECONDS), "", "");
   FileWrite(fh, "ENV","server_minus_gmt_s", (long)TimeTradeServer() - (long)TimeGMT(),
             "NOTE: local-PC estimate only; MT5 exposes no broker timezone", "");

   //--- H1: bar history depth per timeframe -------------------------
   for(int i = 0; i < NTF; i++)
     {
      ResetLastError();
      MqlRates r[];
      int ret = CopyRates(_Symbol, TFS[i], 0, 5, r);
      FileWrite(fh, "DEPTH", NAMES[i],
         Bars(_Symbol, TFS[i]),
         TimeToString((datetime)SeriesInfoInteger(_Symbol, TFS[i], SERIES_FIRSTDATE), TIME_DATE|TIME_SECONDS),
         "copyrates_ret=" + (string)ret + " err=" + (string)GetLastError());
     }

   //--- H2: real tick history range ---------------------------------
   ResetLastError();
   MqlTick tk[];
   int n = CopyTicks(_Symbol, tk, COPY_TICKS_INFO, 0, 10);
   FileWrite(fh, "TICKS","first_call_ret", n, GetLastError(),
             "-1 or 0 on a cold call is expected: async load begins");
   Sleep(3000);
   ResetLastError();
   n = CopyTicks(_Symbol, tk, COPY_TICKS_INFO, 0, 10);
   FileWrite(fh, "TICKS","after_wait_ret", n, GetLastError(), "tests H4");

   // walk backwards a year at a time to find where tick history begins
   datetime probe = TimeTradeServer();
   for(int y = 1; y <= 12; y++)
     {
      datetime from = probe - (datetime)(y * 31536000);   // y years back
      MqlTick tt[];
      ResetLastError();
      int got = CopyTicksRange(_Symbol, tt, COPY_TICKS_INFO,
                               (long)from * 1000, (long)(from + 3600) * 1000);
      FileWrite(fh, "TICKRANGE", (string)y + "y_ago",
                TimeToString(from, TIME_DATE), got, GetLastError());
     }

   //--- H3: missing M1 bars inside the recent window ----------------
   MqlRates m1[];
   int got = CopyRates(_Symbol, PERIOD_M1, 0, GapScanBars, m1);
   if(got > 1)
     {
      int gaps = 0; long biggest = 0; datetime at = 0;
      for(int i = 1; i < got; i++)
        {
         long d = (long)m1[i].time - (long)m1[i-1].time;
         if(d > 60) { gaps++; if(d > biggest) { biggest = d; at = m1[i-1].time; } }
        }
      FileWrite(fh, "GAPS","bars_scanned", got,
                TimeToString(m1[0].time, TIME_DATE|TIME_SECONDS),
                TimeToString(m1[got-1].time, TIME_DATE|TIME_SECONDS));
      FileWrite(fh, "GAPS","gap_count", gaps,
                "largest_gap_seconds=" + (string)biggest,
                "largest_gap_after=" + TimeToString(at, TIME_DATE|TIME_SECONDS));
     }
   else
      FileWrite(fh, "GAPS","copyrates_failed", got, GetLastError(), "");

   //--- H4: request a range that certainly does not exist -----------
   MqlRates far[];
   ResetLastError();
   int f1 = CopyRates(_Symbol, PERIOD_M1, D'1990.01.01 00:00', D'1990.01.02 00:00', far);
   FileWrite(fh, "UNAVAIL","year_1990_ret", f1, GetLastError(),
             "distinguishes NOT-AVAILABLE from NO-EVENT");

   //--- session schedule for the week -------------------------------
   for(int d = 0; d < 7; d++)
     {
      datetime so, sc;
      bool ok = SymbolInfoSessionQuote(_Symbol, (ENUM_DAY_OF_WEEK)d, 0, so, sc);
      FileWrite(fh, "SESSION", (string)d, ok ? "yes" : "no",
                ok ? TimeToString(so, TIME_MINUTES) : "",
                ok ? TimeToString(sc, TIME_MINUTES) : "");
     }

   FileClose(fh);
   Print("E-MT5-007 written to Common/Files/", fn);
  }
//+------------------------------------------------------------------+
