//+------------------------------------------------------------------+
//| E-MT5-033 — MAKER REVERSION STRATEGY                              |
//|                                                                  |
//| The one configuration the evidence points at and we never tested. |
//|                                                                  |
//| Every previous economic run was a TAKER: it entered at market and |
//| paid the spread on 100% of trades, and E-MT5-032 showed that      |
//| spread doubles at the exact moment a signal fires.                |
//|                                                                  |
//| This one is a MAKER: entry is a LIMIT order, and MT5 executes     |
//| take-profit as a limit too. Only the stop crosses the spread.     |
//| So the spread is paid on losers only (~47%), not on everything.   |
//|                                                                  |
//| PREDICTION, recorded before measuring:                            |
//|    taker  EV = -0.276 pips/trade                                  |
//|    maker  EV = +0.167 pips/trade                                  |
//| but this ignores two costs that must be MEASURED, not assumed:    |
//|    (1) fill rate — limits that never execute                      |
//|    (2) adverse selection — you get filled when price keeps going  |
//|        against you, which is exactly when the limit is reachable  |
//| The margin is thin: win rate below 52.00% turns it negative.      |
//|                                                                  |
//| Signal: impulse of 5 pips in 5 min -> trade the REVERSION.        |
//| Sizing: fixed risk (no volatility drag, per E-MT5-027).           |
//+------------------------------------------------------------------+
#property copyright "PROJECT TRADER"
#property version   "1.00"
#include <Trade\Trade.mqh>

input double InpImpPips   = 5.0;    // impulse definition, same as E-MT5-030
input int    InpImpBars   = 1;
input double InpRacePips  = 10.0;   // stop and target, symmetric
input double InpFixedRisk = 100.0;  // fixed $ risk per trade
input int    InpMaxPos    = 1;
input int    InpExpireSec = 300;    // cancel unfilled limit after 5 min
input int    InpCoolS     = 300;
input bool   InpTakerMode = false;  // true = market entry, for A/B comparison
input string InpRunTag    = "e33";

CTrade gT;
int    gPip = 1;
double gD;
int    fh = INVALID_HANDLE;

datetime gLastTrig = 0;
ulong    gPend = 0;
datetime gPendUntil = 0;

struct Tr { int dir; double entry, stop, risk; bool open; double pl; };
Tr gTr[]; int gN = 0;
int  gWin = 0, gLoss = 0;
long gPlaced = 0, gExpired = 0;
double gSpreadAtSignal = 0; long gSigN = 0;

