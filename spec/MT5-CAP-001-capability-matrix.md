# MT5-CAP-001 — MetaTrader 5 Capability Matrix

*MT5 treated as a semantic target, not an implementation detail. The question
throughout is not "can MQL5 do this" but "can the required information be
observed, at the right time, with the right causal semantics, deterministically
enough".*

> ## ⚠ HEADER SUPERSEDED — 2026-08-07
>
> This document originally opened with *"No claim here is an observation"*,
> because the only MT5 found at the time was a sandboxed App Store build whose
> data folder was unreadable. **That was the wrong installation.** The real
> desktop build is fully accessible and has since been driven directly.
>
> **§§0–10 below are the original predictions, left unedited so they can be
> scored.** The measured results are in **§11** (`E-MT5-006`) and **§12**
> (`E-MT5-008`), and they **refute F5 and F8 as stated**. Read §11–§12 before
> relying on anything above them.

Original labels: `[DOC]` documented · `[BELIEF]` high-confidence but unverified
*at the time of writing* · `[EXP]` open pending an experiment.

---

# 0. The eight findings that matter

| # | Finding | Label | Consequence |
|---|---|---|---|
| **F1** | Bar closure is **tick-driven, not clock-driven**. A bar closes when the first tick at or past its boundary arrives. | `[BELIEF]` `E-MT5-001/002` | `t_known` for every HTF fact is data-dependent with an **unbounded** delay. Instantiates `RT-08` concretely. |
| **F2** | `TimeCurrent()` advances **only on ticks**. | `[DOC]` | MT5's native clock **is** the per-symbol clock `RT-12` warned about. An exogenous clock must come from `TimeTradeServer()`/`OnTimer`. |
| **F3** | A minute with no ticks produces **no M1 bar**. | `[BELIEF]` `E-MT5-003` | `Bars(n)` ≠ `Elapsed(d)`. `H-09` is forced into the open by the platform. |
| **F4** | Bars are built from **Bid** (FX) or **Last** (exchange); **Ask is not in bar data**. | `[DOC]` | A spread-aware sweep needs tick history ⇒ `DEC-008` option S3 has a far shorter usable history than S1/S2. |
| **F5** | ~~**Intrabar tick order is fabricated** in generated tester modes.~~ **`[REFUTED]` — see §12.** | ~~`[DOC]`/`[BELIEF]`~~ | Replaced by a granularity statement: at M5+ the ordering of a bar's own extremes is reproduced faithfully by generated models; at M1 it is not recoverable at all. |
| **F6** | MT5 exposes **no broker timezone or DST schedule**. | `[BELIEF]` | Historical UTC reconstruction from MT5 alone is **impossible**. Weakens `A-6` further than `RT-20` did. |
| **F7** | **Services do not run in the Strategy Tester.** | `[DOC]` | The execution-model choice and the replay requirement are **coupled** (§7). |
| **F8** | `CopyRates`/`CopyTicks` report **not-synchronised** distinctly from empty. | `[DOC]` | MT5 *does* supply the raw material for `⊥` / NOT-AVAILABLE. Good news, and it is load-bearing for `H-02`/`DEC-012`. |

---

# 1. Capability matrix

`Live` = normal terminal. `Tester` = Strategy Tester.

