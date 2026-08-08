# REDTEAM-003 — Formal Boundaries

*Part I of the phase. `D-P1`, `D-P2`, `D-P3`, prefix invariance, computational
power, decidability, stack representation, identity, checkpoints, output layer.*

**Epistemic discipline.** Every claim carries one of these, and nothing is
upgraded by convenience:

| Tag | Meaning |
|---|---|
| **THEOREM** | Proved here from stated premises. |
| **LEMMA** | Proved, subordinate to a theorem. |
| **CONJECTURE** | Believed, *not* proved. Stated so it can be attacked. |
| **OBSERVATION** | Empirical. **No MT5 observations exist in this corpus** — see `experiments/mt5/README.md` §1. |
| **ASSUMPTION** | An architectural choice taken as a premise, not derived. |
| **OPEN** | Unresolved. |

---

# 0. What this phase changed

Three results, one of which is a correction to my own previous document.

1. **`D-P1`'s cost is measurable, not speculative** (§1.3). On any *finite*
   dataset, bounded and unbounded semantics agree exactly once `K` exceeds the
   observed maximum population depth. So the entire question reduces to a
   measurement the corpus can perform.
2. **`D-P2`'s proposed restriction is too strong as stated** (§2.3). A
   counterexample exists among predicates the methodology already needs. It is
   repairable by a *stratification* of predicates into birth-time and query-time,
   which is a better answer than the restriction.
3. **REDTEAM-002 §10.2 contains an error.** The claim
   `Pop_known(t) ⊆ Pop_occurred(t)` is **not** true in general (§3.2). It holds
   only if deaths are immediately decidable — and Part II shows MT5 makes that
   false for every timeframe above the base clock.

---

# 1. D-P1 — SEMANTIC UNBOUNDEDNESS

## 1.1 The question made precise

Let `⟦S⟧` be a strategy's denotation under unbounded population semantics and
`⟦S⟧_K` its denotation when every population is truncated at `K`.

> **THEOREM 1.1 (Bounded semantics is not one semantics).**
> There exist a data prefix `d` and a bound `K` with `⟦S⟧_K(d) ≠ ⟦S⟧_{K+1}(d)`.
>
> *Proof.* The construction in REDTEAM-002 §7.1: `K` unmitigated FVGs inside an
> impulse, plus one more whose mitigation invalidates the setup. Under `K` the
> engine emits an opportunity; under `K+1` it does not. ∎

> **COROLLARY 1.2.** `{⟦S⟧_K}` is a *family* of strategies indexed by `K`. Under
> bounded semantics "the strategy" is not a well-defined object without `K`, and
> results produced under different `K` are not comparable.

This is why `D-P1` is constitutional rather than an engineering preference: it
decides whether the specification denotes one thing or a family.

## 1.2 The other direction

Under unbounded semantics `⟦S⟧` is a single function and every implementation
computes some `⟦S⟧_K`. That looks like the same problem relocated — and it is
not, because of:

> **THEOREM 1.3 (Finite-data exactness).**
> For a finite data prefix `d`, let `D(d) = max_t |Pop(t)|` over the run. Then for
> every `K ≥ D(d)`, `⟦S⟧_K(d) = ⟦S⟧(d)`.
>
> *Proof.* If `K ≥ D(d)` the bound never binds, so no truncation is ever applied,
> so the two computations perform identical steps on identical values. ∎

> **COROLLARY 1.4 (The cost is measurable).** The divergence between bounded and
> unbounded semantics on any finite corpus is **decidable** by measuring `D(d)`.
> It is not a matter of judgement.

That converts `D-P1` from a philosophical question into a two-part one:

- *semantics*: unbounded, so `⟦S⟧` denotes one object (Corollary 1.2);
- *implementation*: any `K`, with an obligation to report binding (`D-P6`) and a
  measured `D(d)` over the corpus.

