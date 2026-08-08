# SPEC-200 — The Setup Lifecycle

*L3. Composition and lifecycle only. This document introduces no new market
concepts; every guard references a concept defined in SPEC-100.*

---

## 1. Why a state machine, and why this one

The methodology is a **sequence with waiting**. Each step is necessary, ordered,
and separated from the next by an unbounded-until-constrained interval during
which the world can invalidate everything. That is the definition of a finite
state machine with guards and timeouts, and modelling it as anything else —
a scan, a rule set, a scoring pass over recent bars — loses the ordering and the
waiting, which are the two things that actually make the method selective.

Three properties are demanded of the machine:

1. **Every transition is guarded by a named predicate.** No transition happens
   "because conditions look right".
2. **Every state has a timeout and an invalidation set.** No state is a place a
   setup can sit forever (A3).
3. **Every terminal state records why.** `SetupInvalidated` without a reason is
   a defect.

---

## 2. The aggregate

```
Setup := {
  id            : SetupId              -- stable, content-derived, never reused
  symbol        : Symbol
  direction     : BUY | SELL
  state         : State
  pool_ref      : LiquidityPoolId      -- the origin (CN-11)
  sweep_ref     : SweepId              -- (CN-13)
  anchor_low    : Price   -- or anchor_high for SELL; the invalidation reference
  reference_lvl : Price   -- H*, the MSS threshold (CN-15)
  impulse       : (A, B)  -- frozen at PullbackDeclared (CN-18)
  zone          : PriceInterval        -- frozen with the impulse
  fvg_ref       : FvgId | ⊥            -- (CN-17)
  history       : [TransitionRecord]   -- append-only, full provenance
  spec_version, paramset_version
}
```

`history` is not optional bookkeeping. It is what makes a disagreement between
trader and engine resolvable in minutes rather than never: every setup can
replay its own justification.

---

## 3. States

| State | Meaning | Waiting for | Notes |
|---|---|---|---|
| `POOL_RESTING` | A significant pool exists, untouched | penetration | Not a setup yet; a pool, tracked in the pool registry |
| `PENETRATED` | Price is beyond the level; sweep or break undecided | resolution within `W_sweep` | **Hypothesis state.** The engine's honest answer here is `NoOpportunity(reason=sweep_unresolved)` |
| `SWEPT` | Sweep confirmed; bias established | displacement + MSS | `anchor_low` set (provisionally — see `DEC-033`) |
| `SHIFTED` | MSS confirmed; displacement qualified | pullback declaration | The impulse's terminal point is still running |
| `ZONE_ARMED` | Pullback declared; impulse, zone and FVG frozen | price entering the zone | **The freeze moment.** Nothing about the zone may change after this |
| `IN_ZONE` | Price has entered the zone | reaction / confirmation | Timeout `W_conf` |
| `VALIDATED` | Confirmation detected | — | **Terminal.** Emits the opportunity, exactly once |
| `INVALIDATED` | Any invalidation fired | — | **Terminal.** Carries the reason |
| `EXPIRED` | A state timeout elapsed | — | **Terminal.** Distinct from invalidation: nothing went wrong, time ran out |

`EXPIRED` and `INVALIDATED` are kept separate deliberately. They mean different
things statistically — one says the setup was refuted, the other says the market
walked away — and merging them would destroy the ability to tell "my rules are
wrong" from "my rules are too slow".

---

## 4. Transitions

Notation: `FROM --[guard | timeout]--> TO`. Every guard names a SPEC-100 concept.

