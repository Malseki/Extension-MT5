//+------------------------------------------------------------------+
//| E-MT5-030 — IMPULSE CONTINUATION OBSERVER                         |
//|                                                                  |
//| PURE OBSERVER. No orders, no account, no costs.                   |
//|                                                                  |
//| Question, in two parts, both asked by the trader:                  |
//|   (1) when price moves X pips in Y minutes, does it CONTINUE?     |
//|   (2) HOW FAR and HOW LONG does that move typically run?          |
//|                                                                  |
//| Design: on impulse detection, run a SYMMETRIC race of +/- D pips  |
//| from the trigger price, in the direction of the impulse.          |
//| Structural null = 50%: on a driftless walk a symmetric race is a  |
//| coin flip. Anything above 50% is continuation, below is reversal. |
//|                                                                  |
//| Also records MFE (max favourable excursion), MAE (max adverse)    |
//| and the time to each, which is what answers "hasta cuando".       |
//|                                                                  |
//| EXPLORATORY on EURUSD (contaminated). Cannot confirm anything.    |
//| Its purpose is to decide whether the question deserves a          |
//| preregistered test on virgin data.                                |
//+------------------------------------------------------------------+
#property copyright "PROJECT TRADER"
#property version   "1.00"
#property strict

input double InpImpPips  = 5.0;    // impulse size
input int    InpImpBars  = 1;      // over this many M5 bars
input double InpRacePips = 10.0;   // symmetric race, both sides
input int    InpHorizonS = 86400;  // race timeout
input int    InpCoolS    = 300;    // no re-trigger inside this window
input string InpRunTag   = "e30";

int    gPip = 1;
double gD, gImp;
int    fh = INVALID_HANDLE;

bool     gActive = false;
int      gDir = 0;
double   gRef = 0, gMFE = 0, gMAE = 0, gTrigMove = 0;
datetime gT0 = 0, gLastTrig = 0, gTmfe = 0;

long gCont = 0, gRev = 0, gTimeout = 0;

//+------------------------------------------------------------------+
int OnInit()
  {
   gPip = (_Digits == 3 || _Digits == 5) ? 10 : 1;
   gD   = InpRacePips * gPip * _Point;
   gImp = InpImpPips  * gPip * _Point;

   fh = FileOpen("E-MT5-030-" + InpRunTag + "-impulse.csv",
                 FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON, ',');
   if(fh == INVALID_HANDLE) return(INIT_FAILED);
   FileWrite(fh, "t_trigger", "dir", "impulse_pips", "outcome",
             "mfe_pips", "mae_pips", "secs_to_mfe", "secs_total");
   PrintFormat("E-MT5-030 start impulse=%.1fp/%dbars race=+-%.1fp",
               InpImpPips, InpImpBars, InpRacePips);
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
void Close(const int outcome, const datetime tnow)
  {
   FileWrite(fh, TimeToString(gT0, TIME_DATE | TIME_SECONDS),
             (gDir > 0 ? "UP" : "DOWN"), DoubleToString(gTrigMove, 1),
             (string)outcome,                       // 1 cont, 2 rev, 3 timeout
             DoubleToString(gMFE, 1), DoubleToString(gMAE, 1),
             (string)(int)(gTmfe - gT0), (string)(int)(tnow - gT0));
   if(outcome == 1) gCont++; else if(outcome == 2) gRev++; else gTimeout++;
   gActive = false;
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   MqlTick t; if(!SymbolInfoTick(_Symbol, t)) return;
   double b = t.bid;

   // ---- resolve an active race -------------------------------------
   if(gActive)
     {
      double fav = gDir * (b - gRef) / (gPip * _Point);   // + favourable
      if(fav > gMFE) { gMFE = fav; gTmfe = TimeCurrent(); }
      if(fav < gMAE) gMAE = fav;

      if(gDir * (b - gRef) >= gD)       Close(1, TimeCurrent());   // continued
      else if(gDir * (b - gRef) <= -gD) Close(2, TimeCurrent());   // reversed
      else if(TimeCurrent() - gT0 > InpHorizonS) Close(3, TimeCurrent());
      return;                                    // one race at a time
     }

   // ---- detect a new impulse ---------------------------------------
   if(TimeCurrent() - gLastTrig < InpCoolS) return;
   double mv = MovePips(InpImpBars);
   if(MathAbs(mv) < InpImpPips) return;

   gDir = (mv > 0) ? +1 : -1;
   gRef = b; gT0 = TimeCurrent(); gTmfe = gT0;
   gMFE = 0; gMAE = 0; gTrigMove = mv;
   gActive = true; gLastTrig = gT0;
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   long n = gCont + gRev;
   double p = (n > 0) ? 100.0 * gCont / n : 0;
   if(fh != INVALID_HANDLE) FileClose(fh);
   PrintFormat("E-MT5-030 done impulse=%.1f race=%.1f races=%I64d cont=%I64d rev=%I64d "
               "timeout=%I64d P(continua)=%.2f%% (nulo 50%%)",
               InpImpPips, InpRacePips, n + gTimeout, gCont, gRev, gTimeout, p);
  }
//+------------------------------------------------------------------+
