# PROJECT TRADER — Specification Corpus

**Scope of this corpus:** the functional specification of a trading *opportunity
detection* engine. Not an EA, not a bot, not an indicator library.

> **Status — superseded, 2026-08-08.** This file's original header ("Foundation
> Phase, iteration 1. No code exists and none is authorised") is no longer true
> and is kept only so the change is visible. A DEMO-only measurement instrument
> now exists and has been run against real history. **It is not the engine this
> corpus specifies** — 8 of the methodology's stages are still `BLOCKED` and it
> tests `PATTERN → TRADE` only.
>
> Current state, read in this order:
> `DEC-LOCK-001` (economic layer, locked 2026-08-07) →
> `CHECKPOINT-001` (V1 frozen + defects found) →
> `CHECKPOINT-002` (stop padding X=5, time-adjacency locked 2026-08-08).
> Runs and raw evidence, SHA-256 sealed: `spec/experiments/mt5/raw/`.
> Every economic figure carries the mandatory label
> **ENGINEERING VALIDATION BACKTEST — NOT A PROFITABILITY CLAIM.**

---

## 0. How to read this

Read in this order. Each document assumes the previous ones.

| ID | Document | What it settles |
|----|----------|-----------------|
| `SPEC-000` | [Foundations](spec/SPEC-000-foundations.md) | The rules the specification itself must obey: admissibility of a definition, time & causality, data model, units, parameter discipline, layering. |
| `SPEC-100` | [Ontology](spec/SPEC-100-ontology.md) | Every concept in the methodology, one card each: definition, purpose, inputs, outputs, dependencies, assumptions, ambiguities, objective interpretations, edge cases, mathematical models. |
| `SPEC-200` | [Setup Lifecycle](spec/SPEC-200-lifecycle.md) | The setup as a state machine: states, guards, invalidation, expiry, deduplication, verdict emission. |
| `SPEC-300` | [Formal Vocabulary](spec/SPEC-300-vocabulary.md) | The event/entity language. Signatures, emission conditions, knowledge times, invariants. |
| `CRIT-001` | [Critique](spec/CRIT-001-contradictions.md) | Contradictions, circularities and risks found **inside the methodology as stated**. Read this one even if you read nothing else. |
| `DEP-001` | [Dependency Analysis](spec/DEP-001-dependency-analysis.md) | The specification analysed as a formal system: dependency graph, 7 cycles, 20 hidden decisions, the critical path, and the reduction of the methodology to a 4-primitive kernel. **Supersedes the tiering in `DEC-001`.** |
| `DEC-001` | [Decision Register](spec/DEC-001-open-decisions.md) | Every question that must be answered by the trader before the specification can close. Numbered, with options and consequences. |
| `VAL-001` | [Falsifiability Plan](spec/VAL-001-falsifiability.md) | How we will ever know the engine is correct. Includes the labelled-corpus requirement, which is the project's critical path. |

---

## 1. The one-paragraph summary of where we stand

*(Revised after `DEP-001`. The Phase 1 summary was too coarse.)*

The methodology's **structure** is not merely coherent — it reduces to **four
primitives and two combinators**, and that kernel absorbs every capability on the
20-year roadmap (Order Blocks, SMT, multi-symbol, replay, AI explanation) without
extension. Its **semantic layer does not exist yet**: six of the nine
constitutional decisions were never written down, and the highest-fanout decision
in the entire system was filed as low-priority output polish. Its **content** —
*significant*, *impulsive*, *clean*, *reaction*, *accumulation* — is genuinely
empty, but that is the *last* layer to fill, not the first. And the project is
**not blocked on the trader**: half the critical path is formal-semantic work
that can begin immediately.

## 2. The three things that must happen next, in order

1. **Settle the semantic layer (Σ0).** `DEP-001` §9, phase P3. Six decisions
   about what a predicate *means* — value domain, negation, `UNKNOWN`
   propagation, window typing, rounding, directional duality. Only one of them
   (`DEC-050`) needs the trader. Everything else in the corpus rests on these,
   and every concept written before they are settled must later be rechecked by
   hand.
2. **Build the labelled corpus** (`VAL-001` §2). Nothing here can be validated
   without a set of charts where *you* marked the setups you would take and the
   ones you would refuse, before seeing any engine output. Six open decisions
   cannot be answered by introspection at all — only by measuring your own
   labels. Blocked by nothing; can start today.
3. **Cut the three cycles** (`DEC-025`, `DEC-029`, `DEC-040`). `DEP-001` §9,
   phase P7 — the highest-value conversation to have with the trader.

**Do not** work through `DEC-001` in tier order. `DEP-001` §5.2 corrects that
tiering: 6 of the 13 Tier A items are architecturally light, and 3 Tier C items
plus 6 hidden decisions rank above all of them.

## 3. Non-negotiables established in this corpus

- **A-1 Causality.** No fact may be emitted at a time earlier than the first
  instant at which it is decidable from data available at that instant.
  Mechanically testable (`VAL-001` §4, prefix invariance).
- **A-2 No repainting.** Facts are immutable once emitted. A fact that could
  change is not a fact; it is a hypothesis and must be modelled as one.
- **A-3 Unknown is not False.** Three-valued logic throughout. Any undecidable
  input yields `NoOpportunity` with a stated reason, never a guess.
- **A-4 No literal constants.** Every threshold is a named parameter in a
  versioned `ParameterSet`, with a written justification. A number without a
  justification is a defect, not a value.
- **A-5 No opaque scores.** A rejection must name the predicate that failed.
  Weighted scoring is forbidden at the gating layer.
- **A-6 Broker independence.** Higher timeframes are derived by us from M1 with a
  declared anchor, never taken from the platform, because platform H1/H4
  boundaries are broker- and DST-dependent.

> **Caveat added by `DEP-001`.** A-3 and A-5 presuppose a value domain that
> `DEC-050` has not yet fixed. If the answer is "graded output", both are
> reopened. SPEC-000 currently *assumes* an answer to the highest-fanout open
> decision in the system — which is why the semantic layer needs a document of
> its own, above SPEC-000, before any further concept text is written.

## 4. What this corpus deliberately does not contain

Order Blocks, Rejection Blocks, SMT, execution, sizing, risk, trade management,
architecture, module design, language choice, data structures, and code.
All out of scope by instruction, and none of them are needed to close the
specification.
