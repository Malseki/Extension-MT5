# SPEC-000 — Foundations

*The rules that the specification itself must obey. Nothing in SPEC-100 or
SPEC-200 may violate this document. If a trading concept cannot be expressed
within these constraints, the concept does not enter the engine.*

---

## 1. Purpose and standing

This document does not describe trading. It describes **what counts as a valid
definition** in this project, and fixes the substrate — time, data, units,
numerics, parameters — on which every trading concept is later defined.

It exists because the dominant failure mode of trading systems is not bad
strategy. It is that the strategy was never stated precisely enough to be wrong.
A system that cannot be wrong cannot be improved, and will silently decay for
years while appearing to work.

**Standing:** normative. Violations are defects regardless of profitability.

---

## 2. The Precision Doctrine, formalised

The brief states: *"Missing opportunities is preferable to generating
low-quality signals. Precision is more important than frequency."*

This is a preference in natural language. Here is its operational form.

### 2.1 Three-valued logic

Every predicate in this system returns a value in `{TRUE, FALSE, UNKNOWN}`.

`UNKNOWN` is returned when the predicate's inputs are unavailable, insufficient,
or degenerate — not enough history, a gap in the data, a division by a zero
range, a parameter not yet decided.

Conjunction follows Kleene's strong three-valued logic:

```
TRUE  ∧ UNKNOWN = UNKNOWN
FALSE ∧ UNKNOWN = FALSE          (a failed necessary condition is decisive)
UNKNOWN ∨ TRUE  = TRUE
UNKNOWN ∨ FALSE = UNKNOWN
```

### 2.2 The asymmetry rule (A-3)

A setup is emitted **only** if its validation predicate evaluates to `TRUE`.
`UNKNOWN` and `FALSE` both produce `NoOpportunity`, but they are **distinguished
in the output**: `NoOpportunity(reasons=[...])` where each reason names either a
failed predicate or an undecidable one.

**Rationale.** This makes the asymmetry structural rather than aspirational. A
system that treats missing information as permission to signal will,
statistically, signal most often exactly when the market is least legible.

### 2.3 Necessary conditions, not evidence accumulation

The validation predicate is a **conjunction of necessary conditions**. It is not
a weighted score compared against a cut-off.

**Rationale (A-5).** Two systems can produce identical signals while being
completely different engineering objects. A scoring system can only answer "the
score was 0.62". A conjunctive system answers "rejected: `pullback.depth` was
0.38, below `pullback.min_retracement` = 0.50". Only the second is auditable,
only the second can be debugged by a human trader, and only the second lets a
disagreement between engine and trader be resolved into a specific rule change.

**Consequence, stated honestly:** conjunctive gating cannot express "weak on this
dimension, exceptionally strong on that one, therefore acceptable". If the
methodology genuinely requires compensation between dimensions, A-5 must be
revisited — see `DEC-051`. It must not be worked around by quietly introducing
a score.

---

## 3. Admissibility criteria for a definition

A concept may enter SPEC-100 only if its definition satisfies **all** of A1–A7.
Each concept card in SPEC-100 is audited against this list.

| # | Criterion | Statement | Failure example |
|---|-----------|-----------|-----------------|
| **A1** | **Determinism** | Same inputs, same parameters ⇒ same output, on every platform, forever. No dependence on wall-clock, iteration order, floating-point mode, or platform library versions. | "Use the platform's ATR function." Different platforms smooth differently. |
| **A2** | **Causality** | The output at instant *t* depends only on data with timestamp ≤ *t*. | "The swing high" — not knowable until after the swing ends. |
| **A3** | **Bounded locality** | The definition declares a finite maximum lookback *L*, in bars of a named timeframe. Evaluating it never requires unbounded history. | "The last significant high" with no bound is unbounded state and unbounded memory. |
| **A4** | **Totality** | Defined for every syntactically valid input, including degenerate ones: zero-range bars, gaps, insufficient history, identical prices, first bar of the dataset. Degenerate cases return `UNKNOWN`, never crash and never silently return a default. | A retracement ratio when impulse height = 0. |
| **A5** | **Parameter explicitness** | Every constant appears as a named parameter with a written justification. Zero literals in the definition text. | "70.5%". |
| **A6** | **Scale and instrument invariance** | Thresholds are expressed in dimensionless units (ratios) or in volatility-normalised units. Absolute price units are permitted only where a named parameter is per-symbol. | "displacement ≥ 20 pips" — meaningless across EURUSD, XAUUSD, US30, BTCUSD. |
| **A7** | **Stated discontinuity** | Threshold predicates are discontinuous by nature. The definition must state where its knife-edges are and either (a) accept them with a documented sensitivity requirement, or (b) specify hysteresis. | A setup that flips between valid and invalid on a 1-tick data revision. |

