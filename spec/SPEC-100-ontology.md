# SPEC-100 — Concept Ontology

*Every concept present in the methodology, and every concept the methodology
requires but does not mention. One card each.*

**Card format.** Definition · Purpose · Inputs · Outputs · Dependencies ·
Assumptions · Ambiguities · Objective interpretations · Edge cases ·
Mathematical models · Admissibility (A1–A7) · Status.

**Status values.** `SETTLED` — fully definable now, no trader input needed.
`PARAMETRIC` — structure settled, thresholds open. `BLOCKED` — cannot be defined
at all until a decision is taken. `UNDEFINED-BY-BRIEF` — the brief names it but
gives no content whatsoever.

**Reading shortcut.** L1 cards (§2) are structural and dull by design; skim them.
The project's real content is §3, and the three cards that matter most are
**CN-14 Displacement**, **CN-18 Pullback anchoring**, and **CN-20 Confirmation**.

---

## 1. Inventory

| Layer | ID | Concept | Status |
|---|---|---|---|
| L1 | CN-01 | Bar geometry (body, range, wick) | SETTLED |
| L1 | CN-02 | Timeframe & aggregation | SETTLED |
| L1 | CN-03 | Pivot (swing point) | PARAMETRIC |
| L1 | CN-04 | Leg | PARAMETRIC |
| L1 | CN-05 | Retracement ratio | SETTLED |
| L1 | CN-06 | Three-bar imbalance (raw gap) | SETTLED |
| L1 | CN-07 | Volatility estimator | PARAMETRIC |
| L1 | CN-08 | Bar overlap | SETTLED |
| L1 | CN-09 | Directional efficiency | SETTLED |
| L1 | CN-10 | Level cluster (equality with tolerance) | PARAMETRIC |
| L2 | CN-11 | Liquidity pool | PARAMETRIC |
| L2 | CN-12 | Significance of a pool | BLOCKED |
| L2 | CN-13 | Liquidity sweep | PARAMETRIC |
| L2 | CN-14 | Displacement / impulse | BLOCKED |
| L2 | CN-15 | Structural reference level | BLOCKED |
| L2 | CN-16 | Market Structure Shift | PARAMETRIC |
| L2 | CN-17 | Fair Value Gap (qualified) | PARAMETRIC |
| L2 | CN-18 | Pullback & impulse anchoring | BLOCKED |
| L2 | CN-19 | Pullback multiplicity & quality | BLOCKED |
| L2 | CN-20 | Reaction & Confirmation | UNDEFINED-BY-BRIEF |
| L2 | CN-21 | Accumulation / range regime | BLOCKED |
| L2 | CN-22 | Directional bias | PARAMETRIC |
| L2 | CN-23 | Higher-timeframe context | PARAMETRIC |
| L2 | CN-24 | Draw on liquidity (target) | PARAMETRIC |
| L2 | CN-25 | DPMO | **BLOCKED — undefined term** |
| L3 | CN-26 | Setup aggregate | see SPEC-200 |
| L3 | CN-27 | Invalidation & expiry | BLOCKED |
| L3 | CN-28 | Deduplication & competing setups | BLOCKED |
| L4 | CN-29 | Verdict & alert | PARAMETRIC |

29 concepts. The brief explicitly names 11. **Eighteen are load-bearing concepts
the methodology depends on but never mentions** — that gap is the main finding of
this phase.

---

## 2. Layer 1 — Geometry (methodology-free)

These are pure functions of price. No trading school would dispute them. They are
the vocabulary in which L2 is written, and they are expected never to change.

### CN-01 · Bar geometry

**Definition.** For a bar *b*:

```
range(b)      = high(b) − low(b)                                  ≥ 0
body(b)       = |close(b) − open(b)|                              ≥ 0
direction(b)  = +1 if close>open ; −1 if close<open ; 0 if equal
upper_wick(b) = high(b) − max(open(b), close(b))                  ≥ 0
lower_wick(b) = min(open(b), close(b)) − low(b)                   ≥ 0
body_ratio(b) = body(b) / range(b)          if range(b) > 0 else UNKNOWN
wick_ratio(b) = 1 − body_ratio(b)
```

**Purpose.** Substrate for displacement, accumulation and confirmation measures.

**Edge cases.** `range = 0` (a true doji on an illiquid minute) ⇒ ratios are
`UNKNOWN`, per A4. This is not rare on M1 outside session hours; any measure
averaging `body_ratio` over a window must define how `UNKNOWN` elements are
handled — excluded from the mean, or poisoning it. **`DEC-012`.** Excluding them
biases the measure toward liquid periods; poisoning makes the measure unavailable
in exactly the quiet conditions the accumulation filter is meant to detect.

**Admissibility.** A1–A7 ✅. **Status:** SETTLED.

---

### CN-02 · Timeframe & aggregation

**Definition.** A timeframe is a period *P* plus an anchor *α*. Bar *k* of
timeframe *P* covers `[α + kP, α + (k+1)P)`. Aggregation from M1:

```
open  = open of first M1 bar in window
close = close of last  M1 bar in window
high  = max high ; low = min low
tick_volume = Σ
```

An aggregated bar exists iff ≥ 1 M1 bar exists in its window (A-6, SPEC-000 §4.5).

**Ambiguity.** A partially-formed HTF bar. At any M1 close inside an H4 window,
an H4 "bar" exists but is incomplete. **Rule (normative):** an HTF bar becomes
readable only at `t_known` = its close. Reading a forming HTF bar's high is the
single most common look-ahead bug in MT5 systems and is forbidden by A-1.

**Consequence, uncomfortable and worth stating:** the methodology says liquidity
is taken from *H1/H4 highs and lows*. Under this rule, the current H4 bar's high
is invisible until the H4 closes — up to 4 hours of blindness. That is almost
certainly not what the trader means. The resolution is that a *pool* is not
"the H4 bar's high"; it is a **pivot** derived from *closed* H4 bars (CN-03,
CN-11). The running high of the forming bar is not a liquidity pool; it is just
the current price extreme. This distinction must be confirmed — **`DEC-013`**.

