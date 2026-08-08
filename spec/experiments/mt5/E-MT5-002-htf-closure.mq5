//+------------------------------------------------------------------+
//| E-MT5-002 — Higher-timeframe bar closure, observed from M1       |
//|                                                                  |
//| OBJECTIVE                                                        |
//|   Establish the exact mapping                                    |
//|      t_occurred / t_closed / t_known                             |
//|   for M5, M15, M30, H1, H4, measured against tick arrival.       |
//|   This is the single most important MT5 timing question for the  |
//|   whole project: it fixes how stale "HTF context" necessarily is.|
//|                                                                  |
//| HYPOTHESIS (to be falsified)                                     |
//|   H1: An HTF bar becomes knowably closed at the first tick with  |
//|       time >= its nominal boundary — the same instant the        |
//|       corresponding M1 bar closes. No earlier signal exists.     |
//|   H2: known_delay_ms grows with timeframe only because           |
//|       boundaries are rarer, not because HTF has extra latency.   |
//|   H3: iHigh(sym, TF, 0) on a forming HTF bar returns a PARTIAL   |
//|       high that changes over the life of the bar. It is not      |
//|       future information, but it is non-final — a repaint        |
//|       source, i.e. an A-2 hazard rather than an A-1 hazard.      |
//|                                                                  |
//| SETUP                                                            |
//|   Attach to an M1 chart. Run >= 5 hours so at least one H4       |
//|   boundary is crossed. Note the broker's H4 alignment.           |
//|                                                                  |
//| OUTPUT  Common/Files/E-MT5-002-<symbol>.csv                      |
//|   event=NEWBAR  emitted once per timeframe per transition        |
//|   event=PARTIAL emitted each minute: the forming HTF high/low    |
//|                 so H3 can be checked for monotone drift          |
//|                                                                  |
//| NOT PRODUCTION CODE. NO DETECTOR LOGIC. DISPOSABLE.              |
//+------------------------------------------------------------------+
#property copyright "PROJECT TRADER - feasibility experiment"
#property version   "1.0"
#property strict

#define NTF 6
ENUM_TIMEFRAMES TFS[NTF] = {PERIOD_M1, PERIOD_M5, PERIOD_M15,
                            PERIOD_M30, PERIOD_H1, PERIOD_H4};
int      SECS[NTF] = {60, 300, 900, 1800, 3600, 14400};
string   NAMES[NTF]= {"M1","M5","M15","M30","H1","H4"};

int      fh = INVALID_HANDLE;
datetime last_bar[NTF];
datetime last_partial_minute = 0;

int OnInit()
  {
   string fn = "E-MT5-002-" + _Symbol + ".csv";
   fh = FileOpen(fn, FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON, ',');
   if(fh == INVALID_HANDLE) return(INIT_FAILED);

   FileWrite(fh, "event","tf","tick_time_msc","tick_time",
      "closed_bar_open","nominal_boundary","known_delay_ms",
      "closed_o","closed_h","closed_l","closed_c","closed_ticks",
      "forming_bar_open","forming_h","forming_l","forming_ticks",
      "bars_available","synced");

   FileWrite(fh, "ENV", (string)TerminalInfoInteger(TERMINAL_BUILD),
      AccountInfoString(ACCOUNT_SERVER), _Symbol,
      TimeToString(TimeTradeServer(), TIME_DATE|TIME_SECONDS),
      (string)((long)TimeTradeServer() - (long)TimeGMT()),  // approx server-GMT offset
      "", "", "", "", "", "", "", "", "", "", "", "");

   for(int i = 0; i < NTF; i++) last_bar[i] = iTime(_Symbol, TFS[i], 0);
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason) { if(fh != INVALID_HANDLE) FileClose(fh); }

void OnTick()
  {
   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t)) return;

   for(int i = 0; i < NTF; i++)
     {
      datetime nb = iTime(_Symbol, TFS[i], 0);
      if(nb == last_bar[i] || last_bar[i] == 0) { last_bar[i] = nb; continue; }

      datetime boundary = last_bar[i] + SECS[i];
      long     delay_ms = (long)t.time_msc - (long)boundary * 1000;

      FileWrite(fh, "NEWBAR", NAMES[i], t.time_msc,
         TimeToString(t.time, TIME_DATE|TIME_SECONDS),
         TimeToString(last_bar[i], TIME_DATE|TIME_SECONDS),
         TimeToString(boundary,   TIME_DATE|TIME_SECONDS),
         delay_ms,                                   // <-- the key measurement
         DoubleToString(iOpen (_Symbol, TFS[i], 1), _Digits),
         DoubleToString(iHigh (_Symbol, TFS[i], 1), _Digits),
         DoubleToString(iLow  (_Symbol, TFS[i], 1), _Digits),
         DoubleToString(iClose(_Symbol, TFS[i], 1), _Digits),
         iVolume(_Symbol, TFS[i], 1),
         TimeToString(nb, TIME_DATE|TIME_SECONDS),
         DoubleToString(iHigh(_Symbol, TFS[i], 0), _Digits),
         DoubleToString(iLow (_Symbol, TFS[i], 0), _Digits),
         iVolume(_Symbol, TFS[i], 0),
         Bars(_Symbol, TFS[i]),
         SeriesInfoInteger(_Symbol, TFS[i], SERIES_SYNCHRONIZED));

      last_bar[i] = nb;
     }

   // ---- once per minute, snapshot every forming HTF bar (tests H3) ----
   datetime m1 = iTime(_Symbol, PERIOD_M1, 0);
   if(m1 != last_partial_minute)
     {
      last_partial_minute = m1;
      for(int i = 1; i < NTF; i++)   // skip M1
         FileWrite(fh, "PARTIAL", NAMES[i], t.time_msc,
            TimeToString(t.time, TIME_DATE|TIME_SECONDS),
            "", "", "", "", "", "", "", "",
            TimeToString(iTime(_Symbol, TFS[i], 0), TIME_DATE|TIME_SECONDS),
            DoubleToString(iHigh(_Symbol, TFS[i], 0), _Digits),
            DoubleToString(iLow (_Symbol, TFS[i], 0), _Digits),
            iVolume(_Symbol, TFS[i], 0),
            Bars(_Symbol, TFS[i]),
            SeriesInfoInteger(_Symbol, TFS[i], SERIES_SYNCHRONIZED));
     }
  }
//+------------------------------------------------------------------+
