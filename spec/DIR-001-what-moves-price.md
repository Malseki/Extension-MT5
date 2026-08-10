# DIR-001 — WHAT ACTUALLY MOVES THE PRICE

    STATUS   RESEARCH DIRECTION. Nothing here is a decision or a hypothesis
             under test. The hypothesis budget is exhausted; this document
             exists to inform what a NEW budget would be spent on, if any.
    DATE     2026-08-10

---

## 1. Why this document exists

Four measurements, four dead ends, and all four asked the same question in
different clothes: *given this shape on the chart, will price go up or down?*

    1-2-3 sweep + rejection      z = -6.98   refuted out-of-sample
    tick order-flow imbalance    P(up) = 50.20%, z = +0.24   null
    H-FOCAL round numbers        -2.91 pp on virgin GBPUSD   refuted
    variance ratio (general)     real reversion, below the spread

The fourth is the important one: it was the *general* test. It found genuine
structure and then priced it — and the price was under the spread. That result
does not say "look harder at chart shapes". It says the question was wrong.

## 2. What the evidence says actually moves exchange rates

[EVIDENCE: PRIMARY] Evans & Lyons, *How is macro news transmitted to exchange
rates?* — the variance decomposition is the single most useful finding for us:

- Direct effect of **scheduled** macro announcements: **less than 10%** of daily
  price variance.
- Macro news arrival in the broad sense: **more than 30%**, once indirect
  channels are included.
- **Roughly two thirds of the total news effect is transmitted via ORDER FLOW**,
  not by prices adjusting directly to the announcement.
- Scheduled announcements are only about **10% of news arrivals**. Most of what
  moves price is unscheduled.

[DERIVED] The mechanism is therefore: information does not enter the price by
being published. It enters when someone **trades on it**. Price moves because of
the imbalance of orders hitting the book, and news matters only insofar as it
changes that imbalance.

[DERIVED] This explains every one of our negatives at once. A chart shape is a
*consequence* of past order flow, not a cause of future order flow. Reading the
shape is reading the exhaust, not the engine.

[EVIDENCE: PRIMARY] Evans & Lyons (JPE 2002) already told us the size of the
engine: signed interdealer order flow yields R² > 50% on daily FX returns, where
10% is rare for macro models.

## 3. Three directions, with what each would cost

### DIR-A · Change the time scale — *the one our own data points to*

[DERIVED] The execution tax is `s/(3D)`. Everything we tested had D of 5-20
pips, so the tax was 0.8-3.1 pp. At D = 200 pips it is 0.08 pp; at D = 500 pips,
0.03 pp. **The same effect that is invisible under the spread intraday becomes
visible at a longer horizon** — not because it grows, but because the cost
shrinks by two orders of magnitude.

[EVIDENCE: SECONDARY] The FX factors with published, replicated support — carry,
momentum, value — operate at **monthly to quarterly** rebalancing, not intraday.
Currency momentum is documented as profitable but transaction-cost sensitive and
requiring frequent rebalancing; carry is documented as robust across a 200-year
history except around the World Wars.

- **Cost:** cheap. Daily/weekly bars, no tick data, no new instrument.
- **Risk:** these factors are widely known and heavily traded. Expect small,
  crowded, slow returns — and the McLean-Pontiff decay (−58% post-publication)
  applies with full force.
- **Fit with the product:** a detector that fires a few times per month suits
  "high precision, low frequency" better than anything intraday.

### DIR-B · Get closer to order flow with data we can actually obtain

[DERIVED] True signed interdealer flow is unavailable to us. But the mechanism
has public proxies we have never touched:

- **CME FX futures volume and open interest** — real traded volume, unlike the
  tick counts our MT5 feed reports. Public and free.
- **CFTC Commitment of Traders**, weekly positioning by category.

[EVIDENCE: SECONDARY] COT positioning has **no predictive power on its own**;
what carries signal, according to the sources reviewed, is **extreme**
positioning as a contrarian indicator. That is a much weaker claim than the
Evans-Lyons result and must be treated as such.

- **Cost:** medium. External data, new ingestion, weekly frequency.
- **Risk:** weekly granularity cannot drive an intraday alert product.

### DIR-C · Stop asking for direction — *the honest reframe*

[OBSERVED] Our own measurements keep confirming that **direction** is
unpredictable while **volatility** is highly structured. E-MT5-029 found the
volatility regime split changed the variance ratio dramatically (z=-9.9 in low
vol vs z=-1.4 in high vol). Volatility clustering is the most robust empirical
regularity in all of finance.

[PROPOSED] A detector that answers *"a large move is becoming more likely"*
instead of *"price will go up"*:

- It is predicting the thing that is actually predictable.
- It is genuinely useful to a human operator: it says when to pay attention,
  when to widen stops, when to stay out.
- It does not require beating the spread, because it is not a directional bet —
  which is exactly the barrier that killed the previous four.
- **It is honest.** We would be advertising a capability we can demonstrate.

- **Cost:** low. Same engine, same data, different target variable.
- **Risk:** it does not tell the trader whether to buy or sell. That is the
  point, and it must be stated plainly rather than dressed up.

## 4. Ranking, by evidence and by what it costs to be wrong

| | direction | evidence | cost | biggest risk |
|---|---|---|---|---|
| 1 | **DIR-C** volatility regime | Primary, overwhelming | Low | Does not give direction |
| 2 | **DIR-A** longer horizon | Primary but crowded | Low | Decay; slow; small |
| 3 | **DIR-B** flow proxies | Primary mechanism, weak proxies | Medium | Weekly ≠ intraday |

[INFERRED] DIR-C is ranked first not because it is the most ambitious but
because it is the only one where the thing being predicted is known to be
predictable. The other two ask again for direction, and direction is what four
sealed experiments have now failed to find.

## 5. What is NOT proposed

- No fifth directional chart pattern.
- No parameter tuning of anything already refuted.
- No use of the forward sample until a hypothesis is preregistered.
- No claim that any of these will work. DIR-C is the only one where we can state
  in advance what would count as success and be reasonably sure of measuring it.

## 6. The forward sample

[OBSERVED] `TRADER-FORWARD-M5.csv` began accumulating on 2026-08-10. Every closed
M5 bar with OHLC, tick volume, spread and detector state.

[LOCKED] It is not to be examined until a hypothesis is preregistered against
it. It is the only genuinely virgin data this project can still obtain, and it
grows by 288 bars per trading day whether or not anyone is watching.
