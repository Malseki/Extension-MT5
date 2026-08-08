# SPEC-SW-001 — The 1-2-3 Liquidity Sweep + Rejection Pattern

*Candidate formalisation. **Nothing here is frozen.** Every ambiguity is
enumerated, none is resolved.*

> ## ⚠ SOURCE OF THIS FORMALISATION
>
> **The reference image was not received.** No attachment reached this session.
> This document formalises the **textual description** given in §2 of the
> 2026-08-07 request, quoted verbatim below. Where the image might disambiguate
> something, that is marked `[IMAGE NEEDED]`.
>
> Verbatim source:
> - *Candle 1 — "establishes a reference low; that low represents a location where
>   liquidity may be resting."*
> - *Candle 2 — "breaks/penetrates the reference low; takes the liquidity; leaves
>   a lower wick; the candle closes below the reference low in the illustrated
>   example."*
> - *Candle 3 — "rejects the bearish continuation; moves back upward; does NOT
>   close below the relevant low of candle 2."*

---

# 1. What this pattern is, structurally

It is **not a new concept**. It is a *concrete, three-candle instantiation* of
machinery the corpus already models:

| 1-2-3 element | Existing concept | Governing decision |
|---|---|---|
| Candle 1's low | liquidity pool (`CN-11`) | `DEC-020` significance |
| Candle 2's penetration | penetration (`CN-13` first half) | `DEC-021`, `D-M4` |
| Candle 2 closing beyond | **acceptance** — the thing that normally *kills* a pool | `DEC-023` |
| Candle 3's rejection | sweep resolution / reaction | `DEC-023`, `DEC-044` |

> **This matters more than it looks.** In the corpus so far, a close beyond the
> level is *acceptance* — evidence the pool was **broken**, not swept. The
> described pattern has Candle 2 **closing below** the reference low and then
> treats Candle 3 as the rejection. That is a **failed breakdown / spring**, not
> the wick-sweep that `SPEC-100` CN-13 was drafted around.
>
> They are different phenomena with different geometry. Neither is wrong — but
> the corpus currently models one and the request describes the other, and that
> conflict must be resolved deliberately. Recorded as **`SW-4`**.

---

# 2. Notation

For a candle `i` on the evaluation timeframe: `O(i) H(i) L(i) C(i)`.
Reference candle `R`, sweep candle `S`, rejection candle `J`.
`ℓ = L(R)` is the reference level (bullish case). Bearish is the exact mirror
under the σ involution of `RT-18` — `σ(bid,ask) = (c−ask, c−bid)`, `H ↔ L`,
`above ↔ below` — and is **not** restated separately.

---

# 3. Candidate formalisation (bullish)

```
P1  REFERENCE     valid(R)                         and  ℓ = L(R)
P2  PENETRATION   ∃ price p in S with p < ℓ − δ
P3  ACCEPTANCE?   C(S) < ℓ                          ← SW-4: required or incidental?
P4  WICK          L(S) < C(S)                       ← implied by "leaves a lower wick"
P5  REJECTION     rejection(J) relative to S and R  ← SW-5: four candidates, §4.5
P6  ADJACENCY     R → S → J spacing                 ← SW-6
P7  SESSION       t ∈ NY window                     ← DEC-S-001, unresolved
```

A candidate is `PATTERN_DETECTED` iff P1…P7 hold under a declared reading of
every ambiguity. **It is not a BUY.** §7.

---

# 4. The ambiguities that materially change detection

Ranked by how much the detection set moves. This is the answer to STEP 3.

## 4.1 `SW-1` — What makes Candle 1 a valid reference?

| Option | Meaning |
|---|---|
| **A** | the immediately preceding candle — always valid |
| **B** | an `n`-bar pivot low (`DEC-014`/`DEC-015`) |
| **C** | an equal-lows cluster within `ε` (engineered liquidity) |
| **D** | a session/HTF extreme (H1/H4 per the original methodology) |
| **E** | any of the above, with several coexisting |

Option A makes *every* candle a reference and the pattern fires constantly.
Option D makes it rare. **This single choice can change the detection count by
two orders of magnitude.** Inherits `DEC-020`, which is open.

## 4.2 `SW-2` — Which price stream penetrates?

| Option | Meaning |
|---|---|
| **A** | bid only (what the chart draws — `SYMBOL_CHART_MODE=0`) |
| **B** | ask only (where resting buy-stops actually trigger) |
| **C** | either |
| **D** | bid for the level, ask for the trigger |

