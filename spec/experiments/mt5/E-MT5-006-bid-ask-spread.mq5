//+------------------------------------------------------------------+
//| E-MT5-006 — Historical Bid / Ask / spread availability           |
//|                                                                  |
//| TYPE: Script. Historical analysis only. Runs once.                |
//|                                                                  |
//| OBJECTIVE                                                        |
//|   Determine what historical tick information this broker really  |
//|   provides, and whether a bid-based and an ask-based penetration  |
//|   rule produce DIFFERENT historical event sets.                   |
//|                                                                  |
//| WHAT THIS IS NOT                                                 |
//|   No trading logic. No liquidity detection. No FVG. No MSS.      |
//|   No order is placed, modified or closed. Observation only.       |
//|                                                                  |
//| CRITICAL DESIGN POINT                                            |
//|   MqlTick always CARRIES bid and ask (last known values), but    |
//|   tick.flags says which one actually CHANGED on that tick. Both  |
//|   are recorded and never collapsed:                               |
//|     *_value_present : field > 0        (a value is known)         |
//|     *_flag_set      : flags & TICK_FLAG_*  (it updated here)      |
//|   Conflating them answers "is historical Ask available" wrongly,  |
//|   and wrongly in the optimistic direction.                        |
//|                                                                  |
//| Ask is NEVER derived from spread. Nothing is substituted.         |
//|                                                                  |
//| OUTPUT (Common/Files/)                                            |
//|   E-MT5-006-results.csv     per-tick rows                         |
//|   E-MT5-006-summary.csv     per-window metrics + penetration scan |
//|   E-MT5-006-environment.txt environment metadata                  |
//|                                                                  |
//| REVISION 1.1 — replaced three ambiguous Sum() overloads with one  |
//| string-typed helper. Science unchanged; typing only.              |
//|                                                                  |
//| NOT PRODUCTION CODE. DISPOSABLE.                                  |
//+------------------------------------------------------------------+
#property copyright "PROJECT TRADER - feasibility experiment"
#property version   "1.1"
#property script_show_inputs
#property strict

input string InpSymbol            = "";      // empty = chart symbol
//--- session windows, NEW YORK clock (DEC-S-001) --------------------
input int    InpWinA_StartMin     = 180;     // 03:00 NY
input int    InpWinA_EndMin       = 240;     // 04:00 NY
input int    InpWinB_StartMin     = 570;     // 09:30 NY
input int    InpWinB_EndMin       = 650;     // 10:50 NY
//--- time mapping: audited in output, never trusted -----------------
input int    InpServerToUTCHours  = 0;       // 0 = auto-estimate
input int    InpNYOffsetFromUTC   = -4;      // fixed UTC-4 (DEC-S-001 A-2)
input bool   InpApplyUSDst        = false;   // true = coarse Mar..Oct bracket
//--- sampling -------------------------------------------------------
input int    InpDaysAgo_Recent    = 2;
input int    InpDaysAgo_Month     = 30;
input int    InpDaysAgo_HalfYear  = 182;
input int    InpDaysAgo_Year      = 365;
input bool   InpProbeWinterSummer = true;
input bool   InpProbeOldest       = true;
//--- penetration scan ----------------------------------------------
input int    InpLevelScanCount    = 21;
//--- output ---------------------------------------------------------
input bool   InpWriteTicks        = true;
input int    InpMaxTickRows       = 400000;
input int    InpReadyTimeoutS     = 90;      // wait for feed+history before measuring

string SYM;
int    fhT = INVALID_HANDLE, fhS = INVALID_HANDLE;
int    tickRows = 0;
int    srvUTC   = 0;
int    dg = 5;
double pt = 0.00001;

//--- single helper. Everything is stringified at the call site.
void Sum(const string s, const string k, const string a = "", const string b = "",
         const string c = "", const string d = "", const string e = "", const string f = "")
  { FileWrite(fhS, s, k, a, b, c, d, e, f); }

