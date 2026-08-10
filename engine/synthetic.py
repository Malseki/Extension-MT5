"""
SPEC-LVL-001 v0.3 — synthetic worlds for the adversarial controls.

Four worlds, all built on the SAME driftless integer random walk. They differ
only in which mechanism is injected:

    C-NEG       neither          -> Δ_R = 0,  Δ_PC = 0
    C-POS       both             -> Δ_R > 0,  Δ_PC > 0
    C-SEP-TP    take-profit only -> Δ_R > 0,  Δ_PC < 0     (Part C.2 theorem)
    C-SEP-SL    stop-loss only   -> Δ_R ~ 0,  Δ_PC > 0

The synthetic symbol uses Digits=4 so that 1 pip = 1 point. This is a property
of the synthetic instrument, not of the engine: the engine derives pip_points
from Digits exactly as it will for GBPUSD or USDJPY.

Mechanism injection acts ONLY on focal levels. Control levels always follow the
unmodified walk — that is what makes Δ a valid contrast.
"""
from __future__ import annotations

import numpy as np

from . import spec

DIGITS = 4              # synthetic symbol: 1 pip = 1 point
TICK_DT = 2             # seconds between synthetic ticks


def generate(n_ticks: int, seed: int, q_tp: float = 0.0, q_sl: float = 0.0,
             start: int = 10_000) -> tuple[np.ndarray, np.ndarray]:
    """
    Driftless +/-1 point random walk with optional focal mechanisms.

    q_tp : probability that, standing exactly ON a focal level, the next step is
           reversed against the direction of arrival  (take-profit absorption)
    q_sl : probability that, standing strictly between L+u and L+U beyond a focal
           level, the next step continues the penetration  (stop cascade)

    Both mechanisms are local and memoryless; neither can be observed by the
    engine, which sees only the tick stream.
    """
    rng = np.random.default_rng(seed)
    g = spec.Geometry(DIGITS)
    grid, U, u = g.grid, g.U, g.u

    p = np.empty(n_ticks, dtype=np.int64)
    t = (np.arange(n_ticks, dtype=np.int64) * TICK_DT)

    x = start
    prev_step = 1
    rnd = rng.random(n_ticks)
    coin = rng.random(n_ticks)

    for k in range(n_ticks):
        # distance to nearest focal level
        r = x % grid
        d = r if r <= grid // 2 else r - grid      # signed offset from focal, in points

        step = 1 if coin[k] < 0.5 else -1

        if q_tp > 0.0 and d == 0:
            # exactly on a focal level: absorb with probability q_tp
            if rnd[k] < q_tp:
                step = -prev_step
        elif q_sl > 0.0 and 0 < abs(d) < U and abs(d) >= u:
            # inside the stop band beyond a focal level: continue with prob q_sl
            if rnd[k] < q_sl:
                step = 1 if d > 0 else -1

        x += step
        prev_step = step
        p[k] = x

    return t, p


def day_ids(t: np.ndarray, day_sec: int = 86_400) -> np.ndarray:
    """UTC-day cluster id. The bootstrap resampling unit (I-12)."""
    return t // day_sec


def run_world(n_days: int, ticks_per_day: int, seed: int,
              q_tp: float = 0.0, q_sl: float = 0.0):
    """
    Generate `n_days` independent daily walks and run the event engine on each.

    Independent days give the bootstrap genuine clusters; events within a day
    share one trajectory, which is precisely the intra-cluster correlation the
    design effect must absorb. Returns per-day count matrix (D, 6).
    """
    from . import events, stats

    rng = np.random.default_rng(seed)
    day_seeds = rng.integers(0, 2**31 - 1, size=n_days)
    rows = []
    for d in range(n_days):
        t, p = generate(ticks_per_day, int(day_seeds[d]), q_tp, q_sl)
        ev = events.run(t, p, DIGITS)
        if len(ev) == 0:
            rows.append(np.zeros(6, dtype=np.int64))
            continue
        dc = stats.day_counts(ev, np.zeros(len(ev), dtype=np.int64))
        rows.append(dc[0] if len(dc) else np.zeros(6, dtype=np.int64))
    return np.array(rows, dtype=np.int64)
