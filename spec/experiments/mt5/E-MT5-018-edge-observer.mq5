//+------------------------------------------------------------------+
//| E-MT5-018 — EDGE OBSERVER                                         |
//|                                                                  |
//| *** NO TRADING. No <Trade\Trade.mqh>, no OrderSend, no account.   |
//| *** It is structurally incapable of opening a position.           |
//|                                                                  |
//| WHY IT EXISTS                                                     |
//| hist2 answered "does the pattern have an edge" through an account,|
//| and the account censored the sample: 4,446 of 18,494 signals      |
//| survived, selected by fundability and by the 1-position cap. The  |
//| measured 27.76% was a property of that filter, not of the pattern.|
//|                                                                  |
//| WHAT IT MEASURES                                                  |
//| For EVERY signal, which barrier is touched first, resolved on the |
//| real tick stream. No balance, no sizing, no margin, no compounding|
//| and no 1-position cap, so no signal can be crowded out.           |
//|                                                                  |
//| THE NULL is 33.333% for EVERY X, because the barriers are at -1R  |
//| and +2R by construction. The null is scale-free, so observing     |
//| several X is a structural test of whether the pattern carries     |
//| information at any scale. NO X IS SELECTED HERE. X stays OPEN.    |
//|                                                                  |
//| Entry is taken at Ask for a long and Bid for a short, and exits   |
//| are evaluated at the opposite side, so the feed's real spread is  |
//| paid exactly as a live trade would pay it.                        |
//|                                                                  |
//| Locked rules honoured: A' K=3 left-only, SW-4, SW-5 R-a, SW-6,    |
//| time contiguity of 1->2->3->4, entry on the first tick of         |
//| candle 4, TARGET_R = 2.0. Nothing is decided by this experiment.  |
//+------------------------------------------------------------------+
#property copyright "PROJECT TRADER - edge observer"
#property version   "1.0"
#property strict

input int    InpRefK      = 3;
input double InpTargetR   = 2.0;     // LOCKED, DEC-LOCK-001 section 9
input int    InpHorizon   = 500;     // M5 bars before a virtual trade is UNRESOLVED
input string InpRunTag    = "e18";

#define NX 6
int      XS[NX] = {1, 3, 5, 10, 15, 20};   // observed, not selected
#define MAXOPEN 4096

struct Bar { datetime t; double o, h, l, c; };

struct Sig
  {
   datetime t3, t4;
   int      dir;
   double   ref, sweep, rej, entry;
   double   depth, displace, rejwick, body3, range3, prior, expansion, reclaim, dist;
   int      res[NX];        // 0 open, 1 target-first, 2 stop-first, 3 unresolved
   double   risk[NX];
  };

struct VT { int sid; int xi; int dir; double stop, target; int bars; bool used; };

Sig   gS[];
int   gN = 0;
VT    gO[MAXOPEN];
int   gOpen = 0;
datetime gLastBar = 0;
int   fh = INVALID_HANDLE;
long  gInvalidStop = 0, gGapSkip = 0;

//====================================================================
double Ext(const Bar &b, const int d) { return(d > 0 ? b.l : b.h); }

bool DetectAt(const Bar &bars[], const int i3, const int K, const int d,
              double &ref, double &sweep, double &rejc)
  {
   int i2 = i3 - 1, i1 = i3 - 2;
   if(i1 - K < 0) return(false);
   ref = Ext(bars[i1], d);
   for(int k = 1; k <= K; k++)
      if(d * (Ext(bars[i1 - k], d) - ref) <= 0.0) return(false);
   sweep = Ext(bars[i2], d);
   if(!(d * (sweep - ref) < 0.0))          return(false);
   if(!(d * (sweep - bars[i2].c) < 0.0))   return(false);
   if(!(d * (bars[i2].c - ref) < 0.0))     return(false);
   rejc = bars[i3].c;
   if(!(d * (rejc - sweep) >= 0.0))        return(false);
   return(true);
  }