```
POOL_RESTING --[ PenetrationObserved (CN-13, δ_pen) ]--> PENETRATED

PENETRATED   --[ rejection close within W_sweep (CN-13) ]--> SWEPT
PENETRATED   --[ acceptance beyond level (CN-13)        ]--> INVALIDATED(pool_broken)
PENETRATED   --[ timeout W_sweep unresolved             ]--> EXPIRED(sweep_unresolved)

SWEPT        --[ DisplacementQualified (CN-14)
                 ∧ close beyond H*+δ_break (CN-16)
                 ∧ ¬Accumulation (CN-21)              ]--> SHIFTED
SWEPT        --[ new extreme beyond anchor  (DEC-033)  ]--> re-anchor | INVALIDATED
SWEPT        --[ opposing sweep confirmed   (CN-22)    ]--> INVALIDATED(bias_conflict)
SWEPT        --[ timeout W_mss                         ]--> EXPIRED(no_shift)

SHIFTED      --[ PullbackDeclared (CN-18, DEC-040)     ]--> ZONE_ARMED
SHIFTED      --[ close beyond anchor (r > 1, CN-05)    ]--> INVALIDATED(structure_failed)
SHIFTED      --[ timeout W_pullback                    ]--> EXPIRED(no_pullback)

ZONE_ARMED   --[ price enters zone (CN-18, DEC-031)
                 ∧ FVG present in zone (CN-17, DEC-041)]--> IN_ZONE
ZONE_ARMED   --[ pullback count > N_max (CN-19)        ]--> INVALIDATED(too_many_pullbacks)
ZONE_ARMED   --[ close beyond anchor                   ]--> INVALIDATED(structure_failed)
ZONE_ARMED   --[ timeout W_zone                        ]--> EXPIRED(zone_never_reached)

IN_ZONE      --[ ConfirmationDetected (CN-20, DEC-044) ]--> VALIDATED
IN_ZONE      --[ FVG fully mitigated w/o confirmation
                 (CN-17, DEC-038)                      ]--> INVALIDATED(zone_consumed)
IN_ZONE      --[ close beyond anchor                   ]--> INVALIDATED(structure_failed)
IN_ZONE      --[ timeout W_conf                        ]--> EXPIRED(no_confirmation)
```

**Every `W_*` is an open decision** (`DEC-054`). None may be unbounded: an
unbounded wait violates A3 and makes the engine's memory and behaviour
unanalysable.

**The re-anchor transition on `SWEPT` is the one dangerous edge in this diagram.**
It is the only transition that mutates a setup's own definition. If `DEC-033`
selects re-anchoring (M-b), then it must be modelled as *closing one hypothesis
and opening a successor* with a new id and a link to its predecessor — never as
an in-place edit, which would violate A-2 and make the history unreadable.

---

## 5. Verdict emission

- The engine evaluates all live setups at each evaluation instant, in a
  deterministic order (by setup id — never by hash-map iteration order, which is
  an A1 violation waiting to happen).
- A `BuyOpportunity` / `SellOpportunity` is emitted **exactly once**, on the
  transition into `VALIDATED`.
- If no setup transitions to `VALIDATED`, the engine emits
  `NoOpportunity(reasons)`, where reasons aggregate the blocking predicate of
  each live setup plus `NoCandidateSetup` if none are live.
- A `VALIDATED` setup is terminal. The engine does not track what happens next —
  that is trade management, out of scope. **`DEC-058`** asks whether a validated
  setup should ever be revoked (e.g. immediate structural failure two bars
  later); revocation is expressively cheap but semantically loaded, since a
  revoked alert is an alert the trader may already have acted on.

---

## 6. Concurrency and identity

Unresolved (`DEC-028`, `DEC-055`, `DEC-056`):

- **Identity.** Are two setups from the same sweep but different FVGs the same
  setup? Proposed identity key: `(symbol, direction, sweep_ref)` — one setup per
  sweep, with the FVG a property rather than an identity component. Consequence:
  competing FVGs must be resolved by a selection rule (nearest to MSS? largest?
  deepest in zone?) rather than by spawning parallel setups.
- **Limit.** Maximum concurrent live setups per symbol and per direction.
- **Cascades.** One bar sweeping several stacked pools: proposed rule is to keep
  the pool with the highest significance and treat the rest as consumed.

Under the Precision Doctrine the defaults should be restrictive: **one setup per
sweep, one alert per setup.**

---

## 7. Invariants (mechanically checkable)

```
L-1  A setup never leaves a terminal state.
L-2  Every non-terminal state has ≥ 1 timeout transition.
L-3  history is append-only; no record is ever modified.
L-4  zone and impulse are immutable after ZONE_ARMED.
L-5  Exactly one opportunity event per setup, and only from VALIDATED.
L-6  t_known is non-decreasing along history.
L-7  Every transition record names the guard that fired and the observed values.
L-8  Two runs over the same data, spec and parameters produce identical histories.
```

L-1…L-8 are testable without any market knowledge and should be the first
property tests written, whenever code eventually exists.
