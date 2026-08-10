//+------------------------------------------------------------------+
//| E-MT5-029 — VARIANCE RATIO / STRUCTURE OBSERVER                   |
//|                                                                  |
//| PURE OBSERVER. No orders, no account, no costs, no strategy.      |
//|                                                                  |
//| The question this closes:                                         |
//|   Is there ANY exploitable linear structure in the returns, at    |
//|   ANY intraday scale?                                             |
//|                                                                  |
//| Method: Lo-MacKinlay variance ratio.                              |
//|                                                                  |
//|   VR(q) = Var(r_q) / (q * Var(r_1))                               |
//|                                                                  |
//|   VR = 1  ->  random walk, no linear structure                    |
//|   VR < 1  ->  mean reversion at that horizon                      |
//|   VR > 1  ->  momentum at that horizon                            |
//|                                                                  |
//| Heteroskedasticity-robust z from Lo & MacKinlay (1988), because   |
//| FX returns are strongly heteroskedastic and the homoskedastic     |
//| statistic would reject far too often.                             |
//|                                                                  |
//| Stratified by realised-volatility regime: the short-term-reversal |
//| literature reports the effect is stronger when realised vol and   |
//| illiquidity are high. That is the only conditioning with primary  |
//| published support that this project has not yet tested.           |
//|                                                                  |
//| A flat VR=1 across every scale and regime would mean no           |
//| price-based directional strategy can work here — which is as      |
//| decisive as a positive result, and is why this is worth the last  |
//| unit of the hypothesis budget.                                    |
//+------------------------------------------------------------------+
#property copyright "PROJECT TRADER"
#property version   "1.00"
#property strict

input int    InpBaseTF     = 1;       // base timeframe in minutes (r_1)
input int    InpMaxBars    = 500000;  // bars to consume
input string InpRunTag     = "e29";

// aggregation horizons q (in base bars)
#define NQ 6
int Q[NQ] = {2, 4, 8, 16, 32, 64};

int fh = INVALID_HANDLE;

//+------------------------------------------------------------------+
ENUM_TIMEFRAMES TFof(const int m)
  {
   switch(m)
     {
      case 1:  return(PERIOD_M1);
      case 5:  return(PERIOD_M5);
      case 15: return(PERIOD_M15);
      case 30: return(PERIOD_M30);
      default: return(PERIOD_M1);
     }
  }

//+------------------------------------------------------------------+
//| Lo-MacKinlay VR with heteroskedasticity-robust z                  |
//+------------------------------------------------------------------+
void VarianceRatio(const double &r[], const int n, const int q,
                   double &vr, double &z, int &nUsed)
  {
   vr = 0; z = 0; nUsed = 0;
   if(n < q * 20) return;

   double mu = 0;
   for(int i = 0; i < n; i++) mu += r[i];
   mu /= n;

   // Var(r_1)
   double v1 = 0;
   for(int i = 0; i < n; i++) v1 += (r[i] - mu) * (r[i] - mu);
   v1 /= (n - 1);
   if(v1 <= 0) return;

   // Var(r_q) on overlapping q-sums
   int m = n - q + 1;
   double vq = 0;
   for(int i = 0; i < m; i++)
     {
      double s = 0;
      for(int j = 0; j < q; j++) s += r[i + j];
      double d = s - q * mu;
      vq += d * d;
     }
   vq /= (double)q * (double)(n - q + 1) * (1.0 - (double)q / (double)n);
   if(vq <= 0) return;

   vr = vq / v1;

   // heteroskedasticity-robust variance of VR (Lo & MacKinlay 1988)
   double theta = 0;
   for(int j = 1; j <= q - 1; j++)
     {
      double num = 0, den = 0;
      for(int i = j; i < n; i++)
        {
         double a = (r[i] - mu) * (r[i] - mu);
         double b = (r[i - j] - mu) * (r[i - j] - mu);
         num += a * b;
        }
      for(int i = 0; i < n; i++)
        { double c = (r[i] - mu) * (r[i] - mu); den += c; }
      den = den * den;
      if(den <= 0) continue;
      double dj = num / den;
      double w  = 2.0 * (q - j) / (double)q;
      theta += w * w * dj;
     }
   if(theta <= 0) return;
   z = (vr - 1.0) / MathSqrt(theta);
   nUsed = n;
  }