**A7 in practice.** For every threshold parameter *p*, `VAL-001` requires a
sensitivity report: how does the detected-setup count change for *p* ± 10% and
*p* ± 25%? A parameter whose ±10% perturbation changes the setup count by more
than a stated tolerance is a **fragile parameter** and must be flagged as such
in the ParameterSet. Fragile parameters are the ones that will destroy the
system in three years, and we want their names written down now.

---

## 4. Time, and the distinction that most systems get wrong

### 4.1 Two timestamps, always

Every fact in this system carries two timestamps:

- **`t_occurred`** — the market instant the fact is about.
- **`t_known`** — the first instant at which the fact became **decidable** from
  data available at that instant.

`t_known ≥ t_occurred`, always. The difference is the fact's **confirmation
latency**.

**This is not bookkeeping. It is the core of the design.** Nearly every concept
in the methodology is defined retrospectively by a human looking at a finished
chart:

- A *swing high* is only a swing high once price has come down from it.
- A *sweep* is only a sweep once price has failed to hold above the level; while
  it is above, it is indistinguishable from a breakout.
- An *impulse leg* has no terminal point until the pullback has begun.
- The *high of the pullback* is unknown while the pullback is still forming.

A human reading a chart left-to-right has already seen the right side. An engine
has not. Systems that ignore this produce backtests that are not merely
optimistic — they are **describing a different strategy** than the one that runs
live.

### 4.2 A-1, the Causality Axiom

> No fact may be emitted at any instant earlier than its `t_known`. No predicate
> may read any datum whose timestamp exceeds the evaluation instant.

Mechanically testable by prefix invariance — see `VAL-001` §4.

### 4.3 A-2, the No-Repaint Axiom

> Emitted facts are immutable. A fact is never retracted, amended, or moved.

Anything provisional is not a fact. It is a **hypothesis**, and hypotheses are
first-class objects in the vocabulary (SPEC-300 §3) with their own lifecycle:
a hypothesis is `OPEN`, then becomes either a `CONFIRMED` fact or a `REFUTED`
record. Both outcomes are permanent.

**Worked example — the sweep.** The naïve model is one event, `LiquiditySwept`,
emitted when price exceeds a level and comes back. That model repaints: at the
moment of penetration you do not know which it is. The correct model is three
objects:

```
PenetrationObserved   fact        t_occurred = t_known = bar that pierced the level
SweepHypothesis       hypothesis  opened at penetration, resolves within W bars
SweepConfirmed        fact        t_occurred = penetration bar
                                  t_known    = the later bar that resolved it
PoolBroken            fact        the opposite resolution — level was breached, not swept
```

Nothing repaints. The engine's public output at penetration time is honest:
*a hypothesis is open; there is no opportunity yet.*

### 4.4 The evaluation clock

The engine is evaluated at a discrete, totally ordered set of **evaluation
instants**. Two admissible policies exist and they are not equivalent:

| | **E1 — Bar-close clock** | **E2 — Tick clock** |
|---|---|---|
| Instants | Closes of the base timeframe (M1) | Every tick |
| Determinism | High. M1 bars are stable historical objects. | Low. Tick histories differ between brokers, are revised, and are often unavailable historically. |
| Latency | Up to one base-timeframe period | Zero |
| Backtest fidelity | Exact | Depends on tick data quality |
| Recommended | ✅ Default | Only for a later "early-warning" layer, if ever |

**Recommendation:** E1 with base timeframe M1. This makes the engine a pure
function of M1 OHLC history, which is the most reproducible artefact available
across MT5, TradingView, Python and any future host. See `DEC-002`.

