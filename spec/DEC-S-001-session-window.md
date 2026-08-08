# DEC-S-001 — The Session Window Constraint

*New domain input received 2026-08-07. Recorded, not resolved. Per the project's
core rule, an ambiguous concept is stopped on and formalised as options — never
guessed.*

---

# 1. What was stated

> «LAS ZONAS HORARIAS SON NY UTC-4 DE 03 A 04 DE LAS 09:30 A 10:50, LA TOMA DE
> LIQUIDEZ SE TIENE QUE DAR EN ESE HORARIO OSEA QUE TODO ESE SISTEMA SE TIENE QUE
> DAR CUANDO EMPIEZA ESE HORARIO SINO NO ES UN RESULTADO VALIDO»

Extracted with confidence:

- The reference timezone is **New York**, given as **UTC−4**.
- Two clock ranges are named: **03:00–04:00** and **09:30–10:50**.
- A liquidity grab outside the named time is **not a valid result**.

That is a **hard gate**, not a quality preference — the first hard gate the
methodology has produced. Everything else about it is ambiguous.

---

# 2. Why this is more consequential than it looks

## 2.1 It is the first constraint that shrinks the domain

Every prior constraint filtered *shapes*. This one filters *time*, and by roughly
90%: two windows totalling **2 h 20 min** out of a 24-hour day.

Consequences, all favourable and none previously available:

| Affected | Effect |
|---|---|
| `D-P1` population depth | Fewer qualifying events ⇒ `D(d)` measured over a much smaller event set |
| `D-M4` / `D-M5` tick-data cost | If only ~2.3 h/day can produce a setup, **tick storage and processing drop by ~90%**. Option (b) — intrabar rules requiring real ticks — becomes far cheaper than `MT5-EXP-001` §3.3 assumed |
| Corpus construction | Labelling effort concentrates on two windows per day |
| `VAL-001` sampling | The corpus must over-sample these windows, not sample uniformly |

**The single biggest practical objection to requiring tick data was its cost. This
constraint largely removes that objection.** `D-M4`/`D-M5` should be re-costed
once the windows are pinned down.

## 2.2 It makes a RED capability load-bearing

`MT5-CAP-001` F6 established `[BELIEF]` that **MT5 exposes no broker timezone and
no DST schedule**, and `MT5-FORMAL-001` §1 classified broker-independent absolute
time as **RED**.

Until now that was a problem for HTF bar *alignment*. It is now a problem for the
**entry gate itself**:

> To decide whether a sweep happened at 09:37 New York, the engine must convert
> broker server time to New York time, historically, across DST transitions on
> **both** calendars. MT5 supplies neither offset.

> **Severity escalation: `D-M6` moves from Structural to Constitutional.** A
> mis-converted hour does not degrade a signal — it admits or rejects the setup
> outright.

This is exactly the class of discovery the phase ordering was designed to catch:
a trading rule arriving after a platform limitation was already documented, and
landing directly on it.

---

# 3. The ambiguities — none resolved here

## A-1 · One window or two?

«DE 03 A 04 DE LAS 09:30 A 10:50» admits at least two readings:

1. **Two disjoint windows**: `03:00–04:00` **and** `09:30–10:50`.
2. **One window** with a typo or an elision, e.g. `03:00–04:00` being something
   else entirely (a date? a month range? an H4 candle index?).

Reading 1 is coherent with common practice — `03:00–04:00` NY is the London open
hour, `09:30–10:50` NY spans the NYSE cash open plus the first 80 minutes — but
**coherence is not evidence**, and the project forbids inferring a rule because it
resembles a familiar one.

## A-2 · Fixed UTC−4, or America/New_York with DST?

This is the sharpest one and the answer changes results for four months a year.

- **UTC−4 fixed** is New York *daylight* time. Held year-round, the window sits at
  a different local New York hour every winter.
- **America/New_York** means `09:30` is always the NYSE cash open — UTC−4 in
  summer, **UTC−5 in winter**.

> These differ by exactly one hour for roughly November–March. If the intent is
> "the equity open", only the second is correct. If the intent is a fixed UTC
> offset, only the first is. **They are not approximations of each other.**

## A-3 · Does the whole sequence sit in the window, or only the sweep?

The two clauses say different things:

- «LA TOMA DE LIQUIDEZ SE TIENE QUE DAR EN ESE HORARIO» — only the **sweep**.
- «TODO ESE SISTEMA SE TIENE QUE DAR CUANDO EMPIEZA ESE HORARIO» — the **whole
  system**.

