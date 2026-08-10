# E-MT5-028 — PRE-REGISTRATION: FOCAL SIGNAL ON VIRGIN GBPUSD

    STATUS      PRE-REGISTRATION. Sealed BEFORE any GBPUSD tick is downloaded
                or examined. No GBPUSD price data has ever been read by this
                project at the time of writing.
    DATE        2026-08-10
    REPLICATES  E-MT5-027 (exploratory, EURUSD, contaminated sample)

---

## 1. Why this experiment

[OBSERVED] On EURUSD 2024-2026, the focal reversal signal with optimised
execution produced win rate 33.57% (n=1717), PF 1.0086, final balance $10,862 —
the first non-negative economic result of the project.

[OBSERVED] But `z = +0.20` against break-even and the 95% CI is
[31.33%, 35.80%], which **contains** the break-even of 33.33%. The result is
statistically indistinguishable from having no edge at all. EURUSD is a
contaminated sample: it cannot confirm anything.

[DERIVED] The only way to learn whether the +1.06 pp over random is real is to
measure it on an instrument this project has never read.

## 2. Data status — established by census, without reading prices

[OBSERVED] `Bases/MetaQuotes-Demo/ticks/` contains 177 monthly tick files for
EURUSD only. GBPUSD, USDJPY, USDCHF and AUDUSD have an empty tick directory
(124 KB `ticks.dat`, zero `.tkc` files). **GBPUSD tick data is virgin.**

## 3. Sample-preserving decision

[PROPOSED] Only **2024.01.01 → 2026.08.08** of GBPUSD is consumed, matching the
EURUSD window exactly. GBPUSD **2011–2023 is deliberately left untouched** and
reserved as a higher-powered confirmation sample should this test justify one.

Rationale: the matched window is the cleanest possible contrast (same period,
same macro regime, different instrument). Burning all of GBPUSD now would repeat
the EURUSD mistake.

## 4. The two runs — both required

The economic null is instrument-specific because the spread differs. It must be
measured on GBPUSD, not imported from EURUSD.

    RUN A   E-MT5-025 random-entry control, GBPUSD, sealed config
            -> establishes the empirical null for THIS instrument
    RUN B   E-MT5-027 focal signal mode 0, GBPUSD, sealed config
            -> the signal

Both use identical stop, target, sizing, expiry and position policy.

## 5. Sealed configuration — no parameter may differ from EURUSD

| parameter | value |
|---|---|
| Grid | 10 pips |
| U (arming) | 4 pips |
| Stop | 20 pips |
| Target | 2.0 R |
| Entry | limit order at the level |
| Limit expiry | 3600 s |
| Sizing | **fixed $100 risk per trade** |
| Max positions | 1 |
| Mode | 0 (reversal at the focal level) |
| Symbol / TF | GBPUSD / M5 |
| Model | 4 — every tick, real ticks |
| Range | 2024.01.01 → 2026.08.08 |
| Deposit | $10,000 |

## 6. Primary endpoint

    Δ = winrate(RUN B)  −  winrate(RUN A)

Prediction from EURUSD: Δ ≈ +1.06 pp.

Secondary: win rate of RUN B against the structural break-even of 33.333%;
profit factor; final balance; maximum drawdown.

## 7. PRE-REGISTERED PREDICTION — the falsifiable claim

> **The focal signal will NOT exceed the random-entry control by a statistically
> significant margin on GBPUSD.**

[INFERRED] This is the expected outcome: the EURUSD estimate had `z = +0.58`
against random, which is well inside noise. Recording the prediction in advance
is what makes a crossing informative rather than retrofitted.

## 8. POWER — declared honestly, in advance

[DERIVED] To detect Δ = +1.06 pp at α = 0.05 with power 0.80 requires ≈ 31,000
trades per arm. The matched window yields roughly 1,700.

> **This experiment is underpowered by a factor of ~18 for the effect it is
> nominally testing, and that is stated before measuring.**

What it CAN do, and why it is still worth running:

- It has ample power to detect a **large negative** result. The 1-2-3 pattern
  ran at −5 pp; anything of that magnitude would be unmistakable here.
- It estimates the sign and rough magnitude on virgin data.
- It costs one download and two runs of ~30 s each.

## 9. Decision criteria — fixed before measurement

    (A)  Δ significantly NEGATIVE  (z < −1.96)
         -> the focal signal is anti-predictive on virgin data.
            H-FOCAL is dead. Do not tune. Report and stop.

    (B)  Δ significantly POSITIVE  (z > +1.96)
         -> surprising given the power. Justifies spending GBPUSD 2011-2023
            as a properly powered confirmation. Still not an edge claim.

    (C)  Δ not significant, sign POSITIVE, and RUN B profit factor > 1
         -> consistent with EURUSD but unconfirmed. UNDERPOWERED.
            Justifies the reserved sample ONLY if the sign matches.

    (D)  Δ not significant, sign NEGATIVE
         -> EURUSD result was noise. H-FOCAL loses its last support.
            Do not spend the reserved sample.

## 10. What this experiment will NOT do

- will not tune grid, U, stop, target, expiry or sizing
- will not switch mode after seeing results
- will not select a sub-period
- will not substitute another instrument if GBPUSD disappoints
- will not treat a positive result as evidence of a tradeable edge
- will not consume hypothesis budget (this is a REPLICATION, cost 0)

[NOT ESTABLISHED] That any tradeable edge exists. The EURUSD result is
compatible with pure chance and is treated as such.