**Non-obvious consequence.** Under E1, "price touched the FVG" is not observable
directly — only "the M1 bar's low reached into the FVG" is. Intrabar path is
unknown. Every predicate that depends on the *order* of two events inside a
single bar is inadmissible under E1 (violates A1 determinism). SPEC-100 flags
these as **intrabar-order-dependent** and they must be redefined or dropped.
This is a real constraint and it eliminates several tempting confirmation
definitions — see `DEC-034`.

### 4.5 Higher timeframes are derived, never taken (A-6)

Platform H1/H4 bars are **not** a reliable object:

- H4 boundaries align to the broker's server midnight. Brokers differ (GMT+0,
  GMT+2, GMT+3...), so "the H4 high" differs between brokers on the same
  instrument on the same day.
- Broker server time observes DST, and the DST calendar differs between the
  broker's jurisdiction and the market's. On DST transition weekends, H4 bar
  boundaries shift by one hour, permanently changing which extremes exist.
- Weekend and holiday handling differs: some brokers emit a Sunday bar, others
  fold it into Monday.

Therefore: **all higher timeframes are aggregated by the engine from M1**, using
a declared session anchor and a declared timezone, both parameters of the
ParameterSet. The engine's H4 is *our* H4 and is identical everywhere.

Open: which anchor and timezone — `DEC-004`, `DEC-005`. This is a Tier A
decision because every liquidity level in the system depends on it.

### 4.6 Missing bars

MT5 (and most sources) **omit** M1 bars during which no tick occurred. This is
not a data error; it is the format. Consequences:

- "The last 20 bars" ≠ "the last 20 minutes". Any parameter expressed in bars
  silently changes meaning between London session and Asian session.
- Bar-count-based lookbacks (A3) are therefore **not** time-based lookbacks. Any
  definition sensitive to elapsed wall-clock time must say so explicitly and use
  a time-based window instead.

**Decision required:** `DEC-006` — gap-fill policy. Three options: (a) leave
gaps, count bars; (b) synthesise flat bars, count bars; (c) leave gaps, express
all windows in elapsed time. Option (b) corrupts volatility estimates. Option
(c) is the most correct and the most work.

### 4.7 Sessions, DST and the trading calendar

Required as explicit model objects, none of which the brief mentions and all of
which the methodology implicitly depends on:

- Session definitions (Asia / London / New York) with their timezone rules.
- The weekend boundary, and whether Sunday bars exist.
- Holiday calendars per instrument class.
- Whether setups may span a session boundary, a weekend, or a daily rollover.
  A pullback that "completes" across a weekend gap is not the same object as one
  that completes intraday. `DEC-007`.

---

## 5. Data model

### 5.1 The bar

```
Bar := {
  t_open      : Instant        -- opening instant, in engine time (UTC-anchored)
  timeframe   : Timeframe
  open, high, low, close : Price
  tick_volume : Integer        -- number of price updates, NOT traded volume
  real_volume : Integer | ⊥    -- present only on some instruments/brokers
}
```

Invariants (violations ⇒ data rejected, run aborted, never silently repaired):

```
I-1  low ≤ open ≤ high
I-2  low ≤ close ≤ high
I-3  low ≤ high
I-4  t_open is an exact multiple of the timeframe period from the session anchor
I-5  bars are strictly ordered and non-overlapping
I-6  all prices are exact multiples of the symbol's tick_size
```

**I-6 matters more than it looks.** Broker feeds occasionally emit prices off the
tick grid. If those enter, price equality tests become unreliable and level
comparisons drift.

### 5.2 Bid, ask, and the spread problem

MT5 OHLC history is **bid-side**. This is not a technicality for this
methodology — it directly changes what a liquidity sweep *is*.

Resting buy-stop orders above a high (the "buy-side liquidity" the methodology
targets) are triggered at the **ask**. The chart shows bid. Therefore stops
sitting at a level `p` (as seen on the bid chart) are triggered when
`ask ≥ p`, i.e. when `bid ≥ p − spread`.

**A sweep of buy-side liquidity can occur without the bid chart ever exceeding
the level.** Symmetrically, a bid-chart penetration of a low by less than the
spread may not have triggered any sell-stops at all.

Options:

- **S1** Ignore spread. Simple, reproducible, systematically wrong near the
  boundary — and the boundary is exactly where sweeps live.
- **S2** Model spread as a per-symbol, per-session constant parameter.
  Reproducible, approximately right, cheap. Fails during news.
- **S3** Use real historical spread. Requires tick data (`MqlTick` carries bid
  and ask; M1 bar history does not). Most correct, least available, hurts
  reproducibility and backtest range.

`DEC-008`. My recommendation is S2 with the constant chosen per symbol and per
session from measured data, plus a recorded note that S1 and S3 change results
in a measurable, reportable way. It is a Tier A decision: the penetration
threshold parameter is meaningless until it is settled.

### 5.3 Symbol metadata (required, per instrument)

```
tick_size, digits, contract/point convention, typical spread by session,
session calendar, instrument class (FX / metal / index / crypto / other),
quote currency, trading hours, whether 24/7
```

**Scope question, unanswered:** which instruments is this engine for? `DEC-009`.
It matters structurally, not cosmetically: a 24/7 instrument has no session
liquidity, no daily open, no overnight gap and no "intraday high" in the sense
the methodology uses. If crypto is in scope, several concepts need a second
definition.

---

## 6. Units and numerics

### 6.1 Forbidden unit: the pip

"Pip" is ambiguous across instrument classes and broker conventions. It is
banned from this specification. Permitted units:

- **ticks** — integer multiples of the symbol's `tick_size`. Exact, comparable,
  per-symbol.
- **ratios** — dimensionless. Preferred for all quality measures.
- **volatility units** — a price distance divided by a named volatility
  estimator. Preferred for all significance thresholds (A6).

### 6.2 The volatility estimator is a decision, not a given

Every "how big is big" threshold needs a denominator. That denominator is a
modelling choice with real consequences:

| Option | Definition | Property |
|---|---|---|
| **V1** ATR-Wilder(n) | Wilder-smoothed true range | Industry default; slow to adapt; asymmetric memory |
| **V2** ATR-SMA(n) | Simple mean of true range | Symmetric window, sharper A3 bound |
| **V3** Median TR(n) | Median of true range | Robust to single spikes — relevant, since news spikes are exactly what precedes sweeps |
| **V4** Realised σ(n) | Std-dev of log returns × √period | Statistically principled; ignores intrabar range |
| **V5** Rolling quantile | e.g. 80th pctile of TR | Directly interpretable as "unusually large" |

`DEC-010`: which estimator, on which timeframe, with which period, and — a
separate question — whether the *same* estimator is used for displacement,
gap-size and accumulation, or different ones. Using one estimator everywhere is
simpler and couples all thresholds together; using three decouples them and
triples the parameter surface.

**Recommendation:** V3 or V5 for significance tests (robustness to the spike
that causes the sweep), V2 for regime measures. Justify in the ParameterSet.

### 6.3 Comparison discipline

- No floating-point equality, ever. Prices are compared as integers in tick
  units, or with an explicit tolerance parameter in ticks.
- "Equal highs" means `|h₁ − h₂| ≤ ε` where ε is a named parameter (`DEC-011`).
  ε = 0 is a legitimate choice but must be a *choice*.
- Every inequality in SPEC-100 must state strict (`>`) or non-strict (`≥`).
  Ties are not rare in FX at round numbers — the exact place this methodology
  operates.
- Internal arithmetic: exact rational or integer-tick arithmetic where possible.
  Where irrational quantities appear (√0.5 for the 70.5%/70.7% level), the
  rounding rule and direction are specified, not left to the host language.

---

## 7. Parameter discipline (A-4)

### 7.1 The ParameterSet

All numeric and policy choices live in a single versioned document, external to
the specification prose. A run is identified by the triple:

```
(specification version, parameter-set version, data snapshot id)
```

Two runs with the same triple must produce byte-identical output. This is the
reproducibility contract.

### 7.2 Every parameter carries

```
name, type, unit, admissible range, default (or ⊥ if undecided),
justification (prose, mandatory),
provenance (measured / trader-stated / literature / arbitrary),
fragility (from the A7 sensitivity report),
decision reference (DEC-xxx)
```