//+------------------------------------------------------------------+
int OnInit()
  {
   gPip = (_Digits == 3 || _Digits == 5) ? 10 : 1;
   gD   = InpRacePips * gPip * _Point;
   fh = FileOpen("E-MT5-033-" + InpRunTag + "-trades.csv",
                 FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON, ',');
   if(fh == INVALID_HANDLE) return(INIT_FAILED);
   FileWrite(fh, "id", "dir", "entry", "stop", "risk", "pl", "R");
   PrintFormat("E-MT5-033 start mode=%s impulse=%.1fp race=%.1fp risk=$%.0f",
               (InpTakerMode ? "TAKER" : "MAKER"), InpImpPips, InpRacePips, InpFixedRisk);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
double MovePips(const int bars)
  {
   double past = iClose(_Symbol, PERIOD_M5, bars);
   if(past <= 0) return(0);
   MqlTick t; if(!SymbolInfoTick(_Symbol, t)) return(0);
   return((t.bid - past) / (gPip * _Point));
  }

//+------------------------------------------------------------------+
double Lots(const double entry, const double stop, double &rAct)
  {
   double vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double vmax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double vst  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double ts   = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tv   = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(ts <= 0 || tv <= 0) { ts = _Point; tv = ts * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE); }
   double lossPerLot = (MathAbs(entry - stop) / ts) * tv;
   if(lossPerLot <= 0) { rAct = 0; return(0); }
   double lot = MathFloor((InpFixedRisk / lossPerLot) / vst) * vst;
   if(lot > vmax) lot = vmax;
   double mAvail = AccountInfoDouble(ACCOUNT_MARGIN_FREE), mReq = 0;
   if(lot > 0 && OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, lot, entry, mReq) && mReq > mAvail)
     { double mPer = mReq / lot; lot = MathFloor((mAvail * 0.95 / mPer) / vst) * vst; }
   if(lot < vmin) { rAct = 0; return(0); }
   rAct = lot * lossPerLot;
   return(lot);
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   MqlTick t; if(!SymbolInfoTick(_Symbol, t)) return;

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

   // ---- a pending limit became a position? -------------------------
   if(gPend != 0 && PositionsTotal() > 0)
     {
      if(PositionSelect(_Symbol))
        {
         Tr tr; ZeroMemory(tr);
         tr.dir   = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? +1 : -1;
         tr.entry = PositionGetDouble(POSITION_PRICE_OPEN);
         tr.stop  = PositionGetDouble(POSITION_SL);
         double ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
         double tv = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
         if(ts <= 0 || tv <= 0) { ts = _Point; tv = ts * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE); }
         tr.risk = (MathAbs(tr.entry - tr.stop) / ts) * tv * PositionGetDouble(POSITION_VOLUME);
         tr.open = true;
         ArrayResize(gTr, gN + 1); gTr[gN] = tr; gN++;
        }
      gPend = 0;
     }
   if(gPend != 0 && OrdersTotal() > 0 && TimeCurrent() >= gPendUntil)
     { if(gT.OrderDelete(gPend)) gExpired++; gPend = 0; }
   if(gPend != 0 && OrdersTotal() == 0 && PositionsTotal() == 0) gPend = 0;

   if(PositionsTotal() >= InpMaxPos) return;
   if(OrdersTotal() > 0) return;
   if(TimeCurrent() - gLastTrig < InpCoolS) return;

   // ---- signal: impulse -> trade the REVERSION ---------------------
   double mv = MovePips(InpImpBars);
   if(MathAbs(mv) < InpImpPips) return;

   int dir = (mv > 0) ? -1 : +1;              // opposite to the impulse
   gLastTrig = TimeCurrent();
   gSpreadAtSignal += (t.ask - t.bid) / (gPip * _Point); gSigN++;

   double px = (dir > 0) ? t.ask : t.bid;     // reference price
   double stop   = px - dir * gD;
   double target = px + dir * gD;
   double rAct = 0;
   double lot = Lots(px, stop, rAct);
   if(lot <= 0) return;

   bool ok = false;
   if(InpTakerMode)
     {
      ok = (dir > 0) ? gT.Buy(lot, _Symbol, 0, stop, target)
                     : gT.Sell(lot, _Symbol, 0, stop, target);
      if(ok && gT.ResultRetcode() == TRADE_RETCODE_DONE)
        {
         Tr tr; ZeroMemory(tr);
         tr.dir = dir; tr.entry = gT.ResultPrice(); tr.stop = stop;
         tr.risk = rAct; tr.open = true;
         ArrayResize(gTr, gN + 1); gTr[gN] = tr; gN++;
         gPlaced++;
        }
      return;
     }

   // MAKER: limit order at the signal price. It fills only if price
   // comes to us — which is precisely where adverse selection lives.
   datetime exp = TimeCurrent() + InpExpireSec;
   ok = (dir > 0) ? gT.BuyLimit(lot, px, _Symbol, stop, target, ORDER_TIME_SPECIFIED, exp)
                  : gT.SellLimit(lot, px, _Symbol, stop, target, ORDER_TIME_SPECIFIED, exp);
   if(!ok || gT.ResultRetcode() != TRADE_RETCODE_DONE) return;
   gPend = gT.ResultOrder(); gPendUntil = exp; gPlaced++;
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
   double avgSp = (gSigN > 0) ? gSpreadAtSignal / gSigN : 0;
   if(fh != INVALID_HANDLE) FileClose(fh);
   PrintFormat("E-MT5-033 done mode=%s placed=%I64d filled=%d expired=%I64d "
               "fillRate=%.2f%% win=%d loss=%d winrate=%.2f%% PF=%.4f "
               "grossP=%.2f grossL=%.2f finalBalance=%.2f totalR=%.1f avgSpreadSignal=%.4f",
               (InpTakerMode ? "TAKER" : "MAKER"), gPlaced, gN, gExpired, fr,
               gWin, gLoss, wr, pf, gp, gl,
               AccountInfoDouble(ACCOUNT_BALANCE), sumR, avgSp);
  }
//+------------------------------------------------------------------+
