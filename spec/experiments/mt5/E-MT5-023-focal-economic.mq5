//+------------------------------------------------------------------+
//| E-MT5-023 — FOCAL LEVEL, ECONOMIC EXPLORATION                    |
//|                                                                  |
//| STATUS: EXPLORATORY / IN-SAMPLE. NOT CONFIRMATORY.                |
//| Runs on EURUSD, whose entire history is already contaminated, so  |
//| this consumes no virgin sample and cannot confirm anything.       |
//|                                                                  |
//| Mechanism under test (Osler 2003):                                |
//|   take-profit orders cluster ON focal prices  -> reversal at level |
//|   stop-loss orders cluster JUST BEYOND        -> continuation past |
//|                                                                  |
//| BOTH directions are declared before running and BOTH are reported.|
//| Neither is selected after seeing the result.                      |
//+------------------------------------------------------------------+
#property copyright "PROJECT TRADER"
#property version   "1.00"
#include <Trade\Trade.mqh>

input int    InpGridPips   = 10;    // focal grid, SPEC-LVL-001
input int    InpUPips      = 4;     // arming distance
input int    InpStopPips   = 5;     // stop beyond the level
input double InpTargetR    = 2.0;   // LOCKED, DEC-LOCK-001
input double InpRiskPct    = 1.0;   // Policy A
input int    InpMaxPos     = 1;
input int    InpMode       = 0;     // 0 = REVERSAL at level, 1 = CONTINUATION past level
input string InpRunTag     = "e23";

CTrade gT;
int    gPip = 1;
double gGrid, gU, gStopD;
double gArmUp = 0, gArmDn = 0;
int    fh = INVALID_HANDLE;

struct Tr { int dir; double entry, stop, target, lot, risk; datetime t; bool open; double pl; };
Tr  gTr[]; int gN = 0;
int gWin = 0, gLoss = 0;
double gPeakEq = 0, gMaxDD = 0;

//+------------------------------------------------------------------+
int OnInit()
  {
   gPip  = (_Digits == 3 || _Digits == 5) ? 10 : 1;
   gGrid = InpGridPips * gPip * _Point;
   gU    = InpUPips    * gPip * _Point;
   gStopD= InpStopPips * gPip * _Point;

   fh = FileOpen("E-MT5-023-" + InpRunTag + "-trades.csv",
                 FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON, ',');
   if(fh == INVALID_HANDLE) return(INIT_FAILED);
   FileWrite(fh, "id", "time", "dir", "entry", "stop", "target", "lot", "risk", "pl", "R");

   gPeakEq = AccountInfoDouble(ACCOUNT_BALANCE);
   PrintFormat("E-MT5-023 start mode=%d grid=%d U=%d stop=%d balance=%.2f",
               InpMode, InpGridPips, InpUPips, InpStopPips,
               AccountInfoDouble(ACCOUNT_BALANCE));
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

   double dist = MathAbs(entry - stop);
   double lossPerLot = (dist / ts) * tv;
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
void Enter(const int dir, const double level)
  {
   if(PositionsTotal() >= InpMaxPos) return;
   MqlTick tk; if(!SymbolInfoTick(_Symbol, tk)) return;

   double entry = (dir > 0 ? tk.ask : tk.bid);
   // stop always sits on the far side of the focal level, where Osler places stops
   double stop  = (dir > 0 ? level - gStopD : level + gStopD);
   if(dir * (entry - stop) <= 0) return;
   double target = entry + dir * MathAbs(entry - stop) * InpTargetR;

   double rAct = 0;
   double lot = PolicyA(dir, entry, stop, rAct);
   if(lot <= 0) return;

   bool ok = (dir > 0) ? gT.Buy(lot, _Symbol, 0, stop, target)
                       : gT.Sell(lot, _Symbol, 0, stop, target);
   if(!ok || gT.ResultRetcode() != TRADE_RETCODE_DONE) return;

   Tr t; ZeroMemory(t);
   t.dir = dir; t.entry = gT.ResultPrice(); t.stop = stop; t.target = target;
   t.lot = gT.ResultVolume(); t.risk = rAct; t.t = tk.time; t.open = true;
   ArrayResize(gTr, gN + 1); gTr[gN] = t; gN++;
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   MqlTick tk; if(!SymbolInfoTick(_Symbol, tk)) return;
   double b = tk.bid;

   // equity curve tracking
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq > gPeakEq) gPeakEq = eq;
   if(gPeakEq > 0) { double dd = (gPeakEq - eq) / gPeakEq; if(dd > gMaxDD) gMaxDD = dd; }

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
      FileWrite(fh, (string)gN, TimeToString(gTr[gN - 1].t, TIME_DATE | TIME_SECONDS),
                (gTr[gN - 1].dir > 0 ? "BUY" : "SELL"),
                DoubleToString(gTr[gN - 1].entry, _Digits),
                DoubleToString(gTr[gN - 1].stop, _Digits),
                DoubleToString(gTr[gN - 1].target, _Digits),
                DoubleToString(gTr[gN - 1].lot, 2),
                DoubleToString(gTr[gN - 1].risk, 2),
                DoubleToString(pl, 2), DoubleToString(R, 3));
     }

   // ---- focal level detection -------------------------------------
   // ORDER MATTERS: fire on the currently armed level BEFORE re-arming.
   // Re-arming first would overwrite a pending armed level the instant price
   // crossed it, which silently disabled one side of the book.
   double pen = gPip * _Point;                    // u = 1 pip

   if(InpMode == 0)
     {
      // REVERSAL: price reaches the focal level -> trade AGAINST the approach
      if(gArmUp > 0 && b >= gArmUp) { Enter(-1, gArmUp); gArmUp = 0; }
      if(gArmDn > 0 && b <= gArmDn) { Enter(+1, gArmDn); gArmDn = 0; }
     }
   else
     {
      // CONTINUATION: price penetrates the level -> trade WITH the break
      if(gArmUp > 0 && b >= gArmUp + pen) { Enter(+1, gArmUp); gArmUp = 0; }
      if(gArmDn > 0 && b <= gArmDn - pen) { Enter(-1, gArmDn); gArmDn = 0; }
     }

   // ---- re-arm ----------------------------------------------------
   // A pending armed level survives until it fires or price retreats by U.
   double lvlDn = MathFloor(b / gGrid) * gGrid;   // focal level below
   double lvlUp = lvlDn + gGrid;                  // focal level above

   if(gArmUp <= 0 || b <= gArmUp - gU)
      { if(b <= lvlUp - gU) gArmUp = lvlUp; }
   if(gArmDn <= 0 || b >= gArmDn + gU)
      { if(b >= lvlDn + gU) gArmDn = lvlDn; }
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double gp = 0, gl = 0, sumR = 0;
   for(int i = 0; i < gN; i++)
     {
      if(gTr[i].pl > 0) gp += gTr[i].pl; else gl += -gTr[i].pl;
      if(gTr[i].risk > 0) sumR += gTr[i].pl / gTr[i].risk;
     }
   double pf = (gl > 0) ? gp / gl : 0;
   double wr = (gWin + gLoss > 0) ? 100.0 * gWin / (gWin + gLoss) : 0;

   if(fh != INVALID_HANDLE) FileClose(fh);
   PrintFormat("E-MT5-023 done mode=%d trades=%d win=%d loss=%d winrate=%.2f%% "
               "PF=%.4f grossP=%.2f grossL=%.2f finalBalance=%.2f totalR=%.1f maxDD=%.2f%%",
               InpMode, gN, gWin, gLoss, wr, pf, gp, gl, bal, sumR, gMaxDD * 100.0);
  }
//+------------------------------------------------------------------+
