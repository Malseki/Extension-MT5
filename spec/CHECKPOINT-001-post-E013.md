# CHECKPOINT-001 — Post E-MT5-013

*Freeze of V1 + the engineering decision report required before any further
economic run. §12 items A–K.*

---

# PART 1 — E-MT5-013 FROZEN

## ENGINEERING VALIDATION BACKTEST — V1
## NOT A PROFITABILITY CLAIM · NOT A STRATEGY VALIDATION

**Immutable. Not to be modified, re-run under changed parameters, or reinterpreted.**

| | |
|---|---|
| Symbol / timeframe | EURUSD / M5 |
| Model | 4 — every tick based on real ticks |
| Feed / account | MetaQuotes-Demo, 10012089985, USD, 1:100 |
| Range | 2026.07.06 → 2026.07.13 |
| Initial balance | $10,000.00 |
| Direction | **BUY only** — bearish mirror not implemented |
| Ticks / bars | 1,643,503 / 1,440 |
| Patterns detected | 67 |
| Signals | 61 |
| Entries | 28 |
| Closed trades | 27 |
| `ORDER_FAILED` retcode 10019 | 23 |
| `SKIPPED_INVALID_STOP` | 10 |
| `SKIPPED_POSITION_OPEN` | 6 |
| Final balance | $8,339.46 |
| Net balance change | **−$1,660.54 (−16.61%)** |
| Ledger discrepancy | +$23.70 |
| Total R | −18.289 |
| Event-log hash | `14820117959951301250` |

Raw evidence, SHA-256 sealed: `experiments/mt5/raw/2026-08-08T1134Z-E013-visual-v1/`

---

# PART 2 — DECISION REPORT

## A. What E-MT5-013 proved `[CONFIRMED]`

1. The **full causal chain executes**: historical ticks → pattern → signal →
   order → position → SL/TP → exit → account P&L.
2. **Visual mode works** for a trading EA; the run was observable live.
3. The **environment guard holds** — `ACCOUNT_TRADE_MODE=DEMO` logged, REAL
   refusal path present.
4. **`BLOCKED` stages were never silently satisfied** — CONFIRMATION, MSS, FVG,
   RETRACEMENT, HTF, SESSION stayed BLOCKED throughout while trades were placed
   from the pattern alone.
5. **R accounting is internally correct.** 3 wins at +2R and 24 losses at −1R
   predict −18.0R; measured −18.289R. The residual is stop slippage.

## B. What E-MT5-013 did **not** prove `[REFUTED / UNKNOWN]`

1. **Nothing about the strategy.** 8 of the methodology's stages are absent.
2. **Nothing about profitability.** The −$1,660.54 was produced on a censored,
   biased sample (C, and §H below).
3. **Nothing about SELL.** Half the pattern was never implemented.
4. **Nothing about real execution** — spread ≈ 0.031 points on this feed;
   `D-M4` remains **OPEN**.
5. **It did not even test the locked configuration** — see D and E.

## C. Exact source of the 23 margin failures `[OBSERVED]` — `E-MT5-014`

`retcode 10019 = TRADE_RETCODE_NO_MONEY`. Forensics over the identical
67-pattern population, against a **fixed $10,000** (optimistic — the live
balance was falling):

**Stop-distance distribution (points):**

| min | p10 | median | p90 | max |
|---:|---:|---:|---:|---:|
| **1.0** | 4.0 | 17.0 | 41.0 | 105.0 |

**Required lot and margin at 1% risk:**

| | min | median | p90 | max |
|---|---:|---:|---:|---:|
| lot | 0.95 | **5.88** | 24.99 | **99.99** |
| margin | $1,083 | **$12,180** | $77,652 | **$334,953** |

> **The median signal demands $12,180 of margin on a $10,000 account.**
> **41 of 67 (61.2%) are unfundable at 1% risk even with a full balance.**
>
> **Root cause is not the risk percentage — it is the stop rule.**
> `SL = L(2) − 1 point`, with entry at a bar open that can sit essentially on
> `L(2)`, produces stop distances down to **1.0 point**. A 1-point stop demands
> 99.99 lots and $334,953 of margin. **A 1-point stop on M5 EURUSD is not a
> stop; it is noise.** The sizing failure is a symptom of a structural defect in
> the locked stop definition.

## D. Exact source of the 10 invalid-stop skips `[OBSERVED]` — and it exposes a bug

Live: 10 signals rejected with `ask <= sl`. Forensics on the same population
finds **0** using the candle-4 open.

The two disagree because **the live run did not execute where the locked rule
says it should.** Verified against the ledger:

```
candle_3 11:15:00  ->  entry 11:25:00     (candle 5, not candle 4)
candle_3 14:50:00  ->  entry 15:00:00     (candle 5)
```

`ExecutePending()` is called on the *next* new-bar event after the one on which
the pattern was detected. Candle 3 closes at bar N; the pattern is detected while
bar N is opening; execution fires at bar N+1.

> **DEFECT 1 — one-bar execution delay.** The locked rule is "first tick of
> candle 4"; the implementation entered on candle 5. The extra bar gives price
> another 5 minutes to fall through `L(2)`, which is what produced the 10 invalid
> stops. **The V1 run did not test the locked entry rule.**

## E. The $23.70 discrepancy — cause, and a worse finding `[OBSERVED]`

**Cause:** 28 `ENTRY`, 27 `EXIT`. One position was still open when the test
ended; MT5 force-closed it. Its +$23.70 reached the balance but never entered my
ledger, because `ManagePosition()` never ran again.
Ledger −$1,684.24 + $23.70 = −$1,660.54 = account. **Fully reconciled.**

