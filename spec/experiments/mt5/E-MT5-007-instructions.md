# E-MT5-007 — Execution Instructions

**Status: AWAITING EMPIRICAL EXECUTION.**

Question: *can the available historical data distinguish "the high happened
first" from "the low happened first" inside one M1 candle — and is M1 OHLC
therefore sufficient to reconstruct "event A then event B"?*

Runtime: 2–20 minutes. Historical only. No orders, no live feed.

---

## 1. Install

Same as `E-MT5-006-instructions.md` §1, with
`E-MT5-007-intrabar-order.mq5` into `MQL5/Scripts/trader-experiments/`.

## 2. Inputs

| Input | Note |
|---|---|
| `InpServerToUTCHours`, `InpNYOffsetFromUTC` | Same audit obligation as `E-MT5-006` §2. Check `ENV/offsets` in the output. |
| `InpSessionOnly` | `true` samples only inside the two New York windows — where the methodology now lives (`DEC-S-001`). **Run once `true` and once `false`**; if intrabar ordering behaves differently inside the windows than outside, that is itself a finding. |
| `InpLookbackDays` | `120` by default. Raise only if tick coverage turns out to be deep (`E-MT5-006` tells you). |
| `InpRandomSeed` | Do not change between runs you intend to compare. The sample is reproducible only if the seed is fixed. |
| `InpWickFraction` | `0.30` — a candle joins the TARGETED sample when **both** wicks are ≥ 30% of its range. Documented criterion, not visual selection. |
| `InpSymbol2` | A second symbol, for the coverage section only. |

## 3. Run order

| Run | Settings | Purpose |
|---|---|---|
| 1 | EURUSD, `InpSessionOnly = true` | the sample that matters |
| 2 | EURUSD, `InpSessionOnly = false` | is the session sample representative? |
| 3 | second symbol, `true` | symbol dependence |

Rename outputs between runs or they overwrite.

## 4. Collect

`Terminal/Common/Files/`:

- `E-MT5-007-results.csv` — one row per candle **per price field**
- `E-MT5-007-summary.csv` — sample sizes, counterexamples, coverage

## 5. Method, so the numbers can be checked

1. Load M1 bars for the lookback window; keep those inside the session windows.
2. **RANDOM sample** — seeded uniform draw from eligible bars. No visual choice.
3. **TARGETED sample** — bars where both wicks are ≥ `InpWickFraction` of range,
   i.e. both extremes genuinely contested. **Kept strictly separate** from RANDOM
   in the `sample` column; never pool them.
4. For each bar, `CopyTicksRange` over `[open, open+60)`.
5. Find the **first** tick reaching the high and the **first** reaching the low;
   compare their positions in the returned sequence.
6. Repeat independently for **BID**, **ASK** and **LAST**:
   - **BID** is matched against the bar's own high/low, because for FX the bar
     *is* a bid series (`MT5-CAP-001` F4);
   - **ASK** and **LAST** extremes are reconstructed **from the ticks**, because
     the bar contains no ask. Never matched against the bar.
7. Tolerance is half a tick size, so float equality is never used.

## 6. The M1-sufficiency test

Exact OHLC collisions are far too rare on 5-digit FX to test directly. The script
therefore buckets candles by **normalised shape** — `(open−low)/range` and
`(close−low)/range`, rounded to percent — and reports any bucket containing both
orderings.

> A bucket with `hi_first > 0` **and** `lo_first > 0` is a concrete counterexample:
> **the same normalised OHLC, two different intrabar orders.** Those rows matter
> more than any aggregate. They are written to `summary.csv` under
> `COUNTEREXAMPLE`, each with a dated example of both orderings.

If the sample yields none, that is *not* evidence that M1 is sufficient — it is
evidence the sample was too small. Say so rather than concluding.

## 7. Statistics to compute from `results.csv`

Restricted to rows with `order_reconstructable = 1`, computed **separately per
`sample` and per `price_field`** — never pooled:

```
P(high before low | both reached)
P(low  before high | both reached)
P(order reconstructable | both reached)
```

These describe the sample only. They are not estimates of a market property, and
must not be reported as one.

## 8. Tester comparison — deliberately not automated

Scripts do not run in the Strategy Tester `[DOCUMENTED]`. Comparing *Real ticks* /
*Every tick* / *1 minute OHLC* needs an EA. Manual procedure:

1. Run `E-MT5-009-live-bidask.mq5` in the tester in each mode over the same range.
2. Compare the recorded tick sequence within identical M1 bars.
3. If the generated modes produce a different intrabar order from real ticks over
   the same bar, generated modes cannot reproduce order-sensitive rules.

**Until run, this is `[UNKNOWN]`.** Do not infer it from documentation.

## 9. Known limitations

- Absence of ticks for a bar is recorded as `no_ticks`, and cannot be
  distinguished from "the bar existed but ticks were never stored" (`D-M2`).
- `same_tick` conflates "one tick set both extremes" with "the bar had one tick".
  Check `tick_count` to separate them.
- The shape bucketing rounds to 1%, so a bucket is a shape *neighbourhood*, not an
  identity. Stated so the counterexamples are read correctly.
- Session filtering depends on an offset MT5 does not supply (§2).

## 10. If it fails

| Symptom | Meaning |
|---|---|
| `eligible_bars = 0` | the offsets or window minutes are wrong — check `ENV/offsets` |
| every row `no_ticks` | no tick history for the lookback — reduce `InpLookbackDays`, or `E-MT5-006` already told you the depth |
| `order_reconstructable = 0` everywhere | extremes never matched — inspect the `note` column before concluding anything |