**The corpus gains a concrete new job:** record `max_t |Pop(t)|` per entity class,
per timeframe, per side. Blocked by nothing. If `D(d)` turns out to be, say, 40
for H4 pools over ten years, the practical stakes of `D-P1` collapse to nearly
nothing while the semantic stakes remain.

**Status: `D-P1` remains OPEN** — this phase does not resolve it. What changed is
that resolving it now requires a measurement rather than a preference.

## 1.3 What is *not* proved

> **CONJECTURE 1.5.** `D(d)` is small in practice (order 10¹–10²) for all entity
> classes on liquid FX symbols over decade-scale history.

Plausible from the staircase structure — each stack entry requires a distinct
non-retraced leg — but **unproved and unmeasured**. It is the empirical claim on
which the practical irrelevance of `D-P1` would rest, and it must not be assumed.

---

# 2. D-P2 — MONOTONICITY

## 2.1 The property

> **DEFINITION.** A predicate `p` over a population is **order-contiguous** if for
> every reachable population state, `{e : p(e)}` is a contiguous segment of the
> stack.

> **LEMMA 2.1.** If the stack is sorted by price (REDTEAM-002 §1.4 Corollary 1)
> and `p` is a threshold predicate on price, then `p` is order-contiguous.
> *Proof.* A threshold on a sorted sequence selects a prefix or a suffix. ∎

> **LEMMA 2.2.** Predicates of the form "born after instant `t`" are also
> order-contiguous. *Proof.* By the staircase theorem, birth order and price order
> coincide; so a birth-time threshold is a price threshold in disguise, and
> Lemma 2.1 applies. ∎

> **THEOREM 2.3.** For order-contiguous `p`, `EXISTS p`, `COUNT p`, `MIN`, `MAX`
> and range queries are answerable by inspecting the segment's endpoints — `O(1)`
> for the extremes and `O(log n)` to locate a boundary. No traversal.

## 2.2 The counterexample — the proposed restriction is too strong

`D-P2` as recorded in REDTEAM-002 asked whether *every* quantified predicate must
be monotone in the stack order. The answer is no, and the methodology itself
supplies the refutation:

> **COUNTEREXAMPLE 2.4.** `DEC-036` requires a minimum FVG size. Size is not a
> function of position in the price-sorted stack — a large gap may sit anywhere.
> `{e : size(e) ≥ θ}` is therefore **not** order-contiguous. The same argument
> applies to `DEC-020` pool significance.

So adopting `D-P2` as stated would forbid two predicates the methodology already
requires. **A restriction that outlaws the domain is not a candidate.**

## 2.3 The repair — predicate stratification

The counterexamples share a feature: **they are properties fixed at birth and
never revised.**

> **DEFINITION.** A **birth filter** is a predicate evaluated once, at the instant
> of an entity's creation, deciding whether the entity enters the population at
> all. A **query predicate** is evaluated against a live population at an
> arbitrary later instant.

> **THEOREM 2.5.** A birth filter may be arbitrary — any computable predicate over
> the entity's birth data — at `O(1)` cost per birth and with no effect on query
> complexity, because entities failing it never enter the stack.
>
> *Proof.* Birth is a single event at a single instant; evaluating a predicate on
> its local data requires no population access. ∎

Under this stratification, `DEC-036` and `DEC-020` become birth filters, and the
query-time population contains only qualifying entities — so the predicate is
vacuous at query time. The counterexample dissolves without weakening anything.

> **RESTATED `D-P2`:** *must every **query-time** predicate over an unbounded
> population be order-contiguous, with all other predicates pushed to birth time?*

> **CONJECTURE 2.6 (Sufficiency).** Every predicate the methodology requires is
> either a birth filter or a conjunction of price-range and time-range constraints
> — hence order-contiguous.
>
> Verified by inspection against every population query currently in `SPEC-100`:
> "unmitigated FVG inside the impulse" (time-range ⇒ contiguous), "nearest pool
> above price" (extremum), "any FVG mitigated since the setup began" (a death
> counter, `O(1)`), "pools within the retracement zone" (price-range ⇒
> contiguous). **Not proved for predicates not yet written**, and it is exactly
> the kind of claim that a future concept could break. Flagged so that any new
> concept must be checked against it.