**Fix:** the `FORCED_TEST_END_EXIT` event and the reconciliation identity
required by §5.

**But the ledger is wrong in a second, more serious way:**

```
candle_3 08:10:00  ->  entry 06:45:00     entry BEFORE the pattern
candle_3 11:55:00  ->  entry 11:10:00     entry BEFORE the pattern
```

> **DEFECT 2 — broken provenance.** The trade row is written at *exit* time using
> the globals `pT1/pT2/pT3/pRef/pSweepLow`, which later patterns have already
> overwritten. **The `candle_1/2/3`, `reference_price`, `sweep_price` and
> `rejection_price` columns of V1 do not describe the pattern that created the
> trade.** They describe whichever pattern was most recent when it closed.
>
> This directly violates the requirement that a trade be causally traceable to
> its pattern. The V1 *money* figures stand; the V1 *attribution* columns must be
> treated as void.

**Fix:** snapshot the pattern into an immutable per-trade record at entry.

## F. BUY/SELL symmetry `[UNKNOWN]` — not testable yet

**The bearish mirror does not exist.** V1 is BUY-only, so no symmetry test could
run. The invariant suite required by §2 is specified but unimplemented:

- bullish/bearish geometry are mirror images under σ
- BUY unreachable from a bearish pattern, SELL from a bullish one
- BLOCKED stages cannot produce either verdict
- no BUY/SELL path outside the decision layer

## G. Sizing-policy comparison `[OBSERVED]` — coverage only, no selection

Same 67-pattern population, fixed $10,000 reference:

| Policy | Executable | Coverage | Risk taken |
|---|---:|---:|---|
| **A** — 1% capped by available margin | 67 / 67 | **100.0%** | **variable, ≤1%**, often far below |
| **B** — 0.25% fixed | 59 / 67 | 88.1% | constant 0.25% |
| **C** — 0.10% fixed | 65 / 67 | 97.0% | constant 0.10% |
| (V1 actual — 1% uncapped) | 26 / 67 | 38.8% | constant 1% |

**P&L was deliberately not computed for any policy.**

## H. Trade coverage — the bias that invalidates V1's economics

| | Population | V1 executed |
|---|---:|---:|
| median stop | 17.0 pts | — |
| mean stop | — | **44.2 pts** |
| min stop | 1.0 pts | **19.0 pts** |

> **V1 executed only wide-stop signals**, because narrow-stop signals demanded
> impossible margin. The executed set is not a sample of the signal population —
> it is the top ~39% by stop width, selected by a funding constraint that has
> nothing to do with the strategy. **The −$1,660.54 measures that censored
> subset, not the specified configuration.**

## I. Recommended policy — engineering grounds only

**Policy A (1% capped by available margin).**

Reasoning, and none of it is about returns:

1. It is the only policy with **100% signal coverage**, so the next run measures
   the *whole* population rather than a funding-selected subset. Coverage is the
   property under test right now.
2. It introduces **no new numeric parameter**. B and C would require choosing
   0.25% or 0.10% *after* seeing a losing result — precisely what §11 forbids.
3. Its cost is honest and measurable: realised risk becomes variable and ≤1%,
   and that variance can be logged per trade.

**Caveat I will not hide:** A makes R-multiples and dollars diverge, since a
capped trade risks less than 1%. Every trade must therefore log both planned and
realised risk. **This is a recommendation, not a decision. It is yours.**

**And A does not fix the real problem.** Capping volume makes 1-point stops
*fundable*; it does not make them *sensible*. The stop rule itself is the
defect (§C), and that is a strategy decision I will not take.

## J. Is the next visual backtest ready? — **NO** `[BLOCKED]`

Three defects must be fixed first:

| | Defect | Status |
|---|---|---|
| 1 | One-bar execution delay — V1 never tested the locked entry rule | **must fix** |
| 2 | Broken trade→pattern provenance | **must fix** |
| 3 | Bearish mirror absent + no symmetry invariants | **must implement** |

Plus the §5 ledger model (`FORCED_TEST_END_EXIT`, full reconciliation identity)
and whichever sizing policy you choose.

**Asking you to approve another economic run now would be asking you to approve
measuring the wrong thing again.**

## K. How to watch, once it is ready

MT5 is open. When the corrected build exists:

1. **View → Strategy Tester** (`⌘R`)
2. Expert `trader-experiments\E-MT5-015-...`, preset `ev_v2.set`
3. EURUSD, **M5**, **Every tick based on real ticks**, 2026.07.06 → 2026.07.13
4. Tick **Visual mode**, then **Start**

On the chart: blue **1 REF** line, orange **2 SWEEP**, green **3 REJECT**, cyan
entry arrow with lots and dollar risk, dotted red **SL** and green **TP**. Panel
shows `MODE=BACKTEST · ENVIRONMENT=DEMO · LIVE TRADING=DISABLED`, live balance,
equity, drawdown, and every unresolved stage as `BLOCKED`.

---

# PART 3 — WHAT I NEED FROM YOU

1. **Sizing policy** — A, B, or C. (Engineering recommendation: A.)
2. **The stop rule.** `SL = L(2) − 1pt` admits 1-point stops. Options include a
   minimum stop distance, a volatility floor, or a different anchor. **This is a
   strategy decision and I will not choose it.** Note that adding a minimum stop
   *changes which signals qualify*, so it is a change to the pattern definition,
   not only to risk.

Defects 1–3 and the ledger model I will fix without asking — they are
implementation errors against an already-locked specification, not new decisions.

**No parameter was optimised. No decision was silently resolved. V1 stands
frozen, losses included.**