**Status:** SETTLED (mechanics), with `DEC-004`/`DEC-005` on anchor/timezone.

---

### CN-03 · Pivot (swing point)

**Definition (fixed-width).** Bar *i* is a pivot high of width (k, m) iff

```
high[i] ≥ high[j]  for all j ∈ [i−k, i−1]      (left condition)
high[i] >  high[j]  for all j ∈ [i+1, i+m]      (right condition)
```

`t_occurred = t(i)`, `t_known = t(i+m)`. **Confirmation latency = m bars.**

Pivot low symmetric.

**Purpose.** The only causal way to speak about "a high" without hindsight.

**Ambiguities.**

1. **Strict vs non-strict, and asymmetry.** The formulation above is non-strict
   left, strict right, which makes the *first* of a set of equal highs the pivot.
   The reverse choice makes the *last* one the pivot. With three equal highs, the
   choices differ by two bars and by which level is later "swept". Equal highs are
   not an exotic case here — they are the methodology's central liquidity
   signature. **`DEC-014`.**
2. **k = m?** Asymmetric widths (more left than right) reduce latency at the cost
   of more pivots.
3. **Width per timeframe?** A pivot width of 2 on H4 spans 16 hours; on M1 it
   spans 2 minutes. Almost certainly needs to be per-timeframe. **`DEC-015`.**

**Alternative models.**

| | Model | Latency | Scale-aware | Determinism |
|---|---|---|---|---|
| P1 | Fixed (k,m) fractal | Fixed, = m | ✗ | ✅ |
| P2 | ATR-threshold zigzag: a swing confirms when retracement ≥ θ·ATR | Variable, unbounded | ✅ | ✅ but violates A3 unless capped |
| P3 | Fixed (k,m) **plus** a separate significance predicate | Fixed | ✅ | ✅ |

**Recommendation: P3.** Separate *pivot-ness* (pure geometry, L1, fixed latency,
bounded memory) from *significance* (economic judgement, L2, CN-12). P2 conflates
them, and its unbounded latency violates A3 — under P2 you cannot state a maximum
lookback, so you cannot bound memory and cannot bound how far back a live engine
must reprocess after a data revision.

**Edge cases.** Fewer than k bars of history ⇒ `UNKNOWN`. Gaps (SPEC-000 §4.6)
mean the k neighbours may span hours. Two adjacent bars with identical highs
under a strict rule ⇒ *no* pivot exists, which can silently erase a level.

**Status:** PARAMETRIC (structure fixed; `DEC-014`, `DEC-015`).

---

### CN-04 · Leg

**Definition.** A directed price excursion between two pivots of opposite type:
`Leg = (A, B)` with `A` a pivot low and `B` a pivot high (bullish leg) or vice
versa. `height = |price(B) − price(A)|`, `duration = bars(A→B)`.

**Critical ambiguity.** The terminal pivot `B` has `t_known` *after* the leg is
over. **A leg is therefore never a causally-available object while it is
forming.** Anything defined in terms of "the impulse leg" inherits this and must
either accept the latency or use a **running** definition (running extreme since
`A`), which is causal but changes value over time and so is a *hypothesis*, not a
fact (SPEC-000 §4.3).

This is the root of CN-18 and the single most consequential ambiguity in the
methodology.

**Status:** PARAMETRIC. Blocked jointly with CN-18.

---

### CN-05 · Retracement ratio

**Definition.** For a bullish leg `A→B` and a price `p`:

```
r(p) = (price(B) − p) / (price(B) − price(A))     if price(B) ≠ price(A)
     = UNKNOWN                                    otherwise
```

`r = 0` at the leg high, `1` at the leg origin, `> 1` beyond the origin
(structural failure), `< 0` at new extremes.

**Edge cases.** Zero-height leg ⇒ `UNKNOWN` (A4). Retracements > 1 must be
handled explicitly, not clamped: `r > 1` for a bullish setup means price traded
below the sweep low, which is an *invalidation* signal, not a deep pullback.
Clamping would erase that. **Normative: never clamp `r`.**

**Which price?** `r` of a bar's low, its close, or its body? Different answers.
See `DEC-031`.

**Status:** SETTLED (given an anchoring decision).

---

### CN-06 · Three-bar imbalance (raw gap)

**Definition.** For consecutive bars `(b₁, b₂, b₃)` on a given timeframe:

```
bullish imbalance ⟺ low(b₃) > high(b₁),  interval G = (high(b₁), low(b₃))
bearish imbalance ⟺ high(b₃) < low(b₁),  interval G = (high(b₃), low(b₁))
size(G) = |G|
```

**This is L1: pure geometry, no interpretation.** The trading concept "Fair Value
Gap" is CN-17 and is a *qualified* imbalance — L2.

**Notes.** Variants exist (body-based "volume imbalance", 2-bar gaps, opening
gaps). They are different objects; only the 3-bar high/low form is specified here
unless `DEC-024` says otherwise.

**Status:** SETTLED.

---

### CN-07 · Volatility estimator

Specified in SPEC-000 §6.2. Open: `DEC-010`. **Status:** PARAMETRIC.

---

### CN-08 · Bar overlap

**Definition.** For bars *a*, *b*:

```
overlap(a,b) = max(0, min(high_a,high_b) − max(low_a,low_b))
union(a,b)   = max(high_a,high_b) − min(low_a,low_b)
overlap_ratio(a,b) = overlap / union      (UNKNOWN if union = 0)
```

**Purpose.** Objectifies "overlapping candles" from the accumulation description
(CN-21). Range-bound price has `overlap_ratio → 1`; trending price → 0.

**Status:** SETTLED.

---

### CN-09 · Directional efficiency

**Definition.** Over a window of *n* bars:

