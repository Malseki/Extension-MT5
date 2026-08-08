# CRIT-001 — Critique of the Methodology as Stated

*Contradictions, circularities, non-causal definitions and structural risks found
inside the brief. This is the document to read if you read only one.*

Each finding: what it is, why it is a problem, what it costs if ignored, and the
decision that resolves it.

---

## X-1 · The instruction paradox (meta, resolved in this delivery)

The brief requires *"the complete functional specification"* and also *"if any
concept is subjective: stop, do not continue, wait until it becomes objectively
defined"*. Taken literally and together, these are unsatisfiable: essentially
every concept in the methodology is currently subjective, so a literal reading
produces an empty document.

**Resolution adopted here:** separate **structure** from **policy**. Structure —
what exists, in what order, with what causal dependencies, under what invariants
— is fully specifiable today and is specified. Policy — every threshold and every
criterion that encodes the trader's taste — is not invented, and is instead
enumerated as `DEC-001`. Nothing is guessed; nothing is left unsaid.

If this reading is wrong, say so now, because it determines the shape of
everything that follows.

---

## X-2 · Ternary output vs. quality ordering — **direct contradiction**

The brief states the engine answers exactly `Buy | Sell | No Opportunity`.
It also states, in five separate places:

- FVGs after liquidity events are *"much more important"* than ordinary ones
- *"Preferred"* retracement 50–70.5%
- *"Preferred"* execution timeframe M1–M5
- multiple pullbacks *"reduce setup quality"*
- HTF context *"influences setup quality"*

**Importance, preference and quality are orderings. A ternary output has no
ordering.** These cannot both be true. Either:

- **(a)** Every "preference" is actually a hard gate, the words *preferred* and
  *quality* are removed from the methodology, and the output stays ternary; or
- **(b)** The output carries a grade, and the engine must define an ordering —
  which under A-5 (no opaque scores) must be lexicographic or tier-based, not a
  weighted sum; or
- **(c)** Preferences become gates whose thresholds are simply looser than the
  ideal, and the ideal is documented but unused.

Each produces a different engine. **`DEC-050`.** Do not let this be settled by
accident during implementation — that is precisely how a detection engine
silently becomes a signal spammer.

**Cost if ignored:** the "quality" concepts get implemented as an ad-hoc score
with invented weights, A-5 is violated, and no rejection is ever explainable
again.

---

## X-3 · Displacement ⇄ Fair Value Gap — **circular definition**

The brief: *"After a valid displacement there must be a Fair Value Gap."*
Standard practice in this school: displacement **is** the presence of an
imbalance in the move.

If both hold, the FVG requirement is not an additional filter — it is the
displacement test restated, and the engine has **one fewer independent
constraint than it appears to have**. Anyone reading the rule list would
reasonably believe two conditions are being checked when only one is.

**`DEC-025`.** Either define displacement independently of imbalance (magnitude /
efficiency / velocity — SPEC-100 CN-14 D1/D2/D5) so the FVG condition adds real
information, or accept D4 and delete the separate FVG requirement as redundant.

**Cost if ignored:** the system is less selective than its documentation claims,
and the discrepancy is invisible until someone audits the logic years later.

---

## X-4 · Retracement of an unfinished leg — **non-causal as stated**

*"Preferred retracement: 50%–70.5% of the impulse."* The impulse's terminal
point is not known while the impulse is running; it is defined by the pullback
that we are trying to measure against it. A human drawing this on a finished
chart has already seen the high. An engine at bar *t* has not.

This is the single most common source of unrealisable backtests in this entire
category of strategy, and it is invisible to inspection: the code looks correct,
the chart looks correct, and the results are unreachable in real time.

**`DEC-040`**, with the causal anchoring options B1–B3 and the mandatory
*freeze at declaration* rule (SPEC-100 CN-18).

**Cost if ignored:** every performance number the project ever produces is
fiction, and nobody will notice for a long time.

---

## X-5 · "H1/H4 highs" vs. the forming bar

