#!/usr/bin/env python3
"""
E-MT5-022 analyzer — proportion of (+2R before -1R) per level provider and X.

Replicates the E-MT5-021 computation exactly. Resolution codes, from the source
(E-MT5-021-htf-level-provider.mq5:83):

    0 open   1 target-first   2 stop-first   3 unresolved   4 no-stop

Denominator is {1,2}. Codes 3 and 4 are excluded, identically to the in-sample
run. No other filtering is applied.

Usage:  analyze_e022.py <signals.csv> [label]
"""
import csv, sys, math
from collections import defaultdict

P0 = 1.0 / 3.0
PROV = {0: "A' K=3 M5", 1: "pivot H1", 2: "pivot H4"}
XCOL = {1: "res_x1", 5: "res_x5", 15: "res_x15"}


def wilson(k, n, z=1.96):
    if n == 0:
        return (float("nan"), float("nan"))
    p = k / n
    d = 1 + z * z / n
    c = (p + z * z / (2 * n)) / d
    h = z / d * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n))
    return (c - h, c + h)


def main(path, label):
    cnt = defaultdict(lambda: defaultdict(int))   # (prov,X) -> code -> n
    ages = defaultdict(list)                      # prov -> age_bars

    with open(path, newline="") as fh:
        for row in csv.DictReader(fh):
            prov = int(row["provider"])
            ages[prov].append(float(row["age_bars"]))
            for X, col in XCOL.items():
                cnt[(prov, X)][int(row[col])] += 1

    print(f"\n{'='*78}\nE-MT5-022 — {label}\nfile: {path}\n{'='*78}")
    print(f"null p0 = 1/3 = {P0*100:.3f}%   "
          f"exploitability floor (0.04R spread) = 34.67%\n")
    hdr = (f"{'provider':<12} {'X':>3} {'n':>7} {'k(+2R)':>7} {'p̂':>8} "
           f"{'z':>8} {'95% CI (Wilson)':>22} {'unres':>7} {'nostop':>7}")
    print(hdr); print("-" * len(hdr))

    out = {}
    for prov in sorted(PROV):
        for X in (1, 5, 15):
            c = cnt[(prov, X)]
            k, s = c.get(1, 0), c.get(2, 0)
            n = k + s
            if n == 0:
                print(f"{PROV[prov]:<12} {X:>3} {0:>7} {'-':>7} {'-':>8}")
                continue
            p = k / n
            z = (p - P0) / math.sqrt(P0 * (1 - P0) / n)
            lo, hi = wilson(k, n)
            print(f"{PROV[prov]:<12} {X:>3} {n:>7} {k:>7} {p*100:>7.2f}% "
                  f"{z:>8.2f} {'['+format(lo*100,'.2f')+'%, '+format(hi*100,'.2f')+'%]':>22} "
                  f"{c.get(3,0):>7} {c.get(4,0):>7}")
            out[(prov, X)] = (n, k, p, z, lo, hi)
        if prov in ages and ages[prov]:
            a = sorted(ages[prov])
            print(f"{'':<12}     median level age = {a[len(a)//2]:.0f} M5 bars "
                  f"(n_signals={len(a)})")
        print()

    # primary endpoint, fixed in the pre-registration: H4 at X=5
    print("=" * 78)
    print("PRIMARY ENDPOINT (pre-registered): pivot H4, X=5")
    if (2, 5) in out:
        n, k, p, z, lo, hi = out[(2, 5)]
        print(f"  n={n}  k={k}  p̂={p*100:.2f}%  z={z:+.2f}  "
              f"95% CI [{lo*100:.2f}%, {hi*100:.2f}%]")
        print(f"  prediction was: H4 will NOT exceed 33.333%  ->  "
              f"{'HELD' if p <= P0 else 'VIOLATED'}")
        sig05 = abs(z) > 1.96
        print(f"  significant at alpha=.05 (|z|>1.96): {'YES' if sig05 else 'NO'}")
        print(f"  exploitable (p̂ >= 34.67%):            "
              f"{'YES' if p >= 0.3467 else 'NO'}")
        if p > P0 and p < 0.3467:
            print("  -> region (C): real but NOT exploitable after real spread.")
        elif p >= 0.3467 and abs(z) > 2.77:
            print("  -> region (B): worth developing.")
        elif p <= P0:
            print("  -> region (A): at or below the null.")
        else:
            print("  -> region (C): underpowered / not significant.")
    print("=" * 78)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else "run")