```
ER(n) = |close[i] − close[i−n]| / Σ_{j=i−n+1}^{i} |close[j] − close[j−1]|
```

Range `[0, 1]`. Dimensionless (A6 ✅), scale-free, instrument-free.

**Purpose.** The single most useful primitive in this corpus. It objectifies
*both* "clean displacement" (CN-14, high ER) *and* "no clean impulse /
sideways" (CN-21, low ER) with one measure and one denominator, which means the
two concepts cannot be tuned into mutual contradiction.

**Edge cases.** Zero denominator (all closes identical) ⇒ `UNKNOWN`. Small *n*
makes ER noisy and near-1 by construction; `n ≥ 3` at minimum.

**Variants.** Close-to-close (above), or high/low path-based
`|net| / Σ range(b)` which accounts for intrabar travel and is stricter — it
penalises wicks, which is exactly what the accumulation description asks for.
**`DEC-016`:** which variant, and whether the same one serves both uses.

**Status:** SETTLED (structure), PARAMETRIC (window).

---

### CN-10 · Level cluster

**Definition.** Given pivot levels `p₁…pₙ` and tolerance ε, a cluster is a
maximal set whose pairwise distance is ≤ ε; its level is a representative
(min / max / mean / first — **`DEC-017`**, and they differ: for buy-side pools,
the *max* is conservative and the *min* triggers earliest).

**Purpose.** "Equal highs" — engineered liquidity. Two or more highs at the same
level concentrate resting stops, which is the entire economic rationale for the
methodology's first step.

**Ambiguities.** ε in ticks or in volatility units? Volatility units are A6-clean
but make cluster membership time-varying — a cluster can dissolve as volatility
falls, which would retract a fact and violate A-2. **Normative: ε must be frozen
at cluster-formation time**, whatever unit is chosen.

**Status:** PARAMETRIC (`DEC-011`, `DEC-017`).

---

## 3. Layer 2 — Interpretation (where the methodology lives)

### CN-11 · Liquidity pool

**Definition.** An entity, not an event:

```
LiquidityPool := {
  id, side       : BUY_SIDE (above highs) | SELL_SIDE (below lows)
  level          : Price
  source_tf      : Timeframe          -- H1 or H4 per the brief
  constituents   : [pivot refs]       -- ≥ 1
  t_formed       : Instant            -- = t_known of the last constituent pivot
  status         : RESTING | SWEPT | BROKEN | EXPIRED
}
```

**Purpose.** The origin of nearly every setup. Encodes where resting stop orders
are presumed to sit.

**Inputs.** Confirmed pivots (CN-03) on the source timeframe; cluster tolerance
(CN-10); significance predicate (CN-12).
**Outputs.** `PoolFormed`; later `SweepConfirmed` / `PoolBroken` / `PoolExpired`.
**Dependencies.** CN-02, CN-03, CN-10, CN-12.

**Assumptions — stated because they are assumptions, not facts.**

1. Stop orders cluster beyond prior extremes. Plausible, widely believed,
   **never verified on this trader's instruments**. The engine cannot see order
   flow; it infers from price geometry.
2. A pool's economic relevance decays with age. Implied by the methodology's
   focus on recent H1/H4 levels, never stated.
3. Untouched levels retain liquidity; touched ones do not. This is why `status`
   exists.

**Ambiguities.**

- **Naming trap, resolved:** sweeping *highs* consumes *buy-side* liquidity and
  produces a *bearish* bias. The brief's "sweep highs → bearish preference" is
  consistent with this. Recorded so nobody inverts it later.
- **Pool death.** When does a `RESTING` pool cease to exist? Options: on sweep;
  on decisive break (`BROKEN`); after age > θ; after N touches; never.
  **`DEC-018`.** Without this the pool set grows monotonically and both memory
  (A3) and signal count are unbounded.
- **Multi-timeframe duplicates.** The same price is often an H1 pivot *and* an
  H4 pivot. One pool or two? If two, a single sweep fires two setups (CN-28).
  **`DEC-019`.**

**Edge cases.** A pool formed inside a gap; a pool at a level price never returns
to; a pool whose constituent pivot is later contained in a larger pivot; the very
first pool in a dataset (no history to establish significance).

**Status:** PARAMETRIC, blocked on CN-12.

---

### CN-12 · Significance of a pool · **BLOCKED**

**The brief says:** *"significant H1 and H4 highs/lows"*.

**Why this is subjective and cannot be guessed.** "Significant" carries no
operational content. It could mean any of the following, and these select
**different, largely non-overlapping** sets of levels:

| | Candidate definition | Character |
|---|---|---|
| **G1** | Pivot of width (k,m) on H1/H4 | Purely local geometry |
| **G2** | Untouched for ≥ N bars / ≥ T elapsed time | Age / maturity |
| **G3** | An equal-highs cluster of ≥ 2 touches (CN-10) | Engineered liquidity |
| **G4** | Session / daily / weekly extreme | Calendar salience |
| **G5** | Origin of a leg whose height ≥ θ·ATR | Consequence-based |
| **G6** | Extreme preceding a displacement (CN-14) | Reflexive with displacement |
| **G7** | Round-number proximity | Psychological |

G1 alone will produce dozens of pools per day per instrument — far too many for
a precision-first engine. G3 and G4 alone will produce a handful.

**The deeper question, which must be answered first (`DEC-020`):** is
significance a **conjunction** (all selected criteria must hold — few, high-grade
pools) or a **disjunction** (any one suffices — many pools)? Under A-5 a weighted
score is not available, so this must be an explicit boolean structure.

**Do not proceed on this concept until answered.** My recommendation *as a
starting hypothesis to be tested against the labelled corpus, not as a decision*:
`G1 ∧ (G3 ∨ G4)` — geometrically valid, and either engineered or calendar-salient.

**Blocking:** CN-11, CN-13, and therefore the entire pipeline. **Tier A.**

---

### CN-13 · Liquidity sweep

