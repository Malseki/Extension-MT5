# E-MT5-036 — PRE-REGISTRATION: DOES FUNDAMENTAL CONTEXT IMPROVE THE TECHNICAL SYSTEM?

    STATUS   PRE-REGISTRATION. Sealed BEFORE the first fundamental report is
             produced and before any observation is recorded.
    DATE     2026-08-24 22:00Z
    RULES    SPEC-FUND-001, frozen the same day. No weight may change once a
             result has been seen.
    TESTS    §26 of the trader's fundamental system.

---

## 1. The claim under test

[PROPOSED] Filtering technical entries by a fundamental bias improves results
over taking the same entries without that filter.

[NOT ESTABLISHED] Anything about whether this is true. The trader's own §26
states it must not be assumed. This document exists to make the claim
falsifiable **and to state honestly which parts of it can be answered at all.**

---

## 2. The power problem, stated before measuring

[DERIVED] Two-proportion test, α = 0.05 two-sided, power 80%:

| effect to detect | n per arm | total trades |
|---|---|---|
| win rate 50% → 55% | 1,565 | 3,130 |
| win rate 50% → 60% | 388 | 776 |

At a realistic discretionary pace:

| pace | trades/year | years to answer +5pp | years to answer +10pp |
|---|---|---|---|
| 3 per week | ~150 | ~21 | ~5 |
| 2 per day | ~500 | ~6 | ~1.6 |

[DERIVED] **The primary test of §26 as written cannot be closed in a reasonable
time.** This is not a reason to skip the recording — the data cannot be
recovered later, and recording costs nothing — but the trader must know from
day one that the statistical answer will probably not arrive.

[OBSERVED] The project has measured what sufficient sample looks like:
E-MT5-031 needed n = 108,678 to reach z = +18.50. Twice, small in-sample
positives collapsed on virgin data (FINDINGS-001 §4.1).

Therefore this experiment is split into three tests, ordered by whether they
can actually be answered.

---

## 3. TEST A — event-risk filter  ·  ANSWERABLE IN WEEKS

The only term that decided this entire project is execution cost. E-MT5-032
established that the spread at the instant of a signal is 1.96× its average on
EURUSD, against an edge of 0.562 pips. Event windows are where that cost is
worst.

**Unit of observation:** every signal emitted by TRADER-ALERT-001, not every
trade. The detector produces many signals per day, so sample accumulates orders
of magnitude faster than trades do.

**Measured for each signal:** whether it fell inside an event window
(tier-1 event ±15 min, from the MT5 native calendar), the spread at emission,
and the recorded outcome (ACERTO / FALLO).

**H0:** signals inside an event window have the same outcome distribution and
the same spread as signals outside one.

**PREDICTION, RECORDED BEFORE MEASURING:** signals inside event windows will
show a **materially wider spread** and a **worse or equal** hit rate. Stated
directionally because E-MT5-032 already established the mechanism — spread
widens exactly when price moves — and an event is the strongest version of that.

**DECISION CRITERIA:**

| result | action |
|---|---|
| spread in-window ≥ 1.5× out-of-window, n ≥ 200 in-window | adopt the event filter permanently |
| spread ratio between 1.1× and 1.5× | keep filtering; the cost argument holds but is weaker than expected |
| spread ratio < 1.1× **and** hit rate not worse | **the event filter is useless — drop it and say so** |

[DERIVED] This test can fail. That is the point.

---

## 4. TEST B — daily bias vs daily direction  ·  ANSWERABLE IN ~1-3 YEARS

**Unit of observation:** one per trading day on which the bias is not NEUTRAL.

**Measured:** whether the sign of the EURUSD daily change (NY close vs NY open)
matches the sign of that morning's fundamental bias.

**H0:** P(match) = 50%.

**PREDICTION, RECORDED BEFORE MEASURING:** no prediction of direction is
offered. [NOT ESTABLISHED] Given six refuted hypotheses in this project, the
honest prior is that P(match) will not differ from 50% at any conventional
significance level.

| effect | n (non-neutral days) | calendar time at ~60% non-neutral |
|---|---|---|
| 50% → 57% | 398 | ~2.6 years |
| 50% → 60% | 194 | ~1.3 years |

**DECISION CRITERIA:**

| result | action |
|---|---|
| P(match) ≥ 57% with n ≥ 398, z > 2 | the bias carries directional information |
| P(match) in 45–55% at n ≥ 398 | **no directional edge — the score is decoration; stop producing it** |
| P(match) ≤ 43% with n ≥ 398 | the bias is inverted — a finding in itself, requires a fresh preregistration before acting |

**This is the criterion the trader's §26 was missing: a condition under which
the fundamental engine gets abandoned.** Without it the experiment cannot fail,
and an experiment that cannot fail teaches nothing.

---

## 5. TEST C — confluence on real trades  ·  PROBABLY UNANSWERABLE

The original §26. Recorded faithfully because the data is unrecoverable, with no
expectation of reaching significance.

**Recorded per trade:** date, fundamental bias, score, conviction, environment,
event risk, technical bias, confluence yes/no, taken/skipped, result in R.

**Reported as descriptive statistics only.** No significance claim will be made
below n = 776 per §2. Any interim number is an observation, never a conclusion.

[DERIVED] The greatest risk in this test is not that it fails. It is that a
favourable interim number gets believed. At n = 40 a difference of 10 pp is
entirely consistent with noise.

---

## 6. Positive control

[OBSERVED] FINDINGS-001 §4.5: a control that measures nothing is worse than no
control. E-MT5-022 lacked one, and a motor that destroyed signal would have
produced an identical-looking result.

**Control for Test A:** the same in-window/out-of-window split applied to a
quantity that MUST differ — realised M5 range. Event windows are known to carry
larger ranges. If the pipeline reports no difference in range either, the
pipeline is broken, not the hypothesis.

**Control for Test B:** the same match statistic computed against a **randomly
signed bias**, generated daily from a seeded RNG and recorded alongside. It must
land at 50%. If the random arm deviates significantly, the accounting is wrong.

---

## 7. What would invalidate this experiment

- Any change to a weight or threshold in SPEC-FUND-001 after a result is seen.
- Any report produced for a past date. The analyst knows what happened after it;
  such a report is contaminated by construction and is not admissible evidence.
- Any day whose report is written after the NY close but timestamped as morning.
- Reading Test C's interim numbers as a conclusion.

**Reports are sealed the day they are produced, before the outcome is known.**
A report that cannot be sealed before the outcome does not enter the sample.

---

## 8. Registry

Daily rows appended to `spec/experiments/mt5/fundamental-log.csv`:

    date, session, bias, score, conviction, environment, event_risk,
    random_control_bias, eurusd_open_ny, eurusd_close_ny, daily_direction,
    match, notes

Signal-level data for Test A comes from the detector's own CSVs, which now carry
the event-risk columns — no manual transcription, so no transcription bias.

---

## 9. Honest summary

Test A is worth running: it is cheap, fast, attacks the term that actually
decides profitability, and can fail cleanly.

Test B is worth recording: it is slow but it is the real question about whether
the fundamental score means anything.

Test C is worth recording and not worth believing for years.

[INFERRED] The most likely outcome of the whole exercise, given this project's
measured base rate, is that Test A confirms an execution-cost effect already
established by E-MT5-032, and that Test B finds nothing. Recording that
faithfully would still be a better result than a fundamental engine believed
without evidence.
