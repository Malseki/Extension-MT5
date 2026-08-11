# FINDINGS-001 — WHAT THIS PROJECT ESTABLISHED

    STATUS   CONSOLIDATED. Every claim here is backed by a sealed experiment
             with its SHA-256 in spec/experiments/mt5/raw/.
    DATE     2026-08-11

---

## 1. The one-paragraph version

Intraday FX **does** contain a measurable inefficiency: prices revert after
short impulses. It is real, it replicates across instruments, methods and
twelve years of untouched data. It is also **not exploitable by a retail
taker**, and the reason is precise: the cost of accessing it rises exactly
when it appears. The spread at the instant of a signal is 1.3–2.0× its own
average, which is 1.5–3.6× the entire edge.

The project did not fail to find an edge. It found one, measured it, measured
its price, and established that the second is larger than the first.

---

## 2. What is ESTABLISHED

### 2.1 Intraday prices revert  [OBSERVED, three independent confirmations]

| experiment | method | instrument | result |
|---|---|---|---|
| E-MT5-029 | Lo-MacKinlay variance ratio | EURUSD | VR < 1 at every intraday scale |
| E-MT5-030 | symmetric race after impulse | EURUSD | P(continue) 47.95%, z = −4.24 |
| **E-MT5-031** | same, **virgin GBPUSD 2012-23** | GBPUSD | **P(revert) 52.81%, z = +18.50, n = 108,678** |

Three methods, two instruments, one conclusion. This is the most solid result
of the project and it survived preregistration on data nobody had read.

### 2.2 The execution tax law  [DERIVED, verified on two instruments]

    P(target before stop) = 1/3 − s/(3D)

where `s` is the spread and `D` the stop distance. Verified in E-MT5-024/025:

| stop | predicted | measured | error |
|---|---|---|---|
| 5 pips | 30.26% | 29.61% | 0.65 pp |
| 10 pips | 31.58% | 31.34% | 0.24 pp |
| 20 pips | 32.36% | 31.51% | 0.85 pp |
| GBPUSD 20 pips | 32.17% | 31.81% | 0.36 pp |

**The structural null of 1/3 applies only to a costless observer.** Any system
crossing the spread starts below it. This invalidated the way every earlier
result in the project had been read.

### 2.3 The spread is correlated with the signal  [OBSERVED, E-MT5-032]

| instrument | avg spread | at signal | ratio |
|---|---|---|---|
| EURUSD | 0.4273p | 0.8360p | **1.96×** |
| GBPUSD | 1.3506p | 1.7601p | **1.30×** |

Measured over 460 million ticks. Signals fire when price moves; market makers
widen when price moves. **The correlation is structural, not incidental.**

This is the finding that closes the economic question, and the one most likely
to be missed by anyone testing a strategy with average-spread assumptions.

### 2.4 Position sizing matters as much as the signal  [OBSERVED, E-MT5-027]

Identical trades, identical R, only the sizing rule changed:

    fractional 1% of live balance    R = +9.8   final balance $9,124
    fixed $100 risk per trade        R = +9.8   final balance $10,862

Volatility drag cost $1,738 on a strategy with positive R. A positive
expectancy can still lose money under fractional sizing after a drawdown.

---

## 3. What is REFUTED

| hypothesis | verdict | evidence |
|---|---|---|
| 1-2-3 sweep + rejection | **refuted, −7σ** | E-MT5-022, 12 years OOS, 12/12 years below null |
| level significance gradient (A′<H1<H4) | **withdrawn** | did not replicate; H4 fell below H1 |
| tick order-flow imbalance | **null** | E-MT5-026, P(up) = 50.20%, z = +0.24 |
| H-FOCAL round-number levels | **refuted** | E-MT5-028, virgin GBPUSD, −2.91 pp vs random |
| bearish-impulse asymmetry | **refuted** | E-MT5-031, asymmetry inverted, z = −2.65 |
| impulse continuation (momentum) | **refuted** | E-MT5-030, impulses revert instead |

