//+------------------------------------------------------------------+
//| E-MT5-007 — Intrabar ordering and M1 sufficiency                 |
//|                                                                  |
//| TYPE: Script. Historical analysis only. Runs once.                |
//|                                                                  |
//| OBJECTIVE                                                        |
//|   Determine empirically whether the available historical data     |
//|   lets us distinguish "the high happened first" from "the low     |
//|   happened first" inside one M1 candle — and therefore whether    |
//|   M1 OHLC is sufficient to reconstruct "event A THEN event B".    |
//|                                                                  |
//| WHAT THIS IS NOT                                                 |
//|   No trading logic, no liquidity detection, no FVG, no MSS.       |
//|   It reconstructs the order of two price extremes. Nothing else.  |
//|                                                                  |
//| DESIGN POINTS THAT MATTER                                        |
//|   1. For FX the M1 bar OHLC is a BID series. The bar's high is    |
//|      therefore matched against tick BID. The ASK extremes are     |
//|      reconstructed FROM THE TICKS, never from the bar, because    |
//|      the bar contains no ask.                                     |
//|   2. Bid, Ask and Last are analysed separately and never          |
//|      collapsed into one price.                                    |
//|   3. Two samples are kept strictly apart:                         |
//|        RANDOM   — seeded, reproducible, no visual selection       |
//|        TARGETED — candles with both wicks significant, i.e. where |
//|                   both extremes are genuinely contested           |
//|   4. The M1-sufficiency test buckets candles by NORMALISED OHLC   |
//|      shape. A bucket containing both orderings is a concrete      |
//|      counterexample: same shape, different intrabar order.        |
//|      Exact OHLC collisions are too rare on 5-digit FX to test     |
//|      directly, so shape-normalisation is used and documented.     |
//|                                                                  |
//| OUTPUT (Common/Files/)                                            |
//|   E-MT5-007-results.csv        one row per analysed candle        |
//|   E-MT5-007-summary.csv        stats, coverage, counterexamples   |
//|                                                                  |
//| NOT PRODUCTION CODE. DISPOSABLE.                                  |
//+------------------------------------------------------------------+
#property copyright "PROJECT TRADER - feasibility experiment"
#property version   "1.0"
#property script_show_inputs
#property strict

input string InpSymbol         = "";     // empty = chart symbol
input string InpSymbol2        = "";     // optional second symbol for coverage
//--- session windows in NEW YORK clock time (DEC-S-001) -------------
input bool   InpSessionOnly    = true;   // sample only inside the windows
input int    InpWinA_StartMin  = 180;    // 03:00 NY
input int    InpWinA_EndMin    = 240;    // 04:00 NY
input int    InpWinB_StartMin  = 570;    // 09:30 NY
input int    InpWinB_EndMin    = 650;    // 10:50 NY
input int    InpServerToUTCHours = 0;    // 0 = auto-estimate (E-MT5-006 measured +3)
input int    InpNYOffsetFromUTC  = -4;
input int    InpReadyTimeoutS    = 90;   // wait for feed+history before measuring
//--- sampling -------------------------------------------------------
input int    InpLookbackDays   = 30;
input int    InpRandomSample   = 150;    // random candles
input int    InpTargetedSample = 60;    // both-wicks-significant candles
input double InpWickFraction   = 0.30;   // each wick >= this share of the range
input int    InpRandomSeed     = 20260807;

string SYM;
int    gDone = 0;
int    fhR = INVALID_HANDLE, fhS = INVALID_HANDLE;
int    srvUTC = 0;

// shape buckets for the M1-sufficiency test
string shapeKey[];  int shapeHiFirst[];  int shapeLoFirst[];  int nShapes = 0;
string shapeExHi[]; string shapeExLo[];