`[OBSERVED]` `E-MT5-006`: bid- and ask-based crossings disagree on **19–100%** of
test levels, with a concrete case where the bid crossed down and the ask **never
did**. This is not a rounding question. Inherits `D-M4`, open, and **cannot be
settled on MetaQuotes-Demo** because its recent spread is ≈0.

## 4.3 `SW-3` — Strictness and minimum excursion

`L(S) < ℓ` or `≤`? And a minimum excursion `δ`: 0, `n` ticks, or volatility-scaled?
Inherits `DEC-021` (δ) and `DEC-011` (ε). With `δ = 0` a one-tick overshoot counts;
with `δ` volatility-scaled, `RT-13`'s count-invariance problem applies.

## 4.4 `SW-4` — Must Candle 2 close beyond the level?

**The structural question of §1.**

| Option | Consequence |
|---|---|
| **Required** (`C(S) < ℓ`) | the pattern is a *failed breakdown*. Under `DEC-023` this same close is *acceptance*, which normally **kills** the pool — the two rules would contradict |
| **Forbidden** (`C(S) ≥ ℓ`) | the classic wick-sweep; matches `SPEC-100` CN-13 |
| **Either** | both admitted; the pattern is "penetration + rejection" regardless of the sweep candle's close |

The description says *"closes below the reference low **in the illustrated
example**"* — the qualifier is yours, and it is exactly the hedge that suggests
you may not have decided whether it is essential. `[IMAGE NEEDED]`

## 4.5 `SW-5` — What is rejection? **Highest impact.**

| Option | Condition | Strength |
|---|---|---|
| **R-a** | `C(J) ≥ L(S)` — "does not close below Candle 2's low" | **near-vacuous** — see below |
| **R-b** | `C(J) > C(S)` | moderate |
| **R-c** | `C(J) > ℓ` — reclaims the swept level | strong; the classic reading |
| **R-d** | `C(J) > H(S)` | engulfing-strength |

> **R-a, the literal reading of your sentence, filters almost nothing.**
> Under P3+P4 the geometry is `L(S) < C(S) < ℓ`. For `C(J)` to fall *below* `L(S)`,
> Candle 3 would have to close beneath the entire sweep candle — a further sharp
> decline. On any ordinary candle `C(J) ≥ L(S)` holds. So as literally written,
> "rejection" excludes only violent continuation and admits nearly everything
> else, including sideways drift.
>
> `[INFERRED]` The intended condition is probably stronger — most likely **R-c**,
> reclaiming the level, which is what "rejects the bearish continuation and moves
> back upward" means in ordinary trading usage. **I am not choosing it.** But you
> should know that the literal text and the probable intent differ, and that this
> is the decision that most changes what the detector finds.

## 4.6 `SW-6` — Adjacency

Strictly consecutive `R,S,J`? Or `R → …k candles… → S → …m candles… → J`?
The image shows three adjacent candles `[IMAGE NEEDED]`, but a three-candle
window is an extremely tight constraint and the rest of the methodology
(`DEC-035` sweep→MSS latency) uses bounded windows, not adjacency.

## 4.7 `SW-7` — Evaluation timeframe

The pattern is timeframe-relative and none was given. M1 makes it noise-dominated;
H1/H4 matches the original "significant H1/H4 highs/lows". Inherits `DEC-002`.

## 4.8 `SW-8` — Boundary equality

`C(J)` exactly on the level: inside or outside? At 5-digit tick resolution this
occurs. Needs `ε` (`DEC-011`).

## 4.9 `SW-9` — Can Candle 3 sweep again?

If `J` itself makes a new low below `L(S)` and *then* closes up — is that
rejection, a new sweep, or invalidation? Inherits `DEC-028` (cascades).

## 4.10 `SW-10` — Session gate

`DEC-S-001` A-1/A-2/A-3 unresolved, and `D-M6` (broker DST) is constitutional
because of it. **`America/New_York` semantics must be preserved explicitly —
no hard-coded UTC−4.**

---

# 5. The blocking set — answer to STEP 1

**The 1-2-3 pattern cannot be frozen independently.** It inherits eight open
decisions and introduces five new ones.

| Inherited, already open | Blocks |
|---|---|
| `DEC-020` pool significance | `SW-1` |
| `D-M4` bid vs ask | `SW-2` |
| `DEC-021` penetration threshold | `SW-3` |
| `DEC-011` equality tolerance | `SW-3`, `SW-8` |
| `DEC-023` acceptance / pool death | `SW-4` — and **contradicts** it |
| `DEC-002` evaluation clock | `SW-7` |
| `DEC-S-001` + `D-M6` | `SW-10` |
| `D-P3` `Pop_known` vs `Pop_occurred` | when `R` becomes a usable reference |