| Requirement | MT5 capability | Live | Tester | Timestamp semantics | Precision | Limitations | Risk |
|---|---|---|---|---|---|---|---|
| Current quote | `SymbolInfoTick` → `MqlTick` | ✓ | ✓ | `time` s, `time_msc` ms, **server time** | symbol digits | `time_msc` **not unique** — several ticks share a ms `[BELIEF]` | Needs `(time_msc, seq)` for a total order — `RT-23` item 3 |
| Bid | `MqlTick.bid`, `SYMBOL_BID` | ✓ | ✓ | as above | digits | — | low |
| Ask | `MqlTick.ask`, `SYMBOL_ASK` | ✓ | ~ | as above | digits | **not in bar data**; tester ask is reconstructed from spread in generated modes `[BELIEF]` | **high** — σ condition 1 |
| Last / volume | `MqlTick.last`, `volume`, `volume_real` | ~ | ~ | as above | — | FX brokers usually supply neither | medium — out of current scope |
| Spread | `SYMBOL_SPREAD`, `MqlRates.spread` | ✓ | ✓ | per-tick vs per-bar | points | **`MqlRates.spread` semantics underdocumented** — which spread of the bar? | **`[EXP]` `E-MT5-006`** |
| M1 bars | `CopyRates`, `iOpen/iHigh/iLow/iClose` | ✓ | ✓ | `time` = **open** time | digits | **non-contiguous** (F3) | high — window semantics |
| HTF bars | same, any `ENUM_TIMEFRAMES` | ✓ | ✓ | open time; boundaries in **server** time | digits | built by the terminal from M1; alignment is broker- and DST-dependent | **high** (F6) |
| Forming bar | shift `0` | ✓ | ✓ | open time of the incomplete bar | digits | **partial and non-final** | **high** — repaint, `A-2` (§3) |
| Closed bar | shift `≥ 1` | ✓ | ✓ | open time | digits | knowably closed only at the next tick (F1) | **high** |
| Bar closure signal | new bar detected by `iTime(...,0)` change | ✓ | ✓ | the detecting tick's time | ms | **no event fires at the nominal boundary** | **high** (F1) |
| Tick history | `CopyTicks`, `CopyTicksRange` | ✓ | ~ | `from_msc`/`to_msc` in ms | ms | broker-dependent depth, typically far shallower than bars | **`[EXP]` `E-MT5-007`** |
| History depth | `Bars`, `SeriesInfoInteger(SERIES_FIRSTDATE)` | ✓ | ✓ | — | — | bounded by broker retention **and** terminal "Max bars in chart" | medium |
| Synchronisation | `SeriesInfoInteger(SERIES_SYNCHRONIZED)`, return `-1` | ✓ | ✓ | — | — | first call may trigger an async load and fail | **F8 — this is the `⊥` source** |
| `iHigh/iLow/...` | built-ins | ✓ | ✓ | shift-indexed | digits | **return `0.0` on missing data instead of erroring** `[BELIEF]` | **high** — silent wrong values |
| `iHighest/iLowest` | built-ins | ✓ | ✓ | shift range | — | `start=0` includes the forming bar | **high** — look-ahead trap (§3) |
| `BarsCalculated` | indicator handles | ✓ | ✓ | — | — | about handles, not price series | low |
| Symbol properties | `SymbolInfoInteger/Double` | ✓ | ✓ | — | — | `SYMBOL_POINT` ≠ `SYMBOL_TRADE_TICK_SIZE` on some instruments `[DOC]` | **high** — comparisons must use tick size |
| Sessions | `SymbolInfoSessionQuote/Trade` | ✓ | ~ | server time-of-day | minutes | per weekday, no holiday calendar | medium |
| Timezone / DST | — | ✗ | ✗ | — | — | **no API** (F6) | **critical** for `A-6` |
| Multi-symbol data | `CopyRates(other, ...)` | ✓ | ✓ | server time | — | must be selected in Market Watch; sync required | medium |
| MTF synchronisation | — | ~ | ~ | — | — | no cross-series barrier; each series syncs independently | **`[EXP]` `E-MT5-004`** |
| Tick event | `OnTick` (EA), `OnCalculate` (indicator) | ✓ | ✓ | tick time | ms | **chart symbol only** | **high** — multi-symbol (§7) |
| Timer event | `OnTimer`, `EventSetMillisecondTimer` | ✓ | ~ | local/modelled | ms | tester timer is modelled, not real-time | medium — the exogenous-clock candidate |
| Alerts | `Alert`, `SendNotification`, `SendMail` | ✓ | ✗ | — | — | suppressed/limited in tester; push is rate-limited `[BELIEF]` | medium |
| Persistence | files, `GlobalVariable*` | ✓ | ~ | — | — | globals are **doubles only**; tester agents have separate sandboxes | **high** (§8) |
| Restart recovery | — | ~ | n/a | — | — | statics lost on recompile / TF change / symbol change | **high** (§8) |

