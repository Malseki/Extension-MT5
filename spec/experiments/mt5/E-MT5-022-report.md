# E-MT5-022 — REPORT: OUT-OF-SAMPLE VALIDATION OF THE H4 LEVEL PROVIDER

    STATUS       COMPLETE. SEALED.
    RESULT       NEGATIVE. The pre-registered prediction HELD.
    RAW          spec/experiments/mt5/raw/2026-08-09T2013Z-E022-oos-2012-2023/
    PREREG       spec/experiments/mt5/E-MT5-022-oos-preregistration.md
                 sealed at commit 6b93045, BEFORE this run existed.

---

## 1. WHAT WAS MEASURED

[OBSERVED] The binary `c99ec72d`, byte-identical to the one that produced the
in-sample result, was run unchanged over **2012.01.01 → 2023.12.31** — 12 years
that no sealed experiment had ever read.

    336,924,773 ticks    891,965 M5 bars    187,518 signals
    544,240 penetrations    78,254 no-resolve    170 gap
    0 orders sent, 0 positions opened, final balance 10000.00 USD (observer)

## 2. PRIMARY ENDPOINT — pivot H4 at X=5

    n = 1,863    k = 479    p̂ = 25.71%    z = −6.98
    95% CI (Wilson) [23.78%, 27.74%]

[OBSERVED] The null of 33.333% lies far outside the interval. The
**pre-registered prediction — "H4 will NOT exceed 33.333%" — HELD.**

[OBSERVED] Decision region **(A)**: below the null with large n.

## 3. THE IN-SAMPLE H4 RESULT WAS SMALL-SAMPLE NOISE

| window | n | p̂ | z |
|---|---|---|---|
| in-sample 2024–2026 | 367 | 31.06% | −0.92 |
| **out-of-sample 2012–2023** | **1,863** | **25.71%** | **−6.98** |

[DERIVED] The entire reason this experiment was run — that H4 was "the only cell
not clearly negative" — does not survive contact with more data. At 5× the
sample the H4 cell collapses into the same regime as everything else.

## 4. THE MONOTONE GRADIENT DID NOT REPLICATE

This is the more important finding.

    in-sample       A' 26.60%  <  H1 29.52%  <  H4 31.06%     monotone
    out-of-sample   A' 25.97%  ,  H1 26.61%  ,  H4 25.71%     H4 is BELOW H1

[DERIVED] The interpretation carried out of E-MT5-021 — "the more significant
the level, the closer to the null" — was an artifact of the in-sample window. It
is not a property of the market. Level significance does not order the outcome.

[DERIVED] Consequently the reasoning that motivated raising the level to H1/H4
is void. "Raising the reference level reduces the damage" is **withdrawn**.

## 5. ROBUSTNESS — [POST-HOC DESCRIPTIVE, selects nothing]

H4 at X=5, partitioned by year. Declared post-hoc; no subset is used to select
any parameter, provider or window.

    12 of 12 years below the null. Zero exceptions.
    range of yearly p̂: 17.75% (2015) to 30.54% (2013)
    BUY   n=928  p̂=25.97%  z=−4.76
    SELL  n=935  p̂=25.45%  z=−5.11

[OBSERVED] Consistent with E-MT5-018, where 27 of 27 structural partitions fell
below the null.

## 6. WHAT IS NOW ESTABLISHED

[DERIVED] The sequence *sweep of a reference level → 3-bar rejection → entry on
bar 4*, evaluated as P(+2R before −1R) with a stop below the sweep extreme, has
**no positive directional edge** at any of the three level scales tested, in
either window, in any year, in either direction.

[OBSERVED] The result is not merely null — it is systematically **negative**.
Across every provider and every X, p̂ lands in 24–28% against a 33.33% null.
Entering in the direction of the rejection performs materially worse than chance.

[DERIVED] Outcomes improve monotonically with X (padding below the sweep
extreme) in every provider, consistent with part of the damage being stop noise
at the sweep extreme. But even the loosest stop tested (X=15) sits at z=−5.50.
Stop noise does not account for the effect.

## 7. WHAT IS *NOT* ESTABLISHED

[NOT ESTABLISHED] That the mirror of this pattern is profitable. A p̂ of 25.7%
against a 2:1 payoff does not convert into an edge by inversion — the payoff is
asymmetric and real spread must still be paid. Nothing here was measured about
the complement, and nothing here licenses trading it.

[NOT ESTABLISHED] That this generalizes beyond EURUSD, or beyond this broker.
The A-6 violation stands: H1/H4 bars come from the platform, so the result is
broker-dependent.

[NOT ESTABLISHED] Anything about the 8 BLOCKED stages (CONFIRMATION, MSS, FVG,
RETRACEMENT, HTF, SESSION, ACCUMULATION, DPMO). This experiment tested the bare
1-2-3 sequence. It does not speak to the full multi-timeframe machinery the
brief describes.

No LOCKED decision was touched. X was not selected. PAD vs FLOOR remains OPEN
and still blocks any economic run.

## 8. A CONSTRAINT THAT NOW EXISTS

[DERIVED] The cached tick history runs 2011.12 → 2026.08 and **all of it has now
been examined**. There is no remaining virgin sample of EURUSD on this server.

Any new hypothesis therefore requires one of:
  - a different instrument, held out and pre-registered before measurement, or
  - forward data accumulated after today, or
  - explicit acceptance that the test is in-sample and cannot confirm anything.

This is the cost of the experiment and it is worth stating plainly: the answer
was bought with the last of the unseen data.

## 9. RECOMMENDATION

Per the pre-registered decision criteria, region (A) prescribes: declare the
absence of edge, and **reformulate the market hypothesis** rather than continue
adjusting this one. Tuning X, switching providers, or relaxing SW-6 are all
excluded — the effect is not marginal, it is −7σ, and it is uniform across every
partition measured.

The honest summary: this formulation of the sweep-rejection pattern does not
contain directional information, and now it is known with evidence that can be
verified by anyone who re-runs the sealed binary over the sealed range.
