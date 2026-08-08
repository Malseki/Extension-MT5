# SPEC-300 — The Formal Vocabulary

*The trading language. Platform independent: nothing here presumes MT5,
TradingView, Python, or any host. A conforming implementation in any language
must produce the same stream of the objects defined below.*

---

## 1. Critique of the vocabulary proposed in the brief

The brief proposes: `LiquidityDetected`, `LiquiditySwept`,
`MarketStructureShiftConfirmed`, `ImpulseDetected`, `PullbackStarted`,
`PullbackCompleted`, `FVGCreated`, `FVGMitigated`, `ConfirmationDetected`,
`SetupValidated`, `SetupInvalidated`, `AlertGenerated`.

It is a reasonable first list. Three structural problems make it insufficient as
stated.

**Problem 1 — it conflates three different kinds of object.**

- `FVGCreated` / `FVGMitigated` are the **birth and death of an entity** that
  exists over an interval and has a mutable status. They are not two unrelated
  events; they are the endpoints of one thing's life. Modelling them as
  independent events loses the entity, and with it the ability to ask the most
  natural question in the methodology: *which FVGs are currently unmitigated?*
- `LiquidityDetected` is likewise the birth of a long-lived entity.
- `SetupValidated` is a **state transition of an aggregate**, not an observation.
- `AlertGenerated` is an **output**, not a market fact. It belongs to a different
  layer and must not sit in the same namespace, or the engine's observations and
  its emissions become indistinguishable in the log.

**Fix:** three distinct categories — **Entity**, **Event**, **Output** — plus a
fourth that the brief lacks entirely.

**Problem 2 — no representation of the undecided.**

`LiquiditySwept` cannot be emitted when the sweep occurs, because at that moment
it is not yet knowable (SPEC-000 §4.3). A vocabulary without a way to say *"this
might be a sweep; ask me again in a few bars"* forces implementers to either
emit early (look-ahead, wrong) or emit late with the wrong timestamp (loses
`t_occurred`, also wrong). **Fix: `Hypothesis` as a first-class category.**

**Problem 3 — no provenance, no versioning, no negative output.**

Nothing in the list can answer "why", "under which rules", or "why not". The
brief's own requirements — auditable, reproducible, precision-first — cannot be
met by that list.

---

## 2. The four categories

| Category | Extent | Mutability | Example |
|---|---|---|---|
| **Fact** | instant | immutable, permanent | `MssConfirmed` |
| **Entity** | interval | status field advances monotonically through a declared lattice | `LiquidityPool`, `Fvg`, `Setup` |
| **Hypothesis** | interval, resolves | `OPEN → CONFIRMED \| REFUTED`, then frozen | `SweepHypothesis` |
| **Output** | instant | immutable | `Verdict`, `Alert` |

**Monotonic status lattices** (an entity's status may only advance, never
regress — this is what keeps A-2 intact for objects that legitimately change):

```
Pool : RESTING → {SWEPT, BROKEN, EXPIRED}
Fvg  : FRESH → PARTIALLY_MITIGATED → {MITIGATED, INVERTED, EXPIRED}
Setup: per SPEC-200 §3, acyclic apart from the re-anchor successor link
```

---

## 3. The common envelope

Every object of every category carries:

```
id               stable, content-derived, globally unique, never reused
kind             the type name below
symbol
t_occurred       market instant the object is about
t_known          first instant it became decidable          (t_known ≥ t_occurred)
source_tf        timeframe of the data that produced it
provenance       explicit references to the bars and objects it derives from
spec_version
paramset_version
payload          type-specific, immutable
```

**`provenance` is not a debugging luxury.** It is the mechanism by which a trader
disagreeing with the engine can be shown exactly which three bars produced an
FVG, which pivot produced a pool, and which parameter value gated the decision.
Without it, disagreement is unarbitrable and the project cannot improve.

**Idempotence.** Emitting the same object twice is an error. The id is derived
from the content (including `t_occurred` and provenance), so duplicate emission
is mechanically detectable.

---

## 4. Catalogue

### 4.1 Layer 1 — geometry

| Kind | Category | Payload | Emission | Latency |
|---|---|---|---|---|
| `PivotConfirmed` | Fact | side, level, bar_ref, (k,m) | CN-03 satisfied | m bars |
| `LegClosed` | Fact | A, B, height, duration | terminal pivot confirmed | inherits pivot |
| `ImbalanceFormed` | Fact | direction, interval, 3 bar refs | CN-06 | 0 |

### 4.2 Layer 2 — interpretation