---

# 2. Temporal semantics — the four times

## 2.1 Definitions mapped to MT5

| Formal | MT5 realisation | Label |
|---|---|---|
| `t_occurred` | the tick's `time_msc` that produced the price event | `[DOC]` |
| `t_closed` | **nominal**: `bar.time + period_seconds`. Never signalled by any event. | `[DOC]` |
| `t_known` | the `time_msc` of the **first tick at or after** `t_closed` — the tick on which `iTime(...,0)` changes | `[BELIEF]` `E-MT5-002` |
| `t_confirmed` | `t_known` of the last bar required by the confirmation rule (e.g. `m` right-hand bars for a pivot) | derived |

> **The gap `t_known − t_closed` is unbounded**, not a constant. A weekend, a
> holiday, or an illiquid overnight session makes it hours or days.

## 2.2 The worked example

Broker server time. A tick arrives at `09:00:00`; the H1 bar `09:00` forms through
`09:59:59`; the `10:00` bar begins.

| Timeframe | Bar containing 09:14:37 | Nominal close | Knowably closed at | Typical delay |
|---|---|---|---|---|
| M1 | `09:14` | `09:15:00` | first tick ≥ `09:15:00` | ms–seconds; **unbounded** |
| M5 | `09:10` | `09:15:00` | *same tick as M1* | identical |
| M15 | `09:00` | `09:15:00` | *same tick* | identical |
| M30 | `09:00` | `09:30:00` | first tick ≥ `09:30:00` | ~15 min later |
| H1 | `09:00` | `10:00:00` | first tick ≥ `10:00:00` | ~45 min later |
| H4 | `08:00`* | `12:00:00` | first tick ≥ `12:00:00` | **~2 h 45 min later** |

\* H4 alignment depends on the broker's day anchor and shifts with **broker** DST
(F6) — the H4 bar containing 09:14 is not the same bar at every broker.

> **CONSEQUENCE.** Higher-timeframe closure is *not* a separate signal — it is the
> same tick that closes the corresponding M1 bar. **Yes, HTF closure is knowable
> causally from the base clock**, which is the good news. The bad news is the
> magnitude: an H4 fact about 09:14 is not knowable until nearly three hours later.

## 2.3 The consequence for "HTF context"

The methodology says M15/M30 FVGs and H1/H4 levels provide context. Two readings,
and the corpus never chose:

- **closed-bar context** — causal, `A-2`-safe, and up to **4 hours stale**;
- **forming-bar context** — fresh, but **non-final**: `iHigh(sym, H4, 0)` changes
  as the bar develops. Not look-ahead (no future data), but a **repaint** source,
  so it violates `A-2`, not `A-1`.

> **This distinction is worth more than most of the open register.** It is the
> difference between a detector that fires on the bar and one that fires hours
> later, and it has never been stated as a decision. Recorded as `D-M1` (§10).

## 2.4 Pivot latency, quantified

A pivot needs `m` bars to its right. Combining with §2.2, for an H4 pivot with
`m = 2`:

```
high occurs        09:14   (inside the 08:00 H4 bar)
its bar closes     12:00 nominal → known at the first tick ≥ 12:00
+2 confirming H4 bars → 20:00 nominal → known at the first tick ≥ 20:00
```

> **A "significant H4 high" is knowable roughly 11 hours after the price that
> formed it.** Nobody had computed this. It is a hard, quantified statement about
> the strategy's latency floor, and it follows from the methodology plus MT5 with
> no extra assumptions.

---

# 3. Look-ahead attack

## 3.1 The mechanisms, ranked by real danger

**(1) Full-array recalculation — the dominant real leak.** `[DOC]`
An indicator's `OnCalculate` receives the whole history when `prev_calculated == 0`.

