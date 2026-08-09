# E-MT5-022 — PRE-REGISTRATION: OUT-OF-SAMPLE VALIDATION OF THE H4 LEVEL PROVIDER

    STATUS      PRE-REGISTRATION. Written and sealed BEFORE any measurement is
                taken on the target window. No result from 2012–2023 has been
                observed by anyone at the time of writing.
    SUPERSEDES  nothing. EXTENDS E-MT5-021 (discovery/replication, in-sample).
    DATE        2026-08-09

---

## 1. WHY THIS EXPERIMENT

[OBSERVED] E-MT5-021 measured P(+2R before −1R) for three reference-level
providers over 2024.01.01→2026.08.08, against the structural null of 1/3:

| provider   | n      | p̂      | z      | median level age |
|------------|--------|--------|--------|------------------|
| A′ K=3 M5  | large  | 26.60% | −28.14 | 3 bars           |
| pivot H1   | —      | 29.52% | −3.01  | 96 bars          |
| pivot H4   | 367    | 31.06% | −0.92  | 375 bars         |

[OBSERVED] A monotone gradient exists — the more significant the level, the
closer to the null — but nothing crosses it. The H4 cell is the only one that is
not clearly negative, and its 95% CI [28.10%–37.65%] contains the null.

[DERIVED] With n=367 the H4 cell cannot distinguish "no edge" from "a small
edge". Only more sample can. The 2012–2023 window supplies it and has never
been examined.

## 2. DATA VIRGINITY — the basis of the out-of-sample claim

[OBSERVED] Real tick data is cached on disk for EURUSD covering 2011.12→2026.08,
177 monthly `.tkc` files, 1.52 GB, no missing month. The pre-2024 files were
downloaded 2026-08-07T20:00 local.

[OBSERVED] All 15 sealed experiment directories under `spec/experiments/mt5/raw/`
declare their range. Every one runs on `2024.01.01→2026.08.08`, except two smoke
tests on 2026.07.09→2026.07.10. **No sealed experiment has ever read a tick
before 2024.01.01.**

[DERIVED] Therefore 2012.01.01→2023.12.31 is genuinely out-of-sample: the H4
provider hypothesis was formed on 2024–2026, and the target window was never
observed while forming it.

## 3. HYPOTHESIS AND PREDICTION

    H0   For the H4 provider, P(+2R before −1R) = 1/3.
    H1   For the H4 provider, P(+2R before −1R) ≠ 1/3.

**PRE-REGISTERED PREDICTION — the falsifiable claim:**

> The H4 provider will NOT exceed 33.333% in the unseen window.

[INFERRED] This is the expected outcome given that 27 of 27 structural
partitions in E-MT5-018 fell below the null and no provider in E-MT5-021 crossed
it. Recording it in advance is what makes a crossing informative rather than
retrofitted.

## 4. ENDPOINTS — fixed before measurement

    PRIMARY     provider = pivot H4, X = 5.  One cell. One test.
    SECONDARY   H4 at X ∈ {1, 15}; H1 and A′ M5 at X ∈ {1, 5, 15}.
    TEST        two-sided one-proportion z-test against p0 = 1/3.
    ALPHA       0.05 for the primary endpoint.
                Secondary endpoints: Bonferroni over the 9 cells, α = 0.00556,
                |z| > 2.77 required.

Signals whose outcome is UNRESOLVED (code 3) are excluded from the denominator,
identically to E-MT5-021. No other filtering, trimming or windowing is permitted.

## 5. POWER — declared in advance

[DERIVED] Expected n for the H4 cell: 367 × (144 months / 32 months) ≈ 1,650.

    standard error at p0, n=1650      1.16 pp
    MDE, primary endpoint (α=.05)     ±2.27 pp  →  detectable if p ≥ 35.6%
    MDE, Bonferroni (|z|>2.77)        ±3.21 pp  →  detectable if p ≥ 36.5%

## 6. THE EXPLOITABILITY THRESHOLD — declared before seeing the number

[OBSERVED] The demo account's spread is 0.031 points. A real broker charges 1–2.
[DERIVED] On a median stop that is ≈0.04 R of cost per trade.

