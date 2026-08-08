# E-MT5-006 — Report · Historical Bid / Ask / Spread

# STATUS: EXECUTED

Real run against the live desktop MT5. Raw evidence preserved at
`raw/2026-08-07T2000Z-EURUSD/` with SHA-256 sums. **176,099 ticks measured.**

Labels: `[OBSERVED]` measured here · `[DOC]` documented · `[INFERRED]` derived ·
`[UNKNOWN]` · `[BLOCKED]` · `[REFUTED]` · `[CONFIRMED]`.

---

# 0. Headline results

| # | Result | Status |
|---|---|---|
| **R1** | Historical **Ask is available and genuinely updated** on EURUSD back to **2013-08-12** on this feed | `[CONFIRMED]` |
| **R2** | Ask **value** present on **100.0%** of ticks but the **ask update flag** set on only **76.2%** — the distinction the instrument was built around is real | `[CONFIRMED]` |
| **R3** | Bid-based and Ask-based penetration produce **different event sets on 19%–100% of test levels**, and divergence tracks spread magnitude | `[CONFIRMED]` |
| **R4** | Tick history spans **~13 years** (2013-08-12 → now). The local `.tkc` cache showed **one month** — cache is not coverage | `[REFUTED]` (my prior caution was right) |
| **R5** | Server clock is **UTC+3**, measured directly, not inferred | `[CONFIRMED]` |
| **R6** | `time_msc` is **not unique**: duplicate timestamps carry **different prices**, at rates from 0.1% to **39.6%** | `[CONFIRMED]` |
| **R7** | `CopyTicksRange` returned **strictly non-decreasing** timestamps — zero backward steps in 176,099 ticks | `[CONFIRMED]` |
| **R8** | **Spread on this demo feed collapsed to ≈0 between Jan and Jul 2026** — 100% of recent ticks ≤1 point vs 0% a year earlier | `[OBSERVED]` — serious feed artifact |
| **R9** | "0 ticks, no error" occurs for **both weekends and genuinely absent history**, indistinguishably | `[CONFIRMED]` — `D-M2` is real |
| **R10** | MetaEditor CLI **fails silently on paths containing spaces** under Wine | `[OBSERVED]` — refutes my previous diagnosis |

---

# 1. Environment `[OBSERVED]`

| Field | Value |
|---|---|
| Installation | `~/Library/Application Support/net.metaquotes.wine.metatrader5/drive_c/Program Files/MetaTrader 5` |
| Launcher | `/Applications/MetaTrader 5.app`, bundled Wine 11.1, `/portable` |
| Terminal build | **6096** |
| Host | Wine 11.1 / Darwin 25.5.0, Apple M2, host **GMT−3** |
| Company / server | MetaQuotes Ltd. / **MetaQuotes-Demo** |
| Account | `10012089985`, demo (`trade_mode=0`) |
| Symbol | **EURUSD**, digits 5, point `0.00001`, tick size `0.00001` |
| `SYMBOL_CHART_MODE` | **0 = `BID_PRICE`** → bars are built from **Bid** `[CONFIRMED]` (F4) |
| Run | script loaded `19:59:01`, removed `20:00:24` (83 s) |
| Readiness gate | connected + synced after **2010 ms**, `bars_m1=100000`, `synced=1` |
| Script version | v1.2, `.ex5` sha256 `c7765999092f65dd…` |

> The readiness gate matters: it proves the measurements were taken against a
> connected, synchronised terminal. Without it, a startup-launched run would have
> reported "no data" everywhere and that would have looked exactly like absent
> history.

## 1.1 The limitation that governs everything below

`MetaQuotes-Demo` is MetaQuotes' synthetic demo feed, not a broker feed. **R8**
below shows it behaving in a way no real broker would. Every number here is a
true measurement *of this feed*. **`D-M4` must not be closed on this data.**

---

# 2. Access — what was actually usable

| Interface | Result |
|---|---|
| Filesystem (install, `MQL5/`, `Bases/`, logs) | ✅ full read/write |
| MetaEditor CLI compile | ✅ **after** discovering the space-in-path defect (§3) |
| Terminal execution | ✅ via `/config` startup script, fully programmatic |
| Output collection | ✅ `Common/Files` under the **`nachogm`** Wine profile, not `user` |
| Journal / logs | ✅ UTF-16LE |
| MetaTrader MCP `:22346` | ❌ 401 — key in `config/assistant.ini` (12:12) predates the MCP restart |
| MetaEditor MCP `:22345` | ❌ unresponsive after terminal restart |

**No GUI interaction was required.** Compilation and execution were both driven
from the shell.

