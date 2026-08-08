# E-MT5-008 — Report · Tester Model Fidelity

# STATUS: EXECUTED (partial — one comparison BLOCKED)

Raw evidence: `raw/2026-08-07T2215Z-E008-modes/` with SHA-256 sums.

---

# 0. Headline result — and it refutes a claim of mine

> **`[REFUTED]`** `MT5-CAP-001` **F5: "Intrabar tick order is fabricated in
> generated tester modes."**
>
> At **M5**, across 288 bars, **real ticks, generated every-tick and 1-minute
> OHLC produced identical intrabar ordering — zero disagreements** — despite
> delivering 290,996 / 220,890 / 5,757 ticks respectively.

| Model | Ticks | ticks/bar (min–max, mean) | high-first | low-first | undetermined |
|---|---:|---|---:|---:|---:|
| `Model=4` real ticks | 290,996 | 54–2578, 1010.4 | 142 | 146 | 0 |
| `Model=0` every tick (generated) | 220,890 | 34–1943, 767.0 | 142 | 146 | 0 |
| `Model=1` 1-minute OHLC | 5,757 | 17–20, 20.0 | 142 | 146 | 0 |

```
order, bar-by-bar:   m4 vs m0 → 0 differing    m4 vs m1 → 0 differing
OHLC,  bar-by-bar:   m4 vs m1 → 0 differing
```

Same bar under all three models:

```
m4  2026.07.09 00:05:00, 142 ticks, H=1.14199 L=1.14146, idx_hi=141 idx_lo=7,  LOW_FIRST
m0  2026.07.09 00:05:00,  91 ticks, H=1.14199 L=1.14146, idx_hi=91  idx_lo=2,  LOW_FIRST
m1  2026.07.09 00:05:00,  20 ticks, H=1.14199 L=1.14146, idx_hi=19  idx_lo=2,  LOW_FIRST
```

The tick *paths* are entirely different — the hashes differ
(`2902195103736716685` / `4195658740764198420` / `710620364845699507`). The
*ordering of the bar's extremes* is identical.

---

# 1. Why this happens, and why it does not exonerate generated modes

`[INFERRED]` An M5 bar contains five M1 bars. The M5 high lies in one of them and
the M5 low in another. **Which M1 sub-bar holds each extreme is real information
present in M1 OHLC**, so a generator built from M1 data reproduces that ordering
faithfully. Fabrication can only matter when **both** M5 extremes fall inside the
*same* M1 bar — a minority of cases, and evidently not enough to alter any of the
288 orderings here.

> **The correct statement is therefore about granularity, not about generation:**
>
> - At **M5 and coarser**, the order of a bar's own extremes is largely recoverable
>   from M1 OHLC. Generated models reproduce it. `[OBSERVED]`
> - At **M1**, order is **not** recoverable — `E-MT5-007` proved it on real ticks
>   with two candles of identical range and identical normalised shape and
>   opposite order. `[CONFIRMED]`

## 1.1 What this does **not** establish

This experiment measured the order of **the bar's own high and low**. The
methodology's sweep rule is *penetration of an external level, then rejection* —
which involves prices that need not be the bar's extremes, and timing within the
bar. **Nothing here validates generated models for sweep detection.**

`[UNKNOWN]` Whether generated models reproduce the *timing* of an arbitrary level
crossing within a bar, as opposed to the ordering of the bar's extremes.

---

# 2. Blocked comparison

The decisive test — **the same comparison at the M1 timeframe**, where order is
known to be unrecoverable — is **`[BLOCKED]`**.

| Run | Result |
|---|---|
| M1, `Model=4` real ticks | ✅ 1,440 bars — `hi_first=711, lo_first=729, undetermined=0` |
| M1, `Model=1` OHLC | ❌ **failed to launch**, three attempts |

`[OBSERVED]` The failure is the launch-environment defect of `E-MT5-OBS-002` §7,
not a tester or EA problem: the second run in any sequence frequently fails to
start because the `.app` wrapper exits with the previous terminal, leaving no
correctly configured `wineserver`. The identical config for M5 succeeded.

**Prediction, recorded before the test so it can be scored:** at M1 the two models
**will** disagree on a substantial fraction of bars, because a 1-minute-OHLC
generator has, by construction, no information about intra-minute sequence beyond
its fixed synthetic path. If they agree, that would be surprising and would
require explaining what information the generator is using.

---

# 3. Environment guard probe `[OBSERVED]`

For the `ENVIRONMENT = DEMO` guard requested in the authorization:

```
GUARD, ACCOUNT_TRADE_MODE,        DEMO, raw=0
GUARD, account,                   10012089985, MetaQuotes-Demo, MetaQuotes Ltd.
GUARD, trade_allowed_terminal,    true, expert=true
```

> `[CONFIRMED]` **MT5 exposes the account type programmatically.**
> `AccountInfoInteger(ACCOUNT_TRADE_MODE)` returns
> `ACCOUNT_TRADE_MODE_DEMO (0)` / `CONTEST (1)` / `REAL (2)`. A guard that refuses
> to operate when the value is `REAL` is therefore **technically implementable**
> and needs no invented architecture.
>
> Note `trade_allowed_terminal=true` and `expert=true` — i.e. the terminal *would*
> permit trading. The observability EA does not trade because **no trade function
> is linked**, not because permission is absent. That is the stronger guarantee,
> and it is the one already in force.

The guard's *placement* is a design decision, not settled here — see
`VAL-002` §5.

---

# 4. Decision impact

| Decision | Effect |
|---|---|
| `D-M5` (valid tester modes) | **Materially advanced.** Generated models are *not* categorically invalid; validity depends on the **timeframe** and on whether the rule depends on the bar's extremes or on arbitrary level crossings. The blanket rejection in `MT5-CAP-001` §6 is withdrawn |
| `MT5-CAP-001` F5 | **`[REFUTED]` as stated.** Replaced by the granularity statement in §1 |
| `MT5-EXP-001` §3.2 fork | Unchanged — the (a)/(b) fork still turns on whether any rule is order-sensitive **at M1 or intrabar** |
| New `D-V11` | Where does the `ENVIRONMENT` guard live — kernel, adapter, host, or configuration? |

Register: **81 → 82.**

---

# 5. Red-team

| Attack | Assessment |
|---|---|
| **"Zero disagreements is too clean — the probe must be broken."** | Checked: the probe *does* discriminate — hashes and tick indices differ sharply between models. Only the derived ordering coincides. The instrument distinguishes what it should and agrees where the data agrees. |
| **One day, one symbol** | 288 bars on a single 24-hour window. Not a frequency estimate. |
| **Feed** | MetaQuotes-Demo. Irrelevant to ordering; still disqualifying for spread. |
| **Extremes ≠ sweeps** | Stated explicitly in §1.1. This is the biggest limitation of the result and the reason it must not be read as "generated modes are fine". |
| **Missing M1 comparison** | The result that would most likely *contradict* the headline is precisely the one that is blocked. Recorded as such rather than omitted. |