Liquidity is specified on H1/H4. Under A-1 a higher-timeframe bar is not readable
until it closes, so the current H4 bar's high is invisible for up to four hours.
That is certainly not what the trader means when watching the chart.

The resolution is that a liquidity pool is a **confirmed pivot from closed
bars**, not "the current extreme" — the running high of a forming bar is just
price, not a pool. This is coherent, but it must be confirmed explicitly, because
it means the engine will not treat the freshest extreme as liquidity until it has
matured. **`DEC-013`.**

---

## X-6 · MUST or SHOULD — unresolved modality

*"A valid FVG **should** exist inside that area."* In a specification, *should*
and *must* are different words with different consequences: one produces
`NoOpportunity`, the other does not. The same ambiguity affects *"preferred
execution timeframe M1–M5"* — is an M15 FVG disqualifying or merely less good?

**`DEC-041`**, `DEC-003`. Every modal verb in the final specification must be
MUST, MUST NOT, or SHOULD-with-an-ADR. No other modality is permitted.

---

## X-7 · No invalidation, no expiry — **unbounded state**

The brief describes how a setup is born and never how it dies. Consequences:

- hypotheses accumulate without limit ⇒ A3 violated, memory unbounded;
- a sweep from three weeks ago can still produce a signal today;
- there is no defined answer to "is this setup still alive?", which is the
  question a trader asks most often.

**`DEC-054`** requires one invalidation rule and one timeout per state in
SPEC-200. This is the largest single gap in the brief by volume, and it is
entirely mechanical to fix once the trader states the rules.

---

## X-8 · No deduplication — **contradicts the stated mission**

The brief opens by declaring the system is *not a signal spammer*. It then
describes a pipeline in which a single sweep can produce several FVGs, one bar
can sweep several stacked pools, and the same price can be both an H1 and an H4
pool. With no identity and no concurrency rule, **the natural implementation of
this methodology is a spammer** — not through bad engineering, but through the
absence of three rules.

**`DEC-028`, `DEC-055`, `DEC-056`.** Recommended defaults: one setup per sweep,
one alert per setup, an explicit cap per symbol and direction.

---

## X-9 · The precision claim is currently unverifiable — **the epistemic gap**

*"Missing opportunities is preferable to generating low-quality signals.
Precision is more important than frequency."*

Precision and recall are ratios against a ground truth. **There is no ground
truth in this project.** No labelled set of setups the trader would take and
would refuse exists. Therefore, today:

- no threshold can be justified as anything but arbitrary;
- no version can be shown to be better than another;
- the central claim of the project cannot be tested, only asserted.

This is the project's critical path and it is **not blocked by any decision**.
It can start today and it should. `VAL-001` §2.

**Cost if ignored:** the engine encodes whoever tuned it, forever, with no way to
tell whether that was good.

---

## X-10 · DPMO is undefined

The brief specifies DPMO's role fully (a filter, never a trigger) and its meaning
not at all. The acronym is not standard. I will not guess: a fabricated expansion
would embed an invented concept in the foundation. **`DEC-053`.**

---

## X-11 · "Reaction. Confirmation." — the entry trigger has no content

Two undefined words presented as two requirements, with no statement of how they
differ, form the **final gate before a signal is emitted**. Everything else in
the methodology filters; this is what fires. It is the least specified concept in
the brief and the most consequential. **`DEC-044`, `DEC-045`.**

Until it is answered, no end-to-end specification of the engine exists — only
its first six sevenths.

---

## X-12 · Six timeframes, no alignment rule — **scalability risk**

The methodology touches H4, H1, M30, M15, M5, M1. It never states:

- which timeframes are mandatory vs. optional;
- what happens when they disagree;
- whether parameters are shared across timeframes or independent per timeframe.

If parameters are per-timeframe, the parameter surface multiplies by six. With
~25 parameters that is 150 numbers to justify, and no realistic labelled corpus
can support fitting them. **The scale-invariant formulation (A6) exists precisely
to avoid this**: thresholds expressed in volatility units *should* transfer
across timeframes, letting one parameter serve all six. That should be tested,
not assumed. **`DEC-003`.**

