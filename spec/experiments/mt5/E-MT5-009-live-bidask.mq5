//+------------------------------------------------------------------+
//| E-MT5-006 — Bid / Ask / spread and what forms the OHLC           |
//|                                                                  |
//| OBJECTIVE                                                        |
//|   Settle, with data, which price series builds the bars, what    |
//|   MqlRates.spread actually means, and whether Ask is recoverable |
//|   historically. These decide DEC-008 (spread model), RT-18       |
//|   condition 1 (sigma acts on the (bid,ask) pair), and whether a  |
//|   spread-aware sweep is even expressible.                        |
//|                                                                  |
//| HYPOTHESIS (to be falsified)                                     |
//|   H1: For an FX symbol, bar OHLC tracks BID exactly. Test: the   |
//|       running max of tick bid equals iHigh(...,0) at all times,  |
//|       and the running max of tick ask does not.                  |
//|   H2: MqlRates.spread is NOT the max, min or mean spread of the  |
//|       bar. Recorded here so its true meaning can be identified   |
//|       from the distribution rather than guessed.                 |
//|   H3: Ask is available live tick-by-tick, but historical Ask     |
//|       exists only where the broker supplies real tick history.   |
//|       Where it does not, a spread-aware sweep is NOT expressible |
//|       historically, only live — which would make live and tester |
//|       semantically different engines.                            |
//|   H4: Some ticks update only bid or only ask (TICK_FLAG_*), so   |
//|       "the spread at instant t" is itself a reconstruction.      |
//|                                                                  |
//| SETUP                                                            |
//|   Run live on an M1 chart >= 30 min. Then run again in the       |
//|   Strategy Tester in EACH mode and compare the same columns.     |
//|                                                                  |
//| OUTPUT  Common/Files/E-MT5-006-<symbol>.csv                      |
//|   event=TICK    per tick, with running bid/ask extremes          |
//|   event=BARSUM  at each M1 close: measured vs reported spread    |
//|                                                                  |
//| NOT PRODUCTION CODE. NO DETECTOR LOGIC. DISPOSABLE.              |
//+------------------------------------------------------------------+
#property copyright "PROJECT TRADER - feasibility experiment"
#property version   "1.0"
#property strict

int      fh = INVALID_HANDLE;
datetime cur = 0;
double   bidH, bidL, askH, askL;
int      spMin, spMax; long spSum; long nTick;

int OnInit()
  {
   string fn = "E-MT5-006-" + _Symbol + ".csv";
   fh = FileOpen(fn, FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON, ',');
   if(fh == INVALID_HANDLE) return(INIT_FAILED);

   FileWrite(fh, "event","time_msc","time","bid","ask","spread_pts","tick_flags",
      "bar_open","bid_high","bid_low","ask_high","ask_low",
      "bar_h","bar_l","bar_h_eq_bidhigh","bar_l_eq_bidlow",
      "rates_spread","sp_min","sp_max","sp_mean","ticks",
      "chart_mode","is_tester","tester_mode_hint");

   FileWrite(fh, "ENV", (string)TerminalInfoInteger(TERMINAL_BUILD),
      AccountInfoString(ACCOUNT_SERVER), _Symbol,
      (string)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS),
      (string)SymbolInfoDouble(_Symbol, SYMBOL_POINT),
      (string)SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE),
      (string)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD),
      (string)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD_FLOAT),
      "","","","","","","","","","","","","","","");

   ResetBar();
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason) { if(fh != INVALID_HANDLE) FileClose(fh); }

void ResetBar()
  {
   bidH = -DBL_MAX; bidL = DBL_MAX; askH = -DBL_MAX; askL = DBL_MAX;
   spMin = INT_MAX; spMax = -1; spSum = 0; nTick = 0;
  }

void OnTick()
  {
   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t)) return;

   datetime nb = iTime(_Symbol, PERIOD_M1, 0);
   if(nb != cur && cur != 0) { BarSummary(); ResetBar(); }
   cur = nb;

   int sp = (int)MathRound((t.ask - t.bid) / _Point);
   if(t.bid > bidH) bidH = t.bid;
   if(t.bid < bidL) bidL = t.bid;
   if(t.ask > askH) askH = t.ask;
   if(t.ask < askL) askL = t.ask;
   if(sp < spMin) spMin = sp;
   if(sp > spMax) spMax = sp;
   spSum += sp; nTick++;

   FileWrite(fh, "TICK", t.time_msc, TimeToString(t.time, TIME_DATE|TIME_SECONDS),
      DoubleToString(t.bid, _Digits), DoubleToString(t.ask, _Digits), sp,
      (int)t.flags,                                    // tests H4
      TimeToString(nb, TIME_DATE|TIME_SECONDS),
      DoubleToString(bidH, _Digits), DoubleToString(bidL, _Digits),
      DoubleToString(askH, _Digits), DoubleToString(askL, _Digits),
      DoubleToString(iHigh(_Symbol, PERIOD_M1, 0), _Digits),
      DoubleToString(iLow (_Symbol, PERIOD_M1, 0), _Digits),
      (iHigh(_Symbol, PERIOD_M1, 0) == bidH) ? 1 : 0,  // tests H1
      (iLow (_Symbol, PERIOD_M1, 0) == bidL) ? 1 : 0,
      "", "", "", "", nTick,
      SymbolInfoInteger(_Symbol, SYMBOL_CHART_MODE),
      MQLInfoInteger(MQL_TESTER), "");
  }

void BarSummary()
  {
   MqlRates r[];
   int got = CopyRates(_Symbol, PERIOD_M1, 1, 1, r);
   FileWrite(fh, "BARSUM", "", TimeToString(cur, TIME_DATE|TIME_SECONDS),
      "", "", "", "",
      TimeToString(cur, TIME_DATE|TIME_SECONDS),
      DoubleToString(bidH, _Digits), DoubleToString(bidL, _Digits),
      DoubleToString(askH, _Digits), DoubleToString(askL, _Digits),
      got == 1 ? DoubleToString(r[0].high, _Digits) : "NA",
      got == 1 ? DoubleToString(r[0].low,  _Digits) : "NA",
      (got == 1 && r[0].high == bidH) ? 1 : 0,
      (got == 1 && r[0].low  == bidL) ? 1 : 0,
      got == 1 ? (string)r[0].spread : "NA",           // tests H2
      spMin == INT_MAX ? -1 : spMin, spMax,
      nTick > 0 ? DoubleToString((double)spSum / (double)nTick, 2) : "NA",
      nTick,
      SymbolInfoInteger(_Symbol, SYMBOL_CHART_MODE),
      MQLInfoInteger(MQL_TESTER), "");
  }
//+------------------------------------------------------------------+