| Kind | Category | Payload | Emission condition | Latency |
|---|---|---|---|---|
| `PoolFormed` | Entity birth | side, level, constituents, significance evidence | CN-11 ∧ CN-12 | pivot latency |
| `PoolStatusChanged` | Fact | pool_ref, old, new, cause | lattice advance | varies |
| `PenetrationObserved` | Fact | pool_ref, depth, bar_ref | CN-13 | 0 |
| `SweepHypothesis` | Hypothesis | pool_ref, penetration_ref, deadline | on penetration | 0 |
| `SweepConfirmed` | Fact | pool_ref, extreme, extreme_bar | hypothesis resolves positively | ≤ W_sweep |
| `SweepRefuted` | Fact | pool_ref, cause (broken \| timeout) | hypothesis resolves negatively | ≤ W_sweep |
| `DisplacementQualified` | Fact | leg_ref, measures observed vs thresholds | CN-14 | model-dependent |
| `ReferenceLevelSelected` | Fact | level, rule_id (R1–R4), evidence | CN-15 | 0 |
| `MssConfirmed` | Fact | reference, closing bar, margin | CN-16 | 0 |
| `FvgFormed` | Entity birth | interval, CE, provenance tag, size measures | CN-17 | 0 |
| `FvgStatusChanged` | Fact | fvg_ref, old, new, touching bar | mitigation policy | 0 |
| `PullbackDeclared` | Fact | impulse (A,B) **frozen**, zone **frozen**, rule_id | CN-18 | 0 |
| `ZoneEntered` | Fact | setup_ref, entry price, test basis | CN-18 | 0 |
| `ReactionObserved` | Fact | measures | CN-20 stage 1 (if two stages) | UNDEFINED |
| `ConfirmationDetected` | Fact | model_id (C1–C5), evidence | CN-20 | UNDEFINED |
| `AccumulationDetected` | Fact | window, measures observed | CN-21 (veto) | 0 |
| `BiasSet` | Fact | direction, source sweep | CN-22 | 0 |
| `ContextEvaluated` | Fact | HTF FVG refs, agreement/obstruction | CN-23 | HTF close |

### 4.3 Layer 3 — setup

| Kind | Category | Payload |
|---|---|---|
| `SetupOpened` | Entity birth | direction, pool, sweep |
| `SetupTransitioned` | Fact | from, to, guard_id, observed values |
| `SetupValidated` | Fact | full justification chain |
| `SetupInvalidated` | Fact | reason code |
| `SetupExpired` | Fact | which timeout |

### 4.4 Layer 4 — output

| Kind | Category | Payload |
|---|---|---|
| `Verdict` | Output | Buy \| Sell \| NoOpportunity(reasons) — **emitted at every evaluation instant** |
| `Alert` | Output | setup_ref, direction, justification, emitted once |

**`Verdict` at every instant, including negative ones, is deliberate.** It makes
the engine's silence auditable. A system that emits only when it fires cannot be
distinguished from a system that is broken and never fires.

---

## 5. Naming rules

1. **Past tense for facts** (`MssConfirmed`), **noun for entities** (`Fvg`),
   **explicit `Hypothesis` suffix** for the undecided. The tense encodes the
   category and prevents the brief's conflation from returning.
2. `...Detected` is banned except where detection is genuinely the semantics
   (`ConfirmationDetected`, `AccumulationDetected`). "Detected" hides whether an
   object was born or a condition was met.
3. `...Started` / `...Completed` pairs (as in the brief's `PullbackStarted` /
   `PullbackCompleted`) are replaced by an entity with a status lattice, unless
   the two instants are genuinely independent facts. A pullback that "starts" and
   "completes" is one object with two endpoints, and `PullbackCompleted` is in
   any case not causally observable — it completes when price leaves the zone,
   which is only known afterwards.
4. Every kind name is unique across all layers and never reused across versions
   with different semantics. Semantic change ⇒ new name (`MssConfirmedV2`) plus
   an ADR. Silent redefinition of a name is the single most destructive thing
   that can happen to a long-lived specification.

---

## 6. Stream invariants (mechanically checkable)

```
V-1  t_known is non-decreasing across the emitted stream.
V-2  No object references an object with a later t_known.
V-3  Every hypothesis reaches CONFIRMED or REFUTED within its declared deadline.
V-4  Entity statuses only advance within their lattice.
V-5  Ids are unique; identical content yields an identical id.
V-6  Exactly one Verdict per evaluation instant.
V-7  Every Alert is preceded by exactly one SetupValidated with the same setup_ref.
V-8  Removing all bars after time T removes exactly the objects with t_known > T
     and changes no other object.   ← the causality test (VAL-001 §4)
```

**V-8 is the most valuable line in this document.** It is a complete, mechanical
test for look-ahead bias, it requires no market knowledge, and it will catch
errors that no amount of chart-reading ever would.
