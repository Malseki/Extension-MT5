# E-MT5-037 — PRE-REGISTRATION: DOES A CONTINUATION ALERT BEAT DOING NOTHING?

    STATUS   PRE-REGISTRATION. Sealed BEFORE the first continuation alert has
             fired. TRADER-CONTINUACION.csv did not exist when this was written.
    DATE     2026-08-26 14:40Z
    TESTS    the alert added to TRADER-STRUCTURE-002 the same day.

---

## 1. Where this comes from

[OBSERVED] 2026-08-26. The trader watched EURUSD fall for hours and received no
alert. He was right to complain, and the reason turned out to be structural:

- TRADER-ALERT-001 implements REVERSION. When price falls to a level it warns
  BUY. In a sustained decline it will never issue a sell on a level touch.
- Its other two warnings measure movement INSIDE one M5 candle: 3 pips forming,
  or 5 pips in 5 minutes. A 25-pip fall spread over twenty candles is 1.25 pips
  per candle and trips neither.

[DERIVED] Nothing in the system watched persistent direction. The structure
indicators did mark the move correctly — which is exactly why the trader saw
BOS and CHoCH drawn while the detector stayed silent.

The continuation alert fills that hole: it fires when a BOS confirms
continuation on the chart timeframe AND H1 points the same way.

## 2. Why the honest prior is that this LOSES

[OBSERVED] E-MT5-034 ran the economic A/B directly:

| direction | n | win% | PF | total R |
|---|---|---|---|---|
| AGAINST the move (reversion) | 2,631 | 47.78% | 0.9212 | −127.9 |
| WITH the move (momentum) | 1,052 | 44.87% | 0.7505 | −122.1 |

Trading WITH the move measured **2.91 pp worse**. E-MT5-030 and E-MT5-031 found
the same thing by a different route: impulses revert, they do not continue.

[INFERRED] A continuation alert is, by construction, an instruction to trade
with the move. The prior is that it underperforms, and it is being built because
the trader asked for the missing capability, not because evidence supports it.

**This is recorded before any measurement precisely so the result cannot be
reinterpreted afterwards.**

## 3. What could make it different — the only reason to test at all

[NOT ESTABLISHED] E-MT5-034 fired on an early-warning trigger with no structural
filter and no higher-timeframe agreement. This alert demands both: a confirmed
BOS and H1 alignment. Whether that filter changes the sign of the result is
unknown, and unknowable without measuring.

That is the whole hypothesis. Not "momentum works" — that is refuted — but
"a structurally filtered subset of momentum may behave differently".

## 4. PREDICTION, RECORDED BEFORE MEASURING

P(target before stop) for continuation alerts will NOT exceed the structural
null of 1/3, and will land at or below the reversion arm of E-MT5-034.

Stated as a directional prediction so it can fail cleanly.

## 5. Measurement

**Unit:** each row of `TRADER-CONTINUACION.csv`.

**Recorded at emission:** timestamp, direction, BOS level, H1 trend, price,
pivot settings. Written by the indicator, not by hand.

**Outcome:** for each alert, whether price reached +2R before −1R using the same
20-pip stop and 2.0 target ratio as TRADER-ALERT-001, so the number is directly
comparable to the detector's own hit rate.

**Comparison arms:**

| arm | source |
|---|---|
| continuation (this alert) | TRADER-CONTINUACION.csv |
| reversion (existing detector) | TRADER-ALERT-001-results.csv |
| structural null | 1/3, costless |
| null with cost | 1/3 − s/(3D) = 31.94% |

## 6. DECISION CRITERIA

| result | action |
|---|---|
| hit rate ≥ 40% with n ≥ 200 | genuinely surprising; a fresh preregistration before any further claim |
| hit rate 33–40%, n ≥ 200 | no edge over the null — keep as a visual aid, never as a signal |
| hit rate < 33% with n ≥ 200 | **confirms E-MT5-034; the alert is removed or permanently marked as counter-indicative** |
| n < 200 | no conclusion. Interim numbers are observations, not results |

**The alert gets deleted if it loses.** That is the condition that makes this an
experiment rather than a feature.

## 7. Positive control

The reversion arm runs on the same instrument over the same window from
TRADER-ALERT-001. Both arms must show a hit rate in the neighbourhood of the
1/3 null. If the continuation arm returned something absurd — 60%, or 5% — the
pipeline is broken, not the market.

## 8. What invalidates this

- Changing `InpLeftBars`/`InpRightBars` or the H1 confluence rule after seeing
  results. The parameters are frozen at 5/5 with H1 agreement as of today.
- Counting alerts emitted while the indicator was reloading, which replays
  history. The 2-candle freshness guard exists for this; any row whose
  `aviso_t` is more than 2 candles after the BOS is excluded.
- Reading n < 200 as an answer.

## 9. Honest summary

[INFERRED] The most likely outcome is that this confirms what E-MT5-034 already
measured, and the alert ends up documented as counter-indicative — useful
precisely by telling the trader when NOT to follow the move.

That would still be worth having built it. What is not acceptable is keeping it
because it feels responsive, without ever checking.
