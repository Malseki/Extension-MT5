# REDTEAM-002 — Population, Identity and Multiplicity

*Second adversarial phase. Object of study: RT-01, the claim that the kernel cannot
express dynamic populations. RT-01 is treated here as a hostile claim like any
other.*

---

# EXECUTIVE SUMMARY

RT-01 was **correct but far too broad**, and two of the foundations it demanded do
not exist.

Six results:

1. **Only one entity class is genuinely unbounded.** Liquidity pools and
   structural levels have unbounded lifetime. FVGs *within an impulse*, pullbacks,
   impulses, confirmations and setups are all **window-bounded by the
   methodology's own timeouts**, and are therefore expressible in the current
   kernel today, by static unrolling. RT-01 diagnosed a general disease from one
   sick organ.

2. **The unbounded population is not an arbitrary set. It is a monotone stack.**
   Proved in §1.4: at any instant, the unswept pools on one side of one series,
   ordered by creation time, are **strictly monotone in price**. A new pivot
   sweeps exactly a prefix. Push and pop-prefix — a stack, not a collection.
   The same proof applies to unmitigated FVGs.

3. **Identity is derived, not primitive. RT-11 is refuted.** At most one entity of
   a given kind is born per series per instant (§2.2), so
   `(kind, series, birth_instant)` is a **key**. No fresh-name generation, no slot
   reuse, no new capability. `MF-2` should be struck.

4. **σ lifts to populations exactly — and only because identity is derived.**
   Fresh names would not commute with σ. The two results are load-bearing for each
   other (§11).

5. **The missing capability is in the value domain, not the operator set.** §17
   gives a register-counting impossibility proof for scalar dataflow, and shows
   the escape is a single unbounded-carrier value, not a new operator. All three
   options A/B/C were arguments about the wrong axis.

6. **RT-02 is resolved by relocation, not by change.** The ternary contract is
   sound — at the presentation layer. The engine level is set-valued; the decision
   layer selects. The brief's requirement was never wrong; it was filed one layer
   too low (§15).

**Net effect on the register:** two missing foundations struck (`MF-2`, `MF-7`
intra-series), one narrowed (`MF-1`), two prior findings resolved (`RT-23` item 8;
`RT-03` checkpoint format), one relocated (`RT-02`). **Nine new decisions**
discovered, three of them constitutional.

**And one new hard problem, which is now the deepest open risk in the project:**
multiple interacting stacks restore undecidability of verification (§17.4). The
single-stack fragment is decidable; the system has one stack per
symbol × timeframe × side × kind, and the rules relate them.

---

# 1. WHAT A POPULATION IS

## 1.1 The candidates, tested against the domain

| Structure | Test it fails |
|---|---|
| **Set** | Extensional collapse. Two FVGs with identical price interval born at different times are different entities; set semantics identifies things by value and cannot hold both. Also: a set has no order, and §8 shows this domain's order is *intrinsic*, so set semantics discards real information. **Insufficient.** |
| **Sequence** | Position is identity, and positions shift on deletion. Mitigating FVG #2 renumbers #3. Identity must survive deletion of others. **Insufficient.** |
| **Stream** | One value per instant. Cannot hold many simultaneously — that is the whole problem. **Insufficient alone.** |
| **Collection** | Not a definition. Rejected as a term. |
| **Registry** (`id ↦ record`, with allocation) | Adequate but over-powered: it permits arbitrary insertion and deletion, which the domain never performs (§1.4), and that extra power is exactly what destroys verifiability (§17.4). **Sufficient but wasteful.** |
| **Indexed family** `{eᵢ}ᵢ∈I`, `I` fixed | Exactly the bounded-K encoding. Correct for window-bounded classes, wrong for unbounded ones. **Partial.** |
| **Time-varying relation** `Pop : Time → 𝒫_fin(Entity)` | Correct as a *denotation*. Says what a population is, not how it evolves. **Necessary but incomplete.** |
| **Stateful population** | The operational reading. Needs the evolution law to be stated, which is §1.3. |

## 1.2 The definition

> A **population** is a time-indexed finite relation
> `Pop : Time → 𝒫_fin(Entity)`
> with three properties:
> **(P1) Intensional identity.** Entity identity is not a function of the
> entity's *current* attributes; it is fixed at birth (§2).
> **(P2) Birth monotonicity.** The set of *ever-born* entities is monotonically
> non-decreasing in time. An entity is born once, at one instant, and never
> un-born.
> **(P3) Derived liveness.** The live set is not stored. It is
> `live(e,t) ⟺ born(e) ≤ t ∧ ¬∃ t′ ≤ t . death(e, t′)`,
> where `death` is a predicate over the entity and the data prefix.

P2 and P3 together are the **event-sourced** reading: the population is a *fold*
over a stream of birth and death events. A fold is guarded recursion — which is
already in the kernel. This is the first sign that the problem is narrower than
RT-01 claimed.

## 1.3 The evolution law

```
Pop(t) = Pop(t−1)  ∪  births(t)  ∖  deaths(t)
Pop(0) = ∅
```

Guarded (every reference to `Pop` on the right is delayed), deterministic if
`births` and `deaths` are, and causal if both are functions of the prefix. **The
law is expressible in the current kernel. Only the carrier — the value `Pop(t)`
— is not a scalar.**

## 1.4 The structure theorem — the central result of this document

The domain does not need arbitrary insertion and deletion. It performs exactly
two operations, and that is provable.

