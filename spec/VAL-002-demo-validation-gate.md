# VAL-002 — DEMO Validation Gate

*The pre-production gate between the DEMO laboratory and any real-money
consideration. Authorised 2026-08-07. The gate is defined here; **nothing has
passed it**, because the detector it would test does not exist.*

`[OBSERVED]` · `[CONFIRMED]` · `[REFUTED]` · `[INFERRED]` · `[UNKNOWN]` ·
`[BLOCKED]` · `[DECISION REQUIRED]`

---

# 0. Standing status

```
ENVIRONMENT = DEMO-ONLY
```

**No transition to a real account may be proposed by this system.** It requires an
explicit decision from the trader, recorded, and it is not a technical judgement.

**The authorization activates on a condition that is not yet met.** It permits
autonomous DEMO testing *"whenever the required methodology/specification has been
formally defined"*. As of now:

| Blocking | Status |
|---|---|
| `D-P1` unbounded population semantics | OPEN |
| `D-P2` predicate stratification | OPEN |
| `D-P3` `Pop_known` vs `Pop_occurred` | OPEN |
| `D-M1` HTF closed vs forming | OPEN |
| `D-M4` bid vs ask penetration | OPEN — needs a real broker feed |
| `D-M6` broker timezone / DST | OPEN, constitutional |
| `DEC-S-001` A-1/A-2/A-3 session windows | OPEN |
| Every trading-semantic decision in `DEC-001` | OPEN |

> **Therefore: no detector backtest, no forward test, no robustness run.**
> There is nothing to test. What *can* proceed autonomously — and has — is
> platform and infrastructure validation, which is what `E-MT5-006/007/008` and
> `OBS-001/002` are.

---

# 1. Gate structure

Eight categories, from the authorization. Each criterion is written so it can
**fail**. A criterion that cannot fail is not a test.

Status key: **READY** = testable today · **BLOCKED** = needs a decision or the
detector · **PARTIAL** = infrastructure proven, subject pending.

## G1 · Functional correctness

| # | Criterion | Status | Evidence |
|---|---|---|---|
| G1.1 | Every stage behaves per specification | **BLOCKED** | no specification |
| G1.2 | No forbidden state transitions | **BLOCKED** | state machine not frozen |
| G1.3 | No accidental BUY/SELL | **PARTIAL — mechanism proven** | `E-MT5-OBS-002` IT-4: 126 combinations, `Verdict()` structurally incapable |
| G1.4 | No signal while a prerequisite is BLOCKED/UNKNOWN | **PARTIAL — mechanism proven** | IT-5 |
| G1.5 | No duplicate signals | **BLOCKED** | requires `DEC-055` setup identity |

## G2 · Historical correctness

| # | Criterion | Status | Evidence |
|---|---|---|---|
| G2.1 | Correct replay model selected | **PARTIAL** | `E-MT5-008`: model validity depends on timeframe and rule shape |
| G2.2 | Real ticks used where intrabar order matters | **READY** | `Model=4` confirmed working end-to-end |
| G2.3 | No look-ahead | **READY (test exists)** | recalculation-invariance, `REDTEAM-003` §4.1 |
| G2.4 | `t_occurred` ≠ `t_known` preserved | **CONFIRMED for infrastructure** | `E-MT5-OBS-002` §4.1 |
| G2.5 | No future information in historical decisions | **BLOCKED** | no decisions exist |

## G3 · Determinism

| # | Criterion | Status | Evidence |
|---|---|---|---|
| G3.1 | Identical inputs → identical event log | **CONFIRMED for infrastructure** | byte-identical logs, identical FNV-1a hash, two runs |
| G3.2 | Hashes reproducible | **CONFIRMED** | `16633771818731992620` twice |
| G3.3 | Replay independent of wall-clock | **CONFIRMED** | runs 12 minutes apart, identical output |
| G3.4 | Determinism of the *detector* | **BLOCKED** | detector does not exist |
| G3.5 | Multi-symbol / multi-agent determinism | **UNKNOWN** | untested |

## G4 · Execution semantics

| # | Criterion | Status |
|---|---|---|
| G4.1 | Signals at the correct causal moment | **BLOCKED** |
| G4.2 | Spread / bid / ask semantics explicit | **BLOCKED** — `D-M4`, and needs a real feed |
| G4.3 | Signal price explicitly defined | **BLOCKED** — not yet a decision in the register |
| G4.4 | Invalidation explicitly defined | **BLOCKED** — `DEC-054` |
| G4.5 | Duplicate/repeated ticks cannot double-fire | **READY to test** | `E-MT5-006` measured `time_msc` collisions up to 39.6% — the hazard is real and quantified |

## G5 · Observability

| # | Criterion | Status | Evidence |
|---|---|---|---|
| G5.1 | Every signal explainable from the panel | **PARTIAL** | panel renders; content pending |
| G5.2 | Every signal has event/rule identity | **CONFIRMED for infrastructure** | ids follow `REDTEAM-002` §2.2, reproducible across runs |
| G5.3 | All relevant levels/values visible | **PARTIAL** | all 13 object types work |
| G5.4 | Chart reconstructs why the signal happened | **BLOCKED** |
| G5.5 | Human can audit without trusting a black box | **BLOCKED** |
| G5.6 | Visual evidence capturable from replay | **`[OBSERVED]` NOT POSSIBLE** via `ChartScreenShot` — `D-V10` |

