# VAL-001 — Falsifiability Plan

*How we will ever know the engine is correct. Written before the engine, on
purpose: a validation plan designed after the fact always validates whatever was
built.*

---

## 1. The problem

The brief's central commitment — *precision over frequency, missing setups is
better than low-quality signals* — is a claim about **precision and recall**.
Both are ratios against a ground truth. This project has no ground truth.

Consequently, today:

- no threshold in `DEC-001` can be justified as anything other than arbitrary;
- no version of the engine can be shown to be better than another;
- the trader and the engine can disagree, and there is no procedure to decide
  who is right;
- the project's central claim is untestable.

Everything below exists to close that gap. **Section 2 is the critical path of
the entire project and is blocked by nothing.**

---

## 2. The labelled corpus

### 2.1 What it is

A set of chart windows in which the trader has recorded their own decision,
**before** seeing the outcome and **before** seeing any engine output.

### 2.2 The protocol (the details are what make it valid)

1. **Random sampling.** Date ranges are drawn at random from history, per
   instrument. **Not** ranges the trader remembers. See `CRIT-001` X-16: labelling
   from memory encodes outcome rather than structure, and produces thresholds that
   look excellent in review and fail live. This is the single most important
   sentence in this document.
2. **Right-hand side hidden.** The chart is revealed left-to-right. The label is
   recorded at the instant of decision, with the future invisible. This is the
   only way the labels answer the same question the engine will be asked.
3. **Both classes.** Positives (*I would take this*) **and** negatives
   (*there was a sweep and a shift here and I would refuse it, because…*).
   **Negatives are more valuable than positives.** They are what encodes
   selectivity, and selectivity is the whole product. A corpus of positives only
   can calibrate nothing.
4. **Outcome recorded separately, and never used for calibration.** Whether the
   trade would have worked is interesting and must be kept in a different column,
   consulted only after thresholds are fixed. Mixing it in turns the engine into
   a curve-fit of the past.
5. **Intermediate marks, not just verdicts.** For each labelled instance, mark
   the *components*: which level was the liquidity, where the structural high
   was, where the impulse started and ended, where the zone was. These are what
   answer `DEC-029`, `DEC-020`, `DEC-026`, `DEC-043` **by measurement instead of
   by opinion** — see `DEC-001` §"Fastest path".

### 2.3 Record format

```
instrument, timeframe, decision timestamp (UTC), verdict (TAKE | REFUSE),
direction, refusal reason (free text — later coded),
marked liquidity level, marked structural high, marked impulse A and B,
marked zone, marked FVG, marked confirmation instant,
confidence (trader's own, 1–5),
outcome (separate column, quarantined)
```

Free-text refusal reasons are deliberate: coding them afterwards will reveal
which filters the trader actually uses, including ones the brief never mentions.
Expect surprises there — that is the point.

### 2.4 Size

Enough to hold out a test set. As a rough target, **150–300 labelled instances
with at least 40% negatives**, spread across instruments and sessions. Fewer than
~100 cannot support even the small number of genuinely fitted parameters
(`CRIT-001` X-13), and a corpus without held-out data cannot demonstrate
anything at all.

### 2.5 Reliability check

The trader labels a random 10% subset **twice**, separated by weeks and blind to
the first pass. The agreement rate between the two passes is the **ceiling on any
engine's achievable accuracy**. If a human agrees with themselves 70% of the
time, an engine scoring 70% has matched the methodology exactly, and chasing 90%
would be fitting noise. Nobody can interpret the engine's numbers without this
one.

---

## 3. Determinism tests (no market knowledge required)

- **T-1 Repeatability.** Same data, spec and parameters ⇒ byte-identical event
  stream. Run twice, diff.
- **T-2 Order independence.** Shuffling any internal collection must not change
  output. Catches hash-map iteration order and other silent A1 violations.
- **T-3 Chunk independence.** Feeding history in one pass vs. many chunks
  produces identical output.
- **T-4 Platform agreement.** Two independent implementations on the same input
  produce identical streams. The strongest available test of the specification's
  own clarity: if two competent implementers disagree, the *specification* is
  defective, not the code.

---

## 4. The causality test (prefix invariance) — **the most valuable test here**

