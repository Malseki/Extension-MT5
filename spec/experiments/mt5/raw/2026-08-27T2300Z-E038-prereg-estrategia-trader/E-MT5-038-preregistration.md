# E-MT5-038 — PRE-REGISTRATION: THE TRADER'S OWN SETUP, MEASURED

    STATUS   PRE-REGISTRATION. Sealed BEFORE writing the backtest EA and
             BEFORE running a single test.
    DATE     2026-08-27 23:00Z
    RULES    SPEC-STRAT-001, frozen the same day.

---

## 1. What is being tested

The trader's discretionary setup, stated by him and formalised in
SPEC-STRAT-001: liquidity sweep of an H1/H4 level with the trend, inside two
NY windows, confirmed by CHoCH on M1, an FVG in the traded direction, and MACD
histogram agreement. Stop beyond the sweep extreme, target at 1:2.

## 2. The evidence he provided, and why it cannot settle the question

12 trades, 10 winners, 2 losers, +20R, 83% hit rate.

[NOT ESTABLISHED] That 83% is the real rate. These are trades **selected and
reported from memory**, not a complete sample. Unknown: how many setups the
rules produced on those days, how many were taken and not recorded, whether
these are all of them or the ones that worked. Exact binomial CI for 10/12 runs
from 52% to 98%.

Break-even at 1:2 is 33.3%. If 83% were real it would be extraordinary — which
is exactly why it has to be measured on a sample nobody chose.

[OBSERVED] 4 of the 12 fall OUTSIDE the windows he specified (09:03, 09:20,
08:44, 09:11), all between 08:44 and 09:20. Frames extracted from his own
videos show trades at 03:01, 08:44 and 09:36 NY. Either the morning window
starts earlier than stated, or those timestamps are in another zone. The
backtest runs the stated rule and reports the discrepancy separately.

## 3. PREDICTION, RECORDED BEFORE MEASURING

The measured hit rate will be **substantially below 83%**, and most likely
below the 33.3% break-even.

Grounds, all from this project's own sealed work:
- E-MT5-022 refuted sweep+rejection at -7 sigma over 12 out-of-sample years.
- E-MT5-028 refuted round-number levels on virgin GBPUSD, -2.91 pp vs chance.
- E-MT5-034 measured trading WITH the move at 2.91 pp worse than against it.
- E-MT5-032: the spread at signal time is 0.838 pips against a 0.562 pip edge.
- Measured 2026-08-27: 22% of sweeps penetrate less than the spread itself.

[INFERRED] The gap between 83% and whatever the backtest returns is the size of
the selection effect in remembered trades. That number is worth having on its
own, whatever it turns out to be.

## 4. DECISION CRITERIA

| result | reading |
|---|---|
| hit rate >= 50%, n >= 100 | contradicts five sealed experiments; needs a fresh preregistration and virgin data before anyone believes it |
| 33-50%, n >= 100 | profitable at 1:2 before costs; recompute with the real spread at signal time before concluding anything |
| < 33%, n >= 100 | **not profitable at 1:2 — consistent with everything already measured** |
| n < 100 | no conclusion |

## 5. Costs are not optional

Every result is reported twice: gross, and net of 0.838 pips per entry
(E-MT5-032, the spread at the instant of a movement-triggered signal). Reporting
only the gross number is the mistake that made an earlier backtest in this
project look profitable when it was not.

## 6. What would invalidate this

- Tuning any threshold in SPEC-STRAT-001 after seeing results.
- Reporting the gross figure alone.
- Comparing against the 12 remembered trades as if they were a baseline.
- Treating a window that was widened after the fact as the original rule.

## 7. Honest note

The trader asked for this to be made to work. The honest service is to measure
it exactly as he described it and report what comes out — including, if it
comes to that, that his remembered 83% does not survive contact with a sample
he did not choose.