Candidate formalisations:

| ID | Rule |
|---|---|
| **W1** | The sweep instant ∈ window. Everything downstream may fall outside. |
| **W2** | Sweep **and** MSS ∈ window. |
| **W3** | The entire chain through confirmation ∈ window. |
| **W4** | The sweep ∈ window; the chain must complete within `Δ` of the window's close. |

W1 and W3 produce materially different setup counts — W3 requires sweep, MSS,
pullback and confirmation inside 80 minutes, which for a 60-minute window is a
severe constraint. **This is not a detail; it is most of the rule.**

## A-4 · Which instrument?

`09:30` is the **NYSE cash open**. It is a meaningful discontinuity for indices
and equities. FX has no 09:30 event of its own — it inherits one via correlation.
`MT5-CAP-001` does not know which symbol this project targets, and the answer
changes whether the constraint is causal or incidental.

## A-5 · Calendar scope

Weekdays only? Behaviour on US market holidays, when NYSE is closed but FX trades?
Half-days? `D-M2` already established MT5 provides no holiday calendar.

## A-6 · Inclusive or exclusive bounds?

Is a sweep at exactly `10:50:00` inside or outside? At tick resolution this
decides real cases.

---

# 4. What changes in the experiments, now

The instruments in `experiments/mt5/` are updated to serve this constraint:

1. **Session-aligned sampling.** `E-MT5-006` and `E-MT5-007` sample **inside** the
   two candidate windows rather than uniformly, because that is where the
   methodology now lives. Uniform sampling would measure a population the strategy
   never trades.
2. **A DST probe.** Both experiments sample the same New-York clock window in a
   **winter** month and a **summer** month and record where each lands in broker
   server time. If the server offset shifts between them, the broker observes DST
   and `A-2` becomes measurable rather than speculative.
   **This turns a RED capability into a measurable one**, for this broker.
3. **Offset auditing.** Every row carries server time, the assumed offset, and the
   derived New York time, so a wrong offset is visible in the output rather than
   silently baked into the conclusions.

---

# 4bis. EMPIRICAL UPDATE — 2026-08-07

Measured on MetaQuotes-Demo, terminal build 6096 (`E-MT5-006`, 176,099 ticks).

**`[CONFIRMED]` Server clock = UTC+3.** Measured directly by the script
(`server_time 2026.08.08 01:59:03` vs `gmt_time 2026.08.07 22:59:03`), and
independently corroborated three times by journal timestamp pairs.

**Window mapping in August 2026** (NY on EDT, UTC−4), verified against the raw
`ny_time` column — a row with `server_time = 2026.08.06 16:30:00` carries
`ny_time = 2026.08.06 09:30:00`:

| NY window | Server time |
|---|---|
| `03:00–04:00` | `10:00–11:00` |
| `09:30–10:50` | **`16:30–17:50`** |

Sanity check that the mapping is meaningful, not just arithmetic: window B
(NY open) consistently carries **~1.8× the tick volume** of window A across every
sampled period — 27,377 vs 15,219 recently, 33,831 vs 18,431 in July. The busier
window is where the NY session actually is.

**`A-2` remains OPEN, and the run could not settle it.** The script applied the
*current* UTC+3 offset to *all* historical windows, including the January sample.
That is a defect of the run, not a finding: it means the winter mapping was
assumed, not measured. Recorded honestly rather than quietly reported as data.

> To settle `A-2` the winter offset must be measured **from winter data itself** —
> e.g. by locating a known daily session boundary in January ticks and reading its
> server timestamp — rather than by applying today's offset backwards.

Note that `A-2` is only *half* an empirical question. Even with the broker's DST
behaviour fully measured, **whether you mean "a fixed UTC−4" or "the New York
equity open" is a statement of intent that no measurement can supply.**

# 5. Status

**OPEN.** Six ambiguities, none resolved. Two register consequences:

- **`D-M6` escalates to Constitutional** (§2.2).
- **`D-M4`/`D-M5` must be re-costed** once the windows are fixed (§2.1) — the
  economics of requiring tick data changed by roughly an order of magnitude.

`A-1`, `A-2` and `A-3` block any use of this constraint in a specification.
`A-2` in particular cannot be resolved by measurement — only the trader knows
whether the intent is "a fixed UTC offset" or "the New York equity open".