**Status: `D-P2` remains OPEN, but reformulated.** The reformulation is the
contribution; the decision is not taken here.

---

# 3. D-P3 — Pop_known VERSUS Pop_occurred

## 3.1 Definitions

```
Pop_occurred(t) = { e : birth_occurred(e) ≤ t  ∧  ¬(death_occurred(e) ≤ t) }
Pop_known(t)    = { e : birth_known(e)    ≤ t  ∧  ¬(death_known(e)    ≤ t) }
```

## 3.2 The correction to REDTEAM-002

REDTEAM-002 §10.2 asserted `Pop_known(t) ⊆ Pop_occurred(t)`, unconditionally.
**That is false.**

> **THEOREM 3.1.** `Pop_known(t) ⊆ Pop_occurred(t)` holds **iff** deaths are
> decidable without delay.
>
> *Proof.* (⇐) With zero death delay, `death_known = death_occurred`, and birth
> delay only removes elements from `Pop_known`, giving containment.
> (⇒) Suppose a death has delay `m′ > 0`. Take `t ∈ [death_occurred(e),
> death_known(e))`. Then `e ∉ Pop_occurred(t)` but `e ∈ Pop_known(t)`.
> Containment fails. ∎

> **COROLLARY 3.2.** If both births and deaths carry delay, the two populations
> are **incomparable**: each contains elements the other lacks.

**Why the error mattered.** Under containment, quantifying over `Pop_known` is
merely *conservative* — you might miss an entity, never invent one. Under
incomparability, a rule quantifying over `Pop_known` can be satisfied by an entity
that **has already been destroyed**. That is not conservatism; it is a false
positive, and the Precision Doctrine forbids exactly that.

## 3.3 The link to Part II — deaths do have delay

Part II establishes `[BELIEF]` that in MT5 an HTF bar becomes knowably closed only
when the first tick at or after its boundary arrives, with an unbounded gap
(`MT5-CAP-001` §2, `E-MT5-002`).

> **COROLLARY 3.3.** Any death predicate evaluated on a timeframe above the base
> clock inherits a non-zero, data-dependent delay. Therefore **the incomparable
> case of Corollary 3.2 is the operative one**, not the containment case.

`D-P3` is therefore not a choice between a safe and a risky option. **Both options
are unsafe in different directions**, and the specification must say which
direction it accepts. That is a materially different decision from the one
REDTEAM-002 posed.

**Status: `D-P3` remains OPEN, and is more severe than recorded.**

---

# 4. PREFIX INVARIANCE

> **THEOREM 4.1.** If every fact is stamped with the instant at which it becomes
> determinable from the prefix, then truncating the data at `t` leaves unchanged
> every fact with `t_known ≤ t`.
> *Proof.* Immediate: such a fact's value is a function of the prefix up to
> `t_known ≤ t`, which truncation does not alter. ∎

Theorem 4.1 is nearly vacuous — which is the point. **Prefix invariance is not a
property the design earns; it is a property a correct implementation must not
break.** Its whole value is as a *test*.

> **THEOREM 4.2 (Populations inherit it).** If births and deaths are prefix-stable,
> so is `Pop(t)`, since `Pop` is a fold over them. ∎

## 4.1 The MT5-executable form of the test

MT5 supplies a natural adversary that the abstract statement does not:

> **Recalculation invariance.** An indicator recomputing from scratch
> (`prev_calculated == 0`) has the entire history array in scope, while one
> running incrementally does not. The same source can therefore yield different
> results depending on how it was invoked.
>
> **Test:** run the engine incrementally over `[0,T]`; separately run it once over
> the full `[0,T]`; assert the two fact streams are byte-identical.

