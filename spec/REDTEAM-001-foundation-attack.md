# REDTEAM-001 — Adversarial Attack on the Foundation

*Independent red-team review. The objective was to falsify SPEC-000, SPEC-100,
SPEC-200, SPEC-300, DEC-001 and DEP-001. Previous conclusions are treated as
hostile claims, including the ones this same corpus produced.*

---

# EXECUTIVE VERDICT

## **SURVIVES WITH REQUIRED CHANGES**

The methodology's **causal skeleton survives**. Every cycle found is definitional
rather than temporal, and each is cuttable by stratification. No contradiction
was found that makes the project impossible.

The **kernel proposed in DEP-001 does not survive**. It is wrong in both
directions at once:

- **Over-engineered:** three of its five primitives (`Level`, `Window`,
  `Crossing`) are derivable and are not primitives. Σ0 is not a layer.
- **Under-powered:** it cannot express a **dynamic population of entities**, and
  the methodology requires one from the first bar. The expressibility table in
  DEP-001 §6.3 was verified on singletons and silently assumed there is one pool,
  one FVG, one setup. There never is.

Three previously-stated results are **refuted outright**: that the spread is the
unique σ-asymmetry, that every threshold can be a parameter, and that A-6 delivers
broker independence. One stated requirement — the **ternary output contract** — is
proved insufficient by the methodology's own structure and cannot be satisfied as
written.

**28 findings. 4 CRITICAL, 18 HIGH, 5 MEDIUM, 1 LOW.**
**11 of them block future work.**

The single most important sentence in this report:

> The corpus has been reasoning about a language of *values* while the
> methodology is about a *population of objects with identity, lifetime and
> evidence*. Everything that broke, broke on that seam.

---

# 1. FINDINGS

Severity is assigned by *what the finding invalidates*, not by how hard it is to
fix. `BLOCKS` means downstream work done before resolving it will have to be
redone rather than extended.

---

## RT-01 · CRITICAL · The kernel cannot express dynamic entity populations

**Affects:** DEP-001 §6, SPEC-100 (CN-11, CN-17, CN-26), SPEC-200, SPEC-300
**Concept:** liquidity pools, FVGs, setups — all of them
**Blocks:** everything

**Failure mode.** `Series / Window / Level / Crossing / Aggregate` composed by
`Then-within` and `And` is a calculus of *streams of values*. It has a fixed,
statically-known number of streams. The methodology requires an unbounded,
dynamically-created, individually-stateful **population**: many resting pools,
many live FVGs, several concurrent setups, each with its own birth, status,
lifetime and death.

**Counterexample.** Take the methodology's own pathological case list. At bar `t`
there are 4 unmitigated bullish FVGs from 3 different impulses, 11 resting pools
across H1 and H4, and 2 live setups. Write the term for *"the setup is invalid if
any FVG created inside its impulse has been mitigated"*. It requires
∃-quantification over a set whose cardinality is not known until runtime and whose
members were created by earlier evaluation steps. No composition of `Lift` and
`Delay` over a fixed stream set produces this. The quantifier has no domain.

**Why it was missed.** DEP-001 §6.3's table reads *"CN-11 pool | `Zone` of width ε
with status"* — singular. Every row is singular. The reduction is correct for one
instance of each concept and says nothing about the general case. A proof on a
singleton is not a proof.

**Consequence.** Every expressibility claim in DEP-001 §6.3 and §6.4 is
provisional. The claim in §6.4 that Order Blocks, Rejection Blocks and SMT need no
new primitive is **unproven**, because they too are populations.

**Recommended resolution.** One of three, and the choice is architectural, not
cosmetic:
1. **Bounded population.** Fix a maximum live count `K` per entity kind. Memory
   becomes static; the kernel survives unchanged; completeness is lost and the
   loss must be quantified (how often does the real market exceed `K`?).
2. **Population primitive.** Add an instance/collection former with explicit
   creation, identity, iteration and termination. New semantic power, honestly
   declared.
3. **Reified registry.** Entities as a stream of records with an explicit store.
   Unbounded memory; forfeits any bounded-memory guarantee.

Option 1 is the only one that preserves the current kernel, and it is the only one
whose cost is measurable from the corpus. **This is the first thing that must be
decided after this report.**

---

## RT-02 · CRITICAL · The ternary output contract is provably insufficient

**Affects:** README §Mission, SPEC-000, SPEC-200, SPEC-300
**Concept:** verdict
**Blocks:** the output contract and every future consumer

