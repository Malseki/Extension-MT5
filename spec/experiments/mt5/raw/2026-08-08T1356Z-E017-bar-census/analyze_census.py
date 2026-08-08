#!/usr/bin/env python3
"""
E-MT5-017 offline analysis.

Replicates E-MT5-015 DetectAt() EXACTLY against the censused bar stream, so the
SW-6 / entry-gap question can be answered over the whole signal population
(18,494) rather than only over the 4,394 executed trades.

Mapping (verified against the engine source):
  census row j          = candle 3 (shift 1 at the new-bar event)
  rows j-1, j-2         = candles 2 and 1
  rows j-3 .. j-5       = the K=3 left-only look-back
  row j+1               = candle 4, the entry bar (shift 0 at that event)
"""
import csv, collections, datetime as dt, sys

F = ("/Users/nachogm/Library/Application Support/net.metaquotes.wine.metatrader5/"
     "drive_c/users/nachogm/AppData/Roaming/MetaQuotes/Terminal/Common/Files/"
     "E-MT5-017-census-bars.csv")
K, PERIOD, PAD_PTS, POINT, TARGET_R = 3, 300, 5, 1e-5, 2.0


def load(path):
    bars = []
    with open(path) as fh:
        for r in csv.DictReader(fh):
            bars.append((dt.datetime.strptime(r["bar_time"].strip(), "%Y.%m.%d %H:%M:%S"),
                         float(r["open"]), float(r["high"]),
                         float(r["low"]), float(r["close"])))
    return bars


def ext(b, d):
    return b[3] if d > 0 else b[2]          # low for BUY, high for SELL


def detect(B, j, d):
    """Exact port of DetectAt(). j is the index of candle 3."""
    i2, i1 = j - 1, j - 2
    if i1 - K < 0:
        return None
    ref = ext(B[i1], d)
    for k in range(1, K + 1):
        if d * (ext(B[i1 - k], d) - ref) <= 0.0:
            return None
    sweep = ext(B[i2], d)
    if not d * (sweep - ref) < 0.0:      return None   # sweep beyond REF
    if not d * (sweep - B[i2][4]) < 0.0: return None   # wick beyond close
    if not d * (B[i2][4] - ref) < 0.0:   return None   # SW-4
    if not d * (B[j][4] - sweep) >= 0.0: return None   # SW-5 R-a
    return ref, sweep, B[j][4]