> **Theorem (Monotone staircase).** Let `h₁` and `h₂` be pivot highs on one
> series with birth instants `t₁ < t₂`, both unswept at time `T ≥ t₂`. Then
> `h₂ < h₁`.
>
> **Proof.** `h₂` is a pivot high at `t₂`, so the price series attained `h₂` at
> `t₂`. Suppose `h₂ ≥ h₁`. Then price attained a value `≥ h₁` at `t₂ > t₁`, which
> is a penetration of `h₁` after its birth — so `h₁` is swept at `t₂ ≤ T`,
> contradicting the hypothesis. Hence `h₂ < h₁`. ∎

> **Corollary 1 (Order).** The unswept buy-side pools on a series, ordered by
> birth time newest-first, are **strictly increasing in price**. The order is
> total and intrinsic; it is not a convention.

> **Corollary 2 (Operations).** A penetration to level `L` sweeps exactly those
> unswept pools with level `≤ L`. By Corollary 1 these are a **contiguous prefix
> from the newest end**. Therefore the only operations the domain performs are
> **push** (a new pivot) and **pop-prefix-while** (a penetration).
>
> **The live pool population is a stack.**

> **Corollary 3 (FVGs).** The same argument transfers. A bullish FVG is
> unmitigated only if price has not returned to it. If a newer unmitigated bullish
> FVG were *below* an older one, price would have had to traverse the older one to
> reach it, mitigating it. So unmitigated FVGs are monotone in the same sense, and
> mitigation pops a prefix. **Also a stack.**

The consequences run through the rest of this document. The domain never needs
`delete(arbitrary element)`. It never needs `insert(at position)`. It needs
`push` and `pop-prefix`. That is the smallest structure that fits, and it is
strictly weaker than a registry, a map, or a set.

## 1.5 The three population classes

Every multiplicity in the methodology falls into exactly one class.

| Class | Members | Cardinality bound | Expressible in the current kernel? |
|---|---|---|---|
| **I · Horizon-unbounded, stack-structured** | liquidity pools, structural levels, unmitigated FVGs *outside a bounded window* | none | **No** |
| **II · Window-bounded** | FVGs *within an impulse*, pullbacks within an impulse, impulses within a setup, confirmations, setup candidates | bounded by the methodology's own timeouts (`DEC-035`, `DEC-045`, `DEC-054`) | **Yes** — static unrolling, §5.1 |
| **III · Singleton** | bias per series, current verdict per symbol | 1 | Yes |

**RT-01's scope was wrong.** Class II is the majority of the methodology's
multiplicity and needs nothing new. Only Class I is a genuine gap, and within
Class I the structure is a stack.

---

# 2. IDENTITY

## 2.1 What the question actually is

RT-11 claimed identity is primitive under dynamic creation, on the grounds that
dynamic creation requires fresh-name generation. That reasoning imports an
assumption from process calculi that this domain does not satisfy.

## 2.2 The key theorem

> **Theorem (One birth per instant).** For a fixed entity kind `κ` and a fixed
> series `σ`, at most one entity of kind `κ` is born on `σ` at any instant `t`.
>
> **Proof by cases over the kinds.** A pivot high is the high of one bar; one bar
> per instant per series, so at most one. A three-bar FVG completes at one bar; at
> most one per bar per direction, and direction is part of the kind. A structural
> level is a selected pivot, so it inherits the bound. A setup is born at one
> confirmed MSS, and an MSS is a crossing of one level by one series at one
> instant. ∎

> **Corollary (Derived identity).** `(kind, series, birth_instant)` is a key on
> the entity population. Identity is therefore **derived from the data**, not
> generated.

`series` here expands to `(symbol, timeframe, side)` — see §12.

## 2.3 The minimum identity model

```
EntityId  =  (kind, symbol, timeframe, side, birth_instant)
```

Classified against the options the brief asked about:

| Model | Verdict |
|---|---|
| **Intrinsic** (a fresh name, ν-style) | **Rejected.** Unnecessary — the key exists. Actively harmful — breaks σ (§11.2). |
| **Derived** (a function of the data) | **This one.** |
| **Temporal** (birth instant) | A *component* of the key, not sufficient alone — several kinds are born at one instant. |
| **Positional** (slot index) | **Rejected.** Slot reuse makes a slot's history differ from an entity's history, violating A-2. The defect RT-11 identified is real and this model avoids it entirely. |
| **Structural** (kind + series) | A *component*, not sufficient — many entities per series. |

**Derived = temporal × structural.** Nothing else is needed.

## 2.4 Does identity survive replay?

**Yes, and provably.** The key is a function of the data prefix, so replaying the
same prefix under the same parameters yields byte-identical ids. Contrast: a fresh
counter yields identical ids only if every birth occurs in the identical order,
which is a much stronger and unverifiable condition.

**One consequence, and it is not cosmetic.** `birth_instant` is the instant of
*determinability* (RT-08), which depends on confirmation delays, which depend on
parameters (pivot width `m`). Therefore:

> Entity identity is relative to `(spec, selectors, thresholds, snapshot)`.
> Ids are **not comparable across parameter versions.**

This is `RT-16` reappearing at the identity layer, and it means an entity id is
never a global name — it is a name *within a run*. Recorded as decision `D-P7`.

## 2.5 The brief's example, resolved

The brief asked what distinguishes two FVGs with the same interval, timestamp and
source. **Nothing does — because by §2.2 that situation cannot arise.** Two
entities of one kind on one series never share a birth instant. If two records
appear identical, they are one entity recorded twice, which is a defect in the
recording, not an identity problem in the domain.