//+------------------------------------------------------------------+
void OnStart()
  {
   SYM = (InpSymbol == "") ? _Symbol : InpSymbol;
   if(!SymbolSelect(SYM, true)) { Print("E-MT5-006: cannot select ", SYM); return; }

   dg = (int)SymbolInfoInteger(SYM, SYMBOL_DIGITS);
   pt = SymbolInfoDouble(SYM, SYMBOL_POINT);
   if(pt <= 0.0) pt = 0.00001;

   fhT = FileOpen("E-MT5-006-results.csv", FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON, ',');
   fhS = FileOpen("E-MT5-006-summary.csv", FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON, ',');
   if(fhT == INVALID_HANDLE || fhS == INVALID_HANDLE)
     { Print("E-MT5-006: cannot open output, err=", GetLastError()); return; }

   //--- readiness gate: never measure an unsynchronised terminal -----
   //    Without this, a startup-launched run reports "no data" for every
   //    window simply because the feed had not connected yet — which would
   //    look exactly like a genuine absence of history.
   int    waited   = 0;
   bool   ready    = WaitReady(InpReadyTimeoutS, waited);

   int autoOff = (int)MathRound(((double)TimeTradeServer() - (double)TimeGMT()) / 3600.0);
   srvUTC = (InpServerToUTCHours == 0) ? autoOff : InpServerToUTCHours;

   Sum("READINESS", "connected_and_synced", ready ? "YES" : "NO",
       "waited_ms=" + (string)waited,
       "terminal_connected=" + (string)TerminalInfoInteger(TERMINAL_CONNECTED),
       "bars_m1=" + (string)Bars(SYM, PERIOD_M1),
       "synced=" + (string)SeriesInfoInteger(SYM, PERIOD_M1, SERIES_SYNCHRONIZED));
   if(!ready)
      Sum("READINESS", "WARNING",
          "terminal not ready within timeout",
          "ALL WINDOW RESULTS BELOW ARE SUSPECT",
          "re-run when connected");

   FileWrite(fhT, "symbol","window","tick_index","time_msc","server_time","ny_time",
      "bid","ask","last","volume","volume_real","flags","spread_price","spread_points",
      "has_bid_value","has_ask_value","has_last_value",
      "bid_flag_set","ask_flag_set","last_flag_set","volume_flag_set");

   FileWrite(fhS, "section","key","v1","v2","v3","v4","v5","v6");

   WriteEnvironment(autoOff);

   datetime now = TimeTradeServer();
   ProbeDay("RECENT",   now - (datetime)InpDaysAgo_Recent   * 86400);
   ProbeDay("MONTH",    now - (datetime)InpDaysAgo_Month    * 86400);
   ProbeDay("HALFYEAR", now - (datetime)InpDaysAgo_HalfYear * 86400);
   ProbeDay("YEAR",     now - (datetime)InpDaysAgo_Year     * 86400);

   if(InpProbeWinterSummer)
     {
      ProbeDay("WINTER", MostRecentMonth(1, 15));
      ProbeDay("SUMMER", MostRecentMonth(7, 15));
     }

   if(InpProbeOldest)
     {
      datetime oldest = FindOldestTick();
      Sum("COVERAGE","oldest_tick_found",
          oldest > 0 ? TimeToString(oldest, TIME_DATE|TIME_SECONDS) : "DATA_NOT_AVAILABLE",
          oldest > 0 ? (string)(((long)now - (long)oldest) / 86400) : "-1", "days_back");
      if(oldest > 0) ProbeDay("OLDEST", oldest + 86400);
     }

   FileClose(fhT); FileClose(fhS);
   Print("E-MT5-006 finished. tick rows written = ", tickRows);
  }

