# DEC-001 — Open Decision Register

*Every question that must be answered before the specification can close.
None of these has been guessed. Where I give a recommendation it is labelled
either **[REC]** — an engineering judgement I will defend — or **[HYP]** — a
starting hypothesis that must be tested against data, not adopted on my say-so.*

**How to use this.** Answer Tier A first; the pipeline cannot be defined without
it. Tier B blocks detection. Tier C blocks quality, context and output polish.
Several Tier C items are one-word answers — do them while thinking about Tier A.

**Answer format.** For each: the choice, and one sentence of *why*. The "why"
becomes the parameter's `justification` field and is not optional — an
unjustified parameter is a defect under A-4.

| Tier | Count | Blocks |
|---|---|---|
| **A** | 13 | Everything. No concept downstream can be defined. |
| **B** | 23 | The detection layer. No signal can be produced. |
| **C** | 22 | Quality grading, context, output behaviour, operations. |

---

## TIER A — blocks everything

### DEC-002 · Evaluation clock
Bar-close (E1) or tick (E2)? SPEC-000 §4.4.
**Consequence:** E1 makes the engine a pure function of M1 OHLC — reproducible
everywhere, testable, backtestable on universally available data — at the cost of
up to one minute of latency and of blindness to intrabar ordering.
**[REC] E1 with M1 base.** Reproducibility is worth more than 60 seconds to a
system whose entire purpose is precision, and E2 makes cross-platform agreement
practically impossible.

### DEC-003 · Timeframe set and role
Which timeframes exist in the engine, and is each mandatory or optional?
Brief implies: H4, H1 (liquidity), M30, M15 (context), M5, M1 (execution).
Also: are parameters shared across timeframes (via A6 normalisation) or
independent per timeframe? See X-12.
**[REC]** Shared parameters in volatility units, with a test that they actually
transfer. Independent per-timeframe parameters multiply the fitting problem by
six and cannot be supported by any realistic corpus.

### DEC-004 · HTF aggregation anchor
From which instant do H1/H4 bars start? Options: UTC midnight; broker midnight;
New York 17:00 (the FX day convention); the trader's local midnight.
**Consequence:** determines every H1/H4 extreme in the system.
**[REC] New York 17:00 in a fixed timezone** if FX is primary — it matches the
market's own daily boundary rather than an arbitrary clock. Must be an explicit
parameter regardless.

### DEC-005 · Engine timezone and DST policy
Fixed offset (no DST) or a DST-observing zone?
**[REC] A fixed offset internally**, with DST-aware session labels layered on
top. Bar boundaries must never move; session *names* may.

### DEC-008 · Spread model
S1 ignore / S2 per-symbol-per-session constant / S3 real tick spread.
SPEC-000 §5.2, X-14.
**[REC] S2**, with the constants measured, plus a documented sensitivity check
against S1 so the size of the effect is known rather than assumed.

### DEC-009 · Instrument scope
Which instruments must v1 support? FX majors only? Metals? Indices? Crypto?
**Consequence:** 24/7 instruments have no session liquidity, no daily open, no
overnight gap and no "intraday high" in the methodology's sense. Including
crypto requires a second definition of several concepts.
**[REC]** Name a small, explicit v1 list. Breadth here is expensive and mostly
invisible until it breaks.

### DEC-020 · Structure of pool significance
Conjunction or disjunction of the candidate criteria G1–G7? SPEC-100 CN-12.
**Consequence:** the difference between ~40 pools/day and ~3.
**[HYP] `G1 ∧ (G3 ∨ G4)`** — geometrically valid, and either engineered
(equal highs) or calendar-salient. To be checked against the corpus.

### DEC-021 · Penetration threshold `δ_pen`
Value and unit. Interacts with `DEC-008`: on a bid feed the economically correct
buy-side test may use a **negative** effective δ.
**[REC]** Express in volatility units, not ticks, and derive the buy-side and
sell-side forms separately from the spread model rather than assuming symmetry.

### DEC-022 · Sweep resolution timeframe
Is the rejection close judged on the pool's own timeframe (H1/H4) or on the
execution timeframe (M1/M5)? SPEC-100 CN-13.
**Consequence:** hours of latency, and a large factor in signal count.
**[HYP]** Execution timeframe for latency, with an H1/H4 confirmation as an
optional stricter mode — but this genuinely depends on how the trader reads it
in practice, so it is a question, not a recommendation.

### DEC-025 · Displacement ⇄ FVG circularity
Is displacement *defined by* the presence of an imbalance, or independently?
X-3, SPEC-100 CN-14.
**[REC]** Define independently (velocity + efficiency), so the FVG requirement
carries real information. Otherwise delete the FVG requirement as redundant and
say so in the documentation.

