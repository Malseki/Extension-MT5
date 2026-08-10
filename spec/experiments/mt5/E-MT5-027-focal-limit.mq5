//+------------------------------------------------------------------+
//| E-MT5-027 — FOCAL SIGNAL + OPTIMISED EXECUTION                    |
//|                                                                  |
//| Combines the two things we actually learned:                      |
//|                                                                  |
//|  (a) E-MT5-024/025: the execution tax is s/(3D). With a 20-pip    |
//|      stop and a limit entry it drops from 3.7pp to 0.82pp.        |
//|  (b) E-MT5-023: the focal CONTINUATION signal (mode 1) was the    |
//|      only one above random (+1.3pp, not significant).             |
//|                                                                  |
//| Mode 1 + limit entry has a natural reading: price penetrates the  |
//| focal level, we place a limit order AT the level and wait for the |
//| retest instead of chasing the break. Unfilled orders expire.      |
//|                                                                  |
//| EXPLORATORY on EURUSD (contaminated). A positive result here does |
//| NOT establish an edge — it would only justify preregistering the  |
//| test on virgin GBPUSD/USDJPY.                                     |
//+------------------------------------------------------------------+
#property copyright "PROJECT TRADER"
#property version   "1.00"
#include <Trade\Trade.mqh>

input int    InpGridPips   = 10;      // focal grid, SPEC-LVL-001
input int    InpUPips      = 4;       // arming distance
input int    InpStopPips   = 20;      // step-1 lesson: dilute the spread tax
input double InpTargetR    = 2.0;     // LOCKED, DEC-LOCK-001
input double InpRiskPct    = 1.0;     // Policy A (fractional, % of live balance)
input double InpFixedRisk  = 0.0;     // >0 = fixed $ risk per trade (kills volatility drag)
input int    InpMaxPos     = 1;
input int    InpMode       = 1;       // 0 = reversal, 1 = continuation/retest
input int    InpExpireSec  = 3600;    // limit lifetime
input string InpRunTag     = "e27";

CTrade gT;
int    gPip = 1;
double gGrid, gU, gStopD;
int    fh = INVALID_HANDLE;

double gArmUp = 0, gArmDn = 0;

struct Tr { int dir; double entry, stop, risk; bool open; double pl; };
Tr gTr[]; int gN = 0;
int gWin = 0, gLoss = 0;
long gPlaced = 0, gExpired = 0;
ulong gPend = 0; datetime gPendUntil = 0;

//+------------------------------------------------------------------+
int OnInit()
  {
   gPip   = (_Digits == 3 || _Digits == 5) ? 10 : 1;
   gGrid  = InpGridPips * gPip * _Point;
   gU     = InpUPips    * gPip * _Point;
   gStopD = InpStopPips * gPip * _Point;

   fh = FileOpen("E-MT5-027-" + InpRunTag + "-trades.csv",
                 FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON, ',');
   if(fh == INVALID_HANDLE) return(INIT_FAILED);
   FileWrite(fh, "id", "dir", "entry", "stop", "risk", "pl", "R");
   PrintFormat("E-MT5-027 start mode=%d grid=%d U=%d stop=%d expire=%d",
               InpMode, InpGridPips, InpUPips, InpStopPips, InpExpireSec);
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
   double planned = (InpFixedRisk > 0.0)
                    ? InpFixedRisk
                    : AccountInfoDouble(ACCOUNT_BALANCE) * InpRiskPct / 100.0;
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
void PlaceLimit(const int dir, const double level)
  {
   double stop   = level - dir * gStopD;
   double target = level + dir * gStopD * InpTargetR;
   double rAct = 0;
   double lot = PolicyA(dir, level, stop, rAct);
   if(lot <= 0) return;

   datetime exp = TimeCurrent() + InpExpireSec;
   bool ok = (dir > 0)
             ? gT.BuyLimit(lot, level, _Symbol, stop, target, ORDER_TIME_SPECIFIED, exp)
             : gT.SellLimit(lot, level, _Symbol, stop, target, ORDER_TIME_SPECIFIED, exp);
   if(!ok || gT.ResultRetcode() != TRADE_RETCODE_DONE) return;
   gPend = gT.ResultOrder(); gPendUntil = exp; gPlaced++;
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   MqlTick tk; if(!SymbolInfoTick(_Symbol, tk)) return;
   double b = tk.bid;

   // ---- close bookkeeping ------------------------------------------
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
                DoubleToString(pl, 2), DoubleToString(R, 3));
     }

   // ---- pending order filled? --------------------------------------
   if(gPend != 0 && PositionsTotal() > 0)
     {
      if(PositionSelect(_Symbol))
        {
         Tr t; ZeroMemory(t);
         t.dir   = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? +1 : -1;
         t.entry = PositionGetDouble(POSITION_PRICE_OPEN);
         t.stop  = PositionGetDouble(POSITION_SL);
         double ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
         double tv = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
         if(ts <= 0 || tv <= 0) { ts = _Point; tv = ts * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE); }
         t.risk  = (MathAbs(t.entry - t.stop) / ts) * tv * PositionGetDouble(POSITION_VOLUME);
         t.open  = true;
         ArrayResize(gTr, gN + 1); gTr[gN] = t; gN++;
        }
      gPend = 0;
     }
   if(gPend != 0 && OrdersTotal() > 0 && TimeCurrent() >= gPendUntil)
     { if(gT.OrderDelete(gPend)) gExpired++; gPend = 0; }
   if(gPend != 0 && OrdersTotal() == 0 && PositionsTotal() == 0) gPend = 0;

   // ---- signal: fire BEFORE re-arming (the E-MT5-023 fix) ----------
   double pen = gPip * _Point;
   bool busy = (PositionsTotal() >= InpMaxPos) || (OrdersTotal() > 0);

   if(!busy)
     {
      if(InpMode == 0)
        {
         if(gArmUp > 0 && b >= gArmUp) { PlaceLimit(-1, gArmUp); gArmUp = 0; }
         if(gArmDn > 0 && b <= gArmDn) { PlaceLimit(+1, gArmDn); gArmDn = 0; }
        }
      else
        {
         // penetration confirmed -> limit AT the level = wait for the retest
         if(gArmUp > 0 && b >= gArmUp + pen) { PlaceLimit(+1, gArmUp); gArmUp = 0; }
         if(gArmDn > 0 && b <= gArmDn - pen) { PlaceLimit(-1, gArmDn); gArmDn = 0; }
        }
     }

   // ---- re-arm ------------------------------------------------------
   double lvlDn = MathFloor(b / gGrid) * gGrid;
   double lvlUp = lvlDn + gGrid;
   if(gArmUp <= 0 || b <= gArmUp - gU) { if(b <= lvlUp - gU) gArmUp = lvlUp; }
   if(gArmDn <= 0 || b >= gArmDn + gU) { if(b >= lvlDn + gU) gArmDn = lvlDn; }
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
   double fr = (gPlaced > 0) ? 100.0 * gN / gPlaced : 0;
   if(fh != INVALID_HANDLE) FileClose(fh);
   PrintFormat("E-MT5-027 done mode=%d placed=%I64d filled=%d fillRate=%.2f%% "
               "win=%d loss=%d winrate=%.2f%% PF=%.4f grossP=%.2f grossL=%.2f "
               "finalBalance=%.2f totalR=%.1f",
               InpMode, gPlaced, gN, fr, gWin, gLoss, wr, pf, gp, gl,
               AccountInfoDouble(ACCOUNT_BALANCE), sumR);
  }
//+------------------------------------------------------------------+
