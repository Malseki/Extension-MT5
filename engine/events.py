"""
SPEC-LVL-001 v0.3 — event engine.

Consumes a tick stream (t_seconds:int64, bid_points:int64) and emits approach
events with their unconditional outcome category.

The stream may be synthetic or real: there is NO branch on data origin (I-14).
No interpolation between ticks ever occurs (I-17).
All level arithmetic is integer (I-08).

Overshoot semantics implement cases C0..C8 of SPEC-LVL-001 §9bis literally.
"""
from __future__ import annotations

import numpy as np

from . import spec
from .spec import Geometry

SIDE_UP, SIDE_DOWN = 1, -1

# event record fields
F_LEVEL, F_SIDE, F_CLASS, F_F100, F_T, F_OUTCOME, F_OVERSHOOT = range(7)


class _Race:
    __slots__ = ("level", "side", "cls", "f100", "t0", "phase", "deadline", "overshoot")

    def __init__(self, level, side, cls, f100, t0, timeout):
        self.level = level
        self.side = side
        self.cls = cls
        self.f100 = f100
        self.t0 = t0
        self.phase = 0            # 0 = touch race, 1 = cross race
        self.deadline = t0 + timeout
        self.overshoot = 0        # 0 none, 1 OVERSHOOT_ENTRY, 2 OVERSHOOT_FULL


def run(ticks_t: np.ndarray, ticks_p: np.ndarray, digits: int,
        timeout_sec: int = spec.TIMEOUT_SEC,
        gap_sec: int = spec.GAP_SEC) -> np.ndarray:
    """
    Returns an (N, 7) int64 array of events:
        level, side, class, is_focal100, t_trigger, outcome, overshoot_flag

    outcome ∈ {REVERSAL, PEN_REJECT, PEN_CONTINUE, UNRESOLVED,
               SKIPPED_GAP, SKIPPED_DISORD}
    """
    g = Geometry(digits)
    step, U, u = g.step, g.U, g.u

    out: list[tuple] = []
    active: dict[tuple[int, int], _Race] = {}     # (level, side) -> race
    armed_up: dict[int, bool] = {}
    armed_dn: dict[int, bool] = {}

    n = len(ticks_t)
    if n == 0:
        return np.empty((0, 7), dtype=np.int64)

    prev_t = ticks_t[0]
    prev_p = ticks_p[0]

    for k in range(n):
        t = int(ticks_t[k])
        p = int(ticks_p[k])

        # ── temporal integrity ──────────────────────────────────────────────
        if t < prev_t:
            # out-of-order tick: every live race is voided (§10, I-09 accounting)
            for key, r in active.items():
                out.append((r.level, r.side, r.cls, r.f100, r.t0,
                            spec.SKIPPED_DISORD, r.overshoot))
            active.clear()
            prev_t, prev_p = t, p
            continue

        gap = (t - prev_t) > gap_sec
        if gap and active:
            # a market gap voids the ENTIRE event, not just the affected race
            for key, r in active.items():
                out.append((r.level, r.side, r.cls, r.f100, r.t0,
                            spec.SKIPPED_GAP, r.overshoot))
            active.clear()

        # ── 1. advance live races on this tick ──────────────────────────────
        if active:
            done = []
            for key, r in active.items():
                L, s = r.level, r.side
                if r.phase == 0:                              # TOUCH race
                    if s == SIDE_UP:
                        rev = p <= L - U
                        pen = p >= L + u
                        full = p >= L + U
                    else:
                        rev = p >= L + U
                        pen = p <= L - u
                        full = p <= L - U
                    if pen and full:                          # C3 / C5→C3
                        r.overshoot = max(r.overshoot, 2)
                        out.append((L, s, r.cls, r.f100, r.t0,
                                    spec.PEN_CONTINUE, r.overshoot))
                        done.append(key)
                    elif pen:                                 # C2 / C5
                        r.phase = 1
                        r.deadline = t + timeout_sec          # cross clock starts here
                    elif rev:                                 # C4
                        out.append((L, s, r.cls, r.f100, r.t0,
                                    spec.REVERSAL, r.overshoot))
                        done.append(key)
                    elif t > r.deadline:
                        out.append((L, s, r.cls, r.f100, r.t0,
                                    spec.UNRESOLVED, r.overshoot))
                        done.append(key)
                else:                                          # CROSS race
                    if s == SIDE_UP:
                        cont = p >= L + U
                        rej = p <= L - u
                    else:
                        cont = p <= L - U
                        rej = p >= L + u
                    if cont:                                   # C6
                        out.append((L, s, r.cls, r.f100, r.t0,
                                    spec.PEN_CONTINUE, r.overshoot))
                        done.append(key)
                    elif rej:                                  # C7
                        out.append((L, s, r.cls, r.f100, r.t0,
                                    spec.PEN_REJECT, r.overshoot))
                        done.append(key)
                    elif t > r.deadline:
                        out.append((L, s, r.cls, r.f100, r.t0,
                                    spec.UNRESOLVED, r.overshoot))
                        done.append(key)
            for key in done:
                del active[key]

        # ── 2. arm levels, then detect new approaches ───────────────────────
        base = (p // step) * step
        for j in (-3, -2, -1, 0, 1, 2, 3):
            L = base + j * step
            if p <= L - U:
                armed_up[L] = True
            if p >= L + U:
                armed_dn[L] = True

        # approaches are checked nearest-first (X-20: |L - prev_p| ascending)
        cand = sorted((base + j * step for j in (-3, -2, -1, 0, 1, 2, 3)),
                      key=lambda L: abs(L - prev_p))
        for L in cand:
            cls = g.level_class(L)
            f100 = 1 if g.is_focal100(L) else 0

            if p >= L and armed_up.get(L, False) and (L, SIDE_UP) not in active:
                armed_up[L] = False
                r = _Race(L, SIDE_UP, cls, f100, t, timeout_sec)
                if p >= L + U:                                # C8 → C3
                    r.overshoot = 2
                    out.append((L, SIDE_UP, cls, f100, t,
                                spec.PEN_CONTINUE, 2))
                elif p >= L + u:                              # C2
                    r.overshoot = 1
                    r.phase = 1
                    r.deadline = t + timeout_sec
                    active[(L, SIDE_UP)] = r
                else:                                         # C0 / C1
                    active[(L, SIDE_UP)] = r

            if p <= L and armed_dn.get(L, False) and (L, SIDE_DOWN) not in active:
                armed_dn[L] = False
                r = _Race(L, SIDE_DOWN, cls, f100, t, timeout_sec)
                if p <= L - U:
                    r.overshoot = 2
                    out.append((L, SIDE_DOWN, cls, f100, t,
                                spec.PEN_CONTINUE, 2))
                elif p <= L - u:
                    r.overshoot = 1
                    r.phase = 1
                    r.deadline = t + timeout_sec
                    active[(L, SIDE_DOWN)] = r
                else:
                    active[(L, SIDE_DOWN)] = r

        prev_t, prev_p = t, p

    # races still open at end of stream are UNRESOLVED
    for r in active.values():
        out.append((r.level, r.side, r.cls, r.f100, r.t0,
                    spec.UNRESOLVED, r.overshoot))

    if not out:
        return np.empty((0, 7), dtype=np.int64)
    return np.array(out, dtype=np.int64)