```
// UNSAFE — reads 5 bars into the future, looks perfectly normal on a chart
for(int i = 0; i < rates_total - 5; i++)
   buf[i] = (high[i+5] > high[i]) ? 1 : 0;
```

This is not exotic; it is how most "repainting" indicators are written, and it is
invisible in a screenshot. **Caught by the recalculation-invariance test**
(`REDTEAM-003` §4.1). Nothing else catches it reliably.

**(2) Forming-bar reads — non-final rather than future.** `[DOC]`

```
// UNSAFE as "the H1 high": the H1 bar is still forming
double h = iHigh(_Symbol, PERIOD_H1, 0);

// SAFE: the last CLOSED H1 bar
double h = iHigh(_Symbol, PERIOD_H1, 1);
```

Strictly this reads no future data — but it violates `A-2` (the value changes
later). The correct framing, which the corpus did not have: **shift 0 is an `A-2`
hazard, not an `A-1` hazard.**

**(3) `iHighest`/`iLowest` with `start = 0`.** `[DOC]`

```
// UNSAFE: the range includes the incomplete current bar
int idx = iHighest(_Symbol, PERIOD_M15, MODE_HIGH, 20, 0);

// SAFE: closed bars only
int idx = iHighest(_Symbol, PERIOD_M15, MODE_HIGH, 20, 1);
```

**(4) `CopyRates` with `start_pos = 0`.** Same hazard as (2); `start_pos = 1`
excludes the forming bar. `[DOC]`

**(5) Cross-timeframe reads.** The specific pattern the brief names — *current M1
→ access H1 high/low* — is safe **only** at shift ≥ 1. At shift 0 it returns the
partial H1 extreme, which already includes the current M1 and will keep changing.
`[BELIEF]`

**(6) `CopyTicks` beyond the current instant.** Live, the tick database ends at
now, so no leak. In the tester `[BELIEF]` the tester bounds it at the modelled
instant — **`[EXP]`, and worth checking explicitly**, because a leak here would be
undetectable by inspection.

## 3.2 The verdict

> MT5 does **not** hand out future data. Every mechanism above is an
> implementation error, not a platform leak — with (6) unverified. But MT5 makes
> the errors *easy* and *invisible*, and the only reliable defence is the
> recalculation-invariance test, run as a gate rather than as a review step.

---

# 4. Bid / Ask / spread

## 4.1 The eight questions

| # | Question | Answer | Label |
|---|---|---|---|
| 1 | Which series forms the OHLC? | Bid for `SYMBOL_CHART_MODE_BID_PRICE`, Last for `..._LAST_PRICE`. FX = Bid. | `[DOC]`, confirm `E-MT5-006` H1 |
| 2 | Which side is a live tick? | Both — `MqlTick` carries `bid` and `ask`; `flags` say which changed. A tick may update only one. | `[DOC]` |
| 3 | Historical ticks and bid/ask? | `COPY_TICKS_INFO` returns bid/ask changes, where the broker supplies them. | `[DOC]` |
| 4 | Both sides always available historically? | **No.** Bar history is deep; real tick history is typically much shallower and broker-dependent. | `[BELIEF]` — `E-MT5-007` measures it |
| 5 | Tester bid/ask? | "Real ticks" mode uses recorded bid/ask. Generated modes synthesise ask from a spread model. | `[BELIEF]` |
| 6 | Spread across tester modes? | Generated modes take spread from M1 history / the current symbol setting; real-ticks mode uses recorded spread. | `[BELIEF]` — `E-MT5-006` in each mode |
| 7 | Historical spread unavailable? | Falls back to a modelled/current spread ⇒ the *same* historical instant yields a different ask in different modes. | `[BELIEF]` |
| 8 | Sweep detectable identically live and in tester? | **Not in general** — see §4.3. | derived |

## 4.2 The penetration scenario

```
Liquidity level  L = 1.10000        (a buy-side pool: stops sit above)
Bid = 1.09995    Ask = 1.10005      spread = 10 points
```