This is stronger and far more practical than the abstract formulation, because the
dominant real-world look-ahead mechanism in MT5 is precisely a full-array
recalculation that reads `rates[i+k]` (`MT5-CAP-001` §3). Recorded as the
canonical form of the `VAL-001` §4 test.

---

# 5. COMPUTATIONAL POWER AND DECIDABILITY

> **THEOREM 5.1.** A single population stack over a **finite** price alphabet,
> driven by a finite-state controller, is a pushdown system; reachability and LTL
> model checking are decidable.

> **ASSUMPTION 5.2.** The price alphabet is finite. Prices lie on a tick grid, so
> the grid is discrete; finiteness additionally requires a bounded price *range*.
> That bound is real in practice and **not** derivable from the formalism. It is
> an architectural assumption, recorded as such.

> **THEOREM 5.3 (The obstacle).** Two independent stacks with a shared finite
> control simulate a two-counter machine; reachability is undecidable.

The system has one stack per `symbol × timeframe × side × kind`, and the rules
relate them. Theorem 5.1 therefore does **not** transfer.

> **CONJECTURE 5.4.** Under the predicate stratification of §2.3, each instant
> touches `O(1)` elements of `O(1)` stacks, placing the system in a
> bounded-context-switching fragment, for which reachability is decidable
> (Qadeer–Rehof).
>
> **Not proved.** The bounded-context result concerns a bounded number of context
> switches over an entire run, not per step; whether the per-instant bound implies
> the global one for this control structure is exactly the gap. This may require
> an outside proof or a different fragment (e.g. ordered multi-pushdown systems,
> for which decidability is known under a stack ordering discipline — whether our
> stacks admit such an order is itself **OPEN**).

**`D-P9` stands as the deepest open technical question in the corpus.** §2.3
improves the odds; it does not close it.

---

# 6. STACK REPRESENTATION AND IDENTITY

Both carried forward from REDTEAM-002 and re-examined; both survive.

> **THEOREM 6.1** (staircase) and **THEOREM 6.2** (one birth per instant ⇒ derived
> identity) are restated unchanged. No counterexample was found this phase.

One refinement, forced by Part II:

> **COROLLARY 6.3.** `birth_instant` must be the instant of *determinability*, not
> the nominal bar time (`RT-08`). In MT5 the nominal time is `MqlRates.time` (the
> bar's **open** time) while determinability is the arrival of the first tick past
> the bar's boundary. **These differ by an unbounded amount**, so identity keyed on
> the nominal time and identity keyed on determinability are different keys.

> **OPEN 6.4.** Which one is the identity key? Nominal time is stable across
> reruns and independent of tick delivery, and is therefore *more reproducible*;
> determinability time is *more causal*. This is a genuine conflict between two
> properties the project holds simultaneously, and it was invisible before MT5
> was treated as a semantic target.

---

# 7. CHECKPOINT SEMANTICS

> **THEOREM 7.1 (Resumability).** If the engine state is exactly (i) a finite
> scalar register set and (ii) the stack family, then serialising both at `t` and
> resuming yields exactly the run that would have continued from `t`.
>
> *Proof.* The evolution law is a fold; a fold's future depends on its accumulator
> and its remaining input alone. Both are captured. ∎

> **COROLLARY 7.2.** `RT-03` (replay is start-dependent; no checkpoint format
> exists) is **resolved conditionally**: the format is exactly (i)+(ii), and
> resumption is provably equivalent to replay from epoch.

> **ASSUMPTION 7.3.** The condition — that nothing else persists — is an
> architectural commitment, not a theorem. Any hidden state (a cached indicator
> handle, a static array, a chart object) falsifies Theorem 7.1 silently. Part II
> shows MT5 offers several such places (`MT5-CAP-001` §7).

---

# 8. OUTPUT-LAYER CLASSIFICATION

Formalising REDTEAM-002 §15:

```
engine       : Data                    → Pop(Setup)      set-valued, total, deterministic
policy       : Pop(Setup) × Policy     → Pop(Alert)      selection; versioned; trader-owned
presentation : Pop(Alert)              → Verdict         ternary; may lose information
```

> **THEOREM 8.1.** `engine` requires no order over setups. *Proof.* Its codomain is
> a set; no selection occurs. ∎

> **THEOREM 8.2.** `policy` requires a total order over `Pop(Setup)` **iff** it
> selects a proper non-empty subset by rank. If it selects by a predicate
> (e.g. "all setups whose timeframe is H1 or above"), no order is needed.

> **COROLLARY 8.3.** The ternary contract forces an order **only** if the policy
> is rank-based. A predicate-based policy satisfies the ternary presentation with
> no appeal to `DEC-050`.

That is a stronger version of REDTEAM-002 §15: the output contract does not merely
*relocate* away from `DEC-050`, it can be **fully decoupled** from it by choosing a
predicate-based policy. Whether that is desirable is a trading question and is not
decided here.

> **REQUIREMENT 8.4.** `policy` must be **total** — defined for the empty
> population and for ties — and **deterministic**. Neither is currently stated
> anywhere.

---

# 9. STATUS OF EVERY CLAIM IN THIS DOCUMENT

| # | Claim | Status |
|---|---|---|
| 1.1 | Bounded semantics is a family, not a semantics | **THEOREM** |
| 1.3 | Finite-data exactness for `K ≥ D(d)` | **THEOREM** |
| 1.5 | `D(d)` is small in practice | **CONJECTURE** — unmeasured |
| 2.1–2.3 | Order-contiguous predicates are `O(1)`/`O(log n)` | **THEOREM** |
| 2.4 | The blanket monotonicity restriction is too strong | **COUNTEREXAMPLE** |
| 2.5 | Birth filters may be arbitrary at no query cost | **THEOREM** |
| 2.6 | Stratification suffices for the whole methodology | **CONJECTURE** — verified only against currently-written concepts |
| 3.1 | Containment holds iff deaths are instant | **THEOREM** |
| 3.2 | With delayed deaths the populations are incomparable | **COROLLARY** |
| 3.3 | MT5 gives deaths a delay ⇒ incomparable case is operative | **COROLLARY** of a `[BELIEF]` — inherits that status |
| 4.1–4.2 | Prefix invariance, and populations inherit it | **THEOREM** |
| 5.1 | Single stack ⇒ decidable | **THEOREM** (standard result) |
| 5.2 | Finite price alphabet | **ASSUMPTION** |
| 5.3 | Two stacks ⇒ undecidable | **THEOREM** (standard result) |
| 5.4 | Our system sits in a decidable fragment | **CONJECTURE** — `D-P9` |
| 6.1, 6.2 | Staircase; derived identity | **THEOREM** (REDTEAM-002) |
| 6.4 | Nominal vs determinability as the identity key | **OPEN** |
| 7.1 | Checkpoint resumability | **THEOREM**, conditional on 7.3 |
| 7.3 | No hidden state | **ASSUMPTION** |
| 8.1–8.3 | Output layering; order needed only for rank-based policy | **THEOREM** |

**Zero OBSERVATIONs.** No MT5 behaviour has been measured in this environment.

---

# 10. WHAT THIS PHASE DID NOT SETTLE

`D-P1`, `D-P2`, `D-P3` all remain **OPEN**, as instructed. What changed:

- `D-P1` now has a **measurement** that would settle its practical stakes.
- `D-P2` was **reformulated** after its original form was refuted.
- `D-P3` was found **more severe** than recorded, and REDTEAM-002's supporting
  claim was **withdrawn**.
- `D-P9` gained a candidate fragment and remains the deepest open question.
- **New: `OPEN 6.4`** — reproducibility and causality select different identity
  keys, and MT5 is what made the conflict visible.