| New | |
|---|---|
| `SW-4` | sweep-candle close: required, forbidden, or either |
| `SW-5` | rejection condition R-a/b/c/d |
| `SW-6` | adjacency |
| `SW-8` | boundary equality |
| `SW-9` | re-sweep on Candle 3 |

Register: **82 → 87.**

## 5.1 The smallest decision set that would freeze the rule — STEP 4

If you answer **only these five**, the pattern becomes detectable and testable.
The rest can take conservative defaults without changing whether a pattern exists,
only how often.

| # | Question | Why it is unavoidable |
|---|---|---|
| **1** | **`SW-5`** — R-a, R-b, R-c or R-d? | Changes the detection set more than everything else combined |
| **2** | **`SW-4`** — must Candle 2 close beyond the level? | Decides whether this is a wick-sweep or a failed breakdown, and whether it contradicts `DEC-023` |
| **3** | **`SW-1`** — which lows qualify as references? | Two orders of magnitude in detection count |
| **4** | **`SW-6`** — strictly three adjacent candles, or bounded windows? | Decides whether the detector is a candle-pattern matcher or a state machine |
| **5** | **`SW-7`** — evaluation timeframe | Everything is relative to it |

`SW-2` (bid/ask) is *deliberately excluded* from the minimum set: it cannot be
answered with evidence until a real broker feed exists, and a conservative default
(bid, matching what the chart draws) lets development proceed while leaving `D-M4`
honestly open.

---

# 6. Pattern state machine (candidate)

States are **pattern** states, never trade states:

```
IDLE
 └─ reference registered ───────────────► ARMED        (P1)
     ├─ penetration observed ───────────► PENETRATED   (P2,P3,P4)
     │   ├─ rejection satisfied ────────► DETECTED     (P5)
     │   ├─ rejection window expired ───► INVALIDATED  (SW-6)
     │   └─ continuation beyond S ──────► INVALIDATED
     └─ reference invalidated ──────────► IDLE
```

Every transition carries `t_occurred`, `t_known`, the rule id, and the parameter
snapshot. `DETECTED` means **PATTERN_DETECTED**, nothing more.

---

# 7. Pattern is not a trade

Per §4 of the request, and enforced structurally:

```
PATTERN_DETECTED      a geometric fact about three candles
PATTERN_WAITING       reference armed, awaiting penetration or rejection
PATTERN_INVALIDATED   a declared invalidation fired
PATTERN_UNKNOWN       data insufficient to decide
PATTERN_BLOCKED       the rule itself is unspecified
TRADE SIGNAL          ✗ DOES NOT EXIST
```

> `Verdict()` remains structurally incapable of returning BUY or SELL
> (`E-MT5-OBS-002` IT-4, 126 combinations, zero leaks). **Detecting this pattern
> changes nothing about that.** A detected 1-2-3 is a candidate observation, and
> the decision layer that would turn it into a verdict does not exist.

---

# 8. What the observability build may legitimately do now

Not "implement the detector" — the semantics are not frozen. But it **can**:

- treat every ambiguity in §4 as an **explicit input**, defaulted to the most
  literal reading of the quoted text;
- render each candidate with the reading that produced it;
- emit `PATTERN_CANDIDATE` events, never verdicts;
- run the **same historical range under different readings** so the choice can be
  made by looking rather than by guessing.

That is the difference between resolving an ambiguity and **exhibiting** it, and
it is what `E-MT5-009` is built to do.

---

# 9. THE REFERENCE GRAPHIC — RECEIVED 2026-08-07

Delivered as a PDF; the embedded JPEG (1536×1024) was extracted and read.
Preserved at `experiments/mt5/raw/2026-08-07T2312Z-E011-123matrix/reference-graphic.jpg`.

**Authoritative text — "RESUMEN DE LA SECUENCIA", verbatim:**

> 1. **VELA 1**: define el mínimo con liquidez
> 2. **VELA 2**: rompe el mínimo, cierra por debajo y deja mecha (toma de liquidez)
> 3. **VELA 3**: rechaza, no cierra por debajo del mínimo de la vela 2 (confirmación)

Plus the panel annotations: *"CIERRA POR DEBAJO DEL MÍNIMO DE VELA 1"*,
*"MECHA INFERIOR TOMA LA LIQUIDEZ (STOPS)"*, *"NO CIERRA POR DEBAJO DEL MÍNIMO DE
LA VELA 2"*, and *"MISMA SECUENCIA PARA MÁXIMOS"* (1 máximo de referencia,
2 barrido, 3 rechazo, no cierra por encima).