## G6 · Robustness

| # | Criterion | Status |
|---|---|---|
| G6.1 | Multiple historical periods | **READY** — ~14.6 y ticks, ~27 y bars available |
| G6.2 | Different market conditions | **READY** |
| G6.3 | Session boundaries | **BLOCKED** — `DEC-S-001` A-1 |
| G6.4 | DST transitions | **BLOCKED** — `D-M6`; the ~4 weeks/year where US and EU DST disagree |
| G6.5 | Missing data | **READY to test** — `E-MT5-006` §4.1: weekend and absent history are indistinguishable |
| G6.6 | Spread variations | **BLOCKED** — MetaQuotes-Demo spread is degenerate |
| G6.7 | Restart / recovery | **READY to test** — needs the checkpoint format (`REDTEAM-003` §7) |
| G6.8 | Long-running demo operation | **READY** — but see §4 |

## G7 · Negative testing

**Deliberately construct situations where BUY/SELL must NOT occur, and verify
silence.** Currently **trivially satisfied and therefore meaningless**: the engine
cannot emit BUY/SELL at all. It becomes a real test the moment `Verdict()` gains
its first reachable BUY path — and **that is the moment it must be written**,
not after.

`[DECISION REQUIRED]` The negative suite must be written **before** the first
positive path, or it will be written to match whatever the implementation does.

## G8 · Regression

Every future change reruns the suite; a passing invariant must not silently
regress. **READY** — the harness exists: hash comparison plus the IT-1…IT-5
invariant battery, both already automated and both already run twice.

---

# 2. What the gate cannot do

- It cannot establish **live execution equivalence**. Demo fills, latency and
  spread are not live ones. No amount of demo passing changes that.
- It cannot establish **future performance**.
- It cannot compensate for a **wrong specification**. A faithful implementation of
  a wrong rule passes every criterion here.

> A strategy that profits in backtest through look-ahead, repainting, fabricated
> intrabar order, wrong session conversion or wrong spread assumptions is a
> **failure**, and G2/G3/G6 exist to catch exactly those before profitability is
> ever discussed.

---

# 3. What is already proven, and what it is worth

`E-MT5-OBS-002` and `E-MT5-008` established the **infrastructure** half of G1.3,
G1.4, G2.2, G2.4, G3.1–G3.3, G5.2 on real tick data.

> **This is a real result and it is not a small one** — determinism, causal
> timestamping and the no-accidental-verdict property are usually discovered to be
> broken *after* a strategy is built. Here they are established first, on an empty
> engine, where fixing them is free.
>
> **It is also worth exactly nothing about the methodology.** Every criterion that
> touches trading semantics is BLOCKED, and no quantity of infrastructure passing
> converts into a trading claim.

---

# 4. The `ENVIRONMENT` guard

`[CONFIRMED]` technically feasible: `AccountInfoInteger(ACCOUNT_TRADE_MODE)`
returns `DEMO(0)` / `CONTEST(1)` / `REAL(2)`, measured live in `E-MT5-008` §3.

**Placement is a decision, not an implementation detail** (`D-V11`):

| Option | Argument |
|---|---|
| **Kernel** | ✗ The kernel is host-agnostic and knows nothing of accounts. Placing it there breaks the layering of `MT5-OBS-001` §1.1. |
| **Adapter** | ✓ The adapter already owns everything MT5-specific. Natural home. |
| **Host (EA)** | ✓ Earliest possible refusal — `OnInit` can decline to start. |
| **Configuration** | ✗ Alone, insufficient — a config file can be edited without review. |

`[PROPOSED]` **Host refuses to initialise + adapter refuses to supply data**, both
required, with configuration as a third independent gate. Defence in depth, and no
single edit can enable a real-account path.

> **Stronger property already in force:** the EA cannot trade because **no trade
> function is linked into it**, not because permission is withheld. The terminal
> reports `trade_allowed=true` and the EA still cannot place an order. That
> guarantee is structural and should be preserved as the primary mechanism, with
> the `ENVIRONMENT` guard as a secondary declaration of intent.

---

# 5. Gate procedure, when the specification is frozen

1. Freeze `spec`, `selectors`, `thresholds`; record the run quadruple.
2. Write the **G7 negative suite first**.
3. G3 determinism: three runs, identical hashes.
4. G2 causality: prefix/recalculation invariance.
5. G1 functional: state machine conformance against the frozen spec.
6. G6 robustness across periods, sessions, DST, missing data, restart.
7. G5 observability audit: reconstruct every signal from the chart alone.
8. Forward-test on DEMO for a declared minimum duration.
9. G8 regression baseline recorded.
10. **Human validation** against the labelled corpus (`VAL-001`).
11. Report to the trader. **The real-account decision is theirs alone.**

Steps 2–7 are automatable and authorised. Steps 8–11 are not automatable.

---

# 6. Status

**Gate defined. Nothing submitted. Nothing passed.**

The only honest summary: the laboratory is built, instrumented and proven
deterministic; the subject of the experiment does not yet exist.