---

# 3. LIFECYCLE

## 3.1 Where lifecycle state lives

RT-04 established that a mutable `status` field violates A-2. §1.2 P3 gives the
alternative: liveness is a **derived time-indexed predicate**, not stored anywhere.

Under §1.4, liveness has an even simpler reading:

> **`live(e, t)` ⟺ `e` is on the stack at `t`.**

The stack *is* the live set. There is no status field, no lifecycle enum, and no
transition table. The entity record is immutable and carries birth data only.

## 3.2 The brief's five-state model is too large

```
CREATE → ACTIVE → MODIFIED → MITIGATED/INVALIDATED/EXPIRED → RETIRED
```

- **MODIFIED is not a state.** The thing it is meant to capture — an FVG being
  partially filled — is a *derived measure*:
  `fill(e,t) = max(0, e.top − min_low(e.birth … t))`.
  A function of the entity and the prefix. Storing it would be storing a
  derivative.
- **RETIRED and MITIGATED/INVALIDATED/EXPIRED are one state**, distinguished only
  by *which predicate* fired. That is provenance (the death cause), not a
  different status.
- **ACTIVE is `¬dead`**, not an independent state.

> **Reduced model: two instants and one predicate.**
> `birth(e)` — an instant, part of the identity.
> `death(e)` — an instant, plus a *cause* for explainability.
> `live(e,t)` — derived.

Everything the five-state model expressed is recoverable, and nothing is stored
that could go stale. **No new primitive; the reduction removes three states.**

---

# 4. FINITE, BOUNDED, OR UNBOUNDED

## 4.1 The distinction the brief insisted on

- **Semantic unboundedness** — the *language* permits arbitrarily many entities.
- **Operational boundedness** — a *runtime* imposes a finite limit.

Conflating them has a specific, severe consequence:

> If the semantics are bounded, the **meaning of the strategy depends on a
> resource limit.** The strategy is then not a mathematical object; it is an
> artefact of a machine, and two implementations with different limits implement
> different strategies while claiming to implement the same one.

For a specification meant to outlive its implementations by decades, that is
disqualifying.

## 4.2 Verdict

> **Abstractly unbounded semantics; operationally bounded execution; the bound is
> a declared, measurable approximation, and the engine must report when it binds.**

The third clause is new and is not optional. An approximation whose binding rate
is unobservable is indistinguishable from a bug. Recorded as `D-P6`.

---

# 5. THE THREE CANDIDATES, ATTACKED

Before the comparison, the observation that reframes all three:

> **A, B and C are three answers to a question about operators. The gap is in the
> value domain (§17). All three are arguing on the wrong axis.**

They are still assessed as posed, because their failure modes are instructive.

## 5.1 A — Bounded population, maximum size K

**Expressive power.** For Class II, *exact*: `K` = the window length, which the
methodology already bounds. The population is `K` parallel copies of one stream
network, selected by an occupancy flag — standard static unrolling. **Constructive
proof that Class II needs nothing new.**

For Class I, lossy. And the loss is not neutral:

> **The truncation is biased against exactly what the methodology values most.**
> By Corollary 1 the stack is ordered by price, with the *oldest* entries furthest
> from current price. Those are the long-standing, high-timeframe levels — the
> "significant H1 and H4 highs" the brief says start every setup. Dropping the
> stack's bottom discards them first. Dropping the top discards the nearest
> levels instead. **There is no truncation policy that is unbiased**, because the
> stack's order is simultaneously an order of recency and an order of
> significance.

**Determinism** ✓ (order is intrinsic). **Memory** ✓ static. **Replay** ✓.
**Explainability** — degraded in a dangerous way: a rejection caused by truncation
is indistinguishable from a rejection caused by the methodology. **Verification**
✓ finite-state, decidable, the strongest of any option.
**MT5 / Python / C++ / Rust** ✓ all trivially. **Multi-symbol** ✓ (§13).

**Worst case.** `O(K)` per tick, `O(K)` memory. Excellent.

**Failure mode.** Silent. This is its defining defect: when `K` binds, the engine
produces a *well-formed, confident, wrong* answer.

## 5.2 B — A population primitive (a new operator)

**Expressive power** ✓ full.

**Semantic complexity** — the highest of the three, and the cost is concentrated
where it hurts most. A general collection primitive permits arbitrary insertion
and deletion. §1.4 proves the domain never uses that power. Granting it:

- destroys the intrinsic order (an arbitrary collection has none) and therefore
  **reopens `RT-23` item 8**, the determinism gap that the stack structure closes
  for free;
- moves verification from a pushdown fragment to general infinite-state
  (§17.4);
- and admits programs that no methodology could mean.

**Verdict: strictly dominated by the stack discipline.** It pays full price for
power the domain does not use.

## 5.3 C — Reified registry

**Expressive power** ✓ full. And it is what a working programmer would build,
which is why it deserves the most careful attack.

Three independent defects:

1. **The `id` field is redundant** — identity is derived (§2.2). A stored id is a
   second source of truth that can disagree with the first.
2. **The stored lifecycle violates A-2** (§3.1, RT-04).
3. **A map has no intrinsic order**, so it reopens `RT-23` item 8, exactly as B
   does.

**Verdict: the natural choice, and wrong in three independent ways.** Its
naturalness is precisely the risk — it is what the project will drift into if no
decision is taken.

