# MT5-FORMAL-001 — Formal × MT5 Compatibility

*Parts XX–XXII. Where the formal model and MetaTrader 5 actually meet, and the
answer to the phase's final question.*

Classification: **GREEN** directly representable and causally observable ·
**YELLOW** representable with explicit adapter semantics · **RED** cannot be
represented reliably from MT5 information · **UNKNOWN** requires an experiment.

Nothing here rests on an observation; see `experiments/mt5/README.md` §1.

---

# 1. Compatibility matrix

| Property | Class | Basis | Adapter required |
|---|---|---|---|
| **Causality** (A-1) | **GREEN** | MT5 hands out no future data; every leak found (`MT5-CAP-001` §3) is an implementation error | none — but the recalculation-invariance gate is mandatory |
| **Determinism** | **YELLOW** | Deterministic given fixed inputs, but `time_msc` collisions, unsynchronised reads and mode-dependent ask all break it silently | `(time_msc, seq)` ordering; a sync barrier; a declared tester mode |
| **Replay** | **YELLOW** | Works, but MT5 is not a system of record: bars re-download, specs drift, broker unrecorded | an **external immutable data store** — `MT5-EXP-001` §3.4 |
| **Prefix invariance** | **GREEN** | Testable directly, and MT5 supplies the adversary (full recalculation) | none |
| **Population semantics** | **GREEN** | Stacks of records are ordinary MQL5 arrays/structs; depth is small (Conjecture 1.5) | none |
| **Identity** | **YELLOW** | The key is derivable, but `birth_instant` is ambiguous between nominal bar time and determinability (`OPEN 6.4`), and these differ by an unbounded amount in MT5 | pick one and state it |
| **Lifecycle** | **GREEN** | Births/deaths are crossings; liveness is stack membership; nothing stored | none |
| **σ symmetry** | **YELLOW** | Exact on bar data (bid-only mirror). The `(bid, ask)` involution `RT-18` requires **needs tick history** | tick history, or σ restricted to bar semantics |
| **Multi-timeframe** | **YELLOW** | HTF closure *is* knowable from the base clock — but only at the next tick, up to 4 h late (`MT5-CAP-001` §2.2) | `D-M1` must be decided |
| **Multi-symbol readiness** | **YELLOW** | Possible via `OnTimer` + `TimeTradeServer`; **not** via `OnTick`, which is chart-symbol only | the exogenous clock (MF-6), which MT5 does not provide natively |
| **Missing-data semantics** | **YELLOW** | Four of five distinctions exposed (`MT5-EXP-001` §1); NOT-APPLICABLE is missing | session + **holiday** calendar — `D-M2` |
| **Checkpointing** | **YELLOW** | Files only; globals are doubles; tester agents have separate sandboxes | file-based checkpoint + `OnDeinit` reason handling |
| **Alert generation** | **GREEN** | `Alert`/`SendNotification`/`SendMail`; suppressed in tester, which is correct | none |
| **Resource bounds** | **GREEN** | Stacks are small; `K > D(d)` makes the implementation *exact*, not approximate (`REDTEAM-003` Thm 1.3) | binding report (`D-P6`) |
| **Broker-independent HTF aggregation** (A-6) | **RED** | MT5 exposes **no** broker timezone or DST schedule; historical UTC cannot be reconstructed from MT5 alone | external timezone/DST model — `D-M6` |
| **Intrabar order** | **RED for history, YELLOW live** | Faithful only where real tick history exists; fabricated in generated tester modes | tick history, or forbid intrabar rules |
| **Historical ask / spread-aware sweep** | **RED beyond tick history** | Bars carry no ask; `MqlRates.spread` semantics unverified | tick history — `D-M4`; **UNKNOWN** pending `E-MT5-006` |
| **`MqlRates.spread` meaning** | **UNKNOWN** | Underdocumented | `E-MT5-006` |
| **Tester `CopyTicks` bounding** | **UNKNOWN** | A leak here would be invisible to inspection | explicit test |
| **Cold-start sync latency** | **UNKNOWN** | Determines whether warm-up is a state or a retry | `E-MT5-004` |

**Tally: 5 GREEN · 9 YELLOW · 3 RED · 3 UNKNOWN.**

---

# 2. Part XXII classification — the mandatory distinction