With TARGET_R = 2.0, expected value per trade in R is `3p − 1`. It is zero at
p = 1/3, which is the structural null. Covering 0.04 R of real spread requires:

    3p − 1 = 0.04   →   p ≥ 34.67%

**A result above 33.33% but below 34.67% is a real edge that is not
exploitable.** This threshold is fixed now so it cannot be moved later.

[DERIVED] Note the uncomfortable gap: the exploitability floor is 34.67% but the
Bonferroni-detectable floor is 36.5%. An edge living between those two values
would be economically meaningful and statistically undetectable at this sample
size. If the result lands there, the honest report is "underpowered", not
"confirmed" and not "refuted".

## 7. DECISION CRITERIA — fixed before measurement

    (A) H4 below the null with large n
        → the sweep+rejection sequence has no directional edge at any level
          scale. Declare it. Reformulate the market hypothesis. Do NOT tune
          parameters, do not switch providers, do not shorten the window.

    (B) H4 above the null, |z| > 2.77, and p̂ ≥ 34.67%
        → a hypothesis worth developing. Only then does it become meaningful to
          discuss X, PAD vs FLOOR, and the blocked stages.

    (C) H4 above the null but p̂ < 34.67%, or above 34.67% without significance
        → underpowered / not exploitable. Report as such. No decision is taken
          on the strength of it.

## 8. FIXED APPARATUS — no changes permitted

    binary sha256   c99ec72dd29a26a407161c3838a35cfe52cb5511ce0a0963269a5b7d2dbd5e32
                    E-MT5-021-htf-level-provider.ex5  (byte-identical to the
                    binary that produced the in-sample result)
    source sha256   04e1e1c5a25b3dd9fa06d4c309ccea9ed0d7671c1ec7ba19ba59d02684e67fe5
    source blob     644e21fdbb22cc5cbddb5b9a3e1a232503e3293f  @ HEAD 0bbc286
    preset          InpRefK=3 InpPivK=2 InpPivM=2 InpTargetR=2.0 InpHorizon=500
    symbol / tf     EURUSD / M5 execution, H1 and H4 level providers
    model           4 — every tick based on real ticks
    range           2012.01.01 → 2023.12.31
    account         MetaQuotes-Demo 10012089985, trade_mode=0 (DEMO), 1:100

### 8.1 MAXLVL is deliberately NOT changed

[OBSERVED] `MAXLVL = 4096` saturated during the in-sample run and acts as an
undeclared implicit age limit (E-MT5-021 MANIFEST, KNOWN LIMIT).

[DERIVED] The eviction is FIFO over a full array. Once saturated, the effective
age window is set by the *rate* of level creation per unit time — a property of
the market and the parameters — not by the length of the run. The stationary
regime is therefore the same at 12 years as at 2.6 years. What differs is only
the pre-saturation fraction, which is smaller over 12 years. This is an edge
effect.

[DERIVED] Raising MAXLVL would change the binary, break byte-identity with the
in-sample run, and require re-running the in-sample window to restore
comparability. It is deferred: if the H4 result lands in region (B), the
MAXLVL-free re-run becomes worth its cost as an artifact check. If it lands in
region (A), MAXLVL never mattered.

## 9. INHERITED LIMITATIONS — carried forward, not resolved

- **[DECLARED VIOLATION] A-6**: H1/H4 bars are taken from the platform, not
  aggregated from M1 with a declared anchor. The result is BROKER-DEPENDENT.
- **MAXLVL=4096** implicit age limit, per §8.1.
- **DEC-022A/B, DEC-032, DEC-003/004/005** remain OPEN. This experiment does not
  close them and must not be read as closing them.
- The X / PAD-vs-FLOOR gate (§4 of DEC-001) remains **OPEN and BLOCKING** for any
  economic run. This is an observer, not an economic run, so it is not blocked —
  but no result here selects X.

## 10. WHAT THIS EXPERIMENT WILL NOT DO

    - will not choose X
    - will not choose a provider
    - will not choose (k, m)
    - will not enable any BLOCKED stage
    - will not modify any LOCKED decision
    - will not sweep parameters or report a best-of
    - will not shorten, split or re-window the range after seeing results

[NOT ESTABLISHED] Nothing in this document establishes that a tradeable strategy
exists. A negative result is a valid result and will be reported as such.
