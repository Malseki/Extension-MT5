# MT5-OBS-001 — Observability Layer Architecture

*Track B. How the engine becomes visible inside MetaTrader 5 without the
visualisation silently deciding anything Track A has not decided.*

**Evidence base:** `E-MT5-OBS-001` executed on the live terminal (build 6096).
Raw: `experiments/mt5/raw/2026-08-07T2100Z-OBS001/` — capability CSV + a rendered
chart screenshot. Every `[OBSERVED]` below is from that run.

`[OBSERVED]` · `[DOC]` · `[INFERRED]` · `[UNKNOWN]` · `[PROPOSED]`

---

# 0. What was measured, not assumed

| Capability | Result |
|---|---|
| `OBJ_HLINE`, `OBJ_VLINE`, `OBJ_TREND`, `OBJ_ARROWED_LINE` | **OK**, read-back verified |
| `OBJ_RECTANGLE` (+ `OBJPROP_FILL`) | **OK** — FVG boxes render filled |
| `OBJ_FIBO` | **OK** — retracement band renders with levels |
| `OBJ_CHANNEL`, `OBJ_ARROW`, `OBJ_TEXT` | **OK** |
| `OBJ_RECTANGLE_LABEL`, `OBJ_LABEL` (pixel-anchored) | **OK** — the debug panel |
| `OBJ_BUTTON`, `OBJ_EDIT` | **OK** — interactive controls exist |
| 500 objects created | **1 ms**, 534 total on chart, clean deletion to 34 |
| `ChartScreenShot` | **OK** — 85 KB PNG, programmatically retrievable |
| `Print` → journal | **OK** — always available, carries full explanation text |
| `PlaySound` | **OK** |
| `SendNotification` | **FAIL, err 4517** — needs a MetaQuotes ID in terminal settings |
| `SendMail` | **FAIL, err 4510** — needs SMTP configured |
| `Alert()` | **not fired** — opens a **modal dialog**; deliberately skipped |

`[OBSERVED]` All 13 object types the methodology needs are available and
read-back correct. **Rendering is not a constraint on this project.**

---

# 1. Host selection — decided on semantics, not convention

| Host | Runs in Tester | Own thread | Buffers | Objects | Chart-independent | Verdict |
|---|---|---|---|---|---|---|
| **Script** | ✗ `[DOC]` | ✓ | ✗ | ✓ | ✗ | one-shot — **rejected** |
| **Service** | **✗** `[DOC]` | ✓ | ✗ | ✗ (no chart) | ✓ | **rejected**: cannot be replayed |
| **Indicator** | ✓ | shared per symbol+TF `[DOC]` | ✓ | ✓ | ✗ | secondary role only |
| **Expert Advisor** | ✓ | ✓ | ✗ | ✓ `[OBSERVED]` | ✗ | **selected as host** |

**`[PROPOSED]` The EA hosts the engine; chart objects are the renderer.**

Reasoning, in order of weight:

1. **Replay is constitutional.** A Service cannot run in the Strategy Tester
   `[DOC]`, which disqualifies it outright however well it fits otherwise. This is
   `MT5-CAP-001` F7 deciding the question.
2. **What the methodology needs to draw is object-shaped, not buffer-shaped.**
   FVG boxes, liquidity levels, retracement bands, state labels and rejection
   reasons cannot be expressed as indicator buffers. Buffers carry one number per
   bar; almost nothing here is one number per bar.
3. **An EA has its own thread** `[DOC]`, so a heavy population fold cannot stall
   other charts — an indicator shares a thread per symbol+timeframe.
4. **The EA never trades.** No trade function is linked. "Expert Advisor" is a
   program type in MT5, not a behaviour.

**Indicators keep a secondary role** for genuinely per-bar numeric series
(volatility baseline, efficiency ratio) where a buffer is the natural carrier.

## 1.1 The layering that keeps Track B from deciding Track A

```
kernel/          host-agnostic .mqh — Series, Lift, Delay, guarded recursion,
                 monotone stacks. No MT5 calls. No rendering.
      ↓
adapter/         MT5 → kernel: bars, ticks, ⊥ from CopyX failures, exogenous
                 clock, symbol metadata. The six adapters of MT5-FORMAL-001 §4.
      ↓
host/            EA: lifecycle, OnTick/OnTimer, checkpointing.
      ↓
render/          objects; consumes the event log, never recomputes anything.
      ↓
signal/          journal + optional channels.
```

