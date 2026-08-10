# E-MT5-031 — PRE-REGISTRATION: BEARISH-IMPULSE REBOUND ON RESERVED GBPUSD

    STATUS   PRE-REGISTRATION. Sealed BEFORE any GBPUSD tick before 2024 is
             downloaded or examined. This project has never read GBPUSD
             2012-2023; it was deliberately reserved in E-MT5-028 §3 for
             exactly this kind of test.
    DATE     2026-08-11
    TESTS    the post-hoc observation recorded in E-MT5-030.

---

## 1. Where the hypothesis comes from, and why that is a problem

[OBSERVED] E-MT5-030 measured impulse continuation on EURUSD 2024-2026 and
found impulses REVERT: P(continue) = 47.95%, z = -4.24, n = 10,674. Consistent
with E-MT5-029 by an independent method.

[OBSERVED] Splitting by direction **after seeing the results**:

| | n | P(rebound) | z | net EV |
|---|---|---|---|---|
| bullish impulse | 5,180 | 51.14% | -1.64 | -0.233 pips |
| bearish impulse | 5,494 | **52.91%** | **-4.31** | **+0.121 pips** |

[NOT ESTABLISHED] That this is real. **The direction split was chosen after
inspecting the data.** That is precisely the manoeuvre that produced the
$10,862 balance in E-MT5-027 which collapsed to $12.23 on virgin GBPUSD in
E-MT5-028. The project has already been burned by exactly this once.

This experiment exists to submit that observation to a fair test.

## 2. Sample — the last reserved virgin data

[OBSERVED] GBPUSD 2024.01.01-2026.08.08 was consumed by E-MT5-028.
**GBPUSD 2012.01.01-2023.12.31 has never been read by this project.**

[DERIVED] This is the last untouched sample of meaningful size available. After
this test there is no reserved historical data left; anything further requires
forward data accumulated from today.

## 3. Sealed configuration — identical to E-MT5-030, no parameter may differ

| parameter | value |
|---|---|
| Binary | `E-MT5-030-impulse-continuation.ex5`, byte-identical |
| Impulse | 5.0 pips over 1 M5 bar |
| Race | symmetric, ±10 pips from trigger |
| Cooldown | 300 s |
| Timeout | 86,400 s |
| Symbol / TF | GBPUSD / M5 |
| Model | 4 — every tick, real ticks |
| Range | 2012.01.01 → 2023.12.31 |

No code is written for this experiment. The same observer runs on a new range.

## 4. Primary endpoint and null

    PRIMARY   p_rebound = P(price reaches -10 pips before +10 pips
                           | bearish impulse of 5 pips in 5 min)

    MECHANISM NULL    p = 50%   (symmetric race on a driftless walk)
    ECONOMIC THRESHOLD p = 52.31%

[DERIVED] The economic threshold is not chosen, it is computed. With a ±10 pip
race and the measured spread of 0.4614 pips:

    EV = 10·(2p − 1) − 0.4614 = 0   ⟹   p = 52.307%

Below 52.31% the effect may be real and still lose money.

## 5. PRE-REGISTERED PREDICTION

> **The bearish-impulse rebound will NOT exceed 52.31% on reserved GBPUSD.**

[INFERRED] Expected because the observation is post-hoc, and because four
previous hypotheses in this project died on virgin data. Registering the
prediction in advance is what makes a crossing meaningful.

## 6. Power — and for once it is adequate

[DERIVED] Expected n: EURUSD 2.6 years produced 5,494 bearish impulses; GBPUSD
over 12 years should produce ≈ 25,000.

| to detect | n required | have | verdict |
|---|---|---|---|
| p > 50% at the observed 52.91% | 2,315 | ~25,000 | **10× over-powered** |
| p > 50% at a smaller 52.00% | 4,900 | ~25,000 | **5× over-powered** |
| p > 50% at 51.50% | 8,711 | ~25,000 | **3× over-powered** |
| **p > 52.31% when truth is 52.91%** | **54,444** | ~25,000 | **UNDER-powered 2.2×** |

[DERIVED] **Declared honestly in advance:** the test has ample power to decide
whether the mechanism exists (beats 50%), and **insufficient power to confirm
that it clears the economic threshold** if the true effect is as small as the
EURUSD estimate. A result between 50% and 52.31% will therefore be reported as
*real but not demonstrably exploitable*, not as a win.

## 7. Decision criteria — fixed before measurement

    (A) p_rebound ≤ 50% or not significant
        → the EURUSD asymmetry was post-hoc noise. Hypothesis dead.
          No further testing. No forward deployment.

    (B) 50% < p_rebound < 52.31%, significant vs 50%
        → mechanism REAL, economically insufficient at this race size.
          Report. Do NOT trade. Do NOT tune the race size to make it fit.

    (C) p_rebound ≥ 52.31%, significant vs 50%
        → first genuinely exploitable finding of the project.
          Still requires forward validation before any deployment.

    (D) bullish impulse also ≥ 52.31%
        → the asymmetry does not exist; the effect is symmetric reversion,
          already known from E-MT5-029/030. Not a new finding.

## 8. Mandatory control — the bullish arm

The bullish impulse is measured in the same run, from the same races. The
asymmetry claim requires bearish > bullish. If both behave alike, the
directional story is refuted regardless of the absolute numbers.

## 9. What this experiment will NOT do

- will not tune impulse size, race size, cooldown or timeout
- will not switch instrument if GBPUSD disappoints
- will not select a sub-period
- will not report a sub-window that looks better
- will not treat criterion (C) as permission to trade real money
- will not consume hypothesis budget: this is a REPLICATION of E-MT5-030

[NOT ESTABLISHED] That any tradeable edge exists. Four hypotheses have died on
virgin data in this project. The base rate says this one dies too.
