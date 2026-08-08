# MT5-EXP-001 — History and Replayability

*Parts VIII and IX. What MT5 remembers, whether "no event" is distinguishable
from "no data", and what the minimum input for deterministic replay is.*

**No experiment has been executed.** See `experiments/mt5/README.md` §1. This
document states what must be measured, what is expected, and what each possible
outcome would mean — written *before* the data, so the interpretation cannot be
fitted to it afterwards.

---

# 1. The constitutional question

> Can the engine distinguish **NO EVENT** from **DATA NOT AVAILABLE**?

It matters because the two license opposite conclusions. "No FVG was mitigated" is
a fact that can satisfy a negative condition. "We do not know whether an FVG was
mitigated" must not. Collapsing them is `RT-03`'s negation-as-failure hazard
arriving through the data layer instead of the logic layer.

**Answer, `[DOC]`: yes, for three of the four cases, and MT5 supplies the
mechanism directly.**

| Situation | MT5 signal | Maps to |
|---|---|---|
| Data present, nothing happened | copy succeeds, values valid | `FALSE` |
| Series not yet synchronised | `CopyRates` → `-1`, `SERIES_SYNCHRONIZED` false, `Bars` = 0 | `⊥` |
| Range outside broker history | copy returns `0` or `-1` for that range | `⊥` |
| **Minute with no ticks** | **no bar exists — indistinguishable from "not loaded" without a calendar** | **ambiguous** |

The fourth row is `D-M2`. It is the only genuine gap, and `E-MT5-007`'s gap scan
measures how often it occurs.

> **This is the strongest empirical support the `⊥` value domain has.** `⊥` was
> derived formally three times over (missing bars, exogenous clock, three-valued
> logic). MT5 returning `-1` for "not synchronised" is a fourth, independent
> arrival at the same requirement — from the platform rather than the theory.

---

# 2. What must be measured

Each row is a prediction. Recording them now makes them falsifiable.

| # | Measurement | Instrument | Prediction (`[BELIEF]`) | If the prediction is wrong |
|---|---|---|---|---|
| M-1 | Bar history depth per timeframe | `E-MT5-007` DEPTH | Deep on M1 (years), deeper on HTF; bounded by broker retention × "Max bars in chart" | If M1 is shallow, HTF must be taken from the terminal, and `A-6` fails outright rather than partially |
| M-2 | Real tick history start date | `E-MT5-007` TICKRANGE | Far later than bar history — order of a few years, broker-dependent | If tick history is absent, `D-M4` resolves itself: ask-based penetration is not available historically at all |
| M-3 | Count of missing M1 bars inside sessions | `E-MT5-007` GAPS | `> 0` even on liquid FX; concentrated at session edges and rollover | If zero, `H-09` (`Bars` vs `Elapsed`) becomes a non-decision for FX and can be closed cheaply |
| M-4 | Behaviour of an impossible range (1990) | `E-MT5-007` UNAVAIL | Returns `0`/`-1` with an error, never a silent empty success | If it returns a silent empty success, **the `⊥` mechanism is unreliable** and `H-02`/`DEC-012` lose their platform support |
| M-5 | Cold-start synchronisation latency | `E-MT5-004` | Seconds; several probes fail before the first success | If long or unbounded, engine startup needs an explicit warm-up state (`H-18`) rather than a retry |
| M-6 | Repeated identical requests | `E-MT5-004` | Fail then succeed with identical arguments — reads are **not** referentially transparent until synchronised | If already transparent, one hazard disappears |
| M-7 | Per-symbol history differences | `E-MT5-005`, `E-MT5-007` per symbol | Different depths and different missing minutes per symbol | If identical, cross-symbol bar-index alignment would be safe — but it should still not be used |

---

# 3. Replayability

## 3.1 The requirement

```
same historical input → same engine state → same output
```

## 3.2 Is M1 sufficient? — proved insufficient in general

> **THEOREM.** M1 bars are **not** a sufficient replay input for any rule whose
> value depends on the order of price movement within a minute.
>
> *Proof.* An M1 bar records `O, H, L, C` but not whether `H` preceded `L`. Two
> distinct tick paths — one reaching `H` then `L`, the other `L` then `H` —
> produce the identical M1 bar. A rule that distinguishes them therefore cannot be
> a function of M1 bars. ∎
>
> **The methodology contains such a rule.** A sweep is *penetration then
> rejection*. When both occur inside one minute, the sweep's existence depends on
> the order. ∎

> **COROLLARY (the fork).** Exactly one of these must be true, and the project
> must choose:
>
> **(a)** Every rule is evaluated on **bar closes only** at the base timeframe,
> and no rule may depend on intrabar order. Then **M1 is sufficient**, replay
> works on M1 bars, the corpus is as deep as bar history, and generated tester
> modes are valid.
>
> **(b)** Intrabar rules are permitted. Then **tick data is required**, replay
> works only where real tick history exists, and only the real-ticks tester mode
> is valid (`MT5-CAP-001` §6).
>
> There is no middle option. A rule that is "usually" bar-close-only still forces
> (b) if any exception exists.

This is `DEC-002` (evaluation clock) meeting `D-M5` (valid tester modes), and MT5
turns what looked like an efficiency preference into a **corpus-size decision**.
`M-2` measures the price of (b).

## 3.3 Minimum input per option

| Option | Minimum replay input | Corpus depth | Valid tester modes |
|---|---|---|---|
| (a) bar-close only | M1 bars | full bar history (years–decades) | all modes; generated ticks harmless because unused |
| (b) intrabar permitted | ticks (`COPY_TICKS_INFO`) | real tick history only (`M-2`) | real ticks only |

## 3.4 What replay needs beyond price data

Even under (a), reproducing a run requires more than bars. From `RT-07`, `RT-16`
and `REDTEAM-003` §7:

```
run identity = (spec version, selectors, thresholds, data snapshot,
                symbol metadata at that time, broker/server identity,
                corpus version if any parameter was fitted)
```

MT5 supplies **none** of these as a versioned artifact. Bars can be re-downloaded
and silently differ; symbol specs change (`H-19`); the broker is not recorded in
the data. **A replay harness must capture and freeze the inputs itself** — MT5
cannot be trusted as the system of record for reproducibility.

> That is an architectural consequence, not an implementation detail: it means the
> project needs its own immutable data store, and "just point it at MT5 history"
> is not a reproducible procedure.

---

# 4. Execution protocol

1. Run `E-MT5-007` on a **cold** terminal, then on a **warm** one, per symbol.
2. Run `E-MT5-004` immediately after a terminal restart.
3. Run `E-MT5-006` live, then once in **each** tester mode on the same date range.
4. Return the CSVs with the environment block from `experiments/mt5/README.md` §5.

Until then, every row in §2 stays a prediction, and no conclusion in this document
may be cited as evidence.
