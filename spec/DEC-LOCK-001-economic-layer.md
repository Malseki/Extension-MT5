# DEC-LOCK-001 — Decision Lock Sheet: the Economic Layer

*STEP B deliverable. **No BUY/SELL is implemented until this sheet is approved.***

Three columns of status, and they are never blurred:

- **LOCKED** — you decided it. Binding.
- **DERIVED** — follows from measured project evidence or from MT5 mechanics.
  No choice existed. The derivation is stated so you can reject it.
- **OPEN** — a genuine decision. A **PROPOSED** value is offered so you can
  approve in one pass, but nothing is implemented until you say so.

---

# 0. Measured inputs this sheet rests on

`[OBSERVED]` `E-MT5-012`, EURUSD, MetaQuotes-Demo, build 6096, 2026-08-07:

| Property | Value |
|---|---|
| digits / point / tick size | 5 / 0.00001 / 0.00001 |
| contract size | 100,000 |
| volume min / step / max | **0.01 / 0.01 / 500** |
| **stops level** | **0 points** — broker imposes no minimum SL/TP distance |
| freeze level | 0 |
| spread (current, floating) | 2 points, `SPREAD_FLOAT=1` |
| **spread mean over 5,000 M5 bars** | **0.031 points** (min 0, max 12) |
| swap long / short | −0.70 / −1.00 |
| account currency / leverage | USD / 1:100 |

Two readings were unreliable in that run and will be re-measured at
implementation: `tick_value` returned 0.00000 and `account_balance` 0.00, both
because the startup-launched terminal had not finished synchronising. For EURUSD
with a 100,000 contract, 1 point ≈ **$1.00 per 1.00 lot** `[INFERRED]`.

> ## ⚠ The spread finding governs everything below
>
> **Mean spread 0.031 points across 5,000 M5 bars.** That is effectively zero
> transaction cost. Any P&L produced on this data is **systematically optimistic**
> by roughly one full spread per round trip versus a real broker. `D-M4` stays
> **OPEN**, and the first backtest must be labelled an
> **ENGINEERING VALIDATION BACKTEST**, never a profitability result.

---

# 1. PATTERN