bool Contiguous(const Bar &bars[], const int i3, const datetime entT, const int ps)
  {
   if(bars[i3].t   - bars[i3-1].t != ps) return(false);
   if(bars[i3-1].t - bars[i3-2].t != ps) return(false);
   if(entT         - bars[i3].t   != ps) return(false);
   return(true);
  }

//====================================================================
int OnInit()
  {
   fh = FileOpen("E-MT5-018-" + InpRunTag + "-signals.csv",
                 FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON, ',');
   if(fh == INVALID_HANDLE) return(INIT_FAILED);
   FileWrite(fh, "signal_time", "entry_time", "dir", "ref", "sweep", "rej", "entry",
             "depth", "displace", "rejwick", "body3", "range3", "prior_rng",
             "expansion", "reclaim", "dist_entry",
             "res_x1", "res_x3", "res_x5", "res_x10", "res_x15", "res_x20",
             "risk_x1", "risk_x3", "risk_x5", "risk_x10", "risk_x15", "risk_x20");
   PrintFormat("E-MT5-018 OBSERVER — no trade function linked. trade_mode=%d",
               (int)AccountInfoInteger(ACCOUNT_TRADE_MODE));
   return(INIT_SUCCEEDED);
  }

//====================================================================
void OnTick()
  {
   MqlTick tk;
   if(!SymbolInfoTick(_Symbol, tk)) return;

   //--- resolve open virtual trades against the real tick, spread included
   for(int i = gOpen - 1; i >= 0; i--)
     {
      if(!gO[i].used) continue;
      int    s  = gO[i].sid, x = gO[i].xi, d = gO[i].dir;
      double px = (d > 0 ? tk.bid : tk.ask);        // a long closes at Bid
      bool hitS = (d > 0) ? (px <= gO[i].stop)   : (px >= gO[i].stop);
      bool hitT = (d > 0) ? (px >= gO[i].target) : (px <= gO[i].target);
      if(hitS || hitT)
        {
         gS[s].res[x] = hitT && !hitS ? 1 : (hitS && !hitT ? 2 : 2);  // stop wins a tie
         gO[i] = gO[gOpen - 1]; gOpen--;
        }
     }

   datetime bt = iTime(_Symbol, _Period, 0);
   if(bt == gLastBar || bt == 0) return;
   gLastBar = bt;

   //--- age open trades, expire past the horizon
   for(int i = gOpen - 1; i >= 0; i--)
     {
      gO[i].bars++;
      if(gO[i].bars > InpHorizon)
        { gS[gO[i].sid].res[gO[i].xi] = 3; gO[i] = gO[gOpen - 1]; gOpen--; }
     }

   int need = InpRefK + 4;
   Bar bars[]; ArrayResize(bars, need);
   for(int i = 0; i < need; i++)
     {
      int sh = need - 1 - i;
      bars[i].t = iTime(_Symbol, _Period, sh); bars[i].o = iOpen(_Symbol, _Period, sh);
      bars[i].h = iHigh(_Symbol, _Period, sh); bars[i].l = iLow(_Symbol, _Period, sh);
      bars[i].c = iClose(_Symbol, _Period, sh);
     }
   int i3 = need - 2;
   int ps = PeriodSeconds();

   for(int d = 1; d >= -1; d -= 2)
     {
      double ref, sw, rj;
      if(!DetectAt(bars, i3, InpRefK, d, ref, sw, rj)) continue;
      if(!Contiguous(bars, i3, bt, ps)) { gGapSkip++; break; }
      Register(d, bars, i3, ref, sw, rj, tk);
      break;                                    // geometry is mutually exclusive
     }
  }