//+------------------------------------------------------------------+
//| Block until the terminal is connected AND the symbol's series is  |
//| synchronised. Returns false on timeout; the caller records that   |
//| so an unsynchronised run can never be mistaken for "no history".  |
//+------------------------------------------------------------------+
bool WaitReady(const int timeout_s, int &waited_ms)
  {
   uint t0 = GetTickCount();
   while(!IsStopped() && (int)(GetTickCount() - t0) < timeout_s * 1000)
     {
      waited_ms = (int)(GetTickCount() - t0);
      if(TerminalInfoInteger(TERMINAL_CONNECTED))
        {
         MqlTick tk;
         MqlRates rr[];
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
void WriteEnvironment(const int autoOff)
  {
   Sum("ENV","build",  (string)TerminalInfoInteger(TERMINAL_BUILD));
   Sum("ENV","company",AccountInfoString(ACCOUNT_COMPANY));
   Sum("ENV","server", AccountInfoString(ACCOUNT_SERVER),
       (string)AccountInfoInteger(ACCOUNT_LOGIN),
       AccountInfoInteger(ACCOUNT_TRADE_MODE) == ACCOUNT_TRADE_MODE_DEMO ? "DEMO" : "OTHER");
   Sum("ENV","symbol", SYM, (string)dg, DoubleToString(pt, 8),
       DoubleToString(SymbolInfoDouble(SYM, SYMBOL_TRADE_TICK_SIZE), 8),
       (string)SymbolInfoInteger(SYM, SYMBOL_CHART_MODE),
       (string)SymbolInfoInteger(SYM, SYMBOL_SPREAD_FLOAT));
   Sum("ENV","time_now", TimeToString(TimeTradeServer(), TIME_DATE|TIME_SECONDS),
       TimeToString(TimeGMT(), TIME_DATE|TIME_SECONDS),
       TimeToString(TimeLocal(), TIME_DATE|TIME_SECONDS));
   Sum("ENV","offset_server_minus_gmt_h", (string)autoOff, (string)srvUTC,
       "auto / used", "AUDIT THIS FIRST - DEC-S-001 A-2");
   Sum("ENV","ny_offset", (string)InpNYOffsetFromUTC, InpApplyUSDst ? "US_DST_COARSE" : "FIXED",
       "false=fixed UTC-4; true=coarse Mar..Oct");
   Sum("ENV","windows_ny", (string)InpWinA_StartMin + "-" + (string)InpWinA_EndMin,
       (string)InpWinB_StartMin + "-" + (string)InpWinB_EndMin, "minutes from NY midnight");

   int fe = FileOpen("E-MT5-006-environment.txt", FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);
   if(fe != INVALID_HANDLE)
     {
      FileWrite(fe, "E-MT5-006 environment");
      FileWrite(fe, "terminal_build=" + (string)TerminalInfoInteger(TERMINAL_BUILD));
      FileWrite(fe, "company=" + AccountInfoString(ACCOUNT_COMPANY));
      FileWrite(fe, "server=" + AccountInfoString(ACCOUNT_SERVER));
      FileWrite(fe, "login=" + (string)AccountInfoInteger(ACCOUNT_LOGIN));
      FileWrite(fe, "trade_mode=" + (string)AccountInfoInteger(ACCOUNT_TRADE_MODE));
      FileWrite(fe, "symbol=" + SYM);
      FileWrite(fe, "digits=" + (string)dg + " point=" + DoubleToString(pt, 8));
      FileWrite(fe, "tick_size=" + DoubleToString(SymbolInfoDouble(SYM, SYMBOL_TRADE_TICK_SIZE), 8));
      FileWrite(fe, "chart_mode=" + (string)SymbolInfoInteger(SYM, SYMBOL_CHART_MODE));
      FileWrite(fe, "server_time=" + TimeToString(TimeTradeServer(), TIME_DATE|TIME_SECONDS));
      FileWrite(fe, "gmt_time=" + TimeToString(TimeGMT(), TIME_DATE|TIME_SECONDS));
      FileWrite(fe, "server_minus_gmt_h_auto=" + (string)autoOff);
      FileWrite(fe, "server_minus_gmt_h_used=" + (string)srvUTC);
      FileWrite(fe, "script_version=1.1");
      FileClose(fe);
     }
  }

//+------------------------------------------------------------------+
void ProbeDay(const string tag, const datetime anchor)
  {
   if(anchor <= 0) { Sum("WINDOW", tag, "SKIPPED", "invalid anchor"); return; }

   MqlDateTime d; TimeToStruct(anchor, d);
   d.hour = 0; d.min = 0; d.sec = 0;
   datetime dayStart = StructToTime(d);

   int nyOff = NYOffset(anchor);
   int shift = (srvUTC - nyOff) * 60;         // server = NY + (srvUTC - nyOff)

   ProbeWindow(tag + "_A", dayStart + (InpWinA_StartMin + shift) * 60,
                           dayStart + (InpWinA_EndMin   + shift) * 60, nyOff);
   ProbeWindow(tag + "_B", dayStart + (InpWinB_StartMin + shift) * 60,
                           dayStart + (InpWinB_EndMin   + shift) * 60, nyOff);
  }

//+------------------------------------------------------------------+
void ProbeWindow(const string tag, const datetime from, const datetime to, const int nyOff)
  {
   MqlTick t[];
   ResetLastError();
   int n   = CopyTicksRange(SYM, t, COPY_TICKS_ALL, (ulong)from * 1000, (ulong)to * 1000);
   int err = GetLastError();

   Sum("WINDOW", tag, TimeToString(from, TIME_DATE|TIME_SECONDS),
       TimeToString(to, TIME_DATE|TIME_SECONDS), (string)n, (string)err,
       "ny_off=" + (string)nyOff, "srv_utc=" + (string)srvUTC);

   if(n <= 0)
     {
      Sum("WINDOW", tag + "_STATUS",
          n == 0 ? "EMPTY_VALID_RANGE_OR_NO_DATA" : "COPY_FAILED",
          (string)err, "err 0 with n=0 means no error was raised");
      return;
     }

   long cBidF=0,cAskF=0,cLastF=0,cBoth=0,cOnlyB=0,cOnlyA=0,cNeither=0;
   long cBidV=0,cAskV=0,cLastV=0,cSpread=0;
   double spMin=DBL_MAX, spMax=-DBL_MAX, bidLo=DBL_MAX, bidHi=-DBL_MAX;
   double sp[]; ArrayResize(sp, n); int nsp = 0;

   for(int i = 0; i < n; i++)
     {
      bool fb = (t[i].flags & TICK_FLAG_BID)    != 0;
      bool fa = (t[i].flags & TICK_FLAG_ASK)    != 0;
      bool fl = (t[i].flags & TICK_FLAG_LAST)   != 0;
      bool fv = (t[i].flags & TICK_FLAG_VOLUME) != 0;
      bool vb = (t[i].bid  > 0.0);
      bool va = (t[i].ask  > 0.0);
      bool vl = (t[i].last > 0.0);

      if(fb) cBidF++;   if(fa) cAskF++;   if(fl) cLastF++;
      if(fb && fa) cBoth++; else if(fb) cOnlyB++; else if(fa) cOnlyA++; else cNeither++;
      if(vb) cBidV++;   if(va) cAskV++;   if(vl) cLastV++;

      double s = -1.0;
      if(vb && va)
        {
         s = t[i].ask - t[i].bid; cSpread++;
         if(s < spMin) spMin = s;
         if(s > spMax) spMax = s;
         sp[nsp++] = s;
        }
      if(vb) { if(t[i].bid < bidLo) bidLo = t[i].bid; if(t[i].bid > bidHi) bidHi = t[i].bid; }

      if(InpWriteTicks && tickRows < InpMaxTickRows)
        {
         tickRows++;
         datetime st = (datetime)(t[i].time_msc / 1000);
         FileWrite(fhT, SYM, tag, (string)i, (string)t[i].time_msc,
            TimeToString(st, TIME_DATE|TIME_SECONDS),
            TimeToString(st - (datetime)((srvUTC - NYOffset(st)) * 3600), TIME_DATE|TIME_SECONDS),
            vb ? DoubleToString(t[i].bid,  dg) : "",
            va ? DoubleToString(t[i].ask,  dg) : "",
            vl ? DoubleToString(t[i].last, dg) : "",
            (string)(long)t[i].volume,
            DoubleToString(t[i].volume_real, 2),
            (string)(int)t[i].flags,
            s >= 0.0 ? DoubleToString(s, dg) : "",
            s >= 0.0 ? (string)(int)MathRound(s / pt) : "",
            vb ? "1" : "0", va ? "1" : "0", vl ? "1" : "0",
            fb ? "1" : "0", fa ? "1" : "0", fl ? "1" : "0", fv ? "1" : "0");
        }
     }

   double med = 0.0;
   if(nsp > 0) { ArrayResize(sp, nsp); ArraySort(sp); med = sp[nsp/2]; }

   Sum("METRICS", tag + "_flagcounts", (string)n, (string)cBidF, (string)cAskF,
       (string)cLastF, (string)cBoth, (string)cNeither);
   Sum("METRICS", tag + "_onlyflags", (string)cOnlyB, (string)cOnlyA, "only_bid / only_ask");
   Sum("METRICS", tag + "_valuecounts", (string)cBidV, (string)cAskV, (string)cLastV,
       "values present (not necessarily updated)");
   Sum("METRICS", tag + "_spread",
       nsp > 0 ? DoubleToString(spMin, dg) : "NA",
       nsp > 0 ? DoubleToString(spMax, dg) : "NA",
       nsp > 0 ? DoubleToString(med,   dg) : "NA",
       DoubleToString(100.0 * (double)cSpread / (double)n, 2), "pct_ticks_with_spread");

   PenetrationScan(tag, t, n, bidLo, bidHi);
  }

//+------------------------------------------------------------------+
//| Does a bid-based rule differ from an ask-based rule?              |
//| These are test levels. Not liquidity pools.                       |
//+------------------------------------------------------------------+
void PenetrationScan(const string tag, const MqlTick &t[], const int n,
                     const double lo, const double hi)
  {
   if(!(hi > lo) || InpLevelScanCount < 2) return;

   int diverged = 0;
   for(int k = 0; k < InpLevelScanCount; k++)
     {
      double L = lo + (hi - lo) * (double)k / (double)(InpLevelScanCount - 1);
      long fbUp=-1, faUp=-1, fbDn=-1, faDn=-1;

      for(int i = 0; i < n; i++)
        {
         if(t[i].bid > 0.0)
           {
            if(fbUp < 0 && t[i].bid >= L) fbUp = (long)t[i].time_msc;
            if(fbDn < 0 && t[i].bid <= L) fbDn = (long)t[i].time_msc;
           }
         if(t[i].ask > 0.0)
           {
            if(faUp < 0 && t[i].ask >= L) faUp = (long)t[i].time_msc;
            if(faDn < 0 && t[i].ask <= L) faDn = (long)t[i].time_msc;
           }
        }

      bool div = (fbUp != faUp) || (fbDn != faDn);
      if(div) diverged++;

      Sum("PENETRATION", tag, DoubleToString(L, dg),
          "bidUp=" + (string)fbUp, "askUp=" + (string)faUp,
          "bidDn=" + (string)fbDn, "askDn=" + (string)faDn,
          div ? "DIVERGENT" : "same");
     }

   Sum("PENETRATION", tag + "_SUMMARY", (string)diverged, (string)InpLevelScanCount,
       DoubleToString(100.0 * (double)diverged / (double)InpLevelScanCount, 1),
       "pct_levels_where_bid_and_ask_rules_differ");
  }

//+------------------------------------------------------------------+
int NYOffset(const datetime when)
  {
   if(!InpApplyUSDst) return(InpNYOffsetFromUTC);
   MqlDateTime d; TimeToStruct(when, d);
   // Deliberately COARSE. Exact US DST rules are not implemented, because
   // guessing them is what DEC-S-001 A-2 forbids. Recorded as a limitation.
   return((d.mon >= 3 && d.mon <= 10) ? -4 : -5);
  }

//+------------------------------------------------------------------+
datetime MostRecentMonth(const int month, const int day)
  {
   MqlDateTime now; TimeToStruct(TimeTradeServer(), now);
   MqlDateTime o;
   o.year = (now.mon > month) ? now.year : now.year - 1;
   o.mon = month; o.day = day; o.hour = 0; o.min = 0; o.sec = 0;
   o.day_of_week = 0; o.day_of_year = 0;
   return(StructToTime(o));
  }

//+------------------------------------------------------------------+
datetime FindOldestTick()
  {
   datetime now = TimeTradeServer(), found = 0;
   for(int y = 1; y <= 15 && !IsStopped(); y++)
     {
      datetime from = now - (datetime)y * 31536000;
      MqlTick tt[];
      ResetLastError();
      int got = CopyTicksRange(SYM, tt, COPY_TICKS_ALL,
                               (ulong)from * 1000, (ulong)(from + 86400) * 1000);
      int e = GetLastError();
      Sum("COVERAGE", "probe_" + (string)y + "y_ago", TimeToString(from, TIME_DATE),
          (string)got, (string)e,
          got > 0 ? TimeToString((datetime)(tt[0].time_msc/1000), TIME_DATE|TIME_SECONDS)
                  : "DATA_NOT_AVAILABLE");
      if(got > 0) found = (datetime)(tt[0].time_msc / 1000);
     }
   return(found);
  }
//+------------------------------------------------------------------+