| # | Decision | Status | Value |
|---|---|---|---|
| — | **SW-4** sweep candle close | **LOCKED** | `C(2) < REF` required. Pattern is a false-break / acceptance-then-rejection. Not to be reinterpreted as a wick-sweep. |
| — | **SW-5** rejection | **LOCKED** | **R-a**: `C(3) ≥ L(2)` |
| — | **SW-6** adjacency | **LOCKED** | strict `1 → 2 → 3`, three consecutive candles |
| — | **SW-1 option B** | **ELIMINATED** | symmetric pivot is logically incompatible (`SPEC-SW-001` §10.1) |
| **1** | **SW-1** — definition of REF | **OPEN** | **A** = any previous candle → **5,663** detections / 40,000 M5 bars. **A′** = left-only extreme: `L(R)` is the lowest of the previous `K` candles, no right-hand condition. `A′` is `A` with a filter; it is strictly rarer. **PROPOSED: A′ with K = 3.** |
| **2** | **SW-3** — minimum penetration | **OPEN** | 0 points = any tick below REF (what was measured). **PROPOSED: 0** — keeps the first run identical to the measured baseline. |
| **3** | **SW-7** — timeframe | **OPEN** | **PROPOSED: M5** — the timeframe already measured and already validated for Model=4 replay. |
| **4** | Session filter mandatory? | **OPEN** — blocked by `DEC-S-001` A-1/A-2/A-3 and `D-M6` | **PROPOSED: OFF for the engineering run**, and recorded as a scoping choice, not a resolution of `DEC-S-001`. Turning it on requires answering the NY-window ambiguities first. |
| **5** | Bid/Ask treatment | **DERIVED (pattern)** + **OPEN (rule)** | Pattern is evaluated on **Bid** — `SYMBOL_CHART_MODE=0` measured, bars *are* Bid. Execution side is mechanical (#23). The economic question of whether a sweep *should* be defined on Ask is `D-M4`, still **OPEN**, and does not block this run. |
| **6** | Min/max distance constraints | **OPEN** | **PROPOSED: none.** Adding one is a filter, and filters belong to a later phase. |

# 2. ENTRY

| # | Decision | Status | Value |
|---|---|---|---|
| **7** | Entry trigger | **OPEN** | **PROPOSED:** pattern `DETECTED` on the close of candle 3, no further confirmation. Note this deliberately leaves `CONFIRMATION` **BLOCKED** — the methodology's confirmation stage (`DEC-044`) is unresolved, so the first economic run tests *pattern → trade*, not the full chain. |
| **8** | Entry price | **DERIVED once #9 is chosen** | Market order; MT5 fills a BUY at **Ask**. |
| **9** | Entry timing | **OPEN** | *"At candle 3 close" is not executable* — MQL5 cannot act at a close, only on the next tick. Honest options: **(i)** market on the **first tick of candle 4** (price ≈ candle 3 close), **(ii)** buy-stop above `H(3)`, **(iii)** buy-limit at a retracement level. **PROPOSED: (i)** — the only one that needs no additional undecided parameter. |
| **10** | Stop location | **OPEN** | Candidates: **(a)** below `L(2)` — the sweep extreme, the level the pattern claims was defended; **(b)** below `L(3)`; **(c)** fixed distance. **PROPOSED: (a)**, `SL = L(2) − 1 point`. |
| **11** | Spread in stop | **DERIVED + OPEN (padding)** | A BUY is closed at **Bid**, so the SL is evaluated on Bid — mechanical. Whether to *pad* the stop by one spread is a decision. **PROPOSED: no padding**, since measured spread ≈ 0 makes padding meaningless here and it would mask the real-broker gap. |
| **12** | Minimum stop distance | **DERIVED** | `stops_level = 0` measured → **no broker constraint**. A strategy-level minimum is **OPEN**; **PROPOSED: none**. |

# 3. TARGET

| # | Decision | Status | Value |
|---|---|---|---|
| **13** | Target rule | **OPEN** | **PROPOSED:** fixed R multiple from entry. |
| **14** | Fixed R vs structural | **OPEN** | Structural targets need "opposing liquidity", which is `DEC-020`/`DEC-052`, both **OPEN**. **PROPOSED: fixed R = 2.0** — chosen for auditability, explicitly *not* optimised, and to be reported alongside R = 1.0 and R = 3.0 as a sensitivity check **after** the first result is recorded. |
| **15** | Partial exits | **OPEN** | **PROPOSED: none.** |

# 4. RISK

| # | Decision | Status | Value |
|---|---|---|---|
| **16** | Initial balance | **DERIVED (convention)** | **$10,000 USD** — you authorised it and no specification defines another. |
| **17/18** | Position size | **OPEN** | **PROPOSED: fixed fractional, 1.0% of balance risked per trade**, lot computed from the SL distance and rounded **down** to the 0.01 step, floored at 0.01 and skipped if the computed lot is below the minimum. Fixed-lot is the alternative; it makes R-multiples and dollars diverge as the balance moves. |
| **19** | Max simultaneous positions | **OPEN** | **PROPOSED: 1.** |
| **20** | New signal while a trade is open | **OPEN** | **PROPOSED: ignored**, and logged as `SKIPPED_POSITION_OPEN` so the ledger shows what was declined and why. |

# 5. EXECUTION ASSUMPTIONS

| # | Decision | Status | Value |
|---|---|---|---|
| **21** | Slippage | **DERIVED** | MT5 Strategy Tester applies **no slippage** unless configured. Under `Model=4` fills occur at the recorded tick price. **Assumption: 0.** Real execution will differ. |
| **22** | Spread source | **DERIVED + WARNING** | Real recorded spread under `Model=4`. **Measured mean 0.031 points** → effectively costless. This is the single largest distortion in the result. |
| **23** | Bid/Ask for trigger and execution | **DERIVED** | Pattern and SL/TP levels are Bid-derived (bars are Bid). BUY opens at **Ask**, closes at **Bid**; SELL mirrors. Purely mechanical MT5 semantics, not a choice. |
| **24** | Entry and stop/target inside the same candle | **DERIVED, and it forces the model** | Under **`Model=4` real ticks** the actual tick sequence decides which was hit first — no ambiguity. Under generated models the intrabar path is synthetic; `E-MT5-008` showed generated models reproduce the ordering of a *bar's own extremes* at M5, but that says **nothing** about arbitrary SL/TP level crossings. **Therefore `Model=4` is mandatory for any economic run**, not merely preferred. |

---

# 6. What remains BLOCKED and will be shown as such

These stages stay `BLOCKED` on the panel throughout. The first economic run tests
`PATTERN → TRADE`, deliberately **not** the full methodology:

`CONFIRMATION` (`DEC-044`) · `STRUCTURE / MSS` (`DEC-029`) · `FVG` (`DEC-036`) ·
`RETRACEMENT` (`DEC-030`) · `HTF CONTEXT` (`D-M1`) · `SESSION` (`DEC-S-001`) ·
`ACCUMULATION` · `DPMO`

> **This is the honest framing of what is about to be measured.** It is not
> "the strategy". It is the 1-2-3 pattern plus the smallest possible trade
> wrapper. The measured selectivity — 5,663 detections in 40,000 M5 bars, ≈40 per
> day — is high precisely *because* every filter above is absent. Expect a large
> number of trades and do not read the result as an evaluation of the
> methodology.

---

# 7. Safety, unchanged

- No trade function is linked until this sheet is approved. That structural
  guarantee remains the primary mechanism.
- `ACCOUNT_TRADE_MODE == REAL` → refuse to initialise the trading layer.
- Panel displays `ENVIRONMENT: DEMO`, `LIVE TRADING: DISABLED`, `MODE: BACKTEST`.
- Logged before every run: account mode, account, symbol, timeframe, model,
  initial balance, risk configuration.

---

# 8. Approval

Reply with **"lock as proposed"** to accept every PROPOSED value, or name the
line numbers you want changed. Nothing is implemented before that.

The values most worth a second look, in order: **#14** (R = 2.0 is arbitrary and
I picked it for auditability, not evidence), **#1** (A vs A′ changes the trade
count by an order of magnitude), **#10** (stop placement drives every R), and
**#4** (running without the session filter is a large deviation from your
methodology).

