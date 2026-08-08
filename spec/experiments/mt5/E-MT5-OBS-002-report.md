# E-MT5-OBS-002 — Report · Strategy Tester Visual Replay & Determinism

# STATUS: EXECUTED

Two full visual-mode Strategy Tester runs on real tick data. Raw evidence:
`raw/2026-08-07T2148Z-OBS002-tester/` — event logs, reports, agent log, tester
log, `.set`, `.ini`, SHA-256 sums.

`[OBSERVED]` · `[CONFIRMED]` · `[REFUTED]` · `[INFERRED]` · `[UNKNOWN]`

---

# 0. Headline results

| # | Result | Status |
|---|---|---|
| **R1** | The observability EA runs in the **Strategy Tester in visual mode** on real ticks | `[CONFIRMED]` |
| **R2** | **Replay is deterministic** — two independent runs produced **byte-identical** event logs and the identical FNV-1a hash | `[CONFIRMED]` |
| **R3** | **All six PART VII safety invariants PASS inside the tester** | `[CONFIRMED]` |
| **R4** | `Verdict()` is **structurally incapable** of emitting BUY/SELL — 126 stage combinations tested, zero leaks | `[CONFIRMED]` |
| **R5** | `FILE_COMMON` output **is retrievable from the tester agent** | `[CONFIRMED]` |
| **R6** | **`ChartScreenShot` returns `true` in the tester but produces no retrievable file** | `[OBSERVED]` — a real limitation |
| **R7** | Tick history begins **2011-12-19**, bar history **1999-03-10** — deeper than I previously measured | `[REFUTED]` my earlier figure |
| **R8** | Bare `wine terminal64.exe` launches are unreliable; a healthy wrapper-provided `wineserver` is required | `[OBSERVED]` |

---

# 1. Run parameters `[OBSERVED]`

| Field | Value |
|---|---|
| Terminal build | 6096 |
| Account / feed | `10012089985`, MetaQuotes-Demo |
| Symbol / timeframe | **EURUSD / M5** |
| Date range | **2026.07.09 00:00 → 2026.07.10 00:00** |
| Tester model | **`Model=4` — Every tick based on real ticks** |
| Visual mode | **`Visual=1`** |
| Optimization | off |
| Deposit / currency / leverage | 10000 USD / 1:100 (irrelevant — nothing trades) |
| Ticks processed | **290,996** |
| Bars generated | **288** |
| Test duration | 1:06.4 (run 1), 1:06.6 (run 2) |
| Memory | 1 MB + 6 MB history + 64 MB tick data |
| EA version | 1.0, `spec_snapshot=unfrozen` |
| Parameter set | `obs2_run{1,2}.set`, identical but for `InpRunTag` |

`[OBSERVED]` Agent log: `EURUSD : real ticks begin from 2026.07.09 00:00:00` —
the tester used **genuine recorded ticks**, not generated ones. Generated ticks
were never substituted for speed.

---

# 2. Determinism `[CONFIRMED]` — the strongest result here

| | Run 1 | Run 2 |
|---|---|---|
| Ticks | 290,996 | 290,996 |
| Bars | 288 | 288 |
| Events emitted | 57 | 57 |
| Screenshots attempted | 4 | 4 |
| **FNV-1a final hash** | **16633771818731992620** | **16633771818731992620** |
| Event-log SHA-256 | `0d0f96841448d2fc3722600a0f18e6c9…` | `0d0f96841448d2fc3722600a0f18e6c9…` |

```
diff run1-events.csv run2-events.csv  →  IDENTICAL (0 differing lines)
```

> `[CONFIRMED]` **Same input snapshot → same output.** Byte-identical across the
> whole event log, plus an independent rolling hash computed inside MQL5 over
> every emitted field. Two separate terminal processes, two separate agent
> sessions.
>
> No floating-point drift, no ordering nondeterminism, no state-initialisation
> divergence, no clock dependence appeared in this configuration.

**Scope of the claim, stated precisely.** This establishes determinism for: one
symbol, one timeframe, one 24-hour range, one tester model, a synthetic event
generator, and a single local agent. It does **not** establish determinism for
the real detector (which does not exist), for multi-symbol runs, across terminal
builds, or across data re-downloads. `[UNKNOWN]` for all of those.

---

# 3. Safety invariants `[CONFIRMED]` — PART VII

Verified **inside the tester**, by writing a state to a chart object and reading
the rendered text back off the chart:

| Test | Result | Evidence |
|---|---|---|
| **IT-1** BLOCKED renders as `BLOCKED` | **PASS** | `rendered=BLOCKED` |
| **IT-1b** BLOCKED never renders BUY/SELL | **PASS** | `rendered=BLOCKED` |
| **IT-2** UNKNOWN not silently converted to FAIL | **PASS** | `rendered=UNKNOWN` |
| **IT-3** WAITING not silently converted to UNKNOWN | **PASS** | `rendered=WAITING` |
| **IT-4** `Verdict()` cannot emit BUY/SELL | **PASS** | **126 stage combinations**, zero leaks |
| **IT-5** a BLOCKED prerequisite blocks the verdict | **PASS** | `returned=BLOCKED` |