## 5.4 Comparison

| | **A** bounded | **B** primitive | **C** registry | **D** stack (§6) |
|---|---|---|---|---|
| Class I expressive | ✗ lossy | ✓ | ✓ | ✓ |
| Class II expressive | ✓ exact | ✓ | ✓ | ✓ |
| Determinism | ✓ | ✗ needs order decision | ✗ needs order decision | ✓ intrinsic |
| Memory | ✓ static | ✗ unbounded | ✗ unbounded | ✗ unbounded |
| Replay | ✓ | ✓ | ✓ | ✓ |
| Checkpoint format | ✓ trivial | ✗ undefined | ✗ undefined | ✓ the stacks |
| Explainability | ✗ silent truncation | ✓ | ✓ | ✓ |
| Verification | ✓ finite-state | ✗ general | ✗ general | ~ pushdown (§17.4) |
| σ | ✓ | ~ order-dependent | ~ order-dependent | ✓ exact |
| Excess power granted | none | large | large | **none** |
| MT5/Py/C++/Rust | ✓✓✓✓ | ✓✓✓✓ | ✓✓✓✓ | ✓✓✓✓ |

Portability separates none of them, which is worth stating plainly: **the
portability requirement exerts no pressure on this decision.** It was carried
into the analysis as though it would.

---

# 6. THE FOURTH SOLUTION

> **D · Populations as monotone stacks of immutable records, defined as folds over
> the birth/death event stream, with derived identity and derived liveness.**

- **No new operator.** The evolution law (§1.3) is guarded recursion; identity
  (§2.2) is a projection; liveness (§3.1) is stack membership; every quantifier
  over Class II is a bounded fold (§9).
- **One value-domain extension:** a monotone stack of immutable records, with
  exactly three operations — `push`, `pop-prefix-while`, `peek-k`.
- **No excess power.** §1.4 proves these are the only operations the domain
  performs.

What it buys that A, B and C do not:

| Prior finding | Effect |
|---|---|
| `RT-23` item 8 — undefined iteration order | **Resolved** intra-series. Corollary 1 gives a total intrinsic order. |
| `RT-03` — no checkpoint format exists | **Partially resolved.** The checkpoint is the stack family. |
| `MF-7` — total order over the population | **Struck** intra-series; retained only across series (§8.2). |
| `MF-2` — identity | **Struck** (§2.2). |
| `MF-1` — population | **Narrowed** to a value-domain extension for Class I only. |

**This is not a selection.** It is the option the structure theorem produces, and
it is recorded so the decision can be taken against a complete field.

---

# 7. ATTACKING K

## 7.1 Where K belongs

Construct the adversarial case the brief asked for. `K = 10`; the market holds 11
unmitigated FVGs inside the impulse; the 11th is the one whose mitigation would
have invalidated the setup. With `K = 10` the engine emits BUY. With `K = 11` it
emits nothing.

> **`K` changes the extension of the strategy. Therefore `K` is semantic.**

And therefore `K` **cannot** be runtime configuration, cannot be an optimisation,
and cannot be a resource policy — it is a *selector* in the sense of `RT-16`, and
changing it makes historical results incomparable.

## 7.2 The split — and it is the real answer

The argument above assumed `K` can bind. For Class II it cannot:

> For Class II, `K` is determined by a timeout the methodology *already declares*
> (`DEC-035`, `DEC-045`, `DEC-054`). An impulse of at most `W` bars creates at
> most `W−2` FVGs. Setting `K = W−2` makes `K` **provably never binding**, so it
> cannot change any output, so it is **not semantic** — it is architectural.

> For Class I no such structural bound exists. `K` is semantic there, and only an
> empirical measurement over the corpus can say how often it binds.

**Verdict:**

> **`K` is architectural where a structural non-binding proof exists, and semantic
> everywhere else. The same symbol has different status in different entity
> classes, and that must be recorded per class rather than globally.**

Recorded as `D-P8`. It also gives the corpus a concrete new job: measure the
maximum observed stack depth per timeframe per side. That measurement is not
blocked by anything.

---

# 8. ORDER

## 8.1 Intra-series: semantic and intrinsic

By Corollary 1, price order and creation order coincide on a single series. So:

| Query | Resolution |
|---|---|
| "the most recent FVG" | top of stack — `O(1)` |
| "the nearest unmitigated FVG below price" | top of stack — the same element |
| "all FVGs created after liquidity was taken" | the prefix born after that instant — contiguous |
| "the first valid FVG after the MSS" | the deepest element of that prefix |
| "any FVG satisfying X" | §9 |

No tiebreak is ever required, and no ordering convention is invented. **Order is
not an implementation detail here; it is a theorem.**

## 8.2 Inter-series: a genuine decision

An H1 pool and an M5 pool at nearby prices, or a buy-side and a sell-side pool,
have **no intrinsic order**. Any merged view needs a declared total order across
`(timeframe, side, symbol)`.

`MF-7` therefore survives, but only in this reduced scope. Recorded as `D-P4`.

---

# 9. QUANTIFICATION

None of `EXISTS / FORALL / FIRST / LAST / COUNT / ANY / ALL / NONE / MIN / MAX`
needs to be added as an operator. What they need is different per class.

## 9.1 Over Class II — all derivable

A bounded population is `K` static stream copies. Every listed quantifier is a
**bounded fold** over `K` lifted comparisons — Lift and Delay only. Constructively
derivable, `O(K)` per tick, no extension. ∎