| Interpretation | Penetrated? | What it models | MT5 observability |
|---|---|---|---|
| `bid ≥ L` | **No** (1.09995 < L) | the chart touched the level | ✓ from bars alone |
| `ask ≥ L` | **Yes** (1.10005 > L) | resting **buy stops** actually triggered | ✗ from bars; needs ticks |
| `mid ≥ L` | **No** (1.10000 = L, boundary) | a compromise with no market meaning | ✓ derivable |
| `bid ≥ L − spread` | **Yes** | equivalent to `ask ≥ L`, reconstructed | needs a spread series |

> The two economically meaningful readings **disagree on this exact tick.** The
> stops were taken; the chart never printed the level. Since the methodology's
> whole premise is that sweeps take resting liquidity, the `ask`-based reading is
> the one that means what the strategy says — and it is the one MT5 makes hardest
> to obtain historically.

**No rule is chosen here.** What is established: choosing `ask` semantics commits
the project to tick history, which commits it to a shorter usable corpus and to a
broker-dependent one.

## 4.3 Live/tester divergence

If ask is reconstructed from a modelled spread in generated tester modes, then a
sweep detected live may not be reproducible in the tester **on the same data**.
That breaks the equality `run_live = run_tester`, which the replay requirement
needs. `[BELIEF]` — and among the most important things `E-MT5-006` must settle.

---

# 5. Missing-data semantics

| Formal distinction | Does MT5 expose it? | How | Label |
|---|---|---|---|
| **VALUE** | ✓ | a successful copy | `[DOC]` |
| **UNKNOWN** (exists, not yet determinable) | ✓ | shift 0 = forming bar | `[DOC]` |
| **NOT YET KNOWN** (will become known) | ~ | inferable: bar exists but boundary not passed | derived |
| **NOT AVAILABLE** (data absent/unsynchronised) | ✓ | `CopyRates` → `-1`; `Bars` → `0`; `SERIES_SYNCHRONIZED` = false | `[DOC]` — **F8** |
| **NOT APPLICABLE** (no such thing) | ✗ | no distinct signal — e.g. a minute with no bar is indistinguishable from a minute never loaded, without a session calendar | `[BELIEF]` |

> **MT5 supplies four of the five distinctions.** That is better than expected and
> it is the empirical support for a `⊥`-carrying value domain: `⊥` is not an
> invention of the formalism, it is what `CopyRates` already returns.
>
> The missing one is **NOT APPLICABLE**, and it is exactly the case `F3` creates:
> a minute with no ticks. Distinguishing "the market was closed" from "the market
> was open and silent" from "we never loaded it" requires a session calendar
> (`SymbolInfoSessionQuote`) **plus** a holiday calendar MT5 does not provide.
> Recorded as `D-M2` (§10).

`E-MT5-007` measures how often this matters.

---

# 6. Strategy Tester — semantic validity per mode

| Mode | Intrabar order | Bid/Ask fidelity | Valid for this detector? |
|---|---|---|---|
| **Every tick based on real ticks** | real | recorded | **VALID** — the only mode that can reproduce an intrabar sweep faithfully |
| **Every tick** (generated) | **fabricated** (deterministic path from M1 OHLC) | ask modelled | **INVALID for intrabar rules.** Deterministic, so replayable — but replaying a fiction. Acceptable only if every rule is bar-close-only |
| **1 minute OHLC** | 4 points per M1 | ask modelled | **INVALID for intrabar rules**; same caveat |
| **Open prices only** | one tick per bar | ask modelled | **INVALID** — cannot see intrabar highs/lows at all; the sweep concept is not expressible |
| **Visual mode** | same as its underlying mode | same | semantically equivalent to its base mode `[BELIEF]`; slower only |

> **The mode choice is a semantic commitment, not a speed setting.** If the
> methodology admits any rule that depends on what happened *within* an M1 bar —
> and a same-bar sweep is exactly such a rule — then only real-ticks mode is
> valid, and the usable corpus shrinks to wherever the broker has real tick
> history.