**`provenance = arbitrary` is permitted but must be visible.** The purpose is not
to eliminate arbitrary choices — some are unavoidable — but to make sure nobody
in three years mistakes an arbitrary one for a validated one. This is the
single highest-value piece of documentation discipline in the project.

### 7.3 The magic-number audit

The brief contains exactly two numeric literals: **50%–70.5%** retracement and
the **M1–M5** execution timeframe.

`70.5%` is almost certainly a corruption of `√0.5 = 0.70710678…`, the geometric
mean of a 50% retracement, popularised as the "optimal trade entry" zone. If so,
the correct parameter is `√0.5` and the justification is geometric. If the
trader means literally 0.705, the parameter is arbitrary and must be marked as
such. **These are different numbers and they must not be conflated.** `DEC-030`.

No other literal may enter this specification without the same treatment.

---

## 8. Layered architecture of meaning

Not software architecture — a **dependency discipline for definitions**. Each
layer may reference only lower layers. This is what makes the corpus extensible
without rewriting (Order Blocks, later, enter at L2 and touch nothing else).

| Layer | Contains | Property |
|---|---|---|
| **L0 — Data** | Bars, symbol metadata, calendar | The only input. No interpretation. |
| **L1 — Geometry** | Pivot, leg, range, body/wick, overlap, gap, retracement ratio, volatility | Pure functions of L0. **Methodology-free and universal.** Any trading school would agree with these. |
| **L2 — Interpretation** | Liquidity pool, sweep, displacement, MSS, FVG, pullback, confirmation, accumulation, bias, context | Where the methodology lives. Every disagreement between traders lives here. |
| **L3 — Setup** | The setup aggregate and its state machine | Composition and lifecycle only. Contains no new market concepts. |
| **L4 — Verdict** | Buy / Sell / NoOpportunity, reasons, alerts, deduplication | Output contract. |

**Why the L1/L2 split earns its keep:** L1 is stable for decades and shareable
across any methodology. L2 is where the trader's opinion is, and is expected to
change. Every open decision in `DEC-001` is an L2 or L3 decision — **not one is
an L1 decision**. That is evidence the split is drawn in the right place.

**The dependency rule is directed and acyclic.** SPEC-100 flags one place where
the methodology as stated violates it — displacement defined via FVG presence
while FVG validity is defined via displacement. See `CRIT-001` §3.

---

## 9. Output contract

The engine emits, at every evaluation instant:

```
Verdict := BuyOpportunity(setup_ref)
         | SellOpportunity(setup_ref)
         | NoOpportunity(reasons : NonEmptySet<Reason>)

Reason  := PredicateFailed(predicate_id, observed, threshold)
         | PredicateUndecidable(predicate_id, cause)
         | NoCandidateSetup
```

Three properties, all deliberate:

1. **Totality.** There is a verdict at every instant. Silence is not an output.
2. **Explained negatives.** `NoOpportunity` always carries reasons. This is what
   makes trader/engine disagreement a debuggable event instead of an argument.
3. **The ternary is preserved** — but see `CRIT-001` §2: the methodology also
   speaks of *setup quality*, *preferred* retracements and *reduced* quality.
   Preference is an ordering; a ternary output has no ordering. That
   contradiction is unresolved and is `DEC-050`.

---

## 10. Reproducibility and versioning

- The specification is versioned. Every change is an ADR with rationale.
- Emitted facts carry the spec and parameter-set versions that produced them.
- Determinism is tested, not assumed (`VAL-001` §3).
- Historical results are never silently regenerated under a new version.

---

## 11. What this document does *not* fix, on purpose

- Any trading threshold (that is `DEC-001`).
- Any implementation choice: language, data structures, storage, concurrency.
- Any performance target. Correctness first; the brief is explicit.

---

### Appendix A — Terminology conventions used throughout the corpus

| Symbol | Meaning |
|---|---|
| `⊥` | undefined / absent |
| `t_occurred`, `t_known` | see §4.1 |
| `θ` | a threshold parameter (always named in full in the ParameterSet) |
| `ε` | a tolerance in ticks |
| `W` | a window, in bars of a named timeframe or in elapsed time |
| **MUST / MUST NOT** | normative |
| **SHOULD** | strong default, deviation requires an ADR |
| **UNDECIDED** | blocked on a `DEC-xxx` |