## 9.1 What the graphic settles

| Ambiguity | Resolved to | Basis |
|---|---|---|
| **`SW-4`** sweep-candle close | **REQUIRED** — `C(S) < ℓ` | *"cierra por debajo"* appears in the **summary definition**, not merely as a feature of the drawn example. §4.4's doubt is closed. |
| **`SW-5`** rejection | **R-a** — `C(J) ≥ L(S)` | *"no cierra por debajo del mínimo de la vela 2"*, stated twice |
| **`SW-6`** adjacency | **strict 1→2→3** | three labelled consecutive candles, arrows in the summary |
| direction mirror | confirmed | *"MISMA SECUENCIA PARA MÁXIMOS"* |

> **Consequence, stated plainly:** the pattern **is** a failed breakdown, not a
> wick-sweep. §1's conflict with `DEC-023` (a close beyond the level is
> *acceptance*, which normally kills the pool) is therefore **real and must be
> reconciled** — the corpus and the graphic now demonstrably disagree about what a
> close beyond a level means.

## 9.2 What the graphic does **not** settle

`SW-1` (what makes vela 1's low a valid reference), `SW-2` (bid/ask), `SW-3`
(minimum penetration), `SW-7` (timeframe), `SW-8` (boundary equality),
`SW-9` (re-sweep), `SW-10` (session). And **nothing at all** about entry, stop,
target, sizing, confirmation beyond vela 3, FVG or retracement — the graphic is a
**pattern** reference, not a trade reference.

One minor inconsistency, recorded not corrected: panel 1 says buy orders
accumulate below the low (*"Aquí se acumulan órdenes de compra"*) while panel 2
says the wick takes **stops**. Below a low, resting stops are sell-stops. The
annotations describe different order types. Immaterial to the geometry; material
if `SW-2` is ever decided on economic grounds.

---

# 10. MEASURED — `E-MT5-011`, 2026-08-07

EURUSD **M5**, **40,000 closed bars** (to 2026-01-26), MetaQuotes-Demo, build 6096.
Raw: `raw/2026-08-07T2312Z-E011-123matrix/`.

**`SW-1 = A` (any preceding candle) — 39,993 references armed:**

| `SW-4` \ `SW-5` | **R-a** (graphic) | R-b | R-c | R-d |
|---|---:|---:|---:|---:|
| **REQUIRED** (graphic) | **5,663** (14.16%) | 4,183 (10.46%) | 2,329 (5.82%) | 822 (2.06%) |
| FORBIDDEN | 8,381 (20.96%) | 4,799 (12.00%) | 7,149 (17.88%) | 2,697 (6.74%) |
| EITHER | 14,044 (35.12%) | 8,982 (22.46%) | 9,478 (23.70%) | 3,519 (8.80%) |

**The graphic's exact reading — `SW-1=A` + `SW-4=REQUIRED` + `SW-5=R-a` —
yields 5,663 detections in 40,000 M5 bars (14.16% of references).**

## 10.1 `SW-1 = B` is logically impossible `[CONFIRMED]`

With a symmetric `k=2` pivot reference: **0 detections in all twelve cells**,
against 5,454 references armed.

> **Not a data artifact — a contradiction.** A symmetric pivot low at bar `r`
> requires `L(r−1) ≥ L(r)` (the *next* bar must not go lower). The sequence
> requires `L(S) < ℓ = L(r)` where `S = r−1` — the next bar **must** go lower.
> The two conditions are mutually exclusive by construction.
>
> **`SW-1` option B, as a symmetric pivot, is eliminated on formal grounds.**
> A valid reference must be either any preceding candle (A), a **left-only**
> extreme (lowest of the previous `k` bars, no right-hand condition), or a pivot
> confirmed further back with `SW-6` relaxed to allow gaps. This narrows `SW-1`
> without anyone having to choose.

## 10.2 Correction to §4.5 — I overstated

§4.5 claimed R-a *"filters almost nothing"* and is *"near-vacuous"*.
**Measured, that is too strong.** Under the graphic's `SW-4=REQUIRED`, R-a admits
5,663 and R-c admits 2,329 — R-a is **2.4× more permissive** than R-c and 6.9×
more than R-d, but it is not vacuous. The heavy filtering is done by `SW-4`
(break + close beyond + lower wick), not by the rejection test.

The geometric argument was sound in isolation and misleading in context, because
it ignored how much `SW-4` had already removed. **R-a is the loosest of the four
readings, not an empty one.**