//+------------------------------------------------------------------+
void OnStart()
  {
   SYM = (InpSymbol == "") ? _Symbol : InpSymbol;
   if(!SymbolSelect(SYM, true)) { Print("cannot select ", SYM); return; }

   fhR = FileOpen("E-MT5-007-results.csv", FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON, ',');
   fhS = FileOpen("E-MT5-007-summary.csv", FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON, ',');
   if(fhR == INVALID_HANDLE || fhS == INVALID_HANDLE) { Print("cannot open output"); return; }

   int  waited = 0;
   bool ready  = WaitReady(InpReadyTimeoutS, waited);

   int autoOff = (int)MathRound(((double)TimeTradeServer() - (double)TimeGMT()) / 3600.0);
   srvUTC = (InpServerToUTCHours == 0) ? autoOff : InpServerToUTCHours;

   FileWrite(fhR, "sample","price_field","m1_open_time","ny_time",
      "m1_open","m1_high","m1_low","m1_close","tick_count",
      "first_high_tick_time","first_low_tick_time",
      "high_before_low","low_before_high","same_tick","order_reconstructable",
      "bid_available","ask_available","last_available","note");

   FileWrite(fhS, "section","key","v1","v2","v3","v4","v5");

   Sum("ENV","build",  TerminalInfoInteger(TERMINAL_BUILD), AccountInfoString(ACCOUNT_SERVER), "", "");
   Sum("ENV","symbol", SYM, (string)SymbolInfoInteger(SYM, SYMBOL_DIGITS),
       (string)SymbolInfoInteger(SYM, SYMBOL_CHART_MODE), "");
   Sum("ENV","offsets", (string)autoOff, (string)srvUTC, (string)InpNYOffsetFromUTC,
       "auto / used / ny — AUDIT (DEC-S-001 A-2)");
   Sum("ENV","seed", (string)InpRandomSeed, (string)InpRandomSample,
       (string)InpTargetedSample, "reproducible sample");
   Sum("READINESS","connected_and_synced", ready ? "YES" : "NO",
       "waited_ms=" + (string)waited,
       "bars_m1=" + (string)Bars(SYM, PERIOD_M1),
       "synced=" + (string)SeriesInfoInteger(SYM, PERIOD_M1, SERIES_SYNCHRONIZED));
   if(!ready) Sum("READINESS","WARNING","terminal not ready",
                  "ALL RESULTS BELOW ARE SUSPECT","","");

   //--- load candidate candles ---------------------------------------
   datetime to   = TimeTradeServer();
   datetime from = to - (datetime)InpLookbackDays * 86400;
   MqlRates r[];
   int nr = CopyRates(SYM, PERIOD_M1, from, to, r);
   Sum("SAMPLE","m1_bars_loaded", (string)nr, TimeToString(from, TIME_DATE),
       TimeToString(to, TIME_DATE), (string)GetLastError());
   if(nr <= 0) { Sum("SAMPLE","ABORT","no M1 bars","","",""); Close(); return; }

   //--- eligible index list (session filtered) ------------------------
   int elig[]; ArrayResize(elig, nr); int ne = 0;
   for(int i = 0; i < nr; i++)
      if(!InpSessionOnly || InSession(r[i].time)) elig[ne++] = i;
   Sum("SAMPLE","eligible_bars", (string)ne, InpSessionOnly ? "session-filtered" : "all", "", "");
   if(ne == 0) { Sum("SAMPLE","ABORT","no eligible bars","","",""); Close(); return; }

   //--- RANDOM sample -------------------------------------------------
   MathSrand(InpRandomSeed);
   int nRand = MathMin(InpRandomSample, ne);
   for(int k = 0; k < nRand && !IsStopped(); k++)
      Analyse("RANDOM", r[elig[MathRand() % ne]]);

   //--- TARGETED sample: both wicks significant -----------------------
   int nTarg = 0;
   for(int i = 0; i < ne && nTarg < InpTargetedSample && !IsStopped(); i++)
     {
      MqlRates b = r[elig[i]];
      double rng = b.high - b.low;
      if(rng <= 0.0) continue;
      double upper = b.high - MathMax(b.open, b.close);
      double lower = MathMin(b.open, b.close) - b.low;
      if(upper / rng >= InpWickFraction && lower / rng >= InpWickFraction)
        { Analyse("TARGETED", b); nTarg++; }
     }
   Sum("SAMPLE","targeted_found", (string)nTarg, "wick_fraction=" + DoubleToString(InpWickFraction,2), "", "");

   //--- M1 sufficiency: shape buckets holding BOTH orderings ----------
   int both = 0;
   for(int s = 0; s < nShapes; s++)
      if(shapeHiFirst[s] > 0 && shapeLoFirst[s] > 0)
        {
         both++;
         Sum("COUNTEREXAMPLE", shapeKey[s],
             "hi_first=" + (string)shapeHiFirst[s],
             "lo_first=" + (string)shapeLoFirst[s],
             shapeExHi[s], shapeExLo[s]);
        }
   Sum("M1_SUFFICIENCY","shape_buckets", (string)nShapes,
       "buckets_with_both_orderings=" + (string)both,
       both > 0 ? "SAME NORMALISED OHLC, DIFFERENT ORDER" : "none found in this sample", "");

   //--- coverage ------------------------------------------------------
   Coverage(SYM);
   if(InpSymbol2 != "" && SymbolSelect(InpSymbol2, true)) Coverage(InpSymbol2);

   Close();
   Print("E-MT5-007 done.");
  }

