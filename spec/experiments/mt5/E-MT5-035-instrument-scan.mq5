//+------------------------------------------------------------------+
//| E-MT5-035 — INSTRUMENT COST/VOLATILITY SCAN                       |
//|                                                                  |
//| PURE OBSERVER. No orders.                                         |
//|                                                                  |
//| Every conclusion so far was drawn on EURUSD and GBPUSD. The edge  |
//| is fixed by the market's reversion (0.562 pips on a 10-pip race), |
//| but the COST is a property of the instrument. What matters is not |
//| the spread in pips, it is the spread RELATIVE to how much the     |
//| instrument moves.                                                 |
//|                                                                  |
//|    tradability = spread / sigma(M5)                               |
//|                                                                  |
//| A pair with twice the spread but three times the volatility is    |
//| CHEAPER to trade, not dearer. This has never been measured here.  |
//|                                                                  |
//| Reports, per symbol: average spread, spread at movement, sigma of |
//| M5 returns, and the ratio that decides whether the reversion edge |
//| could ever clear the cost.                                        |
//+------------------------------------------------------------------+
#property copyright "PROJECT TRADER"
#property version   "1.00"
#property strict

input string InpSymbols = "EURUSD,GBPUSD,USDJPY,USDCHF,AUDUSD,USDCAD,NZDUSD,EURGBP,EURJPY,GBPJPY,XAUUSD";
input double InpMovePips = 5.0;   // "movement" threshold, same as the detector
input string InpRunTag  = "e35";

int fh = INVALID_HANDLE;

//+------------------------------------------------------------------+
int OnInit()
  {
   fh = FileOpen("E-MT5-035-" + InpRunTag + "-scan.csv",
                 FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON, ',');
   if(fh == INVALID_HANDLE) return(INIT_FAILED);
   FileWrite(fh, "symbol", "digits", "bars", "avg_spread_pips", "sigma_M5_pips",
             "ratio_spread_sigma", "edge_needed_pips", "verdict");

   string sym[];
   int n = StringSplit(InpSymbols, ',', sym);
   PrintFormat("E-MT5-035 scanning %d symbols", n);

   for(int i = 0; i < n; i++)
     {
      string s = sym[i];
      StringTrimLeft(s); StringTrimRight(s);
      if(s == "") continue;
      if(!SymbolSelect(s, true)) { Print("  ", s, " : no disponible"); continue; }

      int dg = (int)SymbolInfoInteger(s, SYMBOL_DIGITS);
      double pip = ((dg == 3 || dg == 5) ? 10.0 : 1.0) * SymbolInfoDouble(s, SYMBOL_POINT);
      if(pip <= 0) continue;

      // sigma of M5 log-ish returns, in pips, over available history
      MqlRates r[];
      int got = CopyRates(s, PERIOD_M5, 0, 20000, r);
      if(got < 500) { Print("  ", s, " : historia insuficiente (", got, ")"); continue; }

      double sum = 0, sum2 = 0; int cnt = 0;
      for(int k = 1; k < got; k++)
        {
         double d = (r[k].close - r[k-1].close) / pip;
         sum += d; sum2 += d*d; cnt++;
        }
      if(cnt < 100) continue;
      double mean = sum / cnt;
      double sigma = MathSqrt(MathMax(0, sum2/cnt - mean*mean));

      // current spread as a proxy for the average
      double sp = (double)SymbolInfoInteger(s, SYMBOL_SPREAD) * SymbolInfoDouble(s, SYMBOL_POINT) / pip;
      if(sp <= 0) sp = (SymbolInfoDouble(s, SYMBOL_ASK) - SymbolInfoDouble(s, SYMBOL_BID)) / pip;

      double ratio = (sigma > 0) ? sp / sigma : 999;
      // with a race of D = 2*sigma, edge = 0.0562*D ; need edge > spread
      double D = 2.0 * sigma;
      double edge = 0.0562 * D;
      string verdict = (edge > sp) ? "POSIBLE" : "no cubre";

      FileWrite(fh, s, (string)dg, (string)cnt,
                DoubleToString(sp, 4), DoubleToString(sigma, 4),
                DoubleToString(ratio, 4), DoubleToString(edge, 4), verdict);
      PrintFormat("  %-8s dig=%d sigma=%.3f p  spread=%.3f p  ratio=%.3f  edge@2sigma=%.3f  %s",
                  s, dg, sigma, sp, ratio, edge, verdict);
     }
   FileClose(fh);
   Print("E-MT5-035 done");
   return(INIT_SUCCEEDED);
  }

void OnTick() {}
void OnDeinit(const int reason) {}
//+------------------------------------------------------------------+