## 3.1 How IT-4 is enforced

`Verdict()` has **no reachable return path** producing `"BUY"` or `"SELL"`. The
all-PASS case — the only one that could tempt an implementation — returns:

```
BLOCKED: verdict semantics undefined (D-P1/D-P3/D-M1/DEC-S-001)
```

> `[CONFIRMED]` This is the mechanism that lets the UI be built before the
> methodology is frozen. The code does not merely *decline* to emit a verdict —
> it **cannot express one**. When the decision layer is specified, `Verdict()` is
> the single function to change, and IT-4 will then have to be rewritten
> deliberately rather than passing by accident.

Both runs produced identical invariant results, so the invariants are themselves
deterministic.

---

# 4. Rendering under replay

| Question | Result |
|---|---|
| EA renders the panel in the tester | `[OBSERVED]` executed without error; objects created and read back |
| Object classes render | `[OBSERVED]` `OBJ_TREND`, `OBJ_RECTANGLE` (filled), `OBJ_ARROW`, `OBJ_LABEL`, `OBJ_RECTANGLE_LABEL` all created |
| Objects anchored to replay time | `[OBSERVED]` every event carries `t_occurred` and `t_known` differing by exactly one bar; objects are anchored to those datetimes |
| Panel readable while advancing | **`[UNKNOWN]`** — see §5 |
| Deterministic rendering | `[INFERRED]` from R2: the renderer is a pure function of an event log that is byte-identical, so the object set must be identical. **Not directly verified** — the images could not be captured |
| Same visual result inside and outside the tester | **`[UNKNOWN]`** — §5 |

## 4.1 Causal timestamping works

```
seq,event_id,kind,t_occurred,t_known,price1,price2
1,ZONE_EURUSD_5_1783556100,ZONE,2026.07.09 00:15:00,2026.07.09 00:20:00,1.14218,1.14168
2,LINE_EURUSD_5_1783557600,LINE,2026.07.09 00:40:00,2026.07.09 00:45:00,1.14173,1.14148
```

> `[OBSERVED]` Every event describes the **last closed bar** (`t_occurred`) and is
> emitted at the bar that revealed it (`t_known`), one M5 period later. The
> anti-look-ahead discipline of `MT5-OBS-001` §3.2 holds in practice: nothing is
> drawn at a bar before it was knowable.

Event ids follow `REDTEAM-002` §2.2 —
`KIND_SYMBOL_TIMEFRAME_BIRTHINSTANT` — and are reproducible across runs, which is
the identity claim of that document tested on real replay.

---

# 5. The limitation this run found `[OBSERVED]`

> **`ChartScreenShot` returns `true` inside the Strategy Tester but no file is
> produced anywhere retrievable.**

Evidence: the EA counted `screenshots=4` (it only increments on a `true` return),
yet an exhaustive search of the entire Wine prefix found **no**
`E-MT5-OBS-002-*.png`. The tester agent directory contains only `config/`,
`logs/` and `temp/` — **no `MQL5/Files` directory exists at all**.

By contrast, `FILE_COMMON` **worked**: all four CSVs written by the tester agent
landed in the shared `Common/Files` folder and were read back intact.

> `[OBSERVED]` **Asymmetry: data output from the tester is retrievable; image
> output is not.**
>
> `[INFERRED]` Visual verification of replay rendering cannot currently be
> automated through `ChartScreenShot`. Human validation would depend on watching
> the visual tester live, or on capturing the screen externally.

This directly affects PART VIII (human validation): the intended workflow —
replay, pause, human records, engine records, compare — can rely on the **event
log** as the engine's record, but **not** on programmatic image capture as the
visual record.

`[UNKNOWN]` Whether an alternative exists (a different path form, the agent's
sandbox root, or capture from the terminal rather than the agent).

---

# 6. History depth `[REFUTED]` — a correction to my earlier reports

The tester states its own coverage authoritatively:

```
EURUSD: history data begins from 1999.03.10 00:00
EURUSD: ticks data begins from 2011.12.19 00:00
```

| Source | Earlier claim | Correct value |
|---|---|---|
| Tick history start | "**2013-08-12**" (`E-MT5-006` §4) | **2011-12-19** |
| Bar history | "100,000 M1 bars ≈ 3 months" (`E-MT5-007` §5) | **that is the terminal chart cap**; the *tester* reaches **1999-03-10** |

**Why I was wrong.** `E-MT5-006` probed at exactly one-year intervals backwards
from "now". The 14- and 15-year probes landed on **2012-08-11 (Saturday)** and
**2011-08-12**, returning zero ticks, and I read the first non-empty probe as the
start of history. **A sampling artifact, not a property of the data.** The lesson
generalises: probing a market data source on a fixed calendar stride will
systematically hit weekends and understate coverage.