That is a direct, quantifiable trade between semantic fidelity and corpus size,
and `E-MT5-007` measures its size.

---

# 7. Execution model

| | Indicator | Expert Advisor | Script | Service |
|---|---|---|---|---|
| Continuous observation | ✓ `OnCalculate` per tick | ✓ `OnTick` | ✗ runs once | ✓ own loop |
| Multi-symbol | poll only | poll or timer | — | ✓ natural |
| Multi-timeframe | poll | poll | — | poll |
| State across restart | ✗ | ✗ | ✗ | ✗ (all need external persistence) |
| Survives TF change | ✗ re-init | ✗ re-init | n/a | ✓ **not chart-bound** |
| Alerting | ✓ | ✓ | ✓ | ✓ |
| Chart rendering | ✓ native buffers | ✓ objects | ✓ objects | ✗ no chart |
| **Runs in Strategy Tester** | ✓ | ✓ | ✗ | **✗** `[DOC]` |
| Threading | shares one thread per symbol+TF `[BELIEF]` | own thread | own | own |
| Blocking allowed | ✗ no `Sleep` | ✓ | ✓ | ✓ |

> **The decisive constraint is F7.** A Service is the best semantic fit for a
> continuous, multi-symbol, chart-independent detector — and it **cannot be
> replayed in the Strategy Tester**. The project requires deterministic replay.
> Those two facts are in direct conflict.

Three shapes follow, none chosen here:

1. **EA-only** — testable, chart-bound, re-initialised on timeframe change, one
   symbol per chart instance.
2. **Service + EA twin** — the Service runs live, an EA shell runs the same engine
   in the tester. Requires the engine core to be host-agnostic, and requires
   proving the two hosts feed it identically. **That proof obligation is new.**
3. **EA + external replay harness** — replay outside MT5 entirely, with MT5 as a
   data source only.

Recorded as `D-M3` (§10). It is an architecture decision with a **semantic**
precondition, which is why it belongs here rather than in a later phase.

---

# 8. State persistence

| Mechanism | Survives | Holds | Verdict for the stack family |
|---|---|---|---|
| Static/global variables | nothing (lost on re-init, recompile, TF change) | anything | ✗ |
| `GlobalVariable*` | terminal restart | **doubles only** `[DOC]` | ✗ cannot hold records |
| Files (`MQL5/Files`) | restart | anything | ✓ the only viable checkpoint store |
| Files (`FILE_COMMON`) | restart, shared across terminals | anything | ✓ preferred |
| Chart objects | chart lifetime, template | visual only | ✗ never state |
| Input parameters | user-set | config | ✗ |

> **Checkpointing (`REDTEAM-003` §7) must use files.** And tester agents have
> their own sandboxes `[BELIEF]`, so a live checkpoint and a tester checkpoint are
> not interchangeable — which is another face of the F7 conflict.

`OnDeinit` reason codes (`REASON_CHARTCHANGE`, `REASON_PARAMETERS`,
`REASON_RECOMPILE`, `REASON_REMOVE`) `[DOC]` let a program distinguish a
re-initialisation from a removal, so a checkpoint can be written on the right
ones. That is genuinely useful and often overlooked.

---

# 9. Resource limits versus unbounded semantics

The question is not whether MT5 can store an infinite stack. It is whether
**semantic unboundedness can coexist with a finite runtime through a formally
valid execution policy.**

> **It can, and `REDTEAM-003` Theorem 1.3 is why.** On any finite dataset the
> bounded and unbounded semantics coincide once `K ≥ D(d)`. So the policy is:
> unbounded semantics; a runtime bound `K`; a **binding report** (`D-P6`); and a
> measured `D(d)` over the corpus. If `K > D(d)` throughout, the implementation is
> not an approximation of the semantics — it **is** the semantics, exactly.

Practical envelope, all `[BELIEF]`/`[EXP]`:

| Resource | MT5 | Concern |
|---|---|---|
| Memory | `TERMINAL_MEMORY_AVAILABLE` reports it | stacks are small — order 10¹–10² per series (Conjecture 1.5) |
| History depth | broker retention × "Max bars in chart" | caps the *corpus*, not the stacks |
| Symbols | Market Watch limits `[BELIEF]` | out of current scope |
| Timeframes | 21 built-in | static stack count, fine |
| Per-tick CPU | indicators share a thread per symbol+TF | a pop-prefix is amortised `O(1)` (`D-P5`) |
| Timer | `EventSetMillisecondTimer`, practical floor ~16 ms `[BELIEF]` | ample for an exogenous clock |
| Chart objects | practical, not hard, limits | visualisation only |

> **Verdict: resource limits do not threaten the semantics.** They threaten the
> *corpus size* (F5, F6, §4.1 Q4) — which is a different and more serious problem.

---

# 10. New decisions this phase discovered

| ID | Decision | Class | Source |
|---|---|---|---|
| **D-M1** | Is HTF context defined over **closed** HTF bars (causal, up to 4 h stale) or **forming** ones (fresh, non-final, `A-2` hazard)? | **Constitutional** | §2.3 |
| **D-M2** | How is "market closed" distinguished from "market open but silent" and from "not loaded"? Requires a session **and holiday** calendar MT5 does not supply. | **Constitutional** | §5 |
| **D-M3** | Execution host: EA-only, Service + EA twin, or external replay — given that Services cannot be tested (F7). | **Structural**, with a semantic precondition | §7 |
| **D-M4** | Does the engine commit to `ask`-based penetration, and therefore to tick history and a shorter corpus? | **Structural** | §4.2 |
| **D-M5** | Which tester modes are declared valid, and is any intrabar rule permitted at all? | **Structural** | §6 |
| **D-M6** | Is a broker-timezone/DST model supplied externally, given MT5 exposes none? | **Structural** | F6 |

Register: **65 → 71.**

`D-M1` deserves emphasis. It is constitutional, it is cheap to state, nobody has
stated it, and it changes the detector's latency by up to four hours.

---

# 11. EMPIRICAL ADDENDUM — 2026-08-07

Measured on the live desktop MT5 (build 6096, MetaQuotes-Demo, EURUSD,
**176,099 ticks**). Full report: `experiments/mt5/E-MT5-006-report.md`.
Raw data: `experiments/mt5/raw/2026-08-07T2000Z-EURUSD/`.

The original predictions are left untouched above so they can be scored.

| # | Prediction (§0) | Outcome |
|---|---|---|
| **F2** | `TimeCurrent()` is a per-symbol tick clock | untested — but `server_minus_gmt_h` measured directly as **+3** |
| **F4** | Bars built from Bid for FX | **`[CONFIRMED]`** — `SYMBOL_CHART_MODE = 0` (`BID_PRICE`) |
| **F5** | `MqlRates.spread` semantics unclear | still **`[UNKNOWN]`** — this run measured *tick* spread only |
| **F6** | No broker timezone/DST exposed | **partially superseded**: the *current* offset is measurable (**UTC+3**). The **DST question remains `[UNKNOWN]`** |
| **F8** | MT5 separates not-synchronised from empty | **`[REFUTED]` in the important case.** A weekend and genuinely-absent history **both** return `0` ticks with error `0` — indistinguishable. `D-M2` confirmed as a real gap |
| §4.1 Q4 | Historical ask only where real ticks exist | **`[CONFIRMED]` and far better than feared** — ask present on **100%** of ticks and *updated* on **76.2%**, back to **2013-08-12** (~13 years) |
| §4.3 | Live/tester divergence risk | untested |
| §1 "`time_msc` not unique" `[BELIEF]` | | **`[CONFIRMED]`** — duplicates in every window, **up to 39.6%**, and essentially all carry **different prices** |
| §1 "tick order" | not previously asserted | **`[CONFIRMED]` chronological** — **0** backward steps in 176,099 ticks |

## 11.1 Two claims of mine that were wrong