//+------------------------------------------------------------------+
void Analyse(const double &r[], const int n, const string label)
  {
   for(int k = 0; k < NQ; k++)
     {
      double vr, z; int nu;
      VarianceRatio(r, n, Q[k], vr, z, nu);
      if(nu == 0) continue;
      string verdict = (MathAbs(z) < 1.96) ? "RANDOM_WALK"
                       : (vr < 1.0 ? "REVERSION" : "MOMENTUM");
      FileWrite(fh, label, (string)InpBaseTF, (string)Q[k], (string)nu,
                DoubleToString(vr, 5), DoubleToString(z, 3), verdict);
      PrintFormat("E-MT5-029 %s q=%d n=%d VR=%.5f z=%+.3f %s",
                  label, Q[k], nu, vr, z, verdict);
     }
  }

//+------------------------------------------------------------------+
int OnInit()
  {
   fh = FileOpen("E-MT5-029-" + InpRunTag + "-vr.csv",
                 FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON, ',');
   if(fh == INVALID_HANDLE) return(INIT_FAILED);
   FileWrite(fh, "sample", "base_tf_min", "q", "n", "VR", "z", "verdict");
   PrintFormat("E-MT5-029 armado en %s, esperando historia...", _Symbol);
   return(INIT_SUCCEEDED);
  }

bool gDone = false;

//+------------------------------------------------------------------+
//| The analysis runs on the first tick that has enough history.      |
//| In the strategy tester CopyRates returns nothing during OnInit.   |
//+------------------------------------------------------------------+
void Run()
  {
   ENUM_TIMEFRAMES tf = TFof(InpBaseTF);
   int total = Bars(_Symbol, tf);
   if(total > InpMaxBars) total = InpMaxBars;
   if(total < 5000) return;

   MqlRates rt[];
   ArraySetAsSeries(rt, false);
   int got = CopyRates(_Symbol, tf, 0, total, rt);
   if(got < 5000) return;

   double r[]; ArrayResize(r, got - 1);
   for(int i = 1; i < got; i++)
      r[i - 1] = (rt[i].close > 0 && rt[i - 1].close > 0)
                 ? MathLog(rt[i].close / rt[i - 1].close) : 0.0;
   int n = got - 1;

   // realised sigma per base bar, in pips — needed to price the effect
   double mu0 = 0; for(int i = 0; i < n; i++) mu0 += r[i]; mu0 /= n;
   double s2 = 0; for(int i = 0; i < n; i++) s2 += (r[i]-mu0)*(r[i]-mu0);
   double sigma = MathSqrt(s2/(n-1));
   int pipp = (_Digits == 3 || _Digits == 5) ? 10 : 1;
   double sigPips = sigma * rt[got-1].close / (pipp * _Point);
   PrintFormat("E-MT5-029 start %s tf=%dmin bars=%d returns=%d sigma=%.4f pips/barra",
               _Symbol, InpBaseTF, got, n, sigPips);
   FileWrite(fh, "SIGMA_PIPS", (string)InpBaseTF, "-", (string)n,
             DoubleToString(sigPips, 4), "-", "-");

   Analyse(r, n, "ALL");

   int Wv = 60;
   double rv[]; ArrayResize(rv, n); ArrayInitialize(rv, 0.0);
   for(int i = Wv; i < n; i++)
     {
      double s2 = 0;
      for(int j = i - Wv; j < i; j++) s2 += MathAbs(r[j]);
      rv[i] = s2;
     }
   double srt[]; ArrayResize(srt, n - Wv);
   for(int i = Wv; i < n; i++) srt[i - Wv] = rv[i];
   ArraySort(srt);
   double med = srt[(n - Wv) / 2];

   double hi[], lo[]; int nh = 0, nl = 0;
   ArrayResize(hi, n); ArrayResize(lo, n);
   for(int i = Wv; i < n; i++)
     { if(rv[i] > med) hi[nh++] = r[i]; else lo[nl++] = r[i]; }
   ArrayResize(hi, nh); ArrayResize(lo, nl);
   PrintFormat("E-MT5-029 regimenes: alta_vol n=%d  baja_vol n=%d", nh, nl);
   Analyse(hi, nh, "VOL_ALTA");
   Analyse(lo, nl, "VOL_BAJA");

   if(fh != INVALID_HANDLE) { FileClose(fh); fh = INVALID_HANDLE; }
   gDone = true;
   Print("E-MT5-029 done");
  }

void OnDeinit(const int reason) { if(fh != INVALID_HANDLE) FileClose(fh); }
void OnTick() { if(!gDone) Run(); }
//+------------------------------------------------------------------+