| # | Category | Items |
|---|---|---|
| **1** | **Impossible in MT5** | Broker timezone/DST recovery for historical data. Faithful intrabar order before real-tick history begins. Historical ask where tick history is absent. |
| **2** | **Possible but expensive** | Tick-level replay (storage, time, shorter corpus). Multi-symbol via polling. Full-history recalculation-invariance testing. |
| **3** | **Possible with an adapter** | Exogenous clock (`OnTimer` + `TimeTradeServer`). `⊥` semantics (wrap every copy, map `-1` to `⊥`). Checkpointing (files). Session/holiday calendar (external). Immutable data store. Total tick order (`time_msc`, seq). |
| **4** | **Possible natively** | Bar/tick access, populations as arrays, crossings, stack operations, alerting, closed-bar HTF reads, sync detection, `OnDeinit` reasons. |
| **5** | **Possible only historically, not live** | Nothing found. Notably, tick history is the *reverse* case. |
| **6** | **Possible live but not reproducibly in tester** | Ask-based penetration where the tester models spread. Anything in a **Service** (F7 — Services do not run in the tester). Push notifications. |

> **Category 6 is the dangerous one**, and it has exactly two members that matter:
> the ask-based sweep and the Service host. Both would produce a detector that
> works live and cannot be validated — the worst possible failure shape for a
> project whose entire method is falsification.

---

# 3. The intersection — the actual design space

```
   FORMAL LANGUAGE ∩ MT5 OBSERVABLE ∩ MT5 EXECUTION ∩ REAL-TIME CAUSALITY
```

Everything in the intersection, stated positively:

**Data.** Bid-based (or Last-based) OHLC on a base timeframe, plus tick bid/ask
where and only where the broker supplies it. Symbol metadata read at run time and
frozen with the run.

**Time.** One exogenous base clock from `TimeTradeServer()`, driven by a timer,
not by ticks. Every fact stamped at the instant of determinability. HTF facts read
at shift ≥ 1 only. Bar closure detected by transition, never assumed at the
nominal boundary.

**Values.** Scalars over the symbol's tick grid, plus `⊥` — supplied natively by
MT5's not-synchronised signalling.

**Operators.** Lift, Delay, guarded recursion. All expressible in MQL5 without
ceremony.

**Populations.** Monotone stacks of immutable records, one family per
`symbol × timeframe × side × kind`, bounded at runtime by `K` with a binding
report, semantically unbounded.

**Predicates.** Arbitrary at birth; order-contiguous at query time
(`REDTEAM-003` §2.3).

**Output.** A set-valued engine, a versioned selection policy, a ternary
presentation.

**Host.** Something that runs in both the live terminal and the Strategy Tester —
which, per F7, excludes a Service as the *only* host.

Everything **outside** the intersection, and therefore not admissible into the
strategy specification until an adapter is defined:

1. Any rule requiring broker-independent absolute time over history.
2. Any rule requiring intrabar order outside real-tick history.
3. Any rule requiring historical ask outside tick history.
4. Any rule requiring HTF information before the HTF bar is knowably closed —
   unless `D-M1` explicitly admits forming-bar context and accepts the `A-2`
   consequence.
5. Any query-time predicate that is not order-contiguous.
6. Anything that runs only in a Service.

---

# 4. Adapter semantic boundaries

Where an adapter is required, its boundary must be stated, or it silently becomes
part of the strategy.

| Adapter | Input | Output | Boundary — what it may **not** do |
|---|---|---|---|
| **Clock** | `TimeTradeServer()`, timer events | a total order of instants shared by all symbols | may not invent instants where no session exists; may not reorder ticks |
| **⊥ wrapper** | `CopyRates`/`CopyTicks` returns | value or `⊥` | may not substitute a default; may not retry silently within one instant |
| **Calendar** | sessions + an external holiday source | market-open predicate | may not infer closure from absence of ticks — that is the thing it exists to disambiguate |
| **Timezone** | external DST model per broker | server-time ↔ UTC | may not guess from data; an unknown offset yields `⊥`, not an estimate |
| **Spread** | ticks where available | ask series or `⊥` | may **not** model a spread where none was recorded — that would make live and tester different engines |
| **Data store** | MT5 exports | immutable snapshots | may not re-fetch on read |

The spread adapter's constraint is the one most likely to be violated for
convenience, and it is precisely the violation that produces a detector which
cannot be falsified.

---

# 5. The final question

> **What is the smallest computational model that is both formally justified and
> actually observable/executable in MetaTrader 5 under causal real-time
> conditions?**

**Answer:**

> **Guarded synchronous dataflow over a `⊥`-carrying tick-grid value domain,
> extended with monotone stacks of immutable records, driven by an exogenous
> clock, evaluated at base-timeframe bar closes.**
>
> Four operators — `Series`, `Lift`, `Delay`, guarded `Recursion`.
> One value-domain constructor — the monotone stack.
> One discipline — arbitrary birth filters, order-contiguous query predicates.
> One adapter layer — clock, `⊥`, calendar, timezone, spread, data store.