### DEC-029 · Structural reference level rule
R1 (last confirmed pivot high) / R2 (max of the down-leg) / R3 (origin of the
final impulsive leg) / R4 (most recent lower high). SPEC-100 CN-15.
**Consequence:** this is the MSS threshold; it probably moves the signal count
more than any single number in the system.
**Method:** the fastest way to settle it is to take ten charts where the trader
has already marked "the structural high", and see which rule reproduces the
marks. **This is a measurable question, not an opinion.**

### DEC-040 · Impulse anchoring and pullback declaration
Anchor B1 / B2 / B3, plus the `PullbackDeclared` rule if B3. X-4, CN-18.
**[REC] B3 with an explicit declaration rule and a hard freeze.** The only causal
option matching the trader's mental model. B4 (the hindsight swing high) is
inadmissible and must be rejected explicitly, because it is what everyone
implements by default.

### DEC-044 · Reaction vs Confirmation
One concept or two? If two: the definition of each, and their order. X-11, CN-20.
**[REC] C1 or C4 — a lower-timeframe MSS, or a micro-sweep followed by an LTF
MSS.** Argument is structural rather than aesthetic: both reuse operators the
engine already needs, add no new primitives, and make the methodology
self-similar across scales. C6 (volume) is ruled out on data grounds for FX.

---

## TIER B — blocks the detection layer

### DEC-001 · Base timeframe
M1 assumed throughout. Confirm, and confirm that M1 history of sufficient depth
is available for the target instruments.

### DEC-006 · Missing-bar policy
(a) leave gaps, count bars; (b) synthesise flat bars; (c) leave gaps, express all
windows in elapsed time. SPEC-000 §4.6.
**[REC] (c).** (b) corrupts every volatility and efficiency measure; (a) makes
"20 bars" mean different things at different hours.

### DEC-010 · Volatility estimator
Which of V1–V5, on which timeframe, with which period — and whether the same one
serves displacement, gap size and accumulation. SPEC-000 §6.2.
**[REC]** A robust estimator (median TR or a TR quantile) for significance tests,
because news spikes are exactly what precedes sweeps and Wilder's ATR is
contaminated by them.

### DEC-011 · Equality tolerance `ε`
For "equal highs". In ticks or volatility units; frozen at cluster formation.

### DEC-014 · Pivot tie rule
Strict/non-strict on each side. Determines which of several equal highs becomes
*the* level. CN-03.

### DEC-015 · Pivot widths (k, m) per timeframe
And whether asymmetric. Confirmation latency = m bars.

### DEC-017 · Cluster representative
min / max / mean / first. For buy-side pools, max is conservative, min triggers
earliest. CN-10.

### DEC-018 · Pool death
On sweep / on decisive break / age limit / touch count / never. Unbounded
growth otherwise (A3). CN-11.

### DEC-023 · Sweep window and acceptance
Same-bar or windowed (`W_sweep`)? And what constitutes *acceptance* beyond the
level (one close / N closes / a close by ≥ θ·ATR / time beyond)? CN-13.

### DEC-024 · Must the FVG's middle bar be the displacement bar?
The operative link between CN-14 and CN-17.

### DEC-026 · Displacement model and thresholds
Which of D1/D2/D3/D5/D6/D7 (after `DEC-025`), and their values. CN-14.
**[HYP]** `D5 ∧ D2` with a D1 floor — fast for its duration, efficient, and above
a minimum size.

### DEC-030 · 0.705 or √0.5
Is the number literally 0.705, or `√0.5 = 0.70710678…`? Different numbers.
If √0.5, the justification is geometric and the parameter is principled; if
0.705, it is arbitrary and must be marked `provenance: arbitrary`. SPEC-000 §7.3.

### DEC-031 · Zone-entry test basis
Bar low / close / body. Different entry counts, different invalidations. CN-05.

### DEC-032 · MSS timeframe
Which timeframe's body close confirms the shift. CN-16.

### DEC-033 · Running-extreme policy
M-a invalidate on any new low / M-b re-anchor both / M-c re-anchor low only.
If M-b or M-c, the re-anchor must be modelled as a successor hypothesis, never
as an in-place edit (A-2). CN-16, SPEC-200 §4.

### DEC-034 · Intrabar-order-dependent definitions
Confirm they are excluded under E1. Any rule of the form "touched X *then*
reversed within the same bar" is inadmissible. SPEC-000 §4.4.

### DEC-035 · Maximum sweep → MSS latency `W_mss`
Unbounded is inadmissible (A3).

### DEC-036 · FVG minimum size
**[REC]** A hard floor at `κ · spread` — a gap smaller than the spread is not
tradable, which is the cleanest objectively justified threshold available
anywhere in this corpus — plus a volatility-relative qualifier above it. CN-17.

### DEC-037 · FVG containment
Must the FVG lie inside the impulse leg, or anywhere in the zone?

### DEC-038 · Mitigation policy
M1 touched / M2 consequent encroachment (50%) / M3 filled / M4 closed through.
Changes entry price, invalidation point and setup count. CN-17.