---

# 3. Compilation `[OBSERVED]` — and a refuted diagnosis

The previous report concluded MetaEditor CLI failed because MetaEditor was running
(single-instance forwarding). **That was wrong.**

| Test | Result |
|---|---|
| Compile with MetaEditor **not running**, path `C:\Program Files\MetaTrader 5\MQL5\…` | ❌ no `.ex5`, no log, exit 0, nothing in `metaeditor.log` |
| Compile with path `C:\mqltest\t6.mq5` | ✅ **`0 errors, 0 warnings, 1097 ms`**, 29,260-byte `.ex5` |

> `[REFUTED]` Single-instance forwarding was not the cause.
> `[OBSERVED]` **MetaEditor's CLI compiler fails silently on paths containing
> spaces under this Wine build.** It exits 0, writes no log, and logs nothing.
> A genuine platform defect, and one that would have cost days to find later.

**Workaround used:** compile in `C:\mqltest\`, copy the `.ex5` into
`MQL5/Scripts/trader-experiments/`. The terminal loads it normally.

## 3.1 Instrument fixes applied before data collection

- **v1.1** — the three `Sum()` overloads did not cover several call sites; replaced
  by one string-typed helper. Confirmed correct by `0 errors`.
- **v1.2** — added a **readiness gate** (`WaitReady`). Without it a startup run
  measures an unconnected terminal and reports false emptiness.

Both are typing/robustness fixes. **No measurement was altered.**

---

# 4. Historical tick coverage `[OBSERVED]`

Probes at one-year intervals, each requesting a 24 h range:

| Probe date | Ticks | Note |
|---|---:|---|
| 2025-08-08 | 72,580 | |
| 2024-08-08 | 57,485 | |
| 2023-08-09 | 50,976 | |
| 2022-08-09 | 81,651 | |
| 2021-08-09 | 62,417 | |
| 2020-08-09 | 1,635 | **Sunday** |
| 2019-08-10 | **0** | **Saturday** |
| 2018-08-10 | 155,438 | |
| 2017-08-10 | 106,335 | |
| 2016-08-10 | 192,596 | |
| 2015-08-11 | 246,986 | |
| 2014-08-11 | 30,774 | |
| 2013-08-11 | 1,272 | **Sunday**, first tick `2013-08-12 00:00:05` |
| 2012-08-11 | **0** | **Saturday** |
| 2011-08-12 | **0** | **Friday — genuinely no history** |

> ## ⚠ CORRECTED 2026-08-07 by `E-MT5-OBS-002` §6
>
> **This figure is wrong.** The Strategy Tester reports its own coverage
> authoritatively: `EURUSD: ticks data begins from 2011.12.19`, and
> `history data begins from 1999.03.10`.
>
> My yearly-stride probing landed the 14- and 15-year samples on
> **2012-08-11 (Saturday)** and **2011-08-12**, read zero ticks, and I took the
> first non-empty probe as the start of history. **A sampling artifact.**
> Correct values: **ticks from 2011-12-19 (~14.6 y)**, **bars from 1999-03-10
> (~27 y)**. The original text is kept below unedited so the error is auditable.

> `[OBSERVED]` **Oldest retrievable tick: 2013-08-12** — 4,744 days ≈ **13 years**.
>
> `[REFUTED]` The local `.tkc` cache held only `202608` (one month). Concluding
> one month of coverage from it would have been wrong by a factor of ~150.
> **`CopyTicksRange` triggers on-demand download**, and the cache is not the
> coverage. The prior report's refusal to infer from cache is vindicated.

## 4.1 The missing-data ambiguity is real `[CONFIRMED]`

Three probes returned **0 ticks with error code 0**. Two were weekends
(2019-08-10, 2012-08-11 — Saturdays). One, **2011-08-12, was a Friday** — a
normal trading day with genuinely no history.

> **The API return is identical in both cases.** `[CONFIRMED]` MT5 cannot, by
> itself, separate "market closed" from "history absent". `D-M2` is not
> theoretical; it is instantiated in this dataset.

---

# 5. Bid, Ask and update flags `[OBSERVED]`

Windows are the `DEC-S-001` New York sessions: **A = 03:00–04:00 NY**,
**B = 09:30–10:50 NY**, mapped to server time at UTC+3.

| Window | Server range | Ticks | bid-flag | ask-flag | both | only-bid | only-ask | neither |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| RECENT_A | 2026-08-06 10:00–11:00 | 15,219 | 11,415 | 12,050 | 8,246 | 3,169 | 3,804 | 0 |
| RECENT_B | 2026-08-06 16:30–17:50 | 27,377 | 19,758 | 21,670 | 14,051 | 5,707 | 7,619 | 0 |
| MONTH_A | 2026-07-09 | 15,382 | 11,672 | 11,956 | 8,246 | 3,426 | 3,710 | 0 |
| MONTH_B | 2026-07-09 | 30,553 | 23,188 | 23,060 | 15,695 | 7,493 | 7,365 | 0 |
| YEAR_A | 2025-08-08 | 4,364 | 2,998 | 3,035 | 1,669 | 1,329 | 1,366 | 0 |
| YEAR_B | 2025-08-08 | 7,202 | 5,040 | 4,942 | 2,780 | 2,260 | 2,162 | 0 |
| WINTER_A | 2026-01-15 | 4,911 | 3,488 | 3,128 | 1,705 | 1,783 | 1,423 | 0 |
| WINTER_B | 2026-01-15 | 11,211 | 7,516 | 7,046 | 3,351 | 4,165 | 3,695 | 0 |
| SUMMER_A | 2026-07-15 | 18,431 | 14,204 | 14,954 | 10,727 | 3,477 | 4,227 | 0 |
| SUMMER_B | 2026-07-15 | 33,831 | 26,455 | 26,472 | 19,096 | 7,359 | 7,376 | 0 |
| OLDEST_A | 2013-08-13 | 3,147 | 2,416 | 2,459 | 1,788 | 628 | 671 | **60** |
| OLDEST_B | 2013-08-13 | 4,471 | 3,362 | 3,487 | 2,490 | 872 | 997 | **112** |
| **TOTAL** | | **176,099** | **131,512** | **134,259** | | | | 172 |

## 5.1 The result the instrument was designed for

| Measure | Value |
|---|---|
| Ticks carrying an **ask value** (`ask > 0`) | **176,099 / 176,099 = 100.0%** |
| Ticks where the **ask flag** is set (`TICK_FLAG_ASK`) | **134,259 / 176,099 = 76.2%** |
| Ticks where the **bid flag** is set | 131,512 / 176,099 = 74.7% |

> `[CONFIRMED]` **Reading `ask > 0` would have reported "ask available on 100% of
> ticks". The truth is that ask *changes* on 76.2%.** The two questions have
> different answers, and the naive one errs in the optimistic direction — exactly
> as the instrument's design note predicted.

> `[CONFIRMED]` Ticks updating **only one side** are common — roughly 20–40% of
> every window. So "the spread at instant *t*" is always a **reconstruction**
> from the last known other side, never a joint observation.

`[OBSERVED]` `flags` values seen: 1028, 1154, 1158 — i.e. `TICK_FLAG_BID`/`ASK`
plus undocumented bits `0x80` and `0x400`. Decoding against the documented masks
matched the recorded columns on every inspected row.

---

# 6. Spread `[OBSERVED]` — and a serious feed artifact

| Window | min | max | median | % ticks with spread ≤ 1 point |
|---|---|---|---|---:|
| RECENT_A (2026-08) | 0.00000 | 0.00002 | **0.00000** | **99.8%** |
| RECENT_B (2026-08) | 0.00000 | 0.00002 | **0.00000** | **100.0%** |
| MONTH_A (2026-07) | 0.00000 | 0.00026 | 0.00000 | 96.0% |
| SUMMER_B (2026-07) | 0.00000 | 0.00002 | 0.00000 | 99.6% |
| WINTER_B (2026-01) | 0.00000 | 0.00004 | 0.00003 | 10.0% |
| YEAR_A (2025-08) | 0.00008 | 0.00014 | **0.00013** | **0.0%** |
| YEAR_B (2025-08) | 0.00008 | 0.00014 | **0.00013** | **0.0%** |
| OLDEST_B (2013-08) | 0.00001 | 0.00007 | 0.00004 | 2.8% |

Raw confirmation — 2026-08-06, four consecutive ticks with `ask == bid`:

```
EURUSD,RECENT_B,0,1786033800030,...,1.15387,1.15387,,0,0.00,1154,0.00000,0,...
EURUSD,RECENT_B,2,1786033800143,...,1.15388,1.15388,,0,0.00,1154,0.00000,0,...
EURUSD,RECENT_B,4,1786033800189,...,1.15389,1.15389,,0,0.00,1158,0.00000,0,...
```

versus 2025-08-08, realistic 12–13 point spreads:

```
EURUSD,YEAR_B,0,1754670600490,...,1.16503,1.16516,,0,0.00,1158,0.00013,13,...
EURUSD,YEAR_B,3,1754670604119,...,1.16500,1.16512,,0,0.00,1158,0.00012,12,...
```

> `[OBSERVED]` **Between January and July 2026 the demo feed's EURUSD spread
> collapsed to approximately zero.** In 2025 the spread was 10–13 points on 100%
> of ticks; in recent data it is ≤1 point on ~100% of ticks.
>
> `[INFERRED]` No real EURUSD market trades at a zero spread. This is a property
> of the synthetic feed, not of the market. **Recent MetaQuotes-Demo data is
> unusable for any spread-sensitive research**, which includes the entire
> ask-versus-bid question.

`[UNKNOWN]` `MqlRates.spread` semantics — this run measured tick spread only. The
bar-level field still needs a dedicated comparison.

---

# 7. Bid vs Ask penetration divergence `[OBSERVED]` — the decisive result

21 test levels spanning each window's bid range. A level is *divergent* when the
first-crossing timestamp differs between the bid rule and the ask rule, in either
direction. **These are test levels, not liquidity pools.**

| Window | Divergent / 21 | % | Median spread |
|---|---:|---:|---|
| YEAR_A (2025-08) | 21 | **100.0%** | 13 pts |
| YEAR_B (2025-08) | 21 | **100.0%** | 13 pts |
| WINTER_A (2026-01) | 21 | **100.0%** | 3 pts |
| WINTER_B (2026-01) | 20 | 95.2% | 3 pts |
| OLDEST_A (2013-08) | 14 | 66.7% | 4 pts |
| OLDEST_B (2013-08) | 12 | 57.1% | 4 pts |
| RECENT_A (2026-08) | 12 | 57.1% | 0 pts |
| MONTH_A (2026-07) | 11 | 52.4% | 0 pts |
| MONTH_B (2026-07) | 10 | 47.6% | 0 pts |
| SUMMER_A (2026-07) | 7 | 33.3% | 0 pts |
| SUMMER_B (2026-07) | 6 | 28.6% | 0 pts |
| RECENT_B (2026-08) | 4 | 19.0% | 0 pts |

> `[CONFIRMED]` **Bid-based and ask-based penetration are different predicates on
> real data.** Where the spread is realistic (2025, Jan 2026), **95–100% of levels
> produce a different event set**. Divergence falls as spread → 0, exactly as the
> mechanism predicts — which is itself a coherence check on the measurement.

## 7.1 A concrete counterexample

`YEAR_B`, level `L = 1.16460`, 2025-08-08:

```
bidUp = 1754670600490    askUp = 1754670600490     (agree upward)
bidDn = 1754672406318    askDn = -1                (disagree downward)
```

> The **bid crossed down through 1.16460; the ask never did.** A bearish
> penetration defined on Bid is an event that exists. Defined on Ask it does not
> exist at all — not late, *absent*.
>
> Since the methodology's premise is that a sweep takes resting stops, and stops
> trigger at the ask, this is precisely the case where the two readings disagree
> about whether the strategy's founding event happened.

---

# 8. Tick timestamp semantics `[OBSERVED]` — question E

| Window | Ticks | Duplicate `time_msc` | Duplicates with **different** prices | Backward steps |
|---|---:|---:|---:|---:|
| RECENT_A | 15,219 | 62 | 62 | **0** |
| RECENT_B | 27,377 | 177 | 177 | **0** |
| MONTH_B | 30,553 | 253 | 253 | **0** |
| YEAR_B | 7,202 | 8 | 8 | **0** |
| WINTER_B | 11,211 | 51 | 51 | **0** |
| SUMMER_B | 33,831 | 100 | 100 | **0** |
| OLDEST_A | 3,147 | **1,197 (38.0%)** | 1,190 | **0** |
| OLDEST_B | 4,471 | **1,772 (39.6%)** | 1,753 | **0** |

> `[CONFIRMED]` **Ordering is preserved.** Zero backward timestamp steps across
> 176,099 ticks. `CopyTicksRange` returns chronological order.
>
> `[CONFIRMED]` **`time_msc` is not a key.** Duplicates occur in every window, and
> **essentially all of them carry different prices** (1,753 of 1,772 in OLDEST_B).
> In 2013 data nearly **40%** of ticks share a millisecond with another tick.
>
> `[INFERRED]` A total order on ticks therefore requires **`(time_msc, array
> index)`**, and the index is only meaningful within a single `CopyTicksRange`
> result. This confirms `RT-23` item 3 and makes it quantitative.

---

# 9. Server time and DST `[OBSERVED]`

Measured directly by the script, not inferred from logs:

```
server_time              = 2026.08.08 01:59:03
gmt_time                 = 2026.08.07 22:59:03
server_minus_gmt_h_auto  = 3
```

> `[CONFIRMED]` **MetaQuotes-Demo server time = UTC+3** in August 2026.
> Independently corroborated twice by journal timestamp pairs (local + 6 h with a
> GMT−3 host).

Window mapping used, and verified in the raw `ny_time` column:

| NY window | Server |
|---|---|
| 03:00–04:00 | 10:00–11:00 |
| 09:30–10:50 | **16:30–17:50** |

Raw row: `server_time = 2026.08.06 16:30:00` ↔ `ny_time = 2026.08.06 09:30:00`. ✅

`[UNKNOWN]` **Whether the server offset changes in winter.** This run measured the
*current* offset only. The WINTER window (2026-01-15) returned data, but the
script applied the **current** UTC+3 offset to it, so it cannot say what the
offset was in January. **Determining the winter offset requires a different
measurement** — see §12.

---

# 10. Decision status after this run

| Decision | Before | Now |
|---|---|---|
| `D-M4` ask-based penetration | `[UNKNOWN]` | **Technically available** `[CONFIRMED]`: ask exists, updated, 13 years deep. **Materially different from bid** `[CONFIRMED]`: 95–100% divergence at realistic spreads. **The trading choice remains the trader's.** |
| `D-M2` closed vs silent vs absent | `[UNKNOWN]` | `[CONFIRMED]` real — identical API response for weekend and absent history (§4.1) |
| `D-M6` broker timezone | `[UNKNOWN]` | **Current offset `[CONFIRMED]` UTC+3.** DST behaviour still `[UNKNOWN]` |
| `RT-23` item 3 (timestamp collisions) | `[INFERRED]` | `[CONFIRMED]`, up to 39.6% |
| Tick ordering guarantee | `[UNKNOWN]` | `[CONFIRMED]` chronological, 0 inversions in 176,099 |
| F4 bars built from Bid | `[DOC]` | `[CONFIRMED]` `chart_mode=0` |
| Cache ≠ coverage | `[INFERRED]` | `[CONFIRMED]` — 1 month cached, 13 years available |
| `D-M5` valid tester modes | `[UNKNOWN]` | still `[UNKNOWN]` — needs `E-MT5-007` |
| `D-M1` HTF closed vs forming | `[UNKNOWN]` | untouched by this run |

---

# 11. Red-team of these results

| Attack | Assessment |
|---|---|
| **Feed bias** | **The strongest objection.** Zero spread in recent data is not market behaviour (§6). Divergence percentages for 2026 windows are therefore *understated* relative to a real broker. The 2025 and 2013 windows are more credible. |
| **Survivorship / sampling** | One symbol, one day per period, two 60–80 min windows. Not a distribution estimate. Divergence rates are illustrative of mechanism, not population parameters. |
| **Cache-vs-server confusion** | Actively avoided; §4 measures by request, not by file listing, and the result refuted the cache reading. |
| **Look-ahead** | Not applicable — pure historical read, no detector logic. |
| **Timezone dependence** | The NY mapping used the *current* offset for *all* historical windows. For the WINTER window this is very likely wrong by one hour. **Recorded as a defect of this run**, not a finding. |
| **Weekend confound** | Caught: three zero-tick probes turned out to be weekends, one a genuine gap. Reported as a confirmed ambiguity rather than as "no data". |
| **Tester artifacts** | Not exercised; no tester run performed. |
| **Instrument correctness** | Flag decoding verified by hand against raw rows; readiness gate proves the terminal was synced; ordering check found zero inversions, which would have exposed a parsing error. |

---

# 12. Unknowns and the next measurement

`[UNKNOWN]` still open: winter server offset; `MqlRates.spread` semantics; tester
mode fidelity; whether a real broker shows the same ask behaviour; intrabar
ordering (`E-MT5-007`).

> **The single defect in this run worth fixing before anything else:** the script
> applied the current UTC+3 offset to historical windows. To answer `DEC-S-001`
> A-2 and `D-M6`, the winter offset must be measured *from winter data itself* —
> for example by locating a known daily session boundary in January data and
> reading its server timestamp, rather than assuming the offset.

---

# 13. Scientific conclusion

> Historical Ask is **available, real and deep** on this feed, and an ask-based
> penetration rule is **not equivalent** to a bid-based one — at realistic
> spreads they disagree about nearly every level, including cases where one rule
> sees no event at all. The technical obstacle that `D-M4` was assumed to face
> **does not exist here**. What remains is a trading decision, and it must be
> retaken on a real broker feed, because this one currently reports a zero spread.
