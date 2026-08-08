# CHECKPOINT-002 — Decision Lock: stop padding and time adjacency

*This document did not exist until 2026-08-08. `E-MT5-015-engine-v2` shipped an
invariant reading `"PAD X=5 locked by CHECKPOINT-002"` while no such document was
in the corpus, and `DEC-LOCK-001` §9 still recorded `SL = L(2) − 1 point`. That
gap is closed here.*

**Supersedes** the stop line of `DEC-LOCK-001` §9. Everything else in
`DEC-LOCK-001` §9 stands unchanged.

**Binding for the ENGINEERING VALIDATION BACKTEST only.** No value below is an
empirically validated trading rule and none may be presented as one.

---

# 1. Stop padding — LOCKED 2026-08-08

| | |
|---|---|
| Rule | `SL = L(2) − X points` for BUY, `SL = H(2) + X points` for SELL |
| **X** | **5** |
| Previous value | 1 (`DEC-LOCK-001` §9) |
| Enforced by | `SIZING_pad_locked` — the run is blocked at init if `InpStopPadPts != 5` |

**Origin.** `CHECKPOINT-001` §C measured the V1 stop-distance distribution and
found a minimum of 1.0 point: `SL = L(2) − 1pt` with an entry that can sit
essentially on `L(2)` produces stops that are noise, not stops, and demand
$334,953 of margin at 1% risk. §C named the stop rule — not the risk percentage
— as the structural defect, and Part 3 item 2 put the choice to the trader.

> **`[PENDING — one line needed from the trader]`** The corpus records that X
> moved from 1 to 5 and that the change answers `CHECKPOINT-001` Part 3 item 2.
> It does **not** record *why 5*. Under `A-4` a threshold without a written
> justification is a defect, not a value. This document is incomplete until that
> line exists, and `A-4` is formally violated until then.

---

# 2. Time adjacency — LOCKED 2026-08-08

## 2.1 The defect this closes

`DetectAt()` indexes the bar array and never compares timestamps. Index
adjacency is not time adjacency. `SW-6` ("strict adjacency 1→2→3") and the `A′`
look-back ("the 3 candles **immediately** preceding") are both stated in time,
and a market closure or a missing-tick minute (`MT5-CAP-001` F3) makes two
index-adjacent bars arbitrarily far apart in time.

Measured over `E-MT5-017`, EURUSD M5, Model=4, 2024.01.01 → 2026.08.08
(194,013 closed bars, 18,493 detections — the offline replica of `DetectAt`
agrees with the engine's 18,494 to within the range boundary):

| | |
|---:|---|
| 180 | bar-to-bar intervals ≠ 300 s (139 market closures, 41 intraday data gaps) |
| **77** | detections with a gap inside the `1→2→3→4` window |
| 19 | of those had the gap between candle 3 and 4 — the only ones `ENTRY_TIMING` could see |
| **58** | had the gap between candle 1 and 2 (47) or 2 and 3 (11), and were **accepted as valid patterns** |
| 12 | of those 58 reached the `hist1` ledger as real trades, net +$60.08 |

## 2.2 The rule

> **A window is admissible only if every consecutive pair in
> `candle 1 → candle 2 → candle 3 → candle 4` is separated by exactly
> `PeriodSeconds()`.**
>
> A window that fails this is **not a signal**. It is logged
> `SKIPPED_GAP_IN_WINDOW` and no order is attempted. Geometry is still counted
> in `signals` so the population stays comparable with `hist1`.

**Status of the alternatives, both refused on measured grounds:**

- *Enter on the first available bar.* Over the 19 entry-gap cases, 7 (37%) open
  **beyond the stop** — dead on arrival. Of the 12 that would still fill, the
  stop distance widens by a median of **5.4×** and a maximum of **57.4×**
  (2025-04-04: 13 points intended, 746 points realised). At 1% risk that is a
  57× smaller lot on an entry unrelated to the level the pattern identified.
- *Bounded tolerance.* Readmits at most **6 of the 77** at any threshold,
  because 69 of the 77 are market closures and no tolerance below 48 h reaches
  them. It buys almost nothing and costs a parameter that `A-4` would require
  justifying and `§11` forbids setting after seeing a result.

**Cost of the locked rule:** 77 of 18,493 signals, **0.416%**. No new parameter.

## 2.3 Scope, stated precisely

The lock covers the `1→2→3→4` window **only**.

> **`[OPEN — not decided]`** The `A′` look-back (`K`=3 candles "immediately
> preceding" candle 1) has the identical defect and is **not** covered. Measured
> marginal cost of extending contiguity to it: **18 further signals, 0.097%**
> (95 total, 0.514%, no overlap with the 77). The wording "immediately
> preceding" implies contiguity by the same reading that settled `SW-6`, so this
> is very likely an oversight rather than a distinction — but it changes the
> pattern definition, so it is the trader's to decide and is left untouched.

## 2.4 Enforcement

| Invariant | Asserts |
|---|---|
| `ADJ_contiguous_accepts` | a 300 s-spaced window is admitted |
| `ADJ_gap_c1c2_rejected` | a gap between candles 1 and 2 is refused |
| `ADJ_gap_c2c3_rejected` | a gap between candles 2 and 3 is refused |
| `ADJ_gap_c3c4_rejected` | a gap between candle 3 and the entry bar is refused |
| `ENTRY_TIMING_*` | retained as a **backstop**. It should now be unreachable; if it fires, the gap guard has been bypassed and the run is defective |

---

# 3. What this does not change

`hist1` (hash `12873688372365909079`) stays frozen exactly as recorded,
contaminated, in `raw/2026-08-08T1325Z-E015-hist1-2024-2026/`. It is not
re-interpreted and not deleted. It measured a build whose pattern predicate was
wrong in 77 of 18,493 cases.

Still BLOCKED and rendered as such: CONFIRMATION, MSS, FVG, RETRACEMENT,
HTF CONTEXT, SESSION, ACCUMULATION, DPMO.

Still open: `DEC-S-001`, `D-M4`, `DEC-044`, `DEC-029`, `DEC-036`, `DEC-030`,
`D-M1`, the `A′` look-back contiguity (§2.3), and the `X = 5` justification (§1).

Report label, mandatory and unchanged:
**ENGINEERING VALIDATION BACKTEST — NOT A PROFITABILITY CLAIM.**
