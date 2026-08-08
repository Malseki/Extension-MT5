# MT5 Feasibility Experiments

**Status: WRITTEN, NOT EXECUTED, NOT COMPILED.**

These are scientific instruments, not production code. They exist to answer
questions about MetaTrader 5's actual semantics before the foundation is frozen.
None of them contains detector logic, and none may be reused in the detector.

---

## 1. Why nothing here has been run

MetaTrader 5 is installed on this machine as the **native macOS sandboxed build**
(`/Applications/MetaTrader 5.app`, bundle id `net.metaquotes.MetaTrader5Terminal`).
Its data folder lives inside

```
~/Library/Containers/net.metaquotes.MetaTrader5Terminal/Data
```

which macOS protects. That directory returns `Operation not permitted` to this
session — verified, not assumed. Three consequences, all permanent for this
workflow:

1. **I cannot install these files.** They must be copied in by hand (§3).
2. **I cannot compile them.** No MetaEditor access ⇒ the code below is
   syntactically unverified. Expect to fix compile errors on first build; that is
   normal and does not affect the experiment design.
3. **I cannot run them.** Running requires a logged-in terminal with a broker
   connection and a program attached to a chart — GUI actions with credentials.

**Every MT5 claim in `MT5-CAP-001`, `MT5-EXP-001` and `MT5-FORMAL-001` is
therefore labelled `[DOC]`, `[BELIEF]` or `[EXP]`.** Nothing is labelled as
observed. The `[EXP]` items are exactly what these files exist to settle.

## 2. Epistemic labels used throughout the corpus

| Label | Meaning |
|---|---|
| `[DOC]` | Stated in official MQL5/MetaTrader 5 documentation. Still worth confirming, but not in doubt. |
| `[BELIEF]` | High-confidence understanding of MT5 behaviour, **not** verified in this environment and **not** always documented. Treat as a hypothesis with a good prior. |
| `[EXP]` | Genuinely open. Requires one of the experiments here. |

A `[BELIEF]` that turns out false is a first-class discovery and must be recorded
as such, not quietly corrected.

## 3. Installation

The container is protected, so use MT5's own path:

1. In MetaTrader 5: **File → Open Data Folder**.
2. Copy `E-MT5-0*.mq5` into `MQL5/Experts/trader-experiments/`.
3. In MetaEditor: compile each (F7). Fix any syntax errors — see §1.2.
4. Attach to a chart per each file's header. Run with **AutoTrading enabled**
   (these place no orders; MT5 still gates EA execution on it).
5. Output lands in the **common** folder: **File → Open Data Folder →** go up to
   `Terminal/Common/Files/`. Every file is CSV, one row per observation.
6. Send the CSVs back and the `[EXP]` rows get settled with real data.

## 4. The experiments

| ID | Question it settles | Type | Runtime | Status |
|---|---|---|---|---|
| **`E-MT5-006`** | **Historical Bid/Ask/spread availability; do bid- and ask-based penetration produce different historical event sets?** | Script | 1–15 min | **AWAITING EXECUTION** |
| **`E-MT5-007`** | **Intrabar ordering and M1 sufficiency: can we tell whether the high or the low came first?** | Script | 2–20 min | **AWAITING EXECUTION** |
| `E-MT5-001` | When exactly does an M1 bar close, and is closure clock-driven or tick-driven? | EA | ≥ 30 min live | prepared |
| `E-MT5-002` | When does an M5/M15/M30/H1/H4 bar become *knowably* closed, measured from M1? | EA | ≥ 5 h live, spanning an H4 boundary | prepared |
| `E-MT5-003` | What happens across a quiet interval — are bars skipped, and can the engine tell? | EA | overnight or a low-liquidity symbol | prepared |
| `E-MT5-004` | Are multi-timeframe series synchronised, and what does an unsynchronised read return? | EA | 10 min after a fresh terminal start | prepared |
| `E-MT5-005` | Can two symbols share a causal clock? | EA | ≥ 1 h live | prepared |
| `E-MT5-008` | History depth, gaps, tick-history range, "no event" vs "no data". | Script | seconds | prepared |
| `E-MT5-009` | Live Bid/Ask/spread and what forms the OHLC; the tester-mode comparison harness. | EA | ≥ 30 min live, then once per tester mode | prepared |

**`E-MT5-006` and `E-MT5-007` are the priority pair** and have full instruction
and report documents of their own. Between them they settle `D-M4` (ask-based
penetration), `D-M5` (valid tester modes), the σ condition (`RT-18` cond. 1), the
M1-sufficiency fork (`MT5-EXP-001` §3.2), and — via their winter/summer probe —
part of `D-M6`, which no amount of documentation could resolve.

> **Numbering note.** `E-MT5-006` and `E-MT5-007` were re-scoped in the empirical
> phase. The earlier instruments that held those numbers are now `E-MT5-009`
> (live bid/ask) and `E-MT5-008` (history probe). Nothing was lost; the two
> priority questions took the numbers.

**Session windows.** `E-MT5-006` and `E-MT5-007` sample **inside** the New York
windows recorded in `DEC-S-001`, not uniformly, because that is where the
methodology operates. Those windows carry six unresolved ambiguities — read
`DEC-S-001` before trusting any session-filtered result.

## 5. Environment to record with every run

Fill this in and return it alongside the CSVs. Results without it are not
reproducible and will not be accepted as evidence.

```
terminal build      :
broker / server     :
account type        : demo | real
symbol(s)           :
symbol chart mode   : SYMBOL_CHART_MODE_BID_PRICE | ..._LAST_PRICE
digits / point      :
tick size           :
date + time (local) :
server time offset  :
tester mode         : n/a | every tick | real ticks | 1-min OHLC | open prices
tick history depth  : (from E-MT5-007)
```

## 6. Rules

- No experiment may import from another, or from anything in `spec/`.
- No experiment may contain liquidity, MSS, FVG, pullback or confirmation logic.
- Every experiment writes CSV and nothing else — no chart objects, no alerts.
- If an experiment needs to change to answer its question, change the experiment,
  never the interpretation of an old run.