## 9.2 Over Class I — the monotonicity criterion

The stack's order makes several queries free, and one class of query expensive:

| Query | Cost | Why |
|---|---|---|
| `LAST` / top | `O(1)` | peek |
| `MIN`, `MAX` | `O(1)` | **the stack is sorted by price** — the extremes are its two ends |
| `COUNT` | `O(1)` amortised | a counter maintained by the same fold |
| `EXISTS p` where `p` is **monotone in the stack order** | `O(1)` | a monotone predicate holds on a prefix; testing the top decides it |
| `FIRST` / bottom, `EXISTS p` for **non-monotone** `p`, `FORALL` non-monotone | `O(depth)` | requires traversal |

> **The required semantic machinery is not a new quantifier. It is a restriction:
> must every predicate quantified over a Class I population be monotone in that
> population's order?**

If yes, the engine is `O(1)` per tick over unbounded populations and stays in the
tractable fragment. If no, per-tick work is unbounded in the stack depth and both
the real-time and the verification story change.

This is a **language design constraint that no previous phase considered**, and it
is constitutional. Recorded as `D-P2`.

## 9.3 The per-tick work problem

A single penetration can pop an unbounded prefix. That is **unbounded work in one
instant**, which violates the synchronous hypothesis of bounded reaction time.

Amortised, it is fine — total pops ≤ total pushes, so the amortised cost is
`O(1)` per tick. But amortised is not the same guarantee as bounded, and the
difference matters for a real-time detector.

> The engine is **amortised-bounded, not hard-real-time-bounded.** That should be
> stated rather than discovered. Recorded as `D-P5`.

---

# 10. POPULATION AND CAUSALITY

## 10.1 The brief's trace

Births and deaths are each determined by the data prefix at their instant.
`Pop(t)` is a fold over them, so `Pop(t)` is a function of the prefix. Prefix
invariance (`P-2`) therefore extends to populations unchanged, and the trace
`Pop(t₁) … Pop(t₄)` is reconstructible with no future information. ✓

## 10.2 The failure the trace hides

Births carry a **knowledge delay** — a pivot confirms `m` bars after it occurs.
So there are two populations, not one:

```
Pop_occurred(t) = { e : birth_occurred(e) ≤ t, not yet dead }
Pop_known(t)    = { e : birth_known(e)    ≤ t, not yet known dead }
```

and `Pop_known(t) ⊆ Pop_occurred(t)`, strictly, for `m > 0`.

> **"There exists an unmitigated FVG" is ambiguous between the two, and the corpus
> has never said which.** Only `Pop_known` is causal. `Pop_occurred` is what a
> trader sees on a finished chart, which is why the ambiguity has survived — the
> two coincide in hindsight and diverge in real time.

Worse, they diverge *asymmetrically*: an entity can be dead in `Pop_occurred` and
still live in `Pop_known`, so a rule quantifying over the wrong one can be
satisfied by an entity that has already been destroyed.

This is `RT-07`/`RT-08` reappearing at the population layer, where nobody looked.
Constitutional. Recorded as `D-P3`.

---

# 11. POPULATION AND σ

## 11.1 The test

| Aspect | Under σ |
|---|---|
| **Identity** | `σ(kind, symbol, tf, side, t) = (σκ, symbol, tf, ¬side, t)`. Bijective; the birth instant is untouched. ✓ |
| **Creation** | Births are crossings; σ preserves crossings (RT-18). ✓ |
| **Mitigation / death** | Same. ✓ |
| **Ordering** | Worked through concretely: buy-side unswept pools `{110@t₁, 105@t₂, 100@t₃}` map under `σ` with `c=200` to `{90, 95, 100}`, which newest-first reads `100, 95, 90` — exactly the form of an unswept sell-side stack in an uptrend. **The staircase maps to the staircase.** ✓ |
| **Lifecycle** | Derived from crossings. ✓ |
| **Selection** ("nearest", "first") | Defined by stack position, which is preserved. ✓ |

> **Verdict: σ lifts to populations exactly, under the same three conditions as
> RT-18.**

## 11.2 Why this depends on identity being derived

> If identity were generated by a fresh-name counter, σ would **not** commute.
> The mirrored dataset produces births in a different global interleaving across
> series, so the counter assigns different numbers, and `σ(id(e)) ≠ id(σ(e))`.
> The mirror test would fail on identity while the logic was perfectly correct —
> an untraceable class of false alarm.

Derived identity is therefore not merely economical. **It is a precondition for
σ over populations.** §2 and §11 are load-bearing for each other, which is the
strongest internal evidence in this document that both are right.

---

# 12. MULTI-TIMEFRAME

## 12.1 Coexistence

The brief's scenario — 3 H4 levels, 7 H1, 11 M15, 23 M5, 47 M1 — is **one stack
family**, not one population:

```
stacks  =  symbol × timeframe × side × kind
```

The *number* of stacks is static; only their *depths* are dynamic. That is a
much weaker requirement than a dynamic set of populations, and it means multi-
timeframe adds **no new semantic power** beyond §6.

## 12.2 Is timeframe part of identity?

**Yes**, and necessarily: `series = (symbol, timeframe, side)` is a component of
the key, and the confirmation delays, significance and lifetimes differ per
timeframe. Two entities derived from the same bar on different timeframes are
different entities.

## 12.3 The same phenomenon produces several entities

**Yes — and it is correct, not a duplication bug.** One physical resting-order
cluster may yield an H4 pool and an M15 pool. They are distinct entities of one
phenomenon.

