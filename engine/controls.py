"""
SPEC-LVL-001 v0.3 — adversarial control gates (Part C).

Runs C-NEG, C-POS, C-SEP-TP, C-SEP-SL through the SAME event engine and the
SAME verdict machinery that will process market data (I-14, I-16).

Two endpoints are evaluated on every replication:

  E2  the v0.3 two-component IUT   (Δ_R > 0  AND  Δ_PC > 0)
  E1  the C.6 fallback             (Δ_R > 0  only)

Gate criterion, per Part C.4: the empirical rate of SUPPORTED verdicts, compared
against the declared α. No "≈ 0" anywhere (I-29).
"""
from __future__ import annotations

import numpy as np

from . import spec, stats, synthetic

# calibrated to 3 x MDE under the geometry in spec.py; synthetic calibration
# only — never fitted against market data.
WORLDS = {
    "C-NEG":     dict(q_tp=0.00, q_sl=0.00),
    "C-POS":     dict(q_tp=0.13, q_sl=0.08),
    "C-SEP-TP":  dict(q_tp=0.13, q_sl=0.00),
    "C-SEP-SL":  dict(q_tp=0.00, q_sl=0.08),
}


def one_replication(world: str, rep: int, n_days: int, tpd: int, B: int) -> dict:
    seed = spec.SEED_BASE + 1000 * rep + hash(world) % 1000
    dc = synthetic.run_world(n_days, tpd, seed, **WORLDS[world])
    dR, dPC = stats.deltas(dc)
    bnd = stats.bca_bounds(dc, spec.ALPHA, B, seed + 1)

    sR = stats.component_state(*bnd["R"])
    sPC = stats.component_state(*bnd["PC"])
    v2 = stats.verdict_L2(sR, sPC)

    # E1 fallback: single component, same states, same thresholds
    v1 = ("SUPPORTED" if bnd["R"][0] > 0 else
          "REFUTED" if bnd["R"][1] < spec.MDE else "INCONCLUSIVE")

    return dict(delta_R=dR, delta_PC=dPC,
                lcb_R=bnd["R"][0], ucb_R=bnd["R"][1],
                lcb_PC=bnd["PC"][0],
                verdict_E2=v2, verdict_E1=v1,
                sup_E2=v2 in stats.SUPPORTED_SET, sup_E1=(v1 == "SUPPORTED"))


def run_gate(world: str, n_rep: int, n_days: int, tpd: int, B: int) -> dict:
    rows = [one_replication(world, r, n_days, tpd, B) for r in range(n_rep)]
    arr = lambda k: np.array([r[k] for r in rows], dtype=float)
    return dict(
        world=world, n_rep=n_rep,
        mean_dR=float(np.nanmean(arr("delta_R"))),
        mean_dPC=float(np.nanmean(arr("delta_PC"))),
        rate_E2=float(np.mean([r["sup_E2"] for r in rows])),
        rate_E1=float(np.mean([r["sup_E1"] for r in rows])),
    )