**Definition (structure, settled).** Three objects, per SPEC-000 §4.3, because
the sweep is not decidable at the moment it happens:

```
PenetrationObserved(pool, bar_i)
  BUY_SIDE:  high[i] > level + δ_pen
  SELL_SIDE: low[i]  < level − δ_pen

SweepConfirmed(pool, t_occurred = bar of extreme, t_known = resolving bar)
  ∃ j ∈ (i, i+W] : close[j] < level − δ_ret          (buy-side case)
  ∧ ¬∃ k ∈ (i, j) : "acceptance above level"

PoolBroken(pool)
  acceptance above the level occurs first, or the window W expires unresolved
```

**Purpose.** The trigger event. Establishes bias and starts the setup lifecycle.

**Inputs.** Pool; bars of the resolution timeframe; `δ_pen`, `δ_ret`, `W`,
acceptance rule.
**Outputs.** The three facts above; a directional bias (CN-22).
**Dependencies.** CN-11, CN-12, CN-02.

**Assumptions.** That penetration-then-rejection indicates stop-hunting followed
by opposing institutional interest, rather than a failed breakout with no
particular meaning. This is the methodology's core belief. **It is not verifiable
by the engine.** It is testable statistically against the corpus, and it should
be — see `VAL-001` §6.

**Ambiguities, each of which changes the detected set materially.**

1. **Penetration threshold `δ_pen`.** Zero admits one-tick noise as a sweep.
   Non-zero requires a unit (ticks / volatility / spread multiples). Interacts
   directly with the spread problem (SPEC-000 §5.2): on a bid-quoted feed, buy
   stops are hit *before* the bid reaches the level, so the economically correct
   test for buy-side is arguably `high_bid + spread > level`, i.e. a *negative*
   effective δ. **`DEC-021`** — Tier A.
2. **Resolution timeframe.** Is the sweep judged on the pool's own timeframe (H4
   close back below) or on the execution timeframe (M1/M5)? These differ by hours
   of latency and by a large factor in signal count. The brief never says.
   **`DEC-022`** — Tier A.
3. **Same-bar vs windowed.** Must rejection occur on the penetrating bar, or
   within `W` bars? Same-bar is strict and low-latency; windowed is permissive
   and lets the sweep extreme drift. **`DEC-023`.**
4. **"Acceptance".** What breaks a pool rather than sweeping it? Candidates: one
   close beyond; N consecutive closes beyond; a close beyond by ≥ θ·ATR; time
   spent beyond. Undefined in the brief. Part of `DEC-023`.
5. **Which extreme is "the sweep low"?** The lowest low within the penetration
   window — but under a windowed rule, that value is only final at resolution.
   Consequence: the anchor for everything downstream (CN-18) is not known until
   the sweep resolves. Correct, but must be explicit.

**Edge cases.**
- Penetration and rejection inside one M1 bar: unobservable under E1 (intrabar
  order unknown). The bar shows a wick through the level and a close back inside
  — this *is* the classic sweep bar, and it is the case where E1's blindness
  costs the least, since order doesn't matter.
- Multiple pools swept by one bar (a cascade through clustered levels). Which is
  "the" sweep? **`DEC-028`** (relates to CN-28).
- A sweep during a weekend/holiday gap: price opens beyond the level with no
  penetration bar at all. Structurally different; needs its own rule.