But there is a consequence nobody has drawn:

> A single physical sweep sweeps **every** entity representing that phenomenon,
> across timeframes, and therefore generates **several setups from one market
> event.**

That is a direct source of the setup multiplicity in §14 and of `RT-02`. It also
recasts `DEC-019` (multi-timeframe duplicate pools): it is not an identity
question — identity is settled — it is a **presentation and policy** question at
the decision layer (§15).

---

# 13. FUTURE MULTI-SYMBOL

The population model is symbol-parametric by construction: `symbol` is a component
of `series`. Cross-symbol reasoning is a comparison of `Pop_EURUSD(t)` and
`Pop_GBPUSD(t)` at a shared `t`.

> **Verdict: no redesign required — conditional on `RT-12`** (the exogenous
> clock). Without it there is no shared `t` and the comparison is not expressible.

One requirement sharpens. Entities on different symbols have **different knowledge
delays** (different confirmation widths, different missing-bar patterns). A
cross-symbol comparison must therefore be taken at a common lag, which promotes
`MF-5` (availability-lag typing) from *desirable* to **required for SMT**.

Nothing in the population model needs to change. The two conditions are both
already on the books.

---

# 14. SETUP MULTIPLICITY

Constructed state: bullish setups A and B and bearish setup C, all valid,
simultaneously — which §12.3 shows is not exotic but *routine*, since one physical
sweep produces one setup per timeframe representing it.

| Model | Semantic consistency | Information loss | Explainability | Determinism | Alerting | API / UI | Testing |
|---|---|---|---|---|---|---|---|
| **1 · One global output** | Requires a total order over setups ⇒ requires `DEC-050` graded | **Total** for all but one | Poor — cannot say why the others lost | ✓ if order total | simple | simple | weak: cannot test the suppressed setups |
| **2 · One result per setup** | ✓ | none | ✓ per setup | ✓ | needs a policy layer | output is a dynamic family | ✓ each setup independently testable |
| **3 · Collection** | ✓ | none | ✓ | ✗ needs an order for the collection | needs policy | collection type in the contract | ✓ |
| **4 · Primary + secondaries** | Requires the total order again | none | ✓ | ✓ if order total | good | moderate | ✓ |
| **5 · Stream of opportunity events** | ✓ | none | ✓ — each event carries its own witness | ✓ **order is temporal, hence intrinsic** | natural | **already the kernel's output type** | ✓ replayable directly |

Two observations that the table makes visible:

- **Models 1 and 4 are not output formats. They are requests for `DEC-050`.**
  Any "the best one" presupposes an order over setups, which is the graded value
  domain. Choosing them decides `DEC-050` by implication — which would be
  deciding the highest-fanout question in the system as a side effect of an output
  format.
- **Model 5 is the only model whose output type already exists in the kernel.**
  A stream of events needs no collection in the contract, no ordering decision
  (time orders it), and no selection policy at the engine level.

Model 5 answers *"what happened"*. A trader also needs *"what is true now"*, which
is Model 2's queryable state. **They are not competitors** — which is §15.

---

# 15. ENGINE STATE VERSUS DECISION

This separation is necessary, and it dissolves `RT-02`.

```
ENGINE          a population of setups, liveness derived        set-valued, no ternary
   ↓
DECISION        a selection policy: explicit, versioned,        policy, not semantics
                trader-owned
   ↓
PRESENTATION    at most one opportunity at a time               ternary
```

`RT-02` proved that *ternary output* + *multi-pool structure* + *no grading*
cannot all hold. The proof is sound and the conclusion was wrong, because it
assumed all three claims live at one layer. They do not:

> **The ternary contract is correct — at the presentation layer. The engine layer
> was never ternary. The brief's requirement was not mistaken; it was filed one
> layer too low.**

> **`RT-02` is therefore downgraded from CRITICAL-unsatisfiable to a layering
> correction.**

The residual question — what to do when two opposite setups are simultaneously
valid — does not disappear. It **moves** from being a semantic contradiction with
no valid answer to being an explicit, versioned, trader-owned policy with several
valid answers. That is the difference between a broken foundation and an open
decision.

It also relocates several open items: `DEC-019` (duplicate pools), `DEC-027` (bias
conflict), `DEC-056` (concurrency), `DEC-057` (alert repetition) are all **decision
layer**, not engine layer. They have been sitting in the wrong stratum.

---

# 16. MEMORY

| Memory kind | Needed? | In the kernel? |
|---|---|---|
| **Current state** | ✓ | ✓ Delay registers |
| **Historical state**, bounded lookback | ✓ | ✓ `n` delays |
| **Derived state** (folds, counters, running extrema) | ✓ | ✓ guarded recursion |
| **Event history**, unbounded | **✗ not required** — every rule is a fold, and folds do not retain their inputs | n/a |
| **Entity history** — Class II | ✓ | ✓ static unrolling |
| **Entity history** — Class I | ✓ | **✗ the only gap** |

> **Explicit persistent state is unavoidable for exactly one thing: Class I entity
> retention.** Everything else is Delay plus guarded recursion.

Note the third row from the bottom: **unbounded event history is not required.**
That is a real saving — an event-sourced *definition* (§1.2) does not imply
event-sourced *storage*. The fold's accumulator is the stack, and the stack is
`O(depth)`, not `O(history)`.

---

# 17. SYNCHRONOUS DATAFLOW — THE FORMAL ATTACK