> Let `S(D)` be the event stream produced from dataset `D`.
> For every truncation time `T`, let `D|T` be `D` with all bars after `T` removed.
> **Required:** `S(D|T)` equals `S(D)` restricted to objects with `t_known ≤ T`,
> exactly — same ids, same payloads, same timestamps.

Run it at many random `T`. Any discrepancy is look-ahead bias, located precisely
at the offending object.

This is mechanical, needs no trading knowledge, and catches the entire class of
error described in `CRIT-001` X-4 — the class that is otherwise invisible until
live trading, and expensive when it surfaces. It should be the first test
written and it should run on every change forever.

---

## 5. Sensitivity analysis (A7)

For every parameter `p`, re-run the corpus at `p ± 10%` and `p ± 25%` and record
the change in setup count and in agreement with the labels. Classify:

- **Robust** — <10% change in setup count under ±10%.
- **Sensitive** — 10–30%.
- **Fragile** — >30%. Recorded as fragile in the ParameterSet, with a note.

Fragile parameters are not necessarily wrong. They are the ones that will break
the system in three years when a market regime shifts, and the point of the
exercise is that their names are written down in advance rather than discovered
during a drawdown.

**A fragile parameter with `provenance: arbitrary` is the highest-risk object
the project can contain.** That combination should be actively hunted.

---

## 6. Statistical questions worth asking of the corpus

Beyond calibration, the corpus makes several of the methodology's own beliefs
testable. These are worth running even if the answers are uncomfortable:

1. **Does the sweep hypothesis hold?** `P(reversal | penetration depth, time
   beyond level, volatility regime)` — is a penetration-and-rejection actually
   followed by displacement more often than a random penetration? If yes,
   `δ_pen` can be *measured* rather than chosen, which removes a Tier A
   arbitrary parameter (`DEC-021`).
2. **Does displacement predict continuation?** Compare D1/D2/D5 as predictors on
   labelled impulses. Answers `DEC-026` empirically.
3. **Do thresholds transfer across instruments and sessions?** Compare each
   measure's distribution per instrument and per session. Settles `CRIT-001` X-17
   and `DEC-003` — either justifying a single parameter set or revealing early
   that one does not exist.
4. **Which of R1–R4 reproduces the trader's marks?** Direct, decisive, cheap
   (`DEC-029`).
5. **Are the accumulation measures as redundant as expected?** Correlation matrix
   of the six candidates on labelled ranges (`DEC-047`).

---

## 7. Acceptance criteria for v1

The engine is acceptable when, on the **held-out** portion of the corpus:

- **Recall** on trader-marked TAKE instances ≥ a threshold the trader sets in
  advance, *knowing* that the Precision Doctrine permits this to be low.
- **Precision**: engine-marked opportunities not present in the trader's TAKE
  set are individually reviewed. Every one resolves into either a specification
  change (with an ADR) or a corpus correction. **No disagreement is ever left
  unresolved.**
- All invariants hold: SPEC-200 L-1…L-8, SPEC-300 V-1…V-8.
- Prefix invariance (§4) passes at 100 random truncation points.
- Every parameter has a written justification and a fragility classification.

Note the asymmetry, which is deliberate and follows from the brief: **low recall
is acceptable; unexplained precision failures are not.**

---

## 8. Disagreement triage

When trader and engine disagree, exactly one of three things is true, and the
procedure is to determine which:

1. **The specification is wrong** — the rule does not capture what the trader
   means. ⇒ ADR, spec change, re-run.
2. **The parameter is wrong** — the rule is right, the number is off.
   ⇒ ParameterSet change, re-run, sensitivity check.
3. **The trader was wrong** — inconsistent with their own stated method.
   ⇒ Corpus correction, recorded with its reason.

**Outcome (3) must remain available and must be used when true.** A process in
which the human is never wrong is not a formalisation; it is an oracle, and an
oracle cannot be encoded in software. Recording (3) honestly is what turns the
trader's intuition into a system instead of a mood.

The `provenance` chain in SPEC-300 §3 is what makes this triage take minutes:
the engine can always show the exact bars, levels and threshold comparisons that
produced its answer.