- Sweep of a buy-side and a sell-side pool within a few bars ("double-sided
  raid"). Bias is contradictory. **`DEC-027`**.

**Mathematical models.** Beyond thresholds: a sweep is a first-passage event
followed by a reversal within a window — formally, a two-sided barrier problem.
If the corpus is ever large enough, `P(reversal | penetration depth, time above,
volatility regime)` is directly estimable, which would replace `δ_pen` with a
measured quantity instead of a chosen one. Note as a future path, not now.

**Status:** PARAMETRIC. Structure is settled and good; four Tier-A thresholds open.

---

### CN-14 · Displacement / impulse · **BLOCKED**

**The brief says:** *"an impulsive move"*, *"clean displacement"*, *"strong
directional movement"*, *"clearly stronger than its pullback"*, *"weak impulses
must be rejected"*.

**Why this is subjective.** Four different adjectives ("impulsive", "clean",
"strong", "stronger than its pullback") that are not synonyms and are not
jointly satisfiable by a single measure. A move can be large but choppy (strong,
not clean); small but perfectly efficient (clean, not strong); fast but retraced
(impulsive, then weak). **Before choosing a threshold we must choose what the
word means.**

**Candidate models — these are genuinely different, not variations.**

| | Model | Formula | Captures | Fails to capture |
|---|---|---|---|---|
| **D1** | Magnitude | `height ≥ θ · ATR(n)` | "strong" | duration — a 30-bar drift passes |
| **D2** | Efficiency | `ER(n) ≥ θ` (CN-09) | "clean" | size — a tiny clean move passes |
| **D3** | Body dominance | `Σbody / Σrange ≥ θ` over the leg | "not wicky" | direction consistency |
| **D4** | Structural | an imbalance (CN-06) exists inside the leg | the SMC-native meaning | is **circular** — see below |
| **D5** | Velocity / z-score | `height / (σ·√duration) ≥ θ` | "impulsive" = fast for its size | wick structure |
| **D6** | Run length | ≥ N consecutive same-direction closes | simple, intuitive | scale-blind |
| **D7** | Relative to pullback | `height_impulse / height_prior_pullback ≥ θ` | the brief's own phrase | needs the pullback defined first |

**The circularity (see `CRIT-001` §3).** The brief says a valid displacement
must be followed by an FVG, *and* SMC practice defines displacement *by* the
presence of an FVG. If both are adopted, the FVG condition is not an independent
filter — it is a restatement of the displacement condition, and the engine has
one fewer constraint than it appears to have. This must be resolved explicitly:
either FVG-presence **is** the displacement definition (D4, and then "there must
be an FVG" is redundant), or displacement is defined independently (D1/D2/D5) and
the FVG requirement genuinely adds information. **`DEC-025`** — Tier A.

**Recommendation as a hypothesis:** `D5 ∧ D2` — fast for its duration, and
efficient — with D1 as a floor to exclude micro-moves. D5 is the only candidate
that captures "impulsive" in the physical sense (rate, not just distance), and
duration-blindness is D1's fatal flaw.

**Inputs.** Leg (CN-04); volatility (CN-07); efficiency (CN-09).
**Outputs.** `DisplacementQualified` fact, or its absence.
**Edge cases.** A leg of one bar (ER undefined for n<2 — needs a rule); a leg
spanning a session gap (the gap inflates magnitude and efficiency alike, and is
not tradable displacement); displacement on the *wrong* side of the sweep.

**Status:** BLOCKED on `DEC-025`, `DEC-026`. **Tier A.**

---

### CN-15 · Structural reference level · **BLOCKED**

**The brief says:** *"closes above the last structural high responsible for the
previous low"*.

**Why this is subjective.** "Responsible for" is a causal-intentional phrase
applied to price geometry. Price is not an agent; no high *causes* a low. The
phrase encodes a real and identifiable chart pattern, but four different formal
readings exist and they select different levels on the same chart:

| | Reading | Formal statement (bullish case; `t_s` = sweep low) |
|---|---|---|
| **R1** | The last confirmed pivot high before `t_s` | `argmax{ t_known(pivot) : t(pivot) < t_s }` |
| **R2** | The highest high of the down-leg into the low | `max high over [t_prev_pivot_high, t_s]` |
| **R3** | The origin of the *final* impulsive leg down into the low | requires CN-14 applied to the down move |
| **R4** | The most recent *lower high* in the down sequence | requires a swing sequence classification |

R1 is simplest and most local. R3 is closest to the words "responsible for" —
the high from which the move that made the low originated — but it depends on
CN-14, which is itself blocked, so R3 cannot be settled before CN-14.

**Consequence, and why this matters more than it looks.** The reference level
*is* the MSS threshold. A too-close level makes MSS trivial (noise breaks it);
a too-far level makes MSS rare and late. This single choice probably moves the
signal count by more than any threshold in the system. **`DEC-029` — Tier A.**

**Edge cases.** No pivot high exists between the previous structure and `t_s`
(possible after a long one-way move) ⇒ the reference is undefined ⇒ `UNKNOWN` ⇒
no setup, per A-3. A reference high *above* the swept pool's level. Multiple
equal candidate highs.

**Status:** BLOCKED.

---

### CN-16 · Market Structure Shift

**Definition (structure, given CN-15).** After a confirmed sweep establishing
bullish bias, with reference level `H*` (CN-15) and running low `L_run`:

```
MSS_bullish confirmed at first bar j with:
    close[j] > H* + δ_break                        (body close, brief-mandated)
  ∧ no new extreme invalidation occurred before j  (see below)
t_occurred = t(j) ; t_known = t(j)                 (latency zero — a close is a close)
```

**Purpose.** The transition from "liquidity was taken" to "direction has changed".
The methodology's commitment point.

**Settled by the brief, gratifyingly:** *only body closes count; wicks are
invalid.* This is unambiguous and admissible. Record it as a fixed rule, not a
parameter.

**Ambiguities.**

1. **Which timeframe's close?** Unspecified, and decisive. An M1 close above `H*`
   and an M5 close above `H*` are different events with different reliability.
   The brief's "execution timeframe M1–M5" refers to FVGs, not to MSS. **`DEC-032`
   — Tier A.**
2. **`δ_break`.** Zero means a one-tick close-through counts. Non-zero needs a
   unit (A6 ⇒ volatility units).
3. **The running-low problem.** Between sweep and MSS, price may make a *lower*
   low. Then the original anchor is stale: the "previous low" is now a different
   low, and by CN-15 the reference high may change too. Three policies:
   - **M-a** Invalidate the setup on any new low. Strict, few setups.
   - **M-b** Re-anchor: `L_run` and `H*` both update; the setup persists.
   - **M-c** Re-anchor the low, keep `H*` fixed.
   These are materially different engines. **`DEC-033` — Tier A.** Note M-b makes
   the setup a long-lived mutable object, which strains A-2 unless each re-anchor
   is modelled as closing one hypothesis and opening another.
4. **Body close vs whole body beyond.** "Closes above" = `close > H*`. A stricter
   reading is `min(open,close) > H*`. The brief supports the former.
5. **Maximum latency.** How many bars may elapse between sweep and MSS before the
   sweep is stale? Unbounded is inadmissible under A3. **`DEC-035`.**

**Edge cases.** A gap that opens above `H*` with no close-through bar. MSS and
sweep on the same bar (M1 bar that both sweeps and closes above the reference —
possible when `H*` is very close). MSS confirmed by a bar whose body is minute.

**Status:** PARAMETRIC; blocked on CN-15.

---

### CN-17 · Fair Value Gap (qualified)

**Definition.** A CN-06 imbalance that additionally satisfies qualification
predicates:

```
FVG := {
  id, direction, interval G = (lower, upper), midpoint CE = (lower+upper)/2
  tf, formation bars (b₁,b₂,b₃)
  t_formed = close of b₃          -- t_known = t_occurred, latency zero
  status : FRESH | PARTIALLY_MITIGATED | MITIGATED | INVERTED | EXPIRED
  provenance : POST_SWEEP | ORDINARY
}
```

**Purpose.** The execution zone. Where the pullback is expected to be rejected.

**Settled by the brief:** FVGs created after liquidity events rank above ordinary
ones — hence the `provenance` field. Note the brief calls this *importance*, an
ordering, which collides with the ternary output (`CRIT-001` §2).

**Ambiguities.**

1. **Minimum size.** An imbalance of one tick is arithmetic, not information.
   Threshold in ticks, in volatility units, or in spread multiples? A gap smaller
   than the spread is not tradable at all — that is a hard floor with an
   objective justification, and it is the cleanest non-arbitrary threshold
   available in this whole corpus. **Recommend `size ≥ κ · spread` as a floor,
   plus a volatility-relative qualifier.** `DEC-036`.
2. **Must the middle bar be the displacement bar?** Standard SMC says yes. This
   is the operative link between CN-14 and CN-17. **`DEC-024`.**
3. **Containment.** Must the FVG lie inside the impulse leg (between sweep
   extreme and MSS), or anywhere in the pullback zone? **`DEC-037`.**
4. **Mitigation policy — four incompatible options:**
   - **M1** touched: price reaches the near edge
   - **M2** consequent encroachment: price reaches the midpoint `CE`
   - **M3** filled: price reaches the far edge
   - **M4** closed through: a body close beyond the far edge
   These define *when the FVG is used up* and therefore when a setup can still be
   valid. They are not variations on a theme; they change the entry price, the
   invalidation point, and the setup count. **`DEC-038` — Tier A.**
5. **Overlapping FVGs.** Merge into one zone, keep separately, or keep only the
   largest / the one nearest the MSS? **`DEC-039`.**
6. **Inversion.** An FVG closed through is held by some schools to become a
   support/resistance of opposite sign. Out of scope for now — but the `INVERTED`
   status is reserved so adding it later is not a breaking change.

**Edge cases.** Gap formed across a session boundary (weekend gaps are enormous
and are not FVGs in any meaningful sense — **must be excluded explicitly**, and
the brief never mentions it). An FVG whose interval contains the MSS reference
level. An FVG mitigated on the same bar it forms.

**Status:** PARAMETRIC. Structure good, five decisions open, one Tier A.

---

### CN-18 · Pullback & impulse anchoring · **BLOCKED — the hardest card**

**The brief says:** *"After the Market Structure Shift we wait for a pullback.
Preferred retracement: 50%–70.5% of the impulse."*

**Why this cannot be implemented as written.** The phrase *"of the impulse"*
presupposes a leg with two known endpoints. The origin `A` is available (the
sweep extreme, once the sweep resolves). **The terminal point `B` is not.** By
CN-04, a leg's terminal pivot is only confirmed after price has moved away from
it — which is the very pullback we are trying to measure. Measuring a
retracement of a leg whose end is defined by that same retracement is circular in
time.

Every retail implementation of this idea is quietly non-causal. That is precisely
the class of error this project exists to avoid.

**Candidate anchors for `B` — causal but different:**

| | `B` = | Causal? | Property |
|---|---|---|---|
| **B1** | close of the MSS-confirming bar | ✅ immediately | Earliest, most conservative; under-measures the true impulse, so the 50–70.5% zone sits **higher** (shallower) than the trader draws it by hand |
| **B2** | highest high between sweep extreme and MSS confirmation | ✅ immediately | Slightly larger leg |
| **B3** | running maximum since the sweep, frozen when a pullback is *declared* | ✅ with a declaration rule | Closest to what the trader actually draws |
| **B4** | the eventual swing-high pivot | ❌ **non-causal** | What a human draws in hindsight — inadmissible |

**B3 requires a `PullbackDeclared` rule**, which is itself a definition the brief
does not provide. Candidates: first bar closing below the prior bar's low; a
retracement of ≥ x% from the running max; a confirmed micro-pivot on the
execution timeframe. Whichever is chosen, the zone is **frozen at declaration**
and never moves afterwards — that freeze is what keeps A-2 intact.

**`DEC-040` — Tier A, and the highest-value decision in the corpus.**
Recommendation: **B3 with an explicit declaration rule**, because it is the only
causal option that matches the trader's mental model, and because freezing at
declaration gives a hard, auditable moment where the zone becomes a permanent
fact. Cost: the zone is unavailable until declaration, so very shallow immediate
pullbacks are missed. That cost is consistent with the Precision Doctrine.

**Then, and only then, the zone:**

```
zone = [ B − r_max·(B−A) , B − r_min·(B−A) ]      r_min = 0.50, r_max = 0.705 (or √0.5)
```

with:
- `DEC-030` — 0.705 vs √0.5 (see SPEC-000 §7.3);
- `DEC-031` — whether zone entry is tested against the bar's low, its close, or
  its body;
- `DEC-041` — whether an FVG inside the zone is **mandatory** ("should exist" in
  the brief is ambiguous between MUST and SHOULD) — this is a genuine
  MUST/SHOULD ambiguity in the source text and cannot be guessed;
- `DEC-042` — behaviour when the FVG only partially overlaps the zone.

**Edge cases.** Price never retraces to 50% and runs to target — the correct
output is `NoOpportunity` and that is *by design*, but the trader should confirm
they accept missing those. Price retraces past 100% (r > 1) — invalidation, not
a deep pullback (CN-05). Retracement satisfied inside the MSS bar itself.

**Status:** BLOCKED. Everything downstream depends on it.

---

### CN-19 · Pullback multiplicity & quality · **BLOCKED**

**The brief says:** *"Ideally: one pullback. Multiple pullbacks reduce setup
quality."*

**Two separate problems.**

1. **Counting.** "A pullback" is not defined, so it cannot be counted. Counting
   requires a swing-detection threshold: with a small threshold every bar is a
   pullback; with a large one there is never more than one. The count is
   **entirely an artefact of the threshold**, not of the market. Any statement
   about "one pullback" is meaningless until the threshold is fixed. **`DEC-043`.**
2. **"Reduces quality."** An ordering, not a predicate. Under A-5 and the ternary
   output contract, quality has no home. Either it becomes a hard gate
   (`count ≤ N`) or the output contract changes. **`DEC-050` / `DEC-051`.**

**Objective counting model.** Count the maximal alternating swings of amplitude
≥ θ (in volatility units or as a fraction of the impulse height) between MSS
confirmation and zone entry. Parameterised by θ, and the parameter must be
reported alongside the count wherever the count appears — a count without its θ
is not a number, it is an opinion.

**Status:** BLOCKED.

---

### CN-20 · Reaction & Confirmation · **UNDEFINED-BY-BRIEF**

**The brief says, in full:** *"Touching an FVG is never enough. We require:
Reaction. Confirmation. Only then can an opportunity exist."*

**This is the entry trigger — the last gate before a signal — and it has zero
content.** Two undefined words, presented as two distinct requirements without
saying how they differ. This is the largest single hole in the methodology.

**First question (`DEC-044`): are "reaction" and "confirmation" one thing or
two?** A coherent two-stage reading exists: *reaction* = price responds at the
zone (necessary, weak); *confirmation* = the response is structurally validated
(sufficient, strong). If that is the intent, they are two sequential gates with
separate definitions and separate timeouts. If not, one of the words is
redundant. Cannot be guessed.

**Candidate confirmation models:**

| | Model | Objective? | Notes |
|---|---|---|---|
| **C1** | An MSS (CN-16) on a lower timeframe, inside/after the zone | ✅ fully | **Reuses existing machinery at a smaller scale.** No new primitive. |
| **C2** | Engulfing / rejection candle with wick-ratio ≥ θ | ✅ | New primitive; pattern definitions are notoriously variable |
| **C3** | A body close back beyond the FVG's near edge within W bars | ✅ | Simple, cheap, weak |
| **C4** | Micro-sweep of a local low inside the zone, then close up | ✅ | Fractal repeat of CN-13 — same argument as C1 |
| **C5** | N consecutive closes moving away from the zone | ✅ | Slow; large adverse excursion before triggering |
| **C6** | Volume/delta expansion on the reaction | ❌ for FX | Tick volume is not traded volume; real volume is unavailable on most FX feeds. **Ruled out on data grounds**, and worth saying so explicitly. |

**Recommendation: C1 (and/or C4).** Strong architectural argument beyond taste:
they introduce **no new concept**. The engine already needs sweep and MSS
operators; applying them at a lower timeframe scale gives confirmation for free,
keeps the primitive count minimal, means every improvement to MSS improves
confirmation, and makes the methodology *self-similar*, which is what the trader's
own school claims about markets anyway. C2 would add a whole family of candle-
pattern definitions, each with its own ambiguities, for no structural gain.

**Also required, and absent:**
- **Timeout.** How long may the engine wait in the zone for confirmation before
  abandoning? **`DEC-045`.**
- **Ordering under E1.** Any definition requiring "price touched the zone *then*
  reversed *within the same bar*" is intrabar-order-dependent and inadmissible
  under the bar-close clock (SPEC-000 §4.4). **`DEC-034`.**

**Status:** UNDEFINED-BY-BRIEF. **Nothing downstream of this can be specified.
This is the single most urgent item for the trader.**

---

### CN-21 · Accumulation / range regime · **BLOCKED (but tractable)**

**The brief says:** sideways movement · many wicks · poor displacement ·
multiple pullbacks · overlapping candles · no clean impulse · price trapped
inside a range.

**Good news: this is the most tractable of the blocked concepts.** Every item on
that list maps to an existing L1 primitive:

| Human phrase | Objective measure | Direction |
|---|---|---|
| sideways movement | `ER(n)` (CN-09) | low |
| price trapped inside a range | `(max high − min low)/ATR ≤ θ` | low |
| overlapping candles | mean `overlap_ratio` (CN-08) | high |
| many wicks | mean `wick_ratio` (CN-01) | high |
| poor displacement / no clean impulse | absence of CN-14 in the window | absent |
| multiple pullbacks | direction-change count (CN-19) | high |

Plus two the trader did not name but which measure the same thing more
rigorously, and are worth putting on the table:

- **Variance ratio** `VR(q) = Var(r_q)/(q·Var(r_1))`. `VR < 1` ⇒ mean-reverting
  (range); `VR > 1` ⇒ trending. Statistically principled, one number, has an
  actual null hypothesis attached, and is the standard tool for exactly this
  question in quantitative finance.
- **Hurst exponent** `H < 0.5` ⇒ anti-persistent. Same idea, noisier on short
  windows; probably not worth it at these sample sizes.

**Remaining subjectivity — three questions, not one.**

1. **Window.** Over what span is accumulation measured, and relative to what — the
   bars before the sweep, the bars of the impulse, or a fixed trailing window?
   A regime label is meaningless without its window. **`DEC-046`.**
2. **Combination.** These six measures are **strongly correlated** (low ER, high
   overlap and high wick-ratio co-occur almost by construction). Requiring all
   six is far stricter than it appears; requiring any one is far looser. Under
   A-5 a weighted score is unavailable. **`DEC-047`.** Recommended: pick the two
   least-correlated (`ER` + range containment, or `VR` + containment) and require
   both. Fewer, less redundant, more explainable.
3. **Thresholds.** These cannot be introspected. **They can only be measured** —
   from the labelled corpus, by computing each measure on the trader's own
   "this was accumulation, I would not take it" examples. This is the clearest
   case in the corpus where the answer must come from data, not from the trader's
   verbal report. `VAL-001` §2.

**Role.** A **veto** predicate. Its output is `FALSE` (no accumulation, proceed)
or `TRUE` (accumulation, reject) or `UNKNOWN` (reject, per A-3).

**Status:** BLOCKED on thresholds; structure is ready.

---

### CN-22 · Directional bias

**Definition.** `bias ∈ {BULLISH, BEARISH, NONE}`, set by the most recent
confirmed sweep: sell-side sweep ⇒ BULLISH; buy-side sweep ⇒ BEARISH.

**Ambiguities.**
1. **Conflict.** Both sides swept within a short window (a "double raid"), or an
   H1 sweep and an H4 sweep disagreeing. Priority rules absent. Options: prefer
   the higher timeframe; prefer the more recent; prefer the larger pool; declare
   `NONE` and stand down. **`DEC-027`.** Under the Precision Doctrine, standing
   down is the defensible default.
2. **Lifetime.** How long does a bias persist without confirmation?
   **`DEC-048`.**
3. **Scope.** Global per symbol, or per setup? If global, one sweep suppresses
   all opposite setups — a large, unstated design commitment. **Recommend
   per-setup**, with global bias reported as context only.

**Status:** PARAMETRIC.

---

### CN-23 · Higher-timeframe context

**The brief says:** M15/M30 FVGs provide context; intraday highs/lows are
targets; HTF context influences quality.

**"Influences quality" is not a rule.** Three objective uses are available:

- **H1 Agreement.** The setup direction must agree with the nearest unmitigated
  M15/M30 FVG. Hard gate, easy, possibly too strict.
- **H2 Obstruction.** An opposing unmitigated HTF FVG lying **between** the entry
  zone and the intended target is an objective, causal obstacle. This is the
  most defensible of the three: it is measurable, it has a clear economic
  reading, and it does not require a quality score.
- **H3 Location.** The setup's zone lies inside a supporting HTF FVG.

**`DEC-049`:** which of these are gates, which are advisory, and what happens if
no HTF FVG exists at all (silence must not be read as agreement — that is the
`UNKNOWN`-is-not-`FALSE` trap in disguise).

**Status:** PARAMETRIC.

---

### CN-24 · Draw on liquidity (target)

**The brief says:** *"Intraday highs/lows are important targets."*

**Tension worth naming.** Targets are excluded from scope (no trade management),
yet they are needed for the obstruction test (CN-23 H2) and for any notion of
setup quality. A target used **only as a filter input** — never as an
instruction — stays inside the mandate. A target expressed as "take profit at X"
does not. **Recommend: the engine computes and reports the nearest opposing
liquidity pool as context, and never as an instruction.** `DEC-052` confirms the
boundary.

**Status:** PARAMETRIC.

---

### CN-25 · DPMO · **BLOCKED — TERM UNDEFINED**

**The brief says, in full:** *"DPMO is only a filter. Never an entry trigger."*

The brief specifies DPMO's **role** completely and its **meaning** not at all.
The acronym is not standard, and I will not guess: an incorrect expansion here
would silently insert a fabricated concept into the foundation of the system,
which is the exact failure mode this project is built to prevent.

**Required from the trader (`DEC-053`):** the expansion, the computation, the
inputs, the timeframe, and — since it is stated to be a *filter* — what exactly
it vetoes and at which stage of the lifecycle.

Everything else about it is already settled by the brief and recorded: it is a
veto, never a trigger. That constraint is retained whatever the term means.

**Status:** BLOCKED. Cannot be specified. Does not block other concepts.

---

### CN-27 · Invalidation & expiry · **BLOCKED**

The brief never mentions invalidation. Without it, every hypothesis lives
forever, memory is unbounded (A3 violated), and stale setups eventually fire on
irrelevant history. Required rules, none of which exist yet:

- Price-based: bullish setup invalid if price closes below the sweep low
  (`r > 1`, CN-05). Almost certainly correct; must be confirmed.
- Time-based: maximum bars/elapsed time in each state.
- Event-based: an opposing sweep, or an opposing MSS.
- Session-based: does a setup survive the session close? the weekend?
- Structural: the FVG fully mitigated without confirmation.

**`DEC-054`** — one rule per state transition in SPEC-200. Tier B, but large.

---

### CN-28 · Deduplication & competing setups · **BLOCKED**

If one sweep produces several FVGs, or one bar sweeps several pools, or H1 and
H4 pools coincide, the engine may generate multiple concurrent setups from a
single market event. Unaddressed, this becomes signal spam — the failure the
brief explicitly names.

Required: an identity rule (what makes two setups "the same"), a selection rule
(which survives), and a concurrency limit (max simultaneous setups per symbol
and per direction). **`DEC-028`, `DEC-055`, `DEC-056`.**

---

### CN-29 · Verdict & alert

Defined in SPEC-000 §9 and SPEC-200 §5. Open: `DEC-050` (quality vs ternary),
`DEC-057` (alert-once vs repeat), `DEC-058` (does a validated setup that is never
taken get revoked, and is revocation itself an output?).

---

## 4. Admissibility audit summary

| Criterion | Concepts currently violating it | Resolution |
|---|---|---|
| A1 determinism | CN-20 candidates requiring intrabar order | `DEC-034` — exclude them |
| A2 causality | CN-18 anchor B4 (the natural human reading) | `DEC-040` — B3 with freeze |
| A3 bounded locality | CN-11 (pool lifetime), CN-27 (expiry), CN-03 model P2 | `DEC-018`, `DEC-054`, use P3 |
| A4 totality | CN-01, CN-05, CN-09 at zero denominators | Specified: `UNKNOWN` |
| A5 parameter explicitness | 50%, 70.5%, M1–M5 | ParameterSet + `DEC-030` |
| A6 scale invariance | every "size" threshold | Volatility units mandated |
| A7 stated discontinuity | all threshold predicates | Sensitivity report, `VAL-001` §5 |

## 5. Verdict on the methodology as stated

**Structure: sound.** The causal chain — pool → sweep → displacement → structural
break → imbalance → retracement → confirmation → verdict — is coherent, correctly
ordered, and each step is expressible in the L1 vocabulary without inventing new
primitives. That is a genuinely good sign and it is not typical.

**Content: absent.** 58 decisions, 12 of them blocking everything. Three concepts
(CN-14, CN-18, CN-20) have no definition at all yet carry most of the engine's
selectivity. The methodology today specifies *what happens in what order*, and
almost nothing about *how much of anything*.

**That is the normal and correct state of a discretionary method at the start of
formalisation.** It is not a criticism of the method. It is the work.