Nothing smaller works: remove the stack and the long-horizon liquidity levels the
methodology is built on become inexpressible (`REDTEAM-002` §17.1); remove `⊥` and
missing data silently satisfies negative conditions (`RT-15`); remove the
exogenous clock and multi-symbol requires a rewrite (`RT-12`); remove guarded
recursion and no running state exists.

Nothing larger is justified: every richer structure attempted — general
collections, registries, fresh-name identity — was shown to grant power the domain
never uses, at the cost of determinism or decidability.

## 5.1 Where the ideal model cannot be faithfully realised

Three places, all RED in §1, none repairable inside MT5:

1. **Absolute time.** The formal model wants instants on a universal timeline.
   MT5 gives server time with an unknown, DST-varying offset and no historical
   record of it. **Consequence: `A-6` "broker independence" is unachievable as
   written and must be restated as "anchor independence given an external
   timezone model".**

2. **Intrabar order before real-tick history.** The formal model permits any
   causal function of the price path; MT5's bar history discards the path. A
   same-bar sweep is *not a function of the available data* on most of the corpus.
   **This is not a precision loss — the information does not exist.**

3. **Historical ask.** The methodology's own premise — sweeps take resting stops,
   which trigger at the ask — needs a series MT5 does not retain outside tick
   history. **The economically correct reading of the strategy's central concept
   is the one the platform makes hardest to obtain.**

## 5.2 The honest summary

The formal foundation survives contact with MT5 substantially intact. Populations,
stacks, derived identity, lifecycle, causality, prefix invariance, resource bounds
and alerting are all GREEN or cleanly adapted. **The kernel does not need to
change.**

What MT5 changes is the **scope of what may be specified**. Three capabilities the
methodology's prose assumes — absolute time, intrabar behaviour, and the ask side
of the book — are unavailable over most of the history the project would validate
against. Those are not implementation problems to be solved later. They are
constraints on what the strategy is allowed to say.

> The single most consequential discovery of this phase is not formal. It is that
> **a "significant H4 high" is knowable roughly eleven hours after the price that
> formed it** (`MT5-CAP-001` §2.4) — a latency floor that follows from the
> methodology plus the platform, that nobody had computed, and that no amount of
> engineering removes.

---

# 5bis. EMPIRICAL REVISION — 2026-08-07

`E-MT5-006` executed on the live terminal. Rows whose class changed:

| Property | Was | Now | Evidence |
|---|---|---|---|
| Historical ask / spread-aware sweep | **RED** beyond tick history | **GREEN on this feed** | ask on 100% of ticks, updated on 76.2%, back to 2013-08-12 |
| Determinism — tick ordering | YELLOW | **GREEN** | 0 backward steps in 176,099 ticks |
| Determinism — unique tick key | YELLOW | **RED** | `time_msc` collides with *differing prices*, up to 39.6% |
| Missing-data semantics | YELLOW | **RED** | weekend and absent history are indistinguishable (identical `0` + err `0`) |
| σ condition 1 (acts on the `(bid, ask)` pair) | YELLOW | **GREEN on this feed** | both sides retained historically |
| Programmatic execution / replay harness | YELLOW | **GREEN** | `/config` `[StartUp] Script=` runs headless; output collected from disk |
| Spread realism | not previously classified | **RED on MetaQuotes-Demo** | median spread 0 in 2026 vs 13 points in 2025 |

**Category 6 of §2 ("possible live but not reproducibly in tester") loses its
most important member.** The ask-based sweep was listed there on the assumption
that historical ask might not exist. It does. The remaining Category 6 member is
the Service host (F7), which is unchanged.

**The §3 intersection widens accordingly.** "Any rule requiring historical ask
outside tick history" was excluded; on this feed the tick history *is* the
history, 13 years of it, so the exclusion no longer binds — **subject to §5ter.**

## 5ter. The constraint that replaces it

> The blocker on ask-based rules is no longer *availability*. It is **feed
> quality**. MetaQuotes-Demo currently reports a **zero spread** on EURUSD, which
> no real market does. On a zero-spread feed, bid- and ask-based rules trivially
> converge — and indeed divergence fell from 100% (2025 data, 13-point spread) to
> 19% (2026 data, 0-point spread).
>
> **Any spread-sensitive conclusion must be re-measured on a real broker demo
> before it enters the specification.** That is now the binding constraint on
> `D-M4`, and it is a data-sourcing problem rather than a platform limitation —
> a strictly better position than the one this document previously recorded.

# 6. Status

Nothing resolved. `D-P1`, `D-P2`, `D-P3` remain open, as instructed. Six new
MT5-originated decisions (`D-M1`–`D-M6`) join the register, which now stands at
**71**. Three of them — `D-M1`, `D-M2` and the (a)/(b) fork in `MT5-EXP-001` §3.2 —
are constitutional and were invisible before MT5 was treated as a semantic target.
