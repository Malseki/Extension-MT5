# E-MT5-006 — Execution Instructions

**Status: AWAITING EMPIRICAL EXECUTION.**

Question: *what historical Bid/Ask/spread information does this broker actually
provide, and does a bid-based penetration rule produce a different historical
event set from an ask-based one?*

Runtime: 1–15 minutes depending on tick availability. Runs once, offline, on
historical data. Places no orders and reads no live feed.

---

## 1. Install

1. MetaTrader 5 → **File → Open Data Folder**.
2. Copy `E-MT5-006-bid-ask-spread.mq5` into `MQL5/Scripts/trader-experiments/`.
3. MetaEditor → open it → **Compile (F7)**.
   *It has never been compiled — expect to fix syntax errors on the first build.
   That is normal and does not affect the design.*
4. In the Navigator, drag the script onto a chart of the symbol under test.
   The inputs dialog appears because `script_show_inputs` is set.

## 2. Before you run — set two inputs correctly

Everything else can stay at default. **These two decide whether the output means
anything**, because MT5 exposes no broker timezone (`MT5-CAP-001` F6):

| Input | What to do |
|---|---|
| `InpServerToUTCHours` | Leave at `0` for the first run — the script estimates it from `TimeTradeServer() − TimeGMT()` and **writes both the estimate and the value it used** into `ENV/offset_server_minus_gmt_h`. Check that row. If your PC clock or timezone is wrong, the estimate is wrong; set it manually and re-run. |
| `InpNYOffsetFromUTC` / `InpApplyUSDst` | Defaults are `−4` fixed, matching the constraint as literally stated. `InpApplyUSDst = true` switches to a **coarse** March–October bracket. **Neither is the real US DST rule** — that is deliberate, see `DEC-S-001` A-2. Run **both** ways if you can; the difference is the measurement. |

The session windows default to `03:00–04:00` and `09:30–10:50` New York
(`DEC-S-001` A-1). If either is wrong, fix it here before running — every sample
is taken inside them.

## 3. Run order

| Run | Symbol | `InpApplyUSDst` | Purpose |
|---|---|---|---|
| 1 | EURUSD | `false` | baseline, constraint as literally stated |
| 2 | EURUSD | `true` | DST sensitivity — does the window move? |
| 3 | second liquid pair (GBPUSD, or whatever the broker offers) | `false` | is coverage symbol-specific? |
| 4 | the symbol you actually trade, if different | `false` | the one that matters (`DEC-S-001` A-4) |

Rename the output files between runs (`…-results.csv` → `…-results-EURUSD-run1.csv`)
or each run overwrites the previous.

## 4. Collect

From **File → Open Data Folder**, go up to `Terminal/Common/Files/`:

- `E-MT5-006-results.csv` — one row per tick
- `E-MT5-006-summary.csv` — metrics, coverage, penetration scan

Send both, per run, plus the environment block from `README.md` §5.

## 5. What the output rows mean

`summary.csv` sections:

| Section | Contains |
|---|---|
| `ENV` | build, broker, symbol specs, **the offsets you must audit** |
| `WINDOW` | one row per sampled window: requested range, tick count, error code |
| `METRICS` | flag counts, value counts, spread min/max/median, % recoverable |
| `PENETRATION` | per level `L`: first bid-crossing and first ask-crossing time, and whether they diverge |
| `COVERAGE` | how far back tick data was found, probed year by year |

**The two columns that decide the most:**

- `METRICS/*_counts` → `cAsk`. If ask-flagged ticks are ~0 in the older windows,
  historical ask does not exist there for this broker.
- `PENETRATION/*_SUMMARY` → `pct_levels_where_bid_and_ask_rules_differ`. If this
  is near 0, `D-M4` stops mattering. If it is large, the bid/ask choice is a real
  fork in the strategy's meaning.

## 6. Reading the ask question correctly

The script records **two different things** and they must not be confused:

- `ask_value_present` — the tick carried an ask value at all;
- `ask_flag_set` — this tick actually *updated* the ask (`TICK_FLAG_ASK`).

`MqlTick` propagates the last known bid and ask onto every tick, so
`ask_value_present` can be 1 everywhere while `ask_flag_set` is rare. **Only the
flag tells you whether the broker recorded ask movement.** A conclusion drawn from
`ask_value_present` alone would be wrong, and would be wrong in the optimistic
direction.

## 7. Known limitations of this instrument

- Cannot tell whether stored ticks are genuine exchange ticks or broker-generated;
  MT5 exposes no such marker `[DOCUMENTED]`.
- The `InpApplyUSDst` bracket is coarse by design (§2).
- Windows are sampled on one calendar day per period, not every day — enough to
  detect presence/absence, not to estimate daily distributions.
- No tester run. Live-vs-tester spread behaviour is `E-MT5-009`'s job.

## 8. If it fails

| Symptom | Meaning |
|---|---|
| All windows `n = 0`, error `4401`/`4066` | history not synchronised — open the symbol's chart, scroll back, wait, re-run |
| `n = 0`, no error | genuinely no ticks stored for that range — **this is a result, not a failure** |
| Only recent windows return ticks | tick history is shallow — **the headline finding**; record where it stops |
| Script hangs | reduce `InpLevelScanCount`, or set `InpWriteTicks = false` |