> **The renderer is a pure function of the event log.** It may not evaluate a
> predicate, and it may not draw anything the engine did not emit. That is what
> stops the visualisation from quietly inventing a rule.

---

# 2. State model — and a formal result the UI forced

The prototype renders four states: **PASS · FAIL · WAITING · UNKNOWN**
`[OBSERVED]` — legible and colour-distinct in the screenshot.

But these four are **not** four truth values, and treating them as such would
re-introduce the exact error `REDTEAM-002` §6 identified. They decompose:

| UI state | Truth value | Epistemic status | Meaning |
|---|---|---|---|
| **PASS** | `TRUE` | determined | the predicate holds |
| **FAIL** | `FALSE` | determined | it does not, and that is final |
| **WAITING** | `⊥` | **pending, deadline running** | undetermined *so far*; more data may resolve it |
| **UNKNOWN** | `⊥` | **undeterminable** | data absent or the decision is unresolved |

> `[INFERRED]` **WAITING and UNKNOWN carry the same truth value and different
> epistemic status.** Merging them — the obvious UI simplification — would make a
> missing-data state indistinguishable from a still-forming one, which is `RT-15`
> and `D-M2` arriving through the interface.
>
> The observability layer therefore needs `(truth, epistemic status)`, exactly the
> decomposition `REDTEAM-002` derived from first principles. **The UI requirement
> independently reproduced the formal result** — weak evidence that both are right.

A fifth display state is required and was **not** in the request:

| **BLOCKED** | — | unresolved decision | the rule itself is not specified yet |

> `[PROPOSED]` Any stage whose specification is still open (`D-M1`, `D-P3`,
> `DEC-S-001` A-1/A-2/A-3 …) must render as **BLOCKED**, visually distinct from
> `UNKNOWN`. Without it the panel implies the engine evaluated something it has
> no rule for. **This is the single most important safeguard in the whole
> observability layer**, and it is what makes it safe to build the UI before
> Track A closes.

---

# 3. Rendering model

## 3.1 Object identity mirrors entity identity

`REDTEAM-002` §2.2 established `EntityId = (kind, symbol, timeframe, side,
birth_instant)`. Object names encode it directly:

```
SIS_<kind>_<tf>_<side>_<birth_msc>[_<part>]
```

Consequences: rendering is idempotent (redraw overwrites, never duplicates);
deletion is precise; and an object on the chart is traceable to the exact event
that produced it. `[PROPOSED]`

## 3.2 Anti-repaint discipline

`[PROPOSED]`, and mechanically checkable:

1. An object is created **only** at the instant the engine emits the event, using
   `t_known` as its creation anchor.
2. Once created, an object's **geometry is immutable**. A changed fact is a *new*
   entity with a new id, not a mutated object.
3. Objects for *hypotheses* (pending sweeps, unfrozen impulse anchors) render in
   a distinct style and are the **only** ones allowed to disappear.
4. On full recalculation the renderer replays the event log from the epoch and
   must produce a byte-identical object set — the rendering form of the
   recalculation-invariance test (`REDTEAM-003` §4.1).

> Drawing an H4 pivot at the bar that formed it, when it only became knowable
> 11 hours later (`MT5-CAP-001` §2.4), is hindsight disguised as detection. Rule 1
> forbids it. **`[PROPOSED]` The chart should be able to display both anchors —
> the bar where it happened and the bar where it became known — with a connector
> between them**, because that gap is a real property of the strategy and hiding
> it would misrepresent the detector's latency.

## 3.3 Capacity

`[OBSERVED]` 500 objects in 1 ms. `[INFERRED]` Object count is not a design
constraint at the scale this methodology implies (a few hundred live entities).
A retention policy is still needed for long sessions, but it is an ergonomics
question, not a feasibility one.

---

# 4. Alert model

`[OBSERVED]` on this installation:

| Channel | Status | Use |
|---|---|---|
| `Print` → journal | **OK** | **primary.** Always available, unlimited text, timestamped, replayable, survives in the log |
| `PlaySound` | **OK** | attention only |
| `Alert()` | modal dialog `[DOC]` | **avoid as the primary channel** — blocks the UI thread; acceptable only as an opt-in |
| `SendNotification` | **FAIL 4517** | needs a MetaQuotes ID — *your* action, see §8 |
| `SendMail` | **FAIL 4510** | needs SMTP — optional |
| Chart panel | **OK** | the persistent, always-visible state |