//====================================================================
void Register(const int d, const Bar &bars[], const int i3,
              const double ref, const double sw, const double rj, const MqlTick &tk)
  {
   Bar c1 = bars[i3-2], c2 = bars[i3-1], c3 = bars[i3];
   double entry = (d > 0 ? tk.ask : tk.bid);     // first tick of candle 4, real side
   double r2 = MathMax(c2.h - c2.l, 1e-9), r3 = MathMax(c3.h - c3.l, 1e-9);
   double hi = bars[0].h, lo = bars[0].l;
   for(int k = 1; k <= i3 - 2; k++) { hi = MathMax(hi, bars[k].h); lo = MathMin(lo, bars[k].l); }
   double prior = hi - lo;

   ArrayResize(gS, gN + 1);
   gS[gN].t3 = c3.t; gS[gN].t4 = bars[i3].t + PeriodSeconds(); gS[gN].dir = d;
   gS[gN].ref = ref; gS[gN].sweep = sw; gS[gN].rej = rj; gS[gN].entry = entry;
   gS[gN].depth     = MathAbs(sw - ref) / _Point;
   gS[gN].displace  = d * (c3.c - c3.o) / _Point;
   gS[gN].rejwick   = (d > 0 ? (c2.c - c2.l) : (c2.h - c2.c)) / r2;
   gS[gN].body3     = MathAbs(c3.c - c3.o) / r3;
   gS[gN].range3    = r3 / _Point;
   gS[gN].prior     = prior / _Point;
   gS[gN].expansion = r3 / MathMax(prior / 4.0, 1e-9);
   gS[gN].reclaim   = d * (c3.c - ref) / _Point;
   gS[gN].dist      = d * (entry - sw) / _Point;

   for(int x = 0; x < NX; x++)
     {
      double stop = (d > 0 ? sw - XS[x] * _Point : sw + XS[x] * _Point);
      if(d * (entry - stop) <= 0) { gS[gN].res[x] = 4; gS[gN].risk[x] = 0; gInvalidStop++; continue; }
      double risk = MathAbs(entry - stop);
      gS[gN].res[x]  = 0;
      gS[gN].risk[x] = risk / _Point;
      if(gOpen < MAXOPEN)
        {
         gO[gOpen].sid = gN; gO[gOpen].xi = x; gO[gOpen].dir = d;
         gO[gOpen].stop = stop; gO[gOpen].target = entry + d * risk * InpTargetR;
         gO[gOpen].bars = 0; gO[gOpen].used = true; gOpen++;
        }
      else gS[gN].res[x] = 3;
     }
   gN++;
  }

//====================================================================
void OnDeinit(const int reason)
  {
   for(int i = 0; i < gOpen; i++) gS[gO[i].sid].res[gO[i].xi] = 3;   // still open at test end
   for(int i = 0; i < gN; i++)
      FileWrite(fh,
        TimeToString(gS[i].t3, TIME_DATE | TIME_SECONDS),
        TimeToString(gS[i].t4, TIME_DATE | TIME_SECONDS),
        (gS[i].dir > 0 ? "BUY" : "SELL"),
        DoubleToString(gS[i].ref, _Digits), DoubleToString(gS[i].sweep, _Digits),
        DoubleToString(gS[i].rej, _Digits), DoubleToString(gS[i].entry, _Digits),
        DoubleToString(gS[i].depth, 1), DoubleToString(gS[i].displace, 1),
        DoubleToString(gS[i].rejwick, 4), DoubleToString(gS[i].body3, 4),
        DoubleToString(gS[i].range3, 1), DoubleToString(gS[i].prior, 1),
        DoubleToString(gS[i].expansion, 4), DoubleToString(gS[i].reclaim, 1),
        DoubleToString(gS[i].dist, 1),
        (string)gS[i].res[0], (string)gS[i].res[1], (string)gS[i].res[2],
        (string)gS[i].res[3], (string)gS[i].res[4], (string)gS[i].res[5],
        DoubleToString(gS[i].risk[0], 1), DoubleToString(gS[i].risk[1], 1),
        DoubleToString(gS[i].risk[2], 1), DoubleToString(gS[i].risk[3], 1),
        DoubleToString(gS[i].risk[4], 1), DoubleToString(gS[i].risk[5], 1));
   if(fh != INVALID_HANDLE) FileClose(fh);
   PrintFormat("E-MT5-018 done: %d signals, %I64d gap-skipped, %I64d invalid-stop slots",
               gN, gGapSkip, gInvalidStop);
  }
//+------------------------------------------------------------------+