### DEC-041 · FVG inside the zone: MUST or SHOULD?
The brief says "should exist". X-6.

### DEC-045 · Confirmation timeout `W_conf`
How long may a setup wait in the zone before expiring.

### DEC-054 · Invalidation rules and timeouts (one per state)
`W_sweep`, `W_mss`, `W_pullback`, `W_zone`, `W_conf`, plus the price-based and
event-based invalidations in SPEC-200 §4. X-7. Large but mechanical.

---

## TIER C — quality, context, output, operations

### DEC-007 · Session/weekend spanning
May a setup survive a session close? A weekend? A daily rollover?

### DEC-012 · `UNKNOWN` inside aggregates
When averaging `body_ratio` over a window, are `UNKNOWN` elements excluded or do
they poison the mean? Excluding biases toward liquid periods; poisoning removes
the measure exactly during quiet regimes. CN-01.

### DEC-013 · Pool = confirmed pivot, not running extreme
Confirm the interpretation in X-5.

### DEC-016 · Efficiency variant
Close-to-close ER or path-based (`|net| / Σ range`). Path-based penalises wicks,
which is what the accumulation description asks for. Same variant for both uses?

### DEC-019 · Multi-timeframe duplicate pools
Same price as both an H1 and an H4 pivot: one pool or two?

### DEC-027 · Bias conflict
Both sides swept, or H1 and H4 disagreeing. Options: prefer higher timeframe /
prefer more recent / prefer larger pool / stand down.
**[REC] Stand down.** Under the Precision Doctrine, contradiction is a reason not
to signal.

### DEC-028 · Cascade sweeps
One bar sweeping several stacked pools — which is "the" sweep?
**[REC]** Keep the most significant; mark the rest consumed.

### DEC-039 · Overlapping FVGs
Merge / keep all / keep largest / keep nearest to the MSS.

### DEC-042 · Partial FVG–zone overlap
Does an FVG that only partly intersects the retracement zone satisfy the
requirement?

### DEC-043 · Pullback counting threshold
The swing amplitude θ below which a wiggle is not a pullback. **Without this, the
pullback count is an artefact of the threshold, not a property of the market** —
and any statement about "one pullback" is unfalsifiable. CN-19.

### DEC-046 · Accumulation window
Which bars are examined, relative to what.

### DEC-047 · Accumulation combination
Which measures, and how combined (A-5 forbids weighted scores).
**[REC]** The two least-correlated measures, both required. The six candidates
are heavily redundant; requiring all six is far stricter than it looks.

### DEC-048 · Bias lifetime
How long a sweep's bias persists unconfirmed.

### DEC-049 · HTF context role
H1 agreement / H2 obstruction / H3 location — which are gates, which advisory,
and what happens when **no** HTF FVG exists (silence must not be read as
agreement). CN-23.
**[REC]** H2 obstruction as the primary use: objective, causal, and it needs no
quality score.

### DEC-050 · Quality vs ternary output
Resolution of X-2: (a) gates only, (b) graded output, (c) loose gates with a
documented ideal. **The highest-leverage conceptual decision in Tier C.**

### DEC-051 · Compensation between dimensions
Is a setup that is weak on one dimension and exceptional on another acceptable?
If yes, A-5 must be revisited openly rather than worked around with a score.

### DEC-052 · Target boundary
Confirm: the engine reports the nearest opposing pool as *context*, never as an
instruction, keeping it inside the "no trade management" mandate. CN-24.

### DEC-053 · DPMO
Expansion, computation, inputs, timeframe, and what exactly it vetoes and when.
X-10, CN-25.

### DEC-055 · Setup identity
**[REC]** `(symbol, direction, sweep_ref)` — one setup per sweep, with the FVG a
property rather than part of the identity. Requires an FVG selection rule.

### DEC-056 · Concurrency limit
Max live setups per symbol and per direction. X-8.

### DEC-057 · Alert repetition
Once at validation, or repeated while valid?
**[REC] Once.** Repetition is the definition of the failure mode the brief names.

### DEC-058 · Revocation
If a validated setup fails structurally two bars later, is a revocation emitted?
Cheap to express, semantically loaded — the trader may already have acted.

---

## Fastest path through this register

Six of these can be settled by **measurement rather than opinion**, and doing so
would both answer them and build the corpus at the same time:

- `DEC-029` (reference level) — which rule reproduces the trader's own marks
- `DEC-020` (pool significance) — which criteria select the trader's own levels
- `DEC-026` (displacement) — measure D1/D2/D5 on labelled impulses
- `DEC-047` (accumulation) — measure the six candidates on labelled ranges
- `DEC-043` (pullback threshold) — the θ at which the trader's count matches
- `DEC-003` (parameter sharing) — do the distributions actually transfer

Every one of them requires the same input: **charts the trader has marked up.**
That is `VAL-001` §2, and it is why the corpus is the critical path.