## 4.1 Explainability is structural, not a message

`RT-10` established that evaluation must produce **evidence**, not just a value,
or explanation diverges from logic. The alert is that evidence rendered:

```
[SYNTHETIC EXAMPLE — the rules are not specified yet]
BUY OPPORTUNITY            EURUSD  t_known=2026-08-06 16:37:12 (NY 09:37:12)
  liquidity     PASS       pool#H1_low_1783615033614, swept t=...
  structure     PASS       MSS close 1.14342 > ref 1.14338   [rule: DEC-029 R1]
  displacement  BLOCKED    DEC-026 unresolved
  fvg           WAITING    2 candidates in zone, none confirmed
  retracement   PASS       0.63 of impulse [DEC-030 unresolved: 0.705 vs √0.5]
  ...
  parameter-set v0.3   spec v0.7   snapshot 2026-08-07
```

Three properties this shape guarantees `[PROPOSED]`:

- **every line names its rule id**, so a claim is traceable to a specification;
- **`BLOCKED` lines are visible in the alert itself**, so an alert can never
  imply a rule exists when it does not;
- **the run identity is attached**, satisfying `RT-16`'s selector-vs-threshold
  separation at the point of consumption.

> `[PROPOSED]` **The engine must not be able to emit a BUY/SELL while any stage is
> `BLOCKED`.** Until Track A closes, the observability layer runs in debug mode
> and emits *candidates*, never verdicts. This is the mechanism that keeps
> Track B from silently resolving Track A.

---

# 5. Debug mode

`[PROPOSED]` Two modes, one build:

- **DEBUG** — every stage rendered with its state, every rejected candidate kept
  with its rejection reason and the failing stratum (`RT-09`: the *set* of failed
  conjuncts at the *first* failing stratum, not "the" predicate). No verdicts.
- **OPERATOR** — validated setups only, plus the explanation panel.

The prototype demonstrates the DEBUG panel is legible at 9 stages `[OBSERVED]`.

## 5.1 Human-in-the-loop labelling (design only, not built)

`OBJ_BUTTON` and `OBJ_EDIT` both work `[OBSERVED]`, so an in-chart labelling
control is feasible. `[PROPOSED]` schema, aligned with `VAL-001` and `H-16`:

```
label_id, symbol, timeframe, t_occurred, t_known, snapshot_id,
spec_version, selector_set, threshold_set,
engine_state, candidate_id, rejection_reason,
human_label ∈ {would_take, would_reject, unsure}, human_note,
outcome (filled later, never at label time)
```

Two constraints that matter: the label must record **what the engine showed at
that instant**, not what it shows now; and `outcome` must be written by a
separate later process, or the corpus acquires hindsight — the very bias
`VAL-001` exists to avoid.

**Not implemented.** It cannot be built before `D-P7` (does identity include the
parameter version?) and `H-16` (is the corpus a versioned input?) are settled.

---

# 5bis. TESTER RESULTS — 2026-08-07 (`E-MT5-OBS-002`)

The `[UNKNOWN]` rows in §6 below are now measured. Two visual-mode runs on real
ticks (`Model=4`), EURUSD M5, 2026-07-09 → 07-10, 290,996 ticks, 288 bars.

| Claim | Outcome |
|---|---|
| EA host works under replay | **`[CONFIRMED]`** |
| Chart objects render in visual mode | **`[OBSERVED]`** created and read back inside the tester |
| Renderer is deterministic under replay | **`[CONFIRMED]`** — byte-identical event logs, identical FNV-1a hash across two runs |
| PART VII invariants hold | **`[CONFIRMED]`** — all six pass **inside** the tester |
| `Verdict()` cannot emit BUY/SELL | **`[CONFIRMED]`** — 126 stage combinations, zero leaks |
| `FILE_COMMON` output from tester agent | **`[CONFIRMED]`** retrievable |
| **`ChartScreenShot` in the tester** | **`[OBSERVED]` returns `true` but writes no retrievable file** |
| Same visual result inside vs outside tester | **`[UNKNOWN]`** — blocked by the line above |

**Architectural consequences, and only these:**

1. **§1's host selection is confirmed by evidence**, not just by elimination.
   The EA renders, replays and stays deterministic in the tester.