**Failure mode.** The brief fixes the output as `Buy | Sell | No Opportunity`.
The methodology simultaneously permits multiple concurrent setups (SPEC-200's own
case list: "a second setup beginning before the first expires", "simultaneous
bullish and bearish candidates").

**Counterexample.** Price sweeps an H4 low at 09:14 and an H1 high at 09:31. Both
produce valid, confirmed setups in opposite directions, live at the same instant.
The output type has no value for this state. The three available responses are:

- emit `No Opportunity` — **false**; two valid setups exist, and the doctrine
  "missing opportunities is preferable" does not license reporting a falsehood;
- emit both — the output is no longer ternary, it is a *set*;
- prioritise one — requires a **total order over setups**, which is `DEC-050`'s
  graded value domain, which the same brief resists.

There is no fourth option. **The ternary contract, the multi-pool structure, and
the refusal to grade are mutually inconsistent — any two can hold, never all
three.**

**Consequence.** This is not an output-formatting problem. It forces `DEC-050`
before the output contract can be written, and it means the project's most
prominently stated requirement is not satisfiable as stated.

**Recommended resolution.** Restate the contract as *per-setup* ternary plus a
*set-valued* engine output. The trader's experience can still be "one alert at a
time" — but that is a presentation policy, not a semantics. Conflating the two is
what produced the inconsistency.

---

## RT-03 · CRITICAL · The system has an unbounded state horizon; warm-up and replay claims are false

**Affects:** SPEC-000, VAL-001 §4, H-18
**Concept:** pool lifetime, running extrema, setup lifetime
**Blocks:** replay, backtesting, any fixed-lookback implementation

**Failure mode.** VAL-001's prefix-invariance test and the implicit "load `L` bars
of history and start" model both assume the engine's state is a function of a
bounded recent window. It is not. A liquidity pool has **no maximum lifetime**
(`DEC-018` does not impose one) and can rest untouched for months. The running
extreme since a sweep is unbounded. A setup's lifetime is bounded only by
`DEC-054`, which is open.

**Counterexample.** Start a replay on 1 March. An H4 pool formed on 12 January is
swept on 3 March. An engine started on 1 March never saw the pool and emits
nothing. An engine started on 1 January emits a setup. Same data at the moment of
the sweep, different output. Determinism holds; **start-independence does not**,
and every backtest silently assumes it.

**Consequence.**
- No warm-up length `L` can be declared correct without a proven maximum entity
  lifetime.
- An MT5-indicator-style implementation with a fixed lookback would be **silently
  wrong**, not obviously wrong — the failure is invisible in the output.
- Replay must always begin from a declared epoch, or from a **serialised
  checkpoint of the entity population** — a format that does not exist and whose
  contents are determined by RT-01's resolution.

**Recommended resolution.** Either impose a maximum entity lifetime (making `L`
provable), or specify a checkpoint. There is no third option, and "just load
enough bars" is not one of them.

---

## RT-04 · CRITICAL · Axiom A-2 is violated by the ontology as written

**Affects:** README §3 (A-2), SPEC-100 CN-11, CN-17, SPEC-300
**Concept:** pool status, FVG status
**Blocks:** SPEC-100 and SPEC-300 revision

**Failure mode.** A-2 states facts are immutable. SPEC-100 models a pool as an
entity with a mutable `status ∈ {resting, swept}` and an FVG with a mutable
mitigation status. **A mutable status field is a retractable fact.** The ontology
contradicts the axiom it is written under.

**Counterexample.** `Pool#7.status = resting` is asserted at `t₁` and
`Pool#7.status = swept` at `t₂`. Either the first assertion was never a fact
(then A-2's scope excludes entity state, and A-2 must say so), or it was and has
been retracted (then A-2 is false).

**Also breaks H-12.** If pool significance decays with age, significance must be
retracted too — same violation, second instance.

**Recommended resolution.** Status is not a field. `swept(pool, t)` is a
time-indexed derived predicate; the pool entity itself is immutable, carrying only
its birth data. A-2 then survives unchanged and the population becomes a set of
immutable records plus derived time-indexed predicates over them — which is also
the shape RT-01 needs.

---

## RT-05 · HIGH · `Level` and `Compare` collapse: the primitive list is misstated

**Affects:** DEP-001 §6.2
**Blocks:** the kernel definition

DEP-001's grammar contains `Event ::= Crossing(...) | Compare(...)` while its
primitive list contains neither `Compare` nor a justification for it. `Compare`
was introduced at the grammar level and omitted from the count.

It does reduce — but only because the grammar also allows `Level ::= Aggregate`,
i.e. a **time-varying level**. A time-varying level is a series. Therefore:

> `Level` is either a constant (a degenerate `Series`) or a `Series`. It is not an
> independent primitive in either case.

Once `Level ⊆ Series`, `Compare(a,b)` and `Crossing(a, level)` are the same
operation on two series, and the distinction between them evaporates. The five
"primitives" contain a redundancy the grammar concealed.

---

## RT-06 · HIGH · `Crossing`, `Window`, `Then-within` and `And` are all derivable

**Affects:** DEP-001 §6.2, §7 (minimality claim)
**Blocks:** the minimality claim

Attempting removal of each, as required:

| Proposed primitive | Removable? | Reduction |
|---|---|---|
| `Crossing` | **yes** | rising edge: `a[t] > b[t] ∧ a[t−1] ≤ b[t−1]` — pointwise comparison plus a one-step delay |
| `Window` (bounded) | **yes** | `Bars(n)` is `n` applications of delay |
| `Aggregate` (bounded) | **yes** | fold of a pointwise operation over delayed copies |
| `Aggregate` (unbounded/running) | **no** | needs feedback: `runmax[t] = max(x[t], runmax[t−1])` |
| `Then-within` | **yes** | a guarded recursion with a counter |
| `And` | **yes** | a pointwise lift of `∧` |
| `Level` | **yes** | RT-05 |
| `Series` | **no** | the only input |

What survives removal: **`Series`, pointwise lifting, delay, and guarded
recursion.** Four operators, not five primitives and two combinators. `Window`,
`Level`, `Crossing`, `Aggregate`, `Then-within` and `And` are all *abbreviations*
— useful ones, but they must be labelled as derived, or over twenty years they
will accrete independent semantics and drift apart from their definitions.

**Note on prior art.** `Series + lift + delay + guarded recursion` is the kernel of
**synchronous dataflow** (Lustre, Signal, Esterel), a forty-year-old family with
model checkers, certified compilers and multi-target code generation. That the
methodology lands there is evidence the reduction is real rather than clever, and
it is directly relevant to the stated MT5/Python/C++/Rust portability goal. It
should be treated as a known formalism to be *used*, not rediscovered.

---

## RT-07 · HIGH · The temporal model is missing a third coordinate

**Affects:** SPEC-000 §5, SPEC-300, H-05
**Blocks:** historical reproducibility

`t_occurred` and `t_known` are valid time and decision time. Brokers revise
historical bars; feeds are backfilled; gaps are patched. A fact derived from data
that was later revised has **no representable status** in a two-coordinate model:
it was true given what the engine held, and is false given what the archive now
holds.

This is the standard bitemporal problem, and the standard answer is a third
coordinate — **transaction/snapshot time**. Without it, "reproduce the run of 3
March" is ambiguous: reproduce what the engine saw, or what the data says now?
Those differ, and the difference is invisible.

**Recommended resolution.** Facts are stamped `(t_occurred, t_known, snapshot)`.
Streams from different snapshots are never compared without an explicit
reconciliation step.

---

## RT-08 · HIGH · Occurrence times are intervals; cross-timeframe event order is a partial order

**Affects:** SPEC-000 §5, SPEC-300, every "must occur after" rule
**Blocks:** MTF rule semantics

Under bar-close evaluation, an event's occurrence is known only to the resolution
of its bar. An H4 event's `t_occurred` is not a point — it is a **four-hour
interval**. The corpus treats it as a point throughout.

**Counterexample.** *"The MSS must occur after the sweep."* The sweep is detected
on H1 (one-hour interval); the MSS on M1 (one-minute interval). If the intervals
overlap, the ordering of the two events is **genuinely undetermined by the data**.
The rule is not merely hard to evaluate — it is ill-posed. Any implementation
picks an order, and the pick is arbitrary.

Assuming a total order on events across timeframes is therefore unsound.

**Recommended resolution.** Stamp every event at the **base-clock instant at which
it became determinable**, not at its nominal HTF bar time. An H4 pivot then
"occurs" at its confirmation instant. Intervals collapse to points, the total
order is restored, and the semantics become more honest — the engine records when
it *knew*, which is the only thing it can record without inventing precision.
This is a semantic change, not a convention, and it will change results.

---

## RT-09 · HIGH · Axiom A-5 is under-specified and yields nondeterministic explanations

**Affects:** README §3 (A-5), VAL-001, SPEC-300
**Blocks:** explainability

A-5: *"a rejection must name the predicate that failed."* Under a conjunction,
**several conjuncts can fail at the same instant**. "The predicate" presupposes a
unique one, which presupposes a short-circuit evaluation order — but evaluation
order is not semantically meaningful in a conjunction.

Consequence: either the explanation depends on an arbitrary order (so *the same
input can produce different explanations under two correct implementations* —
a determinism violation at the explanation layer, which nobody is testing), or
A-5 must require the **set** of failed conjuncts.

Worse, under stratification the honest answer is often at a lower stratum: "no
valid FVG in the zone" is misleading if no significant pool ever existed. A useful
rejection reason needs the **first stratum at which evaluation failed**, not the
last predicate touched.

---

## RT-10 · HIGH · Evaluation produces values, not evidence — explainability cannot be retrofitted

**Affects:** SPEC-300, §17 of the brief, H-15
**Blocks:** the explanation capability, and it blocks it *silently*

To answer *"why did this fire?"* the system must produce, for each satisfied
conjunct, the **witness**: which bars, which entity, which instant, which
parameter values. A calculus of truth values does not produce witnesses. A `TRUE`
carries no record of why.

This cannot be added later without touching every term, because evidence must be
threaded through every composition. It is a change to the **type of evaluation**
(`value` becomes `value × evidence`), not an added module.

**Recommended resolution.** Decide now whether evaluation is evidence-producing.
If yes, it constrains the kernel from the start at modest cost. If no, accept that
explanations will be reconstructed post-hoc and *can diverge from the logic* —
which for an advisory system whose entire value proposition is trustworthiness is
a poor trade, and should at least be made knowingly.

---

## RT-11 · HIGH · Identity is a genuine primitive, not a derived notion

**Affects:** DEP-001 §3, SPEC-100, `DEC-055`
**Blocks:** RT-01's resolution

DEP-001 listed identity among concepts to be tested for derivability and never
resolved it. The result:

- Under a **bounded array** encoding (RT-01 option 1), identity = slot index, and
  is derivable — **but only if slots are never reused**. If a slot is recycled
  after an entity dies, the slot's history is not the entity's history, and A-2 is
  violated a third time.
- Under **dynamic creation**, identity requires fresh-name generation. Not
  derivable from lifting and delay. **Primitive.**

Either way identity must be introduced explicitly. It cannot be left implicit,
and `DEC-055` (setup identity) is downstream of this, not the same question.

---

## RT-12 · HIGH · The per-symbol clock is already baked in

**Affects:** SPEC-000 §5, `DEC-002`, `DEC-006`, H-04
**Blocks:** all future cross-symbol work

DEP-001 raised H-04 as a question. It is not open — **the assumption is already
made**, in a place nobody looked: `DEC-006`. MT5 omits M1 bars in which no ticks
arrived. If the base clock is "M1 bars of this symbol", then the clock is
*derived from the symbol's own activity*, and two symbols have different instant
sets. Every cross-symbol comparison then needs a join that does not exist.

**Minimum requirement to keep cross-symbol reasoning possible:** the base clock
must be **exogenous** — wall-clock minutes, independent of any symbol's data. A
symbol with no ticks in a minute yields a held or undefined bar rather than no
bar at all.

The cost is small and immediate: an exogenous clock means many instants carry no
new information, so the value domain must represent "no update". That is another
independent argument for a `⊥`-carrying value domain, arrived at from a completely
different direction — which is mild evidence both are right.

---

## RT-13 · HIGH · Regime-adaptive normalisation makes the detector count-invariant

**Affects:** SPEC-000, `DEC-010`, H-03, DEP-001 C7
**Concept:** every volatility-normalised threshold

DEP-001's C7 found that an event can inflate its own baseline, and proposed
excluding the event from the estimator window. **That fix is insufficient.**

Even a strictly causal baseline is computed over a window containing *previous
events of the same kind*. A cluster of displacements raises the trailing ATR,
which raises the bar for the next displacement. The detector therefore becomes
**invariant to the frequency of the phenomenon it detects**: in a violently
trending regime it fires no more often than in a quiet one, because the threshold
tracks the regime.

Whether that is desirable is a trading decision. That it is *happening silently
and was never chosen* is the defect. It is a stronger and more consequential
version of C7, and it applies to `DEC-021`, `DEC-026`, `DEC-036`, `DEC-043`,
`DEC-046`.

**Recommended resolution.** Declare explicitly, per threshold, whether it is
*regime-relative* (adaptive baseline) or *absolute* (long-horizon or fixed
baseline). Robust estimators (median/quantile) reduce but do not remove the
effect. This is a decision, currently taken by accident.

---

## RT-14 · HIGH · The accumulation containment metric is fully circular

**Affects:** SPEC-100 CN-21, `DEC-046`, `DEC-047`
**Concept:** accumulation

The proposed containment predicate is `(max high − min low over n) ≤ θ · ATR(n)`
**with the same `n`**. Numerator and denominator measure the same window. The
ratio is then approximately scale-free and measures the window's *shape* — how
much of the total bar movement was net directional — not its *compression
relative to normal volatility*, which is what "accumulation" is meant to capture.

This is not the same defect as RT-13. RT-13 is contamination; this is a metric
that **does not measure what its name claims**, in a filter that exists to
suppress signals. A veto that measures the wrong quantity is worse than no veto,
because it removes true positives with the appearance of rigour.

Compounding it: SPEC-100 already defines accumulation partly as "poor
displacement", so the filter is *also* partly redundant with the displacement gate
(DEP-001 C6). Two independent defects in one concept.

---

## RT-15 · HIGH · Kleene guards break exhaustive case analysis; the state machine can stall

**Affects:** SPEC-200, SPEC-000 §2, `DEC-054`
**Blocks:** the state machine's totality proof

Under three-valued logic, `p ∨ ¬p` is **not a tautology**. Every transition guard
written as an exhaustive case split — *"either the pool was swept or it was
broken"* — has an unhandled third case when the discriminating data is `UNKNOWN`.

**Counterexample.** A data gap spans the bars that would resolve a penetration.
`swept` is `UNKNOWN`, `broken` is `UNKNOWN`. No guard is enabled. The setup
occupies a state with no enabled outgoing transition. If the state has no timeout,
this is a **deadlock**; if it has one, the machine is total but the timeout is
doing semantic work nobody declared.

**Required proof obligation, currently absent:** for every state, either some
transition is enabled within a bounded number of instants, or an explicit
`STALLED` state absorbs the gap. Totality of the transition relation must be
proved, not assumed. Classical reasoning about case exhaustiveness is unsound
here, and it is exactly the reasoning a human reviewer applies by reflex.

---

## RT-16 · HIGH · Definition selectors are mis-filed as parameters

**Affects:** SPEC-000 §8, A-4, VAL-001
**Blocks:** historical comparability

The `ParameterSet` conflates two categorically different things:

- **thresholds** — `δ_pen`, `θ_displacement`, retracement bounds, timeouts.
  Changing one produces *comparable* results: same concepts, different sensitivity.
- **selectors** — the mitigation policy (M1–M4), the reference-level rule (R1–R4),
  the displacement model (D1–D6), the sweep family. Changing one selects a
  **different definition**. Results before and after are not comparable at all;
  they are outputs of different systems that share a name.

Filing both in one versioned set means a selector change looks like a tuning
change in the run record. Every historical comparison silently becomes invalid,
and nothing in the record indicates it.

**Recommended resolution.** Version them separately. A selector change mints a new
*methodology identity*; a threshold change mints a new *configuration* of the same
methodology. Only the latter may be compared across runs.

---

## RT-17 · HIGH · `DEC-029` option R3 is not a function of the data and must be eliminated

**Affects:** `DEC-029`, SPEC-100 CN-15, DEP-001 C2
**Blocks:** nothing — it *unblocks*, by removing an option

R3 reads the structural reference as *"the high responsible for the low"*.
"Responsible" is a **counterfactual**: it asserts that had that high not formed,
the low would not have occurred. Counterfactuals are not observable — not with
delay, not retrospectively, not ever. They are not functions of the realised path.

R3 is therefore not merely ambiguous or non-causal. It **cannot be a definition**,
under any resolution of any other decision. It should be struck from `DEC-029` on
formal grounds, with no trading input required.

Note what this does to DEP-001's cycle C2: C2 exists *only* under R3. Eliminating
R3 **eliminates cycle C2 entirely**, at zero cost. One of the three "cycle-cutting
decisions" on the critical path was an artefact of an inadmissible option.

---

## RT-18 · HIGH · The σ-asymmetry claim is refuted; the real conditions are different

**Affects:** DEP-001 §3 H-20, §7
**Concept:** directional duality

DEP-001 claimed: *"the system is σ-symmetric everywhere except the spread
correction, which is the unique σ-asymmetric term."* **This is false.**

σ must act on the *full observation*, which is a pair `(bid, ask)`, not a single
price. The correct involution is:

> `σ(bid, ask) = (c − ask, c − bid)`

Check: it is an involution (`σ² = id`). Under it, `spread = ask − bid ↦
(c − bid) − (c − ask) = ask − bid`. **The spread is σ-invariant.** A buy-stop
triggered at the ask maps exactly onto a sell-stop triggered at the bid. The
asymmetry DEP-001 identified was an artefact of applying σ to a single price
series when the data has two.

The genuine conditions, tested one by one:

| Tested against | Verdict |
|---|---|
| spread / bid-ask | **symmetric** under the corrected σ |
| tick size, contract specs | symmetric — scale is direction-free |
| sessions, gaps | symmetric — σ does not act on time |
| volatility regimes, leverage effect | symmetric **as a language property**; the *data* is empirically asymmetric, which is a fact about markets, not about definitions |
| execution asymmetry, borrow, uptick rules | out of scope; would break σ for *strategy*, not for *detection* |
| **price domain** | **breaks** — `p ↦ −p` leaves the positive reals. Reflection about a constant, `p ↦ c − p`, can yield negative prices |
| **percentage-of-price quantities** | **breaks** — ratios to absolute price are not preserved by affine reflection |

**Corrected verdict: σ is CONDITIONAL, and the conditions are:**
1. σ acts on the full `(bid, ask)` observation, exchanging them;
2. reflection is affine (`p ↦ c − p`), which preserves all *difference-based*
   quantities — and every quantity in the current concept set is difference-based;
3. **no percentage-of-price quantity is ever introduced.** Condition 3 currently
   holds and is a genuine constraint on all future work.

Under (1)–(3), σ is an **exact involution on the entire current concept set** —
strictly stronger than DEP-001 claimed, with a completely different exception set.
The previously-celebrated "unique asymmetry" does not exist; a real constraint on
future concepts does.

---

## RT-19 · HIGH · Axiom A-4 is false as written

**Affects:** README §3, SPEC-000 §8
**Blocks:** parameter discipline

A-4: *"every threshold is a named parameter."* Counterexample: the **3** in the
three-bar Fair Value Gap. Parameterise it to `n` and the concept changes identity
— an `n`-bar imbalance is a different object, not a tuned one. Same for the
middle-bar index, and for the `0` in "gap > 0".

These are **structural constants**: they participate in the definition rather than
in its calibration. A-4 as written either forces them into a parameter set where
they do not belong, or is quietly violated at every such site.

Additionally, parameters have **degeneracy boundaries**. Pivot width `k = 0` makes
every bar a pivot; the concept collapses. So a parameter is only safely
configurable **on a declared admissible range over which the concept is provably
non-degenerate**. No such ranges exist anywhere in the corpus.

---

## RT-20 · HIGH · Axiom A-6 is over-claimed

**Affects:** README §3, SPEC-000 §5
**Blocks:** nothing, but it licenses a false confidence

A-6 claims broker independence via deriving HTF bars from M1. What it actually
achieves is **aggregation-anchor independence**. The M1 data itself remains
broker-specific: different feeds disagree on highs, lows, tick counts and which
minutes exist at all. Two brokers' M1 histories produce different pivots, hence
different pools, hence different setups.

Broker independence is **unachievable**, and claiming it is dangerous because it
invites cross-broker result comparison that will not hold. A-6 must be restated
truthfully, and any validation result must be stamped with its data source.

---

## RT-21 · HIGH · Σ0 is a category error: the stratification conflates two different relations

**Affects:** DEP-001 §1.1, §5.1, §7 (AR-1)
**Blocks:** the critical-path claim

DEP-001 places Σ0 "above" SPEC-000 in the same stratum numbering as Σ1…Σ6. But the
relation *"Σ4 depends on Σ3"* is **definitional dependency inside one language**,
while *"Σ1 depends on Σ0"* is **"is expressed in"** — an interpretation relation
between a language and its metalanguage. These are not the same relation and do
not compose.

**Consequence.** A critical path is defined on a single DAG of one relation.
DEP-001's ten-step "critical path" mixes two, so it is not a critical path. The
*practical* conclusion — that the semantic work needs no trader and can start
immediately — survives, and is in fact **strengthened**: those items are not
merely *earlier*, they are on a **separate track that runs in parallel**. The
sequencing claim was wrong; the scheduling claim was right for the wrong reason.

**Recommended resolution.** Σ0 is not a layer. Its content collapses into (a) the
*type* of the value domain and (b) the *strictness discipline* of pointwise
lifting w.r.t. `⊥`. Both belong inside the kernel's definition, not above the
trading spec. Recommendation AR-1 in DEP-001 ("create Σ0 as a document above
SPEC-000") should be withdrawn.

---

## RT-22 · HIGH · σ as an axiom smuggles an empirical claim into the metalanguage

**Affects:** DEP-001 H-20, AR-2
**Blocks:** expressiveness

DEP-001 proposes σ-symmetry as a Σ0 *axiom*: every concept must satisfy
`C_bear = σ ∘ C_bull ∘ σ`. As an axiom of the language, it makes
direction-asymmetric methodologies **inexpressible**.

That is not a hypothetical restriction. Equity markets are empirically asymmetric
(the leverage effect; crashes are faster than rallies), and a methodology that
deliberately uses different logic for longs and shorts is legitimate and common.
An axiom forbidding it is a *trading assumption* wearing a logician's coat.

**Recommended resolution.** Demote σ from axiom to **checkable property of a
term**. The methodology then *declares* which terms must be σ-symmetric, and the
property is verified mechanically per term. All the benefits DEP-001 claimed
(write once, no drift, mirror-test) are retained. The expressiveness cost is
removed. AR-2 should be revised accordingly.

---

## RT-23 · MEDIUM · Nine unspecified sources of nondeterminism

**Affects:** SPEC-000 §9, VAL-001
**Blocks:** the determinism verdict

Determinism is *achievable* but nowhere *specified*. Enumerated:

1. floating-point association order inside aggregates;
2. rounding direction for derived levels (H-17, still open);
3. tick timestamp collisions — no `(timestamp, sequence)` total order is defined;
4. timezone/DST changing derived HTF anchors;
5. missing-bar handling under `Bars(n)` vs `Elapsed(d)` windows;
6. HTF boundary inclusion — half-open vs closed intervals unspecified;
7. simultaneous event emission order — no total order on event *types* declared;
8. **iteration order over the entity population** (new, and the worst): with `N`
   live FVGs, "the nearest unmitigated FVG" needs a tiebreak; none exists;
9. data snapshot (RT-07).

Item 8 is unresolvable until RT-01 is, and it makes the whole determinism question
downstream of the population decision.

---

## RT-24 · MEDIUM · Distributional methodologies are not expressible — the kernel's true boundary

**Affects:** DEP-001 §6.4, the generality claim
**Blocks:** nothing now; bounds all future scope

Tested by construction (see §4 for the full table). The kernel handles
**point-and-level** methodologies. It **cannot** express methodologies requiring a
*measure over the price axis*: Market Profile / TPO value areas, volume profile,
POC, footprint and order-flow, DOM-based analysis. These need a price-indexed
histogram — a second dimension — plus cumulative and sorting operations over it.
No composition of lifting and delay over scalar streams produces one.

This is a genuine, permanent boundary and it should be stated rather than
discovered later.

**Associated risk.** The methodology's central term is **"liquidity"**, which here
means *resting stops at price levels* — a point concept, expressible. The same
word in microstructure means *depth of book* — a measure concept, not expressible.
The naming invites a scope creep the kernel cannot absorb, and the day someone
says "let's use real liquidity data", the foundation ends.

---

## RT-25 · MEDIUM · Alert revocation contradicts output monotonicity

**Affects:** `DEC-058`, SPEC-200, A-2
**Concept:** alert lifecycle

A-2 makes the fact stream monotone. `DEC-058` contemplates revoking an alert after
invalidation. A revocation is a non-monotone output. Both cannot hold at the
output layer.

The resolution is not a trade-off but a distinction the corpus has not drawn:
**A-2 governs facts; recommendations are not facts.** A recommendation is a
*derived, time-indexed* view over facts, and views may change without any fact
changing. That distinction must be written down, or the first revoked alert will
look like an axiom violation — and the trader will have already acted on it, which
is a real-world consequence, not a formal one.

---

## RT-26 · MEDIUM · "Decidable" in axiom A-1 is undefined

**Affects:** README A-1, SPEC-000 §5

A-1 forbids emitting a fact before it is "decidable from data available at that
instant". Decidable **by what**? A predicate can be decidable by an unrestricted
computation yet inexpressible in the kernel; conversely a kernel term may be
evaluable but depend on a future-lagged series.

A-1 must read: *expressible in the kernel **and** evaluable on the data prefix*.
As written, it is an undefined term inside an axiom — precisely the defect the
corpus was created to eliminate, appearing in the corpus's own first axiom.

---

## RT-27 · MEDIUM · Concept duplication has no detection mechanism

**Affects:** SPEC-100 throughout

Analysis of the flagged pairs (full table in §5):

| Pair | Classification |
|---|---|
| displacement / impulse | **1 — truly identical.** Merge. |
| reaction / confirmation | **currently 1 by ambiguity**, intended as 3. Undefined until `DEC-044`. |
| sweep / penetration | **3 — different events on the same primitive.** One is a crossing, the other a resolved hypothesis. Keep both. |
| mitigation / invalidation | **2 — different abstractions of one primitive**, applied to different entities. Keep both, mark the shared derivation. |
| structure break / crossing | **2 — MSS is `Crossing` with specific arguments.** An abbreviation, and must be labelled one. |
| pool / FVG / retracement zone | **2 — all are `Zone` + lifecycle.** Newly found. |
| significance / quality | **2 — both are "conjunction of threshold predicates".** Newly found; another reason `DEC-050` is upstream of both. |
| accumulation / ¬displacement | **1, partially.** Newly confirmed (DEP-001 C6). |

The corpus has no rule that would have caught these. **Recommended:** every named
concept must declare its kernel expression, and two concepts whose expressions are
equal modulo arguments must be declared instances of one schema. That converts
duplication detection from taste into a check.

---

## RT-28 · LOW · The Kleene/Łukasiewicz choice is a non-decision

**Affects:** `DEC-050`, Σ0 discussion

K3 and Ł3 differ **only in implication**. The specification's guards are
conjunctions and negations, where the two logics agree everywhere. Framing this as
an open decision manufactures work.

Recorded so it is not re-opened: *if implication is ever introduced into guard
syntax, the choice becomes live; until then it is immaterial.*

---

# 2. PROVEN PROPERTIES

Attacked and survived. These should be promoted to explicit invariants.

**P-1 · The causal skeleton contains no temporal cycle.** Every cycle found across
DEP-001 and this review is **definitional**, not temporal: none requires an event
to precede itself. All are cuttable by stratification. This is the single most
important survival, because a temporal cycle would have been fatal.

**P-2 · Prefix invariance is a sound look-ahead test.** Truncating the data at `t`
must not change any fact with `t_known ≤ t`. Sound (a violation is a genuine
leak), decidable by testing, and it catches MTF leakage, retrospective swing
classification and session-boundary leakage in one test. It is *necessary, not
sufficient* — it tests the engine, not the data pipeline — but it survived every
attempt to construct a leak it would miss within the engine.

**P-3 · Absorbing `UNKNOWN` correctly implements the Precision Doctrine for
positive conjunctions.** Confirmed sound. Note the exact scope: it does **not**
extend to disjunctions (where `TRUE ∨ UNKNOWN = TRUE` admits a conclusion on
partly-unknown data — sound, but worth knowing) nor to exhaustive case analysis
(RT-15).

**P-4 · σ is an exact involution on the entire current concept set**, under the
three conditions in RT-18 — a stronger result than previously claimed, reached by
refuting the previous claim.

**P-5 · The methodology is online-recognisable**, conditionally: with bounded
confirmation delays for pivots and sweeps, an explicit freeze for the impulse
anchor, and the elimination of R3. No concept was found that is *fundamentally*
unobservable except R3, and R3 is eliminable.

**P-6 · CN-20 ≡ CN-16 modulo scale.** Confirmed under the corrected kernel:
confirmation and market-structure-shift are the same term at different scales.
This survives and remains the strongest formal argument available in the corpus.

**P-7 · A single exogenous base clock makes cross-timeframe event order total**
(RT-08) **and simultaneously secures cross-symbol reasoning** (RT-12). Two
independent problems, one mechanism. Convergence of this kind is weak evidence of
correctness and is worth recording as such.

**P-8 · Timeframe belongs to `Series`, not to `Window`, `Event` or `Context`.**
An HTF bar is a derived series on the base clock; an event inherits the timeframe
of the series it is computed from. No separate MTF machinery is required —
MTF leakage becomes an **availability-lag typing** question, which is a static
property rather than a runtime one. This survived every attack in §13 of the
brief.

---

# 3. FAILED ASSUMPTIONS

Previously believed, now known false.

| # | Assumption | Status |
|---|---|---|
| FA-1 | "The kernel is 4 primitives + 2 combinators" | **False.** Three are derivable (RT-05, RT-06); two new capabilities are required (RT-01, RT-11). |
| FA-2 | "The spread is the unique σ-asymmetry" | **False.** The spread is σ-invariant under the corrected involution (RT-18). |
| FA-3 | "Every threshold can be a parameter" (A-4) | **False.** Structural constants exist (RT-19). |
| FA-4 | "A-6 delivers broker independence" | **False.** Anchor independence only (RT-20). |
| FA-5 | "DEP-001's ten steps are a critical path" | **False.** Two distinct relations were conflated (RT-21). |
| FA-6 | "The ternary output contract is satisfiable" | **False.** Inconsistent with multi-pool structure (RT-02). |
| FA-7 | "Σ0 is a layer above SPEC-000" | **False.** It is a value type plus a strictness discipline (RT-21). |
| FA-8 | "§6.3's table proves the reduction" | **False.** Verified on singletons only (RT-01). |
| FA-9 | "Warm-up of `L` bars suffices" | **False.** Unbounded state horizon (RT-03). |
| FA-10 | "H-04 (multi-symbol clock) is an open question" | **False.** The assumption is already made, in `DEC-006` (RT-12). |
| FA-11 | "Cycle C2 must be cut by a decision" | **False.** It exists only under R3, which is inadmissible (RT-17). |
| FA-12 | "Excluding the event from its baseline fixes C7" | **False.** Insufficient — the deeper defect is count-invariance (RT-13). |

Note FA-11 and FA-2: two of the previous phase's headline findings were partly
artefacts of its own errors. That is the expected yield of a red team and is the
reason the phase exists.

---

# 4. EXPRESSIVE POWER

Tested by construction against seven families. **No strategy was implemented**;
each was reduced to the semantic capabilities it requires.

| Family | Expressible? | Requires | Blocking gap |
|---|---|---|---|
| Smart Money Concepts | **Yes**, conditionally | populations, identity | RT-01 |
| Price-action structure systems | **Yes** | pivots, crossings | — |
| Breakout / retest | **Yes** | crossing + sequencing — *structurally identical to sweep + MSS* | — |
| Volatility-based | **Yes** | windowed aggregates | — |
| Mean-reversion | **Yes** | lifted aggregates (z-scores) | — |
| Wyckoff | **Partial** | volume is just another `Series` ✓; **phase labelling** is interval classification over a population ✗ | RT-01 |
| Auction Market Theory / Market Profile | **No** | a **measure over the price axis** (TPO/volume histogram, value area, POC), plus cumulative distribution and sorting on that axis | **fundamental** |
| Order-flow / footprint / DOM | **No** | same as above, plus sub-bar event ordering | **fundamental** |
| Statistical / ML overlays | **Inference yes, training no** | closed-form scoring is a lift ✓; fitting requires optimisation over history ✗ | out of kernel by design |

**Verdict: the kernel is `B`, restricted.** It is *market-methodology general over
the class of point-and-level, event-driven methodologies*, and provably not general
over *distributional or microstructural* ones. The boundary is sharp and has a
single cause: the kernel represents **points on the price axis**, never **measures
over it**.

This is a defensible boundary. It should be stated in the README as a scope
commitment, because the alternative is discovering it in year three when someone
proposes volume profile.

---

# 5. TEMPORAL SOUNDNESS — FORMAL VERDICT

**Verdict: ONLINE-CAUSAL, CONDITIONALLY — with three required changes.**

Classification of every concept by observability:

| Class | Concepts |
|---|---|
| **Immediately observable** (at bar close) | OHLC derivatives, penetration, MSS, confirmation-by-close, zone entry, bias, invalidation-by-price |
| **Observable with bounded delay** | pivot (`m` bars), pool (inherits pivot delay), sweep (≤ `W`), FVG (1 bar), accumulation (window), HTF context (≤ one HTF period), pullback count |
| **Only retrospectively observable** | the impulse terminal `B` — and therefore retracement %, the zone, and everything downstream of it — **unless frozen by an explicit rule** |
| **Fundamentally ambiguous** | `DEC-029` R3 — a counterfactual, not a function of the realised path (RT-17) |

**Required changes:**
1. **Freeze the impulse anchor** at a declared observation point, else the entire
   pullback subsystem is retrospective and cannot run online (this is DEP-001's C3,
   confirmed, and it is the one place where the trader's mental model is genuinely
   non-causal).
2. **Eliminate R3** — inadmissible on formal grounds.
3. **Stamp events at the base-clock instant of determinability** (RT-08), so
   cross-timeframe ordering is total.

With those three, every remaining concept is observable immediately or with a
bounded, declarable delay. **The methodology can be recognised online. It is not
merely a retrospective description of charts** — which was a live risk and is now
closed.

---

# 6. SYMMETRY SOUNDNESS — FORMAL VERDICT

**Verdict: CONDITIONAL — exact under three declared conditions.**

σ, corrected: `σ(bid, ask) = (c − ask, c − bid)`, extended pointwise to
`high ↔ low`, `above ↔ below`, `BUY ↔ SELL`. It is an involution (`σ² = id`).

Conditions under which σ is exact:
1. σ acts on the **full observation pair**, not on a single price series;
2. reflection is **affine**, preserving all difference-based quantities;
3. **no percentage-of-price quantity is ever introduced** — currently true, and a
   binding constraint on all future concepts.

Under (1)–(3), σ is exact on the entire current concept set — **including the
spread**, contradicting the previous claim.

**Status change:** σ must be a **checkable property of individual terms**, not an
axiom of the language (RT-22). As an axiom it forbids legitimate
direction-asymmetric methodologies. As a per-term property it retains every
benefit — single definition, no drift, mechanical mirror-testing — at no
expressiveness cost.

---

# 7. DETERMINISM — FORMAL VERDICT

**Verdict: NOT YET DETERMINISTIC. Achievable; nine gaps, one of them blocked.**

Determinism requires that evaluation be a pure function of `(data, snapshot,
selectors, thresholds)`. Nine unspecified sources are enumerated in RT-23. Eight
are closable by declaration. The ninth — **iteration order over the entity
population** — cannot be closed until RT-01 is resolved, because the population
does not yet have a defined representation.

**Determinism is therefore downstream of the population decision.** It cannot be
verified before it, and any determinism testing done first will pass for the wrong
reasons.

---

# 8. REPLAYABILITY — FORMAL VERDICT

**Verdict: NOT REPLAYABLE AS SPECIFIED. Two blocking defects.**

The intended pipeline — *historical data → event stream → knowledge state →
detector → decision*, with nothing flowing backward — is sound in principle and
survived attack **as a design**. It fails on two concrete points:

1. **Unbounded state horizon (RT-03).** Replay results depend on the start point.
   No warm-up length is provably sufficient. Requires either a proven maximum
   entity lifetime or a serialised population checkpoint.
2. **Missing snapshot coordinate (RT-07).** "Reproduce the run of 3 March" is
   ambiguous between what the engine saw and what the archive now holds.

Prefix invariance (P-2) remains the right test and survived. It is simply not yet
runnable against a system that has neither a bounded horizon nor a snapshot
identity.

---

# 9. EXPLAINABILITY — FORMAL VERDICT

**Verdict: NOT ACHIEVABLE WITHOUT A SEMANTIC EXTENSION. Decide now or pay a
rewrite.**

Minimum required to answer *"why did the engine generate this alert?"*:

| Requirement | Present? |
|---|---|
| rule identifier | derivable from the term structure |
| **witness** — which bars/entity/instant satisfied each conjunct | **absent** — evaluation produces truth values, not evidence (RT-10) |
| **entity identity** | **absent** (RT-11) |
| source series **and its availability lag** | absent (P-8 provides the mechanism, not the record) |
| parameter version, **selector version** | absent as a distinction (RT-16) |
| snapshot | absent (RT-07) |

And to answer *"why was this rejected?"*: the **set** of failed conjuncts at the
**first failing stratum** — neither of which A-5 currently provides (RT-09).

Explainability is not a reporting layer. It is a property of the **type of
evaluation**: `value` must become `value × evidence`, threaded through every
composition. Retrofitting it touches every term. For an advisory system whose only
product is a judgement the trader must be able to audit, deferring this is the
highest-leverage mistake available.

---

# 10. MISSING FOUNDATIONS

Genuinely missing semantic capabilities. Each is listed because a specific finding
requires it — none is included merely because it might be useful.

| # | Capability | Required by | Without it |
|---|---|---|---|
| **MF-1** | **Entity population** with creation, iteration, termination | RT-01 | The methodology cannot be expressed at all beyond a single instance |
| **MF-2** | **Identity** (fresh names, or non-reused slots) | RT-01, RT-11, RT-04 | Populations cannot be referenced; A-2 violated on slot reuse |
| **MF-3** | **Evidence-producing evaluation** (`value × evidence`) | RT-10, RT-09 | Explanation is post-hoc and can diverge from the logic |
| **MF-4** | **Third time coordinate** (snapshot) | RT-07 | Historical reproduction is ambiguous under data revision |
| **MF-5** | **Availability-lag typing** on series | P-8, RT-08 | MTF causality is tested empirically instead of guaranteed statically |
| **MF-6** | **Exogenous base clock** | RT-12, RT-08 | Cross-symbol work requires a rewrite; cross-TF order stays partial |
| **MF-7** | **Total order over the population** | RT-23 item 8 | Determinism unachievable |

Seven. MF-1 and MF-2 are the same decision seen twice; MF-7 is a consequence of
resolving them. The genuinely independent additions are **populations with
identity, evidence, snapshot, lag-typing, and an exogenous clock** — five.

---

# 11. MINIMAL KERNEL AFTER ATTACK

Every primitive and combinator was subjected to removal. What follows is what
survived, plus what the attack proved must be added.

## 11.1 Surviving core

| Operator | Why necessary | If removed | Enables |
|---|---|---|---|
| **`Series`** over a value domain including `⊥` | The only input. `⊥` is forced independently by missing bars (`DEC-006`), by the exogenous clock (RT-12), and by three-valued semantics — three unrelated derivations of the same requirement | Nothing can be expressed | Everything |
| **`Lift`** (pointwise application of a scalar function) | All arithmetic, all comparison, all logic. `And` is `Lift(∧)`; `Compare` is `Lift(>)` | No computation | Comparison, ratios, affine levels, conjunction |
| **`Delay`** (one-step shift with declared initial value) | The only source of memory. `Crossing` is `Lift(>)` plus `Delay`; a bounded `Window` is `n` delays | No memory, no edge detection, no windows, no sequencing | Crossings, windows, bounded aggregates |
| **`Recursion`** (guarded feedback: every cycle passes through a `Delay`) | Unbounded/running aggregates (`runmax` since an event), timers, latches, state machines. Guarding is what makes it well-defined | Only fixed-lookback terms; running extrema, pool lifetimes and setup state all become inexpressible | Aggregates, `Then-within`, the entire lifecycle |

**Four operators.** `Window`, `Level`, `Zone`, `Crossing`, `Aggregate`,
`Then-within` and `And` are **derived abbreviations** and must be labelled as such
in SPEC-100, or they will drift from their definitions over twenty years — the
exact failure mode this corpus exists to prevent.

## 11.2 Forced additions

| Addition | Why it cannot be derived | If omitted |
|---|---|---|
| **Population + identity** (MF-1, MF-2) | A fixed set of streams cannot represent a runtime-determined number of individually-stateful objects. Quantifying over them has no domain | RT-01: the methodology is inexpressible past one instance |
| **Evidence** (MF-3) | Evidence is a property of the *derivation*, not of the value. A calculus of values cannot produce it | RT-10: explanation diverges from logic; retrofit is a rewrite |
| **Snapshot coordinate** (MF-4) | Not a function of the data — it identifies *which* data | RT-07: history is not reproducible |
| **Lag typing** (MF-5) | A static property of terms, not a computable value | Causality tested, never guaranteed |

## 11.3 Verdict on the architecture

Both, simultaneously:

- **Over-engineered** in its primitives — five where four suffice, plus a Σ0
  "layer" that is really a type and a strictness rule.
- **Under-powered** in its semantics — no populations, no identity, no evidence,
  no snapshot, no lag types.

Not "accidentally elegant but incomplete". **Deliberately elegant in the wrong
dimension**: the corpus optimised the calculus of values, which was never the hard
part, while the population of objects — which is where every real difficulty lives
— went unmodelled because the singleton examples always worked.

---

# 12. THE 20-YEAR TEST

**Decisions that would force a migration if taken as currently implied:**

| Current position | Migration triggered by |
|---|---|
| Per-symbol clock (RT-12) | The first cross-symbol feature — SMT, correlation, portfolio |
| Ternary output (RT-02) | The first instant with two valid opposite setups — i.e. immediately |
| No population semantics (RT-01) | The second FVG |
| Values without evidence (RT-10) | The first "why did it do that?" |
| Selectors versioned as parameters (RT-16) | The first methodology revision — silently, with no error |
| Two time coordinates (RT-07) | The first data revision |
| Fixed concept set | Order Blocks |
| O/H/L/C as the complete observation | Volume, or anything from RT-24's excluded class |

**Abstractions likely to become obsolete:** `Level` (subsumed by `Series`),
`Window` (subsumed by `Delay`), `Timeframe`-as-enum (it is a derivation), the
ternary verdict, Σ0-as-layer.

**Dangerous to encode permanently:** any empirical market asymmetry (RT-22); any
percentage-of-price threshold (RT-18 condition 3); any broker-specific session
anchor (RT-20); the assumption that the observation is a single price series
rather than `(bid, ask)` (RT-18); the assumption that the price axis carries points
rather than measures (RT-24).

---

# 13. WHAT THE ATTACK DID NOT BREAK

Recorded deliberately, because a red team that finds only failures is not
measuring anything.

- The **causal ordering** of the methodology. Attacked from four directions; no
  temporal cycle exists.
- **Prefix invariance** as the look-ahead test. No in-engine leak was constructed
  that it fails to catch.
- **Stratification** as the universal cycle-cutting technique. It worked on all
  seven cycles, and it removed one entirely (RT-17).
- The **layered ontology** L0→L4 as a dependency discipline, once the Σ0
  category error is removed.
- The claim that **confirmation is market-structure-shift at a smaller scale**
  (P-6). This survived every attempt to distinguish them and remains the corpus's
  strongest formal result.
- The **corpus-first validation strategy** (VAL-001 §2). Nothing in this attack
  weakens it; RT-13, RT-14 and RT-19 strengthen it, since each is a question only
  measurement can settle.

---

# 14. WHAT MUST BE TRUE BEFORE ANYTHING IS BUILT

Not a plan — a precondition list. Eleven findings block future work:

**RT-01** (populations) · **RT-02** (output contract) · **RT-03** (state horizon) ·
**RT-04** (A-2 vs ontology) · **RT-07** (snapshot) · **RT-08** (event stamping) ·
**RT-10** (evidence) · **RT-11** (identity) · **RT-12** (exogenous clock) ·
**RT-16** (selectors vs thresholds) · **RT-21** (Σ0 category error).

Of these, **RT-01 is upstream of six others**. It is the correct next decision, and
unlike most of the register it is not a trading question — it is a question about
what kind of object the engine manipulates.

**This phase stops here.** Nothing above is resolved, and resolving it is the next
phase's mandate, not this one's.