The `E-MT5-007` §5 statement was narrower and remains true as written — it was
about `Bars(sym, PERIOD_M1)` in the *terminal*, which is capped by
`TERMINAL_MAXBARS`. But the **implication** I drew from it — that a bar-based
engine has less usable history than a tick-based one — **does not hold for the
tester**, which builds its own history from 1999. Corrected in both reports.

> **Net effect: the usable corpus is substantially larger than recorded.**
> ~14.6 years of real ticks and ~27 years of bars, rather than ~13 and ~0.25.

---

# 7. Launch-method finding `[OBSERVED]` — closing an earlier `[UNKNOWN]`

`E-MT5-007` §6 left the "terminal crash" cause open, listing my own launch method
as one candidate. This run settled it:

| Launch method | Result |
|---|---|
| `nohup wine terminal64.exe …` with **no** wrapper process alive | terminal exits within ~60 s, sometimes without a single journal line |
| Same, launched with `start_new_session=True` (setsid) | **still exits** — so it is *not* process-group cleanup |
| `open -a "MetaTrader 5.app"` | **stable indefinitely** |
| `nohup wine terminal64.exe …` **while the `.app` wrapper is alive** | **stable** — all successful runs used this |

> `[INFERRED]` The `.app` wrapper establishes Wine environment state (a correctly
> configured `wineserver`) that a bare `wine` invocation does not reproduce. The
> earlier "crashes" were very likely **launch-environment failures, not MT5
> instability**.
>
> `[OBSERVED]` `open -a … --args` does **not** forward `/config:` to the terminal —
> the journal shows no `launched with` line. So automated tester runs require the
> wrapper to be running *and* a separate `wine terminal64.exe /config:` invocation.

**This removes a false MT5 stability finding from the record.** `MT5-OBS-001` §7
and `E-MT5-007` §6 are updated.

---

# 8. Alert channels — status after this phase

| Channel | Status | Evidence |
|---|---|---|
| `Print` → journal | **works** | `E-MT5-OBS-001`; the agent log carries EA output |
| `PlaySound` | **works** | `E-MT5-OBS-001` |
| Chart panel | **works live**; **unverified visually in tester** | §4, §5 |
| `Alert()` | modal `[DOC]`, unsuitable as primary | not fired |
| `SendNotification` | **fails, err 4517** | needs MetaQuotes ID — user action |
| `SendMail` | **fails, err 4510** | needs SMTP — user action |

Correctness does not depend on push or email, as required by PART IV.

---

# 9. Red-team of these results

| Attack | Assessment |
|---|---|
| **"Determinism is trivial because the generator is synthetic."** | Fair, and it is the point. The generator is deterministic *by construction*; what was under test is whether **MT5's replay pipeline** preserves that determinism — tick delivery, bar formation, event ordering, file I/O. It did. A nondeterministic *detector* would still be possible; this result does not cover it. |
| **"Invariants pass because nothing can fail."** | Partly true and deliberate. IT-4 is strong precisely because the property is structural. IT-1..IT-3 are weaker — they test the renderer's mapping, not the engine's semantics. |
| **Single agent** | One local agent. Multi-agent or cloud runs could reorder output. `[UNKNOWN]` |
| **One date range** | A single 24-hour window on one symbol. Determinism over a longer or busier range is `[UNKNOWN]`. |
| **Screenshot absence could be a path bug** | Possible. I searched the whole prefix for the filename and found nothing, and the agent has no `MQL5/Files` directory at all — but an alternative write location cannot be excluded. Recorded as `[OBSERVED]` for the tested form, `[UNKNOWN]` for alternatives. |
| **Feed** | MetaQuotes-Demo. Irrelevant to determinism and rendering; still disqualifying for anything spread-sensitive. |

---

# 10. Decision impact

| Decision | Effect |
|---|---|
| `D-V1` (`BLOCKED` mandatory) | **Evidence supports it strongly** — IT-1/IT-5 pass and the all-PASS case returns BLOCKED. Still a decision, not taken here |
| `D-V3` (verdict while BLOCKED) | **Implementable and tested.** Recommendation unchanged: no |
| `D-V7` (replay vs incremental rendering) | Determinism achieved with incremental rendering; replay-from-log not yet required |
| `D-M5` (valid tester modes) | **`Model=4` real ticks confirmed working end-to-end.** Generated modes still untested and still suspect for order-sensitive rules |
| `D-M4` | Untouched — needs a real broker feed |
| New: **`D-V10`** | How is visual evidence captured for human validation, given `ChartScreenShot` does not work in the tester? |

Register: **80 → 81.**

---

# 11. Conclusion

> The observability layer **works under replay, deterministically, with its
> safety invariants intact**, on real tick data, inside the Strategy Tester.
> The engine cannot emit BUY or SELL, and that is enforced by construction rather
> than by discipline.
>
> Two things this run changed about the project's own record: the usable history
> is **much larger** than reported (14.6 years of ticks, 27 of bars), and the
> "MT5 crashes" finding was **my launch method**, not the platform.
>
> The one genuine new limitation is that **images cannot be captured from the
> tester**, which constrains how human-versus-engine validation will have to be
> staged.