2. **§2's five-state model, including `BLOCKED`, is validated end-to-end.** The
   all-PASS case returns `BLOCKED: verdict semantics undefined (D-P1/D-P3/D-M1/
   DEC-S-001)` — the safeguard works in practice, not just on paper.
3. **§7's "terminal crashes" row is withdrawn.** `[REFUTED]` — it was the Wine
   launch environment (`E-MT5-OBS-002` §7). The *engineering advice* survives on
   independent grounds: incremental flushing and progress logging are what made
   the failure diagnosable at all.
4. **New limitation: visual evidence cannot be captured programmatically from
   the tester.** This changes PART VIII's human-validation staging — the engine's
   record is the event log; the human's record cannot be an auto-captured image.

# 6. Strategy Tester compatibility

| Aspect | Status |
|---|---|
| EA runs in tester | ✓ `[DOC]` |
| Chart objects in visual mode | `[UNKNOWN]` — **not tested**; the prototype ran live only |
| `Print` in tester | ✓ `[DOC]` |
| `Alert`/`SendNotification` in tester | suppressed/limited `[DOC]` |
| Mode validity | **only real-ticks** for order-sensitive rules — `E-MT5-007` §7 |

> `[UNKNOWN]` Visual-mode rendering is the **largest untested gap** in this
> document and is the natural next observability experiment.

---

# 7. Measured limitations

| Limitation | Evidence |
|---|---|
| `SendNotification` unavailable | `[OBSERVED]` err 4517 |
| `SendMail` unavailable | `[OBSERVED]` err 4510 |
| `Alert()` is modal | `[DOC]` — unsuitable as primary |
| Terminal terminated mid-run | `[UNKNOWN]` cause — twice in `E-MT5-007`, once here; recovered on retry. **My detached launch method is itself unreliable and cannot be excluded as the cause** (`E-MT5-007` §6 correction). Regardless of cause, **the renderer must tolerate host death**: flush state, log progress, resume from checkpoint |
| M1 bars capped at 100,000 (~3 months) while ticks span ~12 years | `[OBSERVED]` `E-MT5-007` §5 |
| Compilation fails on paths with spaces | `[OBSERVED]` `E-MT5-006` §3 |
| Visual-mode rendering | `[UNKNOWN]` |

---

# 8. New decisions this introduces

Added to the register. **None is decided here.**

| ID | Decision | Class |
|---|---|---|
| **D-V1** | Is `BLOCKED` a mandatory render state for unspecified rules? *(Strongly recommended — it is what makes building the UI before Track A safe.)* | **Constitutional** |
| **D-V2** | Does the chart display `t_occurred`, `t_known`, or both with a connector? | **Constitutional** — it decides whether the UI can misrepresent latency |
| **D-V3** | May the engine emit BUY/SELL while any stage is `BLOCKED`? *(Recommended: no.)* | **Constitutional** |
| **D-V4** | Host: EA-only, or EA + indicator for numeric series? | Structural |
| **D-V5** | Object retention policy for long sessions | Structural |
| **D-V6** | Is the journal the system of record for alerts, or is a separate append-only log required? | Structural |
| **D-V7** | Does the renderer replay from the event log on every recalculation, or maintain incremental state? *(Replay is testable; incremental is fast.)* | Structural |
| **D-V8** | Is in-chart labelling permitted before `H-16`/`D-P7` are settled? *(Recommended: no.)* | Behavioral |
| **D-V9** | Which failing stratum is shown when several fail — first, all, or deepest? (`RT-09`) | Behavioral |
| **D-V10** | How is visual evidence captured for human validation, given `ChartScreenShot` produces no retrievable file in the tester? (external screen capture / live-watch only / render-from-event-log outside MT5) | Structural — forced by `E-MT5-OBS-002` §5 |

Register: **71 → 81.**

---

# 9. What is deliberately not built

The detector. No liquidity, sweep, MSS, FVG, retracement, reaction or
confirmation logic exists in any file in this project, and none may be written
while `D-P1`, `D-P2`, `D-P3`, `D-M1`, `D-M4`, `D-M5` and `DEC-S-001` A-1/A-2/A-3
are open.

The prototype draws **hard-coded synthetic values** and says so on the chart
itself — the screenshot shows `SYNTHETIC VALUES — NOT A SIGNAL` rendered directly
under the title, so a screenshot of it can never be mistaken for a signal.