---

# 9. LOCKED — 2026-08-07

Approved by the trader with qualifications. **Binding for the ENGINEERING
VALIDATION BACKTEST only.** None of these values is an empirically validated
trading rule, and none may ever be presented as one.

| Item | LOCKED value |
|---|---|
| REF (`SW-1`) | **A′**, K=3 — `L(1)` strictly lower than the lows of the 3 candles immediately preceding it (left-only extreme, no right-hand condition) |
| `SW-4` | `C(2) < REF` **required** |
| `SW-5` | **R-a**, `C(3) ≥ L(2)` |
| `SW-6` | strict adjacency 1→2→3 |
| Timeframe | **M5** |
| Entry | market on the **first available tick of candle 4**. Both the candle-3 close and the actual fill are recorded so the execution gap is measurable |
| Stop | `SL = L(2) − 1 point`; spread treatment explicit in the log; no padding |
| Target | `TARGET_R = 2.0`, **STATUS = PROVISIONAL / ENGINEERING VALIDATION** |
| Risk | fixed fractional **1.0 % of balance per trade**; balance **$10,000 USD**, fixed |
| Session | **DISABLED** — `STATUS = OPEN DEC-S-001` |
| Bid/Ask | Bid-based pattern (`SYMBOL_CHART_MODE=0` measured). **`D-M4 = OPEN`** |
| Model | **`Model=4` real ticks — REQUIRED**. `Model=0`/`Model=1` forbidden for economic P&L |
| Environment | **DEMO ONLY**; REAL rejected by the guard |
| Scope | **"1-2-3 PATTERN + MINIMUM ECONOMIC WRAPPER"** |

**Still BLOCKED and rendered as such:** CONFIRMATION, MSS, FVG, RETRACEMENT,
HTF CONTEXT, SESSION, ACCUMULATION, DPMO.

**Not resolved by this lock:** `DEC-S-001`, `D-M4`, `DEC-044`, `DEC-029`,
`DEC-036`, `DEC-030`, `D-M1`, and every other open decision.

Report label, mandatory: **ENGINEERING VALIDATION BACKTEST — NOT A PROFITABILITY
CLAIM.**

## 9.1 One implementation detail requiring your eye

`A′` is implemented as: `L(1) < L(1+i)` for `i = 1..3`, strictly. That reads
"candle 1's low is lower than each of the three candles before it". The
alternative reading of your wording — *"the reference level is `min(L)` over the
previous 3 candles"*, where the level need not belong to candle 1 — is a
different rule and would change results. The implemented predicate is written
into every event as `REF_RULE=A_prime_K3_strict_left`. **Correct me if the other
reading was intended.**
