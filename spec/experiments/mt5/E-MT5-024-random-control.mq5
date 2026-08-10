//+------------------------------------------------------------------+
//| E-MT5-024 — RANDOM ENTRY CONTROL                                  |
//|                                                                  |
//| The economic control that E-MT5-023 was missing.                  |
//|                                                                  |
//| Enters at RANDOM instants with identical stop, target, sizing and |
//| position policy. Contains ZERO market information by construction.|
//|                                                                  |
//| Structural null for a 2:1 payoff is 33.333%.                      |
//|                                                                  |
//|   if random ~ 33.3%  -> execution is fair; a signal below 33.3%   |
//|                          is genuinely anti-predictive             |
//|   if random  < 33.3%  -> the shortfall is an execution/cost tax   |
//|                          paid by ANY market-order system, and the |
//|                          signal must be judged against THAT, not  |
//|                          against 33.3%                            |
//|                                                                  |
//| Also records the spread paid at every entry.                      |
//+------------------------------------------------------------------+
#property copyright "PROJECT TRADER"
#property version   "1.00"
#include <Trade\Trade.mqh>

input int    InpStopPips  = 5;      // identical to E-MT5-023
input double InpTargetR   = 2.0;    // identical
input double InpRiskPct   = 1.0;    // identical
input int    InpMaxPos    = 1;      // identical
input int    InpOneIn     = 20000;  // enter on ~1 of N eligible ticks
input int    InpSeed      = 20260809;
input string InpRunTag    = "e24";

CTrade gT;
int    gPip = 1;
double gStopD;
int    fh = INVALID_HANDLE;

struct Tr { int dir; double entry, stop, risk, spread; bool open; double pl; };
Tr gTr[]; int gN = 0;
int gWin = 0, gLoss = 0;
double gSpreadSum = 0;

//+------------------------------------------------------------------+
int OnInit()
  {
   gPip   = (_Digits == 3 || _Digits == 5) ? 10 : 1;
   gStopD = InpStopPips * gPip * _Point;
   MathSrand(InpSeed);

   fh = FileOpen("E-MT5-024-" + InpRunTag + "-trades.csv",
                 FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON, ',');
   if(fh == INVALID_HANDLE) return(INIT_FAILED);
   FileWrite(fh, "id", "dir", "entry", "stop", "risk", "spread_pips", "pl", "R");
   PrintFormat("E-MT5-024 start stop=%d targetR=%.1f oneIn=%d", InpStopPips, InpTargetR, InpOneIn);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
double PolicyA(const int dir, const double entry, const double stop, double &rAct)
  {
   double vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double vmax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double vst  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double ts   = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tv   = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(ts <= 0 || tv <= 0) { ts = _Point; tv = ts * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE); }
   double lossPerLot = (MathAbs(entry - stop) / ts) * tv;
   if(lossPerLot <= 0) { rAct = 0; return(0); }
   double planned = AccountInfoDouble(ACCOUNT_BALANCE) * InpRiskPct / 100.0;
   double lot = MathFloor((planned / lossPerLot) / vst) * vst;
   if(lot > vmax) lot = vmax;
   double mAvail = AccountInfoDouble(ACCOUNT_MARGIN_FREE), mReq = 0;
   ENUM_ORDER_TYPE ot = (dir > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   if(lot > 0 && OrderCalcMargin(ot, _Symbol, lot, entry, mReq) && mReq > mAvail)
     { double mPer = mReq / lot; lot = MathFloor((mAvail * 0.95 / mPer) / vst) * vst; }
   if(lot < vmin) { rAct = 0; return(0); }
   rAct = lot * lossPerLot;
   return(lot);
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   MqlTick tk; if(!SymbolInfoTick(_Symbol, tk)) return;

   // close bookkeeping
   if(gN > 0 && gTr[gN - 1].open && PositionsTotal() == 0)
     {
      double pl = 0;
      if(HistorySelect(0, TimeCurrent()))
        {
         int nd = HistoryDealsTotal();
         for(int i = nd - 1; i >= 0 && i >= nd - 6; i--)
           {
            ulong d = HistoryDealGetTicket(i);
            if(HistoryDealGetInteger(d, DEAL_ENTRY) == DEAL_ENTRY_OUT)
              { pl = HistoryDealGetDouble(d, DEAL_PROFIT)
                   + HistoryDealGetDouble(d, DEAL_SWAP)
                   + HistoryDealGetDouble(d, DEAL_COMMISSION); break; }
           }
        }
      gTr[gN - 1].open = false; gTr[gN - 1].pl = pl;
      if(pl > 0) gWin++; else gLoss++;
      double R = (gTr[gN - 1].risk > 0) ? pl / gTr[gN - 1].risk : 0;
      FileWrite(fh, (string)gN, (gTr[gN - 1].dir > 0 ? "BUY" : "SELL"),
                DoubleToString(gTr[gN - 1].entry, _Digits),
                DoubleToString(gTr[gN - 1].stop, _Digits),
                DoubleToString(gTr[gN - 1].risk, 2),
                DoubleToString(gTr[gN - 1].spread, 3),
                DoubleToString(pl, 2), DoubleToString(R, 3));
     }

   if(PositionsTotal() >= InpMaxPos) return;
   if((MathRand() % InpOneIn) != 0) return;          // random instant

   int dir = ((MathRand() % 2) == 0) ? +1 : -1;      // random direction
   double entry = (dir > 0 ? tk.ask : tk.bid);
   double stop  = entry - dir * gStopD;
   double target = entry + dir * gStopD * InpTargetR;
   double spread = (tk.ask - tk.bid) / (gPip * _Point);

   double rAct = 0;
   double lot = PolicyA(dir, entry, stop, rAct);
   if(lot <= 0) return;

   bool ok = (dir > 0) ? gT.Buy(lot, _Symbol, 0, stop, target)
                       : gT.Sell(lot, _Symbol, 0, stop, target);
   if(!ok || gT.ResultRetcode() != TRADE_RETCODE_DONE) return;

   Tr t; ZeroMemory(t);
   t.dir = dir; t.entry = gT.ResultPrice(); t.stop = stop;
   t.risk = rAct; t.spread = spread; t.open = true;
   ArrayResize(gTr, gN + 1); gTr[gN] = t; gN++;
   gSpreadSum += spread;
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   double gp = 0, gl = 0, sumR = 0;
   for(int i = 0; i < gN; i++)
     {
      if(gTr[i].pl > 0) gp += gTr[i].pl; else gl += -gTr[i].pl;
      if(gTr[i].risk > 0) sumR += gTr[i].pl / gTr[i].risk;
     }
   double pf = (gl > 0) ? gp / gl : 0;
   double wr = (gWin + gLoss > 0) ? 100.0 * gWin / (gWin + gLoss) : 0;
   double avSpread = (gN > 0) ? gSpreadSum / gN : 0;
   if(fh != INVALID_HANDLE) FileClose(fh);
   PrintFormat("E-MT5-024 done trades=%d win=%d loss=%d winrate=%.2f%% PF=%.4f "
               "grossP=%.2f grossL=%.2f finalBalance=%.2f totalR=%.1f avgSpreadPips=%.4f",
               gN, gWin, gLoss, wr, pf, gp, gl,
               AccountInfoDouble(ACCOUNT_BALANCE), sumR, avSpread);
  }
//+------------------------------------------------------------------+