//+------------------------------------------------------------------+
bool WaitReady(const int timeout_s, int &waited_ms)
  {
   uint t0 = GetTickCount();
   while(!IsStopped() && (int)(GetTickCount() - t0) < timeout_s * 1000)
     {
      waited_ms = (int)(GetTickCount() - t0);
      if(TerminalInfoInteger(TERMINAL_CONNECTED))
        {
         MqlTick tk; MqlRates rr[];
         if(SymbolInfoTick(SYM, tk) && tk.bid > 0.0 &&
            CopyRates(SYM, PERIOD_M1, 0, 10, rr) > 0 &&
            SeriesInfoInteger(SYM, PERIOD_M1, SERIES_SYNCHRONIZED))
            return(true);
        }
      Sleep(500);
     }
   waited_ms = (int)(GetTickCount() - t0);
   return(false);
  }

//+------------------------------------------------------------------+
void Analyse(const string sample, const MqlRates &b)
  {
   gDone++;
   if(gDone % 10 == 1)
      Sum("PROGRESS", (string)gDone, sample,
          TimeToString(b.time, TIME_DATE|TIME_SECONDS),
          "mem_mb=" + (string)TerminalInfoInteger(TERMINAL_MEMORY_USED), "");
   MqlTick t[];
   ResetLastError();
   int n = CopyTicksRange(SYM, t, COPY_TICKS_ALL,
                          (long)b.time * 1000, (long)(b.time + 60) * 1000 - 1);
   int err = GetLastError();
   int dg  = (int)SymbolInfoInteger(SYM, SYMBOL_DIGITS);
   double tol = SymbolInfoDouble(SYM, SYMBOL_TRADE_TICK_SIZE) / 2.0;
   if(tol <= 0.0) tol = SymbolInfoDouble(SYM, SYMBOL_POINT) / 2.0;

   if(n <= 0)
     {
      Row(sample, "BID", b, 0, -1, -1, "", "", "",
          "no_ticks: ret=" + (string)n + " err=" + (string)err, 0, 0, 0, dg);
      return;
     }

   bool anyBid=false, anyAsk=false, anyLast=false;
   for(int i = 0; i < n; i++)
     { if(t[i].bid>0) anyBid=true; if(t[i].ask>0) anyAsk=true; if(t[i].last>0) anyLast=true; }

   //--- BID: match against the bar's own high/low (bar IS bid for FX)
   OrderFor(sample, "BID", b, t, n, b.high, b.low, tol, anyBid, anyAsk, anyLast, dg, true);

   //--- ASK: extremes reconstructed from ticks, never from the bar ----
   if(anyAsk)
     {
      double ah = -DBL_MAX, al = DBL_MAX;
      for(int i = 0; i < n; i++)
         if(t[i].ask > 0) { if(t[i].ask > ah) ah = t[i].ask; if(t[i].ask < al) al = t[i].ask; }
      OrderFor(sample, "ASK", b, t, n, ah, al, tol, anyBid, anyAsk, anyLast, dg, false);
     }

   //--- LAST -----------------------------------------------------------
   if(anyLast)
     {
      double lh = -DBL_MAX, ll = DBL_MAX;
      for(int i = 0; i < n; i++)
         if(t[i].last > 0) { if(t[i].last > lh) lh = t[i].last; if(t[i].last < ll) ll = t[i].last; }
      OrderFor(sample, "LAST", b, t, n, lh, ll, tol, anyBid, anyAsk, anyLast, dg, false);
     }
  }

//+------------------------------------------------------------------+
void OrderFor(const string sample, const string field, const MqlRates &b,
              const MqlTick &t[], const int n,
              const double hi, const double lo, const double tol,
              const bool aB, const bool aA, const bool aL, const int dg,
              const bool feedShapes)
  {
   long hiT = -1, loT = -1; int hiI = -1, loI = -1;
   for(int i = 0; i < n; i++)
     {
      double p = (field == "BID") ? t[i].bid : (field == "ASK" ? t[i].ask : t[i].last);
      if(p <= 0.0) continue;
      if(hiT < 0 && p >= hi - tol) { hiT = t[i].time_msc; hiI = i; }
      if(loT < 0 && p <= lo + tol) { loT = t[i].time_msc; loI = i; }
      if(hiT >= 0 && loT >= 0) break;
     }

   bool bothReached = (hiT >= 0 && loT >= 0);
   bool sameTick    = bothReached && (hiI == loI);
   bool hiFirst     = bothReached && !sameTick && (hiI < loI);
   bool loFirst     = bothReached && !sameTick && (loI < hiI);
   bool recon       = bothReached && !sameTick;

   string note = !bothReached
      ? ("extreme_not_matched hi=" + (string)(hiT>=0) + " lo=" + (string)(loT>=0))
      : (sameTick ? "both_extremes_on_same_tick" : "");

   Row(sample, field, b, n, hiT, loT,
       hiFirst ? "1" : "0", loFirst ? "1" : "0", sameTick ? "1" : "0",
       note, aB, aA, aL, dg, recon, hi, lo);

   if(feedShapes && recon) FeedShape(b, hiFirst, dg);
  }