## 17.1 The impossibility

> **Proposition.** Let `P` be a synchronous dataflow program over a scalar value
> domain, with a finite set `D` of delay elements, `|D| = n`, each holding one
> value. Let an entity require `d ≥ 1` fields to be distinguished from another.
> Then `P` can hold at most `⌊n/d⌋` pairwise-distinguishable entities
> simultaneously.
>
> **Proof.** The state of `P` at any instant is exactly the tuple of its delay
> registers; nothing else persists between instants. Two entities are
> distinguishable only if the state differs when they differ, which requires at
> least `d` registers dedicated to each. `n` and `d` are fixed by the program
> text. ∎

> **Corollary.** No SDF program over a scalar value domain expresses the Class I
> population.
>
> **Proof (constructive).** Consider a monotone downtrend of `N` legs, each
> establishing a lower high that is never subsequently exceeded. By the Theorem in
> §1.4, all `N` pools are unswept and pairwise distinct. `N` is unbounded and
> chosen after the program is fixed, so `N > ⌊n/d⌋` for some run. ∎

RT-01 is confirmed — for Class I, and only for Class I.

## 17.2 The escape, and why it is the right one

The Proposition quantifies over *registers holding scalars*. It says nothing about
what a register may hold. If the value domain includes an unbounded carrier, one
register holds the whole population.

> **The missing capability is in the value domain `V`, not in the operator set.**

This is why options A, B and C all miss: each proposes an *operator-level* change
(bound the unrolling / add a collection former / add a registry) to a
*type-level* gap.

What the extension costs, precisely — and it is a short list:

| Property | Survives an unbounded carrier? |
|---|---|
| Causality | ✓ — the law is still Delay-guarded |
| Determinism | ✓ — the stack order is intrinsic |
| Replayability | ✓ — same fold; checkpoint = the stacks |
| Explainability | ✓ — unaffected |
| σ | ✓ — §11 |
| Portability | ✓ — a stack exists in every target |
| **Static memory boundedness** | ✗ **lost** |
| **Finite-state model checking** | ✗ **lost** — see §17.4 |

> **Semantic unboundedness costs exactly two properties and nothing else.** Both
> are verification and resource properties; none is a correctness property.
> That is the cleanest statement of the trade available, and it is the decision
> the project must actually take.

## 17.3 What is derivable once the carrier exists

Everything. The evolution law is guarded recursion; identity is a projection;
liveness is membership; Class II quantifiers are bounded folds; Class I `MIN`,
`MAX`, `COUNT` and monotone `EXISTS` are `O(1)` by Corollary 1. **No operator is
added.**

## 17.4 The new hard problem — and it is the deepest risk in the project

A single stack over a finite alphabet is a **pushdown system**, and reachability
and LTL model checking of pushdown systems are decidable (Bouajjani–Esparza–Maler).
Prices lie on a finite tick grid within a bounded range, so the alphabet is finite
and the fragment applies.

That is the good news, and it is where a careless analysis would stop.

> **Two independent stacks are Turing-complete.** A two-counter machine is
> simulable, so reachability becomes undecidable. The system has **one stack per
> symbol × timeframe × side × kind**, and the methodology's rules relate them —
> *"an FVG inside the impulse following a sweep of a pool"* touches at least two
> stacks at once.

So the decidability recovered in the single-stack case is **not automatically
available in the real system.**

Known escapes exist — bounded context switching (Qadeer–Rehof) yields decidability
for multi-stack systems under a bounded number of interactions, and our rules
appear to touch only a bounded number of elements near each stack's top. That
**suggests** the system sits in a decidable fragment. It is not proved here, and I
will not assert it.

> **Open problem `D-P9`: does the rule language restrict inter-stack interaction
> enough to remain decidable?** If yes, the project keeps machine-checkable
> verification over unbounded populations — a genuinely rare property for a
> trading system. If no, verification becomes deductive rather than automatic, and
> the "formally verifiable" goal must be restated.

This is now the deepest open technical risk in the corpus, and it did not exist
before this phase — it was created by discovering the stack structure, which is
what made the question precise enough to ask.

---

# 18. THE REVISED KERNEL

**Operators — unchanged. No addition survives scrutiny.**

| Operator | Necessity | Without it |
|---|---|---|
| `Series` (with `⊥`) | the only input | nothing expressible |
| `Lift` | all arithmetic, comparison, logic | no computation |
| `Delay` | the only memory; the guard for recursion | no state, no edges, no windows |
| `Recursion` (guarded) | running aggregates, the population fold, timers, lifecycle | Class I and all running state inexpressible |

**Value domain — one extension, with a necessity proof.**

| Extension | Why necessary | What becomes impossible without it | What it enables |
|---|---|---|---|
| **Monotone stack of immutable records** (`push`, `pop-prefix-while`, `peek-k`) | §17.1 Corollary — the Class I population is provably unbounded | Long-horizon liquidity levels — the "significant H1/H4 highs" the brief makes the origin of every setup. `K`-truncation drops them *first* (§5.1) | Unbounded Class I with intrinsic order, a known checkpoint format, `O(1)` `MIN`/`MAX`/`COUNT`, exact σ |

**Derived, not primitive** — each with its proof above: identity (§2.2), liveness
(§3.1), order (§1.4 Cor. 1), all Class II quantifiers (§9.1), Class I `MIN`/`MAX`/
`COUNT`/monotone-`EXISTS` (§9.2), the whole population evolution law (§1.3).