def main():
    B = load(F)
    n = len(B)
    print("=" * 74)
    print("E-MT5-017 BAR CENSUS — EURUSD M5, Model=4, 2024.01.01 -> 2026.08.08")
    print("=" * 74)
    print(f"closed bars censused : {n:,}")
    print(f"range                : {B[0][0]}  ->  {B[-1][0]}")

    # ---------- 1. gap census over the raw bar stream ----------
    gaps = [(i, (B[i + 1][0] - B[i][0]).total_seconds()) for i in range(n - 1)]
    bad = [(i, g) for i, g in gaps if g != PERIOD]
    wknd = [(i, g) for i, g in bad if g > 86400]
    intra = [(i, g) for i, g in bad if g <= 86400]
    print(f"\n-- BAR-STREAM GAPS --")
    print(f"bar-to-bar intervals != 300s : {len(bad):,} of {n - 1:,} "
          f"({100 * len(bad) / (n - 1):.3f}%)")
    print(f"  market closure (>24h)      : {len(wknd):,}")
    print(f"  intraday data gap (<=24h)  : {len(intra):,}")
    hist = collections.Counter(round(g / PERIOD) for _, g in intra)
    print("  intraday gap size (missing M5 bars -> count): "
          + ", ".join(f"{k-1}:{v}" for k, v in sorted(hist.items())[:12]))

    # ---------- 2. full signal population + adjacency classification ----------
    sig = []
    for j in range(5, n - 1):
        for d in (1, -1):                       # engine tries BUY first, then SELL
            r = detect(B, j, d)
            if r:
                sig.append((j, d, r))
                break
    print(f"\n-- SIGNAL POPULATION (offline replica) --")
    print(f"detections : {len(sig):,}   (engine logged 18,494 over the same range)")

    clean = g12 = g23 = g34 = multi = 0
    rows = []
    for j, d, (ref, sw, rj) in sig:
        d12 = (B[j - 1][0] - B[j - 2][0]).total_seconds()
        d23 = (B[j][0] - B[j - 1][0]).total_seconds()
        d34 = (B[j + 1][0] - B[j][0]).total_seconds()
        flags = [d12 != PERIOD, d23 != PERIOD, d34 != PERIOD]
        if not any(flags):
            clean += 1
            continue
        if sum(flags) > 1:
            multi += 1
        g12 += flags[0]; g23 += flags[1]; g34 += flags[2]
        rows.append((j, d, d12, d23, d34, ref, sw, rj))

    print(f"\n-- TIME-ADJACENCY OVER THE FULL POPULATION --")
    print(f"clean (1->2->3->4 all exactly 300s) : {clean:,} "
          f"({100 * clean / len(sig):.3f}%)")
    print(f"gap-affected                        : {len(rows):,} "
          f"({100 * len(rows) / len(sig):.3f}%)")
    print(f"   gap between candle 1 and 2       : {g12:,}   <- SW-6 violation, NOT detected by any invariant")
    print(f"   gap between candle 2 and 3       : {g23:,}   <- SW-6 violation, NOT detected by any invariant")
    print(f"   gap between candle 3 and 4       : {g34:,}   <- ENTRY_TIMING, the only one the run caught")
    print(f"   more than one gap in the window  : {multi:,}")

    # ---------- 3. what option (b) would actually pay ----------
    print(f"\n-- OPTION (b): enter on the first available bar regardless of the gap --")
    print("   measured slip between candle-3 close and the entry bar's open,")
    print("   expressed against the stop distance the pattern itself defines.\n")
    print(f"   {'signal (candle 3)':<21} {'dir':<5} {'gap':>9} {'slip pts':>9} "
          f"{'stop pts':>9} {'slip/stop':>10} {'verdict'}")
    worse = 0
    stats = []
    for j, d, d12, d23, d34, ref, sw, rj in rows:
        if d34 == PERIOD:
            continue                            # only the entry-side gap matters here
        c3close = B[j][4]
        entry = B[j + 1][1]                     # open of the first available bar
        stop = sw - PAD_PTS * POINT if d > 0 else sw + PAD_PTS * POINT
        slip = (entry - c3close) / POINT * d     # +ve = filled worse for the trade
        stopd = abs(entry - stop) / POINT
        ratio = slip / stopd if stopd else float("nan")
        dead = d * (entry - stop) <= 0
        if slip > 0:
            worse += 1
        stats.append((slip, stopd, ratio, dead))
        print(f"   {str(B[j][0]):<21} {'BUY' if d>0 else 'SELL':<5} "
              f"{d34/60:>7.0f}m {slip:>9.1f} {stopd:>9.1f} {ratio:>9.2f}x  "
              f"{'STOP ALREADY BREACHED' if dead else ''}")
    if stats:
        sl = sorted(s[0] for s in stats)
        rt = sorted(s[2] for s in stats)
        print(f"\n   n={len(stats)}  filled worse than candle-3 close: {worse}/{len(stats)}")
        print(f"   slip pts   min {sl[0]:.1f}  median {sl[len(sl)//2]:.1f}  max {sl[-1]:.1f}")
        print(f"   slip/stop  min {rt[0]:.2f}x median {rt[len(rt)//2]:.2f}x max {rt[-1]:.2f}x")
        print(f"   entries where the gap already blew through the stop: "
              f"{sum(1 for s in stats if s[3])}")

    # ---------- 4. cost of option (a) ----------
    print(f"\n-- OPTION (a): skip any signal whose 1->2->3->4 window spans a gap --")
    print(f"   signals lost : {len(rows):,} of {len(sig):,} ({100*len(rows)/len(sig):.3f}%)")
    print(f"   of which the current build already refuses : {g34:,}")
    print(f"   of which the current build WRONGLY TRADED  : {len(rows)-g34:,}")


if __name__ == "__main__":
    main()