---

## X-13 · Parameter count vs. available evidence — **statistical risk**

A rough count of this corpus yields **40–60 free parameters**. A trader can
realistically label a few hundred setups. Fitting 50 parameters to 200 examples
is not calibration; it is memorisation, and it will produce a system that
performs beautifully on the corpus and randomly thereafter.

Mitigations, in order of value:

1. **Fix most parameters by principle rather than by fitting** — e.g. the FVG
   minimum size floored at a spread multiple (an objective, non-fitted bound).
2. **Share parameters across timeframes and instruments** via A6 normalisation.
3. **Fit only the handful that genuinely encode taste** (displacement threshold,
   retracement bounds, confirmation model) and hold out data to test them.
4. **Report the fitted-vs-principled split explicitly** in the ParameterSet
   `provenance` field, so the honest degrees of freedom are always visible.

This risk is structural, not hypothetical, and it is the main reason to keep the
parameter surface deliberately small from the beginning rather than pruning it
later.

---

## X-14 · Bid/ask asymmetry invalidates naïve sweep detection

Charts are bid; buy-stops execute at ask. Buy-side liquidity above a high is
consumed when `bid ≥ level − spread`, i.e. **before the bid chart reaches the
level**. A sweep-detection rule that requires the bid high to exceed the level
by a positive threshold is measuring the wrong event, and it is wrong in a
systematic direction, not randomly. SPEC-000 §5.2, **`DEC-008`, `DEC-021`**.

---

## X-15 · Broker and DST dependence of H1/H4 levels

The same instrument, the same day, two brokers, different H4 boundaries,
different H4 extremes, different liquidity pools, different signals. Add DST
transitions and the boundaries move twice a year within a single broker.

Unless HTF bars are derived by the engine from M1 with a declared anchor (A-6),
the system is not reproducible across hosts, and MT5 results will not match
TradingView results, ever. **`DEC-004`, `DEC-005`.**

---

## X-16 · The corpus must not be drawn from memory — **survivorship risk**

When the labelled corpus is built (`VAL-001` §2), the natural procedure is for
the trader to scroll back and mark the setups they remember. This is exactly
wrong: remembered setups are disproportionately the ones that worked. Thresholds
fitted to them will encode outcome, not structure, and the engine will look
excellent in review and fail live.

**Required protocol:** label on **randomly sampled** date ranges, blind to
outcome — mark the decision at the moment of the setup, with the right-hand side
of the chart hidden. Slower, harder, and the difference between a validated
system and a flattering one.

---

## X-17 · The single-parameter-set assumption is unexamined

The corpus assumes one ParameterSet governs all instruments and all regimes.
That may be false: a threshold tuned on EURUSD in London may be wrong for XAUUSD
in Asia. The alternatives — per-instrument sets, per-session sets, per-regime
sets — each multiply the fitting problem in X-13.

Not a decision for today, but it must be **measured** rather than assumed once
the corpus exists: compute each measure's distribution per instrument and per
session, and see whether the distributions actually coincide. If they do, one set
is justified and that justification is written down. If they do not, the project
learns something important early instead of late. `VAL-001` §6.

---

## Summary of resolutions

| Finding | Severity | Resolved by |
|---|---|---|
| X-2 ternary vs quality | **Contradiction** | `DEC-050`, `DEC-051` |
| X-3 displacement ⇄ FVG | **Circularity** | `DEC-025` |
| X-4 non-causal retracement | **Correctness** | `DEC-040` |
| X-9 no ground truth | **Project-critical** | `VAL-001` §2 — start now |
| X-11 confirmation undefined | **Blocking** | `DEC-044` |
| X-13 parameter count | **Statistical** | design discipline, ongoing |
| X-16 survivorship in labelling | **Methodological** | blind sampling protocol |
| X-5, X-6, X-7, X-8, X-10, X-12, X-14, X-15, X-17 | Structural | see register |