//+------------------------------------------------------------------+
//| Bucket by normalised OHLC shape: same shape + both orderings      |
//| present = a concrete M1-insufficiency counterexample.             |
//+------------------------------------------------------------------+
void FeedShape(const MqlRates &b, const bool hiFirst, const int dg)
  {
   double rng = b.high - b.low;
   if(rng <= 0.0) return;
   int o = (int)MathRound(100.0 * (b.open  - b.low) / rng);
   int c = (int)MathRound(100.0 * (b.close - b.low) / rng);
   string key = "o" + (string)o + "_c" + (string)c;
   string ex  = TimeToString(b.time, TIME_DATE|TIME_SECONDS) +
                " O=" + DoubleToString(b.open, dg) + " H=" + DoubleToString(b.high, dg) +
                " L=" + DoubleToString(b.low, dg) + " C=" + DoubleToString(b.close, dg);

   for(int i = 0; i < nShapes; i++)
      if(shapeKey[i] == key)
        {
         if(hiFirst) { shapeHiFirst[i]++; if(shapeExHi[i] == "") shapeExHi[i] = ex; }
         else        { shapeLoFirst[i]++; if(shapeExLo[i] == "") shapeExLo[i] = ex; }
         return;
        }

   ArrayResize(shapeKey, nShapes+1);     ArrayResize(shapeHiFirst, nShapes+1);
   ArrayResize(shapeLoFirst, nShapes+1); ArrayResize(shapeExHi, nShapes+1);
   ArrayResize(shapeExLo, nShapes+1);
   shapeKey[nShapes] = key;
   shapeHiFirst[nShapes] = hiFirst ? 1 : 0;
   shapeLoFirst[nShapes] = hiFirst ? 0 : 1;
   shapeExHi[nShapes] = hiFirst ? ex : "";
   shapeExLo[nShapes] = hiFirst ? "" : ex;
   nShapes++;
  }

//+------------------------------------------------------------------+
void Row(const string sample, const string field, const MqlRates &b, const int n,
         const long hiT, const long loT, const string hf, const string lf,
         const string st, const string note,
         const bool aB, const bool aA, const bool aL, const int dg,
         const bool recon = false, const double hi = 0.0, const double lo = 0.0)
  {
   FileWrite(fhR, sample, field,
      TimeToString(b.time, TIME_DATE|TIME_SECONDS),
      TimeToString(b.time - (datetime)((srvUTC - InpNYOffsetFromUTC) * 3600), TIME_DATE|TIME_SECONDS),
      DoubleToString(b.open, dg), DoubleToString(b.high, dg),
      DoubleToString(b.low, dg),  DoubleToString(b.close, dg),
      n,
      hiT >= 0 ? (string)hiT : "",
      loT >= 0 ? (string)loT : "",
      hf, lf, st, recon ? "1" : "0",
      aB ? 1 : 0, aA ? 1 : 0, aL ? 1 : 0, note);
   FileFlush(fhR);
  }

//+------------------------------------------------------------------+
bool InSession(const datetime serverTime)
  {
   datetime ny = serverTime - (datetime)((srvUTC - InpNYOffsetFromUTC) * 3600);
   MqlDateTime d; TimeToStruct(ny, d);
   int m = d.hour * 60 + d.min;
   return((m >= InpWinA_StartMin && m < InpWinA_EndMin) ||
          (m >= InpWinB_StartMin && m < InpWinB_EndMin));
  }

//+------------------------------------------------------------------+
void Coverage(const string s)
  {
   datetime now = TimeTradeServer();
   for(int y = 1; y <= 12 && !IsStopped(); y++)
     {
      datetime req = now - (datetime)y * 31536000;
      MqlTick tt[];
      ResetLastError();
      int got = CopyTicksRange(s, tt, COPY_TICKS_ALL,
                               (long)req * 1000, (long)(req + 86400) * 1000);
      Sum("COVERAGE", s + "_" + (string)y + "y_ago",
          "requested=" + TimeToString(req, TIME_DATE),
          "ticks=" + (string)got,
          got > 0 ? "actual_start=" + TimeToString((datetime)(tt[0].time_msc/1000), TIME_DATE|TIME_SECONDS) : "",
          "err=" + (string)GetLastError());
     }
   Sum("COVERAGE", s + "_bars_m1", (string)Bars(s, PERIOD_M1),
       TimeToString((datetime)SeriesInfoInteger(s, PERIOD_M1, SERIES_FIRSTDATE), TIME_DATE), "", "");
  }

//+------------------------------------------------------------------+
void Sum(const string s, const string k, const string a, const string b,
         const string c, const string d)
  { FileWrite(fhS, s, k, a, b, c, d); FileFlush(fhS); }
void Close() { if(fhR != INVALID_HANDLE) FileClose(fhR); if(fhS != INVALID_HANDLE) FileClose(fhS); }
//+------------------------------------------------------------------+