- **"Cache indicates coverage."** Never asserted — and correctly so. The `.tkc`
  cache held **one month**; `CopyTicksRange` retrieved **13 years**. The refusal
  to infer from the filesystem was worth the caution, by a factor of ~150.
- **"MetaEditor CLI fails because of single-instance forwarding."** **`[REFUTED]`.**
  With MetaEditor *not running*, compilation still failed. The real cause is that
  **MetaEditor's CLI compiler fails silently on paths containing spaces** under
  this Wine build — exit 0, no log, no `.ex5`, nothing in `metaeditor.log`.
  Compiling from `C:\mqltest\` succeeds in ~1 s. A genuine platform defect.

## 11.2 New capability rows

| Requirement | Class | Basis |
|---|---|---|
| Historical Ask, deep | **GREEN** on this feed | 100% value presence, 76.2% flag updates, 13 years `[OBSERVED]` |
| Tick chronological order | **GREEN** | 0 inversions `[OBSERVED]` |
| Unique tick key | **RED** | `time_msc` collides with differing prices; needs `(time_msc, index)` `[OBSERVED]` |
| "Closed" vs "absent" | **RED** | identical API response `[OBSERVED]` |
| Programmatic script execution | **GREEN** | `terminal64.exe /portable /config:…` with `[StartUp] Script=` — no GUI needed `[OBSERVED]` |
| Programmatic compilation | **YELLOW** | works only from a space-free path `[OBSERVED]` |
| Spread realism on MetaQuotes-Demo | **RED** | median spread **0** in 2026 windows vs 13 points in 2025 `[OBSERVED]` |

## 11.3 The finding that most constrains the project

> `[OBSERVED]` On MetaQuotes-Demo, EURUSD spread **collapsed to ≈0 between
> January and July 2026**: 100% of recent ticks have spread ≤1 point, against 0%
> a year earlier.
>
> No real EURUSD market trades at zero spread. **This feed cannot be used to
> settle any spread-sensitive question**, which includes `D-M4`. The experiment's
> *method* is validated; its *numbers* need a real broker demo to be decisive.

---

# 12. F5 REFUTED — 2026-08-07 (`E-MT5-008`)

F5 claimed generated tester models fabricate intrabar order. **Measured, and it
is false as stated.** EURUSD M5, 2026-07-09, 288 bars, three models:

| Model | Ticks delivered | high-first | low-first | order disagreements vs real ticks |
|---|---:|---:|---:|---:|
| `Model=4` real ticks | 290,996 | 142 | 146 | — |
| `Model=0` every tick | 220,890 | 142 | 146 | **0** |
| `Model=1` 1-min OHLC | 5,757 | 142 | 146 | **0** |

OHLC identical across models; tick paths and per-bar tick indices very different.

**Corrected statement `[OBSERVED]` + `[INFERRED]`:**

> An M5 bar spans five M1 bars. Which M1 sub-bar holds the M5 high and which holds
> the M5 low **is real information contained in M1 OHLC**, so a generator built
> from M1 data reproduces that ordering faithfully. Fabrication can only bite when
> **both** extremes fall inside the *same* M1 bar.
>
> - **M5 and coarser:** ordering of a bar's own extremes is reproduced. `[OBSERVED]`
> - **M1:** ordering is not recoverable at all — `E-MT5-007`'s two identical-shape
>   candles with opposite order. `[CONFIRMED]`

**Two limits on this correction, both important:**

1. It measured the order of **the bar's own extremes**. The methodology's sweep
   rule concerns an **external level** being penetrated and rejected, which is a
   different and finer question. `[UNKNOWN]`
2. The M1-timeframe cross-model comparison — the test most likely to contradict
   the headline — is **`[BLOCKED]`** by the launch-environment defect.

**§6's blanket "generated modes are INVALID" is therefore withdrawn.** Model
validity depends on the **timeframe** and on whether a rule depends on a bar's
extremes or on arbitrary intrabar level crossings. `D-M5` is advanced, not closed.