Six hypotheses. Every single one that looked promising in-sample died on
virgin data. **That is the base rate of this domain, measured firsthand.**

---

## 4. Methodological findings that cost us the most to learn

**4.1 In-sample positives do not survive.** Twice a result looked good and
collapsed on virgin data: the H4 cell (z = −0.92 → −6.98) and the H-FOCAL
economic run ($10,862 → $12.23). Preregistration caught both before further
spend.

**4.2 The economic threshold is instrument-specific.** E-MT5-031 was
preregistered with the EURUSD spread applied to a GBPUSD test. Every EV flipped
sign once corrected. Thresholds must be recomputed per instrument.

**4.3 Averages hide the cost that matters.** §2.3. A cost averaged over all
ticks is not the cost a movement-triggered strategy pays.

**4.4 Data corruption imitates edge.** December 2014 in GBPUSD showed 96.21%
reversion with a median duration of 0.0 minutes and 39% of races resolving
under 60 seconds. Anyone optimising over that window would have built a
spectacular system on a broken feed.

**4.5 A control that measures nothing is worse than no control.** E-MT5-022 had
no positive control: a motor that destroyed signal would have produced an
identical-looking result. Every subsequent experiment carries one.

**4.6 A modal dialog can silently kill a live system.** `Alert()` froze the
expert thread under Wine after the first alert; the system appeared to run
while processing nothing.

**4.7 A live detector can be blind while looking perfectly healthy.** From
2026-08-10 to 2026-08-11 the detector ran with `ticks = 0`. `OnTick()` is
never delivered under Wine when the chart does not render; all detection lived
inside it, so no early warning, impulse or level touch could ever fire. What
kept working was `OnTimer()`, a system timer independent of the chart — so the
panel refreshed, the price moved, M5 bars were logged, and the heartbeat
advanced once per second. Every visible sign of health was produced by the one
path that still worked.

Two failures compounded it. The startup preset `ta1demo.set` set
`InpPopup=true`, the value the source marks as fatal (§4.6), and
`InpDemoMode=true`, arming at 1 pip; the preset silently overrode both safe
defaults. And the scan of E-MT5-035 had been attached to the same EURUSD M5
chart, evicting the detector — one chart runs one expert.

Fixed 2026-08-11: detection extracted to `Pulse()`, called from `OnTick()` and
from `OnTimer()`, guarded by `time_msc` against double counting. Cost of the
fallback: detection resolves to 1 s instead of per tick, so a level touched and
reverted inside the same second is missed — symmetrically for hits and misses,
so it does not bias direction.

**The lesson generalises past this bug: a liveness signal must be produced by
the path being trusted, not by a neighbouring one.** The heartbeat proved the
timer was alive and was read as proof the detector was alive. `ticks = 0` sat
in plain sight in the panel for two days.

---

## 5. What remains open

- **Providing liquidity instead of taking it.** The entire barrier is that we
  pay the spread precisely when it widens. A maker strategy would collect it.
  This is a different product with different requirements and has not been
  studied. [NOT ESTABLISHED]
- **Forward data.** No untouched historical sample remains. The live detector
  is the only virgin data that will exist from here. **It accumulated nothing
  usable between 2026-08-10 and 2026-08-11:** see §4.7. Signal capture starts
  2026-08-11 12:00 local; M5 bars before that are intact but sparse, and there
  are no signals at all in that window because none could be detected.
- **Whether the reversion effect is stable going forward.** Neely et al. showed
  FX technical edges died in the mid-1990s. Nothing guarantees this one persists.

---

## 6. The honest bottom line

For a retail taker, on these instruments, with these costs: **there is no
tradeable edge here, and we know precisely why.**

That is a real answer to a real question, obtained without curve fitting,
without a single optimised parameter, and reproducible by anyone who re-runs
the sealed binaries over the sealed ranges.

It is worth more than a green backtest, because it is true.
