//+------------------------------------------------------------------+
//| E-MT5-025 — RANDOM ENTRY, LIMIT ORDER                             |
//|                                                                  |
//| Identical to E-MT5-024 (random instants, random direction, same   |
//| stop / target / sizing) except the entry is a LIMIT order placed  |
//| on the favourable side of the book instead of a market order.     |
//|                                                                  |
//| Theory: a market BUY enters at ASK and exits on BID, so the two   |
//| barriers sit at D-s and 2D+s  ->  P = 1/3 - s/(3D).               |
//| A limit BUY filled at BID enters and exits on the same side, so   |
//| the barriers are D and 2D  ->  P = 1/3 exactly, no spread tax.    |
//|                                                                  |
//| BUT a limit order only fills when price comes to it (adverse      |
//| selection) and sometimes never fills at all. Whether the saved    |
//| spread outweighs that is an empirical question — this measures it.|
//|                                                                  |
//| Reports fill rate, expiry rate and the outcome of filled orders.  |
//+------------------------------------------------------------------+
#property copyright "PROJECT TRADER"
#property version   "1.00"
#include <Trade\Trade.mqh>

input int    InpStopPips   = 5;       // same as E-MT5-024
input double InpTargetR    = 2.0;
input double InpRiskPct    = 1.0;
input int    InpMaxPos     = 1;
input int    InpOneIn      = 20000;
input int    InpExpireSec  = 3600;    // cancel unfilled limit after 1 hour
input int    InpSeed       = 20260809;
input string InpRunTag     = "e25";

CTrade gT;
int    gPip = 1;
double gStopD;
int    fh = INVALID_HANDLE;

struct Tr { int dir; double entry, stop, risk, spread; bool open; double pl; };
Tr gTr[]; int gN = 0;
int gWin = 0, gLoss = 0;
long gPlaced = 0, gExpired = 0;
double gSpreadSum = 0;
ulong  gPendTicket = 0;
datetime gPendUntil = 0;

//+------------------------------------------------------------------+
int OnInit()
  {
   gPip   = (_Digits == 3 || _Digits == 5) ? 10 : 1;
   gStopD = InpStopPips * gPip * _Point;
   MathSrand(InpSeed);

   fh = FileOpen("E-MT5-025-" + InpRunTag + "-trades.csv",
                 FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON, ',');
   if(fh == INVALID_HANDLE) return(INIT_FAILED);
   FileWrite(fh, "id", "dir", "entry", "stop", "risk", "spread_pips", "pl", "R");
   PrintFormat("E-MT5-025 start stop=%d targetR=%.1f expire=%ds",
               InpStopPips, InpTargetR, InpExpireSec);
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
                DoubleToString(gTr[gN - 1].spread, 3),
                DoubleToString(pl, 2), DoubleToString(R, 3));
     }

   // ---- a pending order became a position? --------------------------
   if(gPendTicket != 0 && PositionsTotal() > 0)
     {
      // it filled; register the trade using the actual position price
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
         t.spread = (tk.ask - tk.bid) / (gPip * _Point);
         t.open  = true;
         ArrayResize(gTr, gN + 1); gTr[gN] = t; gN++;
         gSpreadSum += t.spread;
        }
      gPendTicket = 0;
     }

   // ---- expire an unfilled pending order ----------------------------
   if(gPendTicket != 0 && OrdersTotal() > 0 && TimeCurrent() >= gPendUntil)
     {
      if(gT.OrderDelete(gPendTicket)) gExpired++;
      gPendTicket = 0;
     }
   if(gPendTicket != 0 && OrdersTotal() == 0 && PositionsTotal() == 0)
      gPendTicket = 0;   // vanished (expired server-side)

   if(PositionsTotal() >= InpMaxPos) return;
   if(OrdersTotal() > 0) return;
   if((MathRand() % InpOneIn) != 0) return;          // random instant

   // ---- place the limit order on the favourable side ----------------
   int dir = ((MathRand() % 2) == 0) ? +1 : -1;
   // BUY limit at the current BID (we do not pay the spread on entry)
   // SELL limit at the current ASK
   double price = (dir > 0 ? tk.bid : tk.ask);
   double stop  = price - dir * gStopD;
   double target = price + dir * gStopD * InpTargetR;

   double rAct = 0;
   double lot = PolicyA(dir, price, stop, rAct);
   if(lot <= 0) return;

   datetime exp = TimeCurrent() + InpExpireSec;
   bool ok = (dir > 0)
             ? gT.BuyLimit(lot, price, _Symbol, stop, target, ORDER_TIME_SPECIFIED, exp)
             : gT.SellLimit(lot, price, _Symbol, stop, target, ORDER_TIME_SPECIFIED, exp);
   if(!ok || gT.ResultRetcode() != TRADE_RETCODE_DONE) return;

   gPendTicket = gT.ResultOrder();
   gPendUntil  = exp;
   gPlaced++;
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
   double fillRate = (gPlaced > 0) ? 100.0 * gN / gPlaced : 0;
   double avSpread = (gN > 0) ? gSpreadSum / gN : 0;
   if(fh != INVALID_HANDLE) FileClose(fh);
   PrintFormat("E-MT5-025 done placed=%I64d filled=%d expired=%I64d fillRate=%.2f%% "
               "win=%d loss=%d winrate=%.2f%% PF=%.4f grossP=%.2f grossL=%.2f "
               "finalBalance=%.2f totalR=%.1f avgSpreadPips=%.4f",
               gPlaced, gN, gExpired, fillRate, gWin, gLoss, wr, pf, gp, gl,
               AccountInfoDouble(ACCOUNT_BALANCE), sumR, avSpread);
  }
//+------------------------------------------------------------------+