**A constraint, not a primitive:** predicates quantified over Class I populations
should be monotone in the stack order (`D-P2`). This is the only genuinely new
*restriction* the analysis produces, and it is what keeps the system tractable.

> **Final shape: four operators, one value-domain constructor, one monotonicity
> restriction.** Smaller than "add populations", larger than "it already works",
> and every element carries a proof.

---

# 19. INVALIDATED CONCLUSIONS FROM REDTEAM-001

| Prior claim | Status |
|---|---|
| `RT-01` — the kernel cannot express dynamic populations | **Narrowed.** True for Class I only. Class II — most of the methodology's multiplicity — is expressible today by static unrolling. |
| `RT-11` — identity is a genuine primitive | **Refuted** (§2.2). Derived from a domain key. |
| `MF-1` — population capability | **Restated** as a value-domain extension, not an operator. |
| `MF-2` — identity | **Struck.** |
| `MF-7` — total order over the population | **Struck intra-series** (theorem); retained across series only (`D-P4`). |
| `RT-23` item 8 — nondeterministic iteration order | **Resolved** intra-series by Corollary 1. |
| `RT-03` — no checkpoint format exists | **Partially resolved.** The format is the stack family. The maximum-lifetime question remains open. |
| `RT-02` — the ternary contract is unsatisfiable | **Downgraded** to a layering correction (§15). The proof was sound; the layer assignment was not. |
| `RT-01`'s premise that A/B/C are the option space | **Rejected.** All three address operators; the gap is in the value domain. |
| REDTEAM-001 §11.2 "populations + identity are the same decision seen twice" | **False.** They are separable, and one of them dissolves. |

Two of RT-01's demanded foundations do not exist. This is the second consecutive
phase in which the previous phase's headline finding was partly an artefact of its
own error — which is the process working, and also a standing reason not to treat
this document as settled either.

---

# 20. NEW DECISIONS DISCOVERED

| ID | Decision | Class | Why it matters |
|---|---|---|---|
| **D-P1** | Semantically unbounded populations with declared operational bounds? | **Constitutional** | Decides whether the strategy is a mathematical object or an artefact of a machine (§4) |
| **D-P2** | Must predicates quantified over Class I populations be monotone in stack order? | **Constitutional** | Decides `O(1)` vs `O(depth)` per tick, and the verification fragment (§9.2) |
| **D-P3** | Do rules quantify over `Pop_known` or `Pop_occurred`? | **Constitutional** | Only one is causal; they coincide in hindsight and diverge live (§10.2) |
| **D-P4** | Cross-series total order for merged population views | Structural | The residue of `MF-7` (§8.2) |
| **D-P5** | Hard or amortised per-tick work bound? | Structural | A sweep pops an unbounded prefix (§9.3) |
| **D-P6** | Must the engine report when an operational bound binds? | Structural | An unobservable approximation is indistinguishable from a bug (§4.2) |
| **D-P7** | Does entity identity include the parameter-set version? | Structural | Ids are names within a run, not global names (§2.4) |
| **D-P8** | Is `K` semantic or architectural — per entity class? | Structural | Architectural where a non-binding proof exists, semantic otherwise (§7.2) |
| **D-P9** | Does the rule language keep inter-stack interaction inside a decidable fragment? | **Open problem** | Determines whether machine-checkable verification survives (§17.4) |

Register: **56 → 65.** Three constitutional, five structural, one open research
question.

---

# 21. DEPENDENCY IMPLICATIONS

Not a rewrite of `DEP-001` — the specific edges that change.

**New upstream root.** `D-P1` sits above the kernel's value domain and therefore
above every Class I concept. In the corrected graph it joins `H-01`/`DEC-050` at
the top of Σ0.

**Stratum reassignments.** `DEC-019`, `DEC-027`, `DEC-056`, `DEC-057` move from
engine semantics to the **decision layer** (§15). They were filed in Σ4/Σ5 as
though they were definitional; they are policy.

**Edges removed.** `K-ID → K-POP` (identity is derived, §2.2). `MF-7`'s edges
intra-series.

**Edges added.** `D-P1 → K-STACK`; `K-STACK → C-LIQ, C-FVG, C-LIFE`;
`D-P2 → K-STACK`; `D-P3 → DEC-018, DEC-038` (both death predicates);
`D-P8 → DEC-035, DEC-045, DEC-054` (the timeouts that make Class II bounded);
`RT-08 → D-P3`.

**Fanout change.** `DEC-035`, `DEC-045` and `DEC-054` gain weight they did not
have: they are the timeouts that keep Class II bounded, so they are what makes
most of the methodology expressible without any extension. Three items previously
filed as parametric timeouts are load-bearing for expressiveness.

The interactive graph has been updated from the dataset accordingly.

---

# 22. WHAT REMAINS TRUE

- The structure theorem (§1.4) and the identity theorem (§2.2) are proved from the
  domain, not assumed. If either is wrong, most of this document falls — and both
  are stated precisely enough to be attacked, which is the point.
- σ survives populations (§11), causality survives populations (§10.1), replay
  survives populations (§10.1), portability is neutral (§5.4).
- The methodology needs **less** new machinery than RT-01 claimed, and the
  machinery it needs is **more specific**: not "collections", but one monotone
  stack with three operations.

**This phase stops here.** Nothing above is resolved. `D-P1`, `D-P2` and `D-P3`
are the next conversation, and `D-P9` may need an outside proof.
