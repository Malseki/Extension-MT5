"""
SPEC-LVL-001 v0.3 — inference and verdict engine.

Primary endpoint (Part E):
    H0 : Δ_R <= 0  ∪  Δ_PC <= 0        (union)
    H1 : Δ_R >  0  ∩  Δ_PC >  0        (intersection)

Procedure: INTERSECTION-UNION TEST. Reject H0 iff both one-sided lower BCa
bounds exceed 0 at level α. By Berger's IUT theorem the level is <= α with no
further correction.

Phi_hat = min(Δ_R, Δ_PC) is REPORTED ONLY (I-30). It is never the test
statistic: the bootstrap is inconsistent for min(θ1,θ2) at θ1=θ2 (X-01).

Uncertainty: cluster block bootstrap over UTC days, BCa with cluster jackknife
acceleration.
"""
from __future__ import annotations

import math
import numpy as np

from . import spec

# ── normal cdf / quantile without scipy ─────────────────────────────────────
def _phi(x: float) -> float:
    return 0.5 * (1.0 + math.erf(x / math.sqrt(2.0)))


_A = (-3.969683028665376e+01, 2.209460984245205e+02, -2.759285104469687e+02,
      1.383577518672690e+02, -3.066479806614716e+01, 2.506628277459239e+00)
_B = (-5.447609879822406e+01, 1.615858368580409e+02, -1.556989798598866e+02,
      6.680131188771972e+01, -1.328068155288572e+01)
_C = (-7.784894002430293e-03, -3.223964580411365e-01, -2.400758277161838e+00,
      -2.549732539343734e+00, 4.374664141464968e+00, 2.938163982698783e+00)
_D = (7.784695709041462e-03, 3.224671290700398e-01, 2.445134137142996e+00,
      3.754408661907416e+00)


def _phi_inv(p: float) -> float:
    """Acklam's inverse normal CDF. Accurate to ~1.15e-9."""
    if p <= 0.0:
        return -np.inf
    if p >= 1.0:
        return np.inf
    pl = 0.02425
    if p < pl:
        q = math.sqrt(-2 * math.log(p))
        return (((((_C[0] * q + _C[1]) * q + _C[2]) * q + _C[3]) * q + _C[4]) * q + _C[5]) / \
               ((((_D[0] * q + _D[1]) * q + _D[2]) * q + _D[3]) * q + 1)
    if p > 1 - pl:
        q = math.sqrt(-2 * math.log(1 - p))
        return -(((((_C[0] * q + _C[1]) * q + _C[2]) * q + _C[3]) * q + _C[4]) * q + _C[5]) / \
               ((((_D[0] * q + _D[1]) * q + _D[2]) * q + _D[3]) * q + 1)
    q = p - 0.5
    r = q * q
    return (((((_A[0] * r + _A[1]) * r + _A[2]) * r + _A[3]) * r + _A[4]) * r + _A[5]) * q / \
           (((((_B[0] * r + _B[1]) * r + _B[2]) * r + _B[3]) * r + _B[4]) * r + 1)


# ── per-day sufficient statistics ───────────────────────────────────────────
def day_counts(events: np.ndarray, day_id: np.ndarray) -> np.ndarray:
    """
    Collapse events to per-day counts. Returns (D, 6) int64:
        [focal_R, focal_PR, focal_PC, ctrl_R, ctrl_PR, ctrl_PC]
    Only RESOLVED outcomes enter (I-23). UNRESOLVED / SKIPPED_* are dropped here
    and accounted separately.
    """
    from .spec import REVERSAL, PEN_REJECT, PEN_CONTINUE, CLS_FOCAL

    keep = np.isin(events[:, 5], spec.RESOLVED)
    ev, dd = events[keep], day_id[keep]
    if len(ev) == 0:
        return np.zeros((0, 6), dtype=np.int64)

    days, inv = np.unique(dd, return_inverse=True)
    D = len(days)
    out = np.zeros((D, 6), dtype=np.int64)
    focal = ev[:, 2] == CLS_FOCAL
    for cat, col in ((REVERSAL, 0), (PEN_REJECT, 1), (PEN_CONTINUE, 2)):
        m = ev[:, 5] == cat
        out[:, col] = np.bincount(inv[m & focal], minlength=D)
        out[:, col + 3] = np.bincount(inv[m & ~focal], minlength=D)
    return out


def _deltas_from_totals(tot: np.ndarray) -> np.ndarray:
    """
    Vectorised. `tot` is (..., 6) of summed counts
    [f_R, f_PR, f_PC, c_R, c_PR, c_PC]. Returns (..., 2) = [Δ_R, Δ_PC].
    """
    tot = tot.astype(np.float64)
    nf = tot[..., 0:3].sum(axis=-1)
    nc = tot[..., 3:6].sum(axis=-1)
    with np.errstate(invalid="ignore", divide="ignore"):
        pR_f, pC_f = tot[..., 0] / nf, tot[..., 2] / nf
        pR_c, pC_c = tot[..., 3] / nc, tot[..., 5] / nc
    out = np.stack([pR_f - pR_c, pC_f - pC_c], axis=-1)
    bad = (nf == 0) | (nc == 0)
    out[bad] = np.nan
    return out


def deltas(dc: np.ndarray) -> tuple[float, float]:
    """Δ_R and Δ_PC from per-day counts. Unconditional proportions (Part C.2)."""
    if len(dc) == 0:
        return float("nan"), float("nan")
    d = _deltas_from_totals(dc.sum(axis=0))
    return float(d[0]), float(d[1])


# ── cluster block bootstrap, BCa ────────────────────────────────────────────
def bca_bounds(dc: np.ndarray, alpha: float, B: int, seed: int
               ) -> dict[str, tuple[float, float]]:
    """
    One-sided BCa bounds at level `alpha` for Δ_R and Δ_PC.
    Resampling unit = day (cluster). Acceleration by cluster jackknife.
    Returns {"R": (lcb, ucb), "PC": (lcb, ucb)}.
    """
    D = len(dc)
    if D < 2:
        nan = (float("nan"), float("nan"))
        return {"R": nan, "PC": nan}

    theta_hat = deltas(dc)
    rng = np.random.default_rng(seed)

    # vectorised cluster bootstrap: resample whole days, sum, then compute deltas
    idx = rng.integers(0, D, size=(B, D))
    boot_tot = dc[idx].sum(axis=1)            # (B, 6)
    boot = _deltas_from_totals(boot_tot)      # (B, 2)

    # cluster jackknife for acceleration: leave-one-day-out
    total = dc.sum(axis=0)
    jack = _deltas_from_totals(total[None, :] - dc)   # (D, 2)

    res = {}
    for j, name in enumerate(("R", "PC")):
        th = theta_hat[j]
        bj = boot[:, j]
        bj = bj[~np.isnan(bj)]
        if len(bj) < 100 or math.isnan(th):
            res[name] = (float("nan"), float("nan"))
            continue

        prop = np.mean(bj < th)
        prop = min(max(prop, 1.0 / len(bj)), 1.0 - 1.0 / len(bj))
        z0 = _phi_inv(prop)

        jm = jack[:, j]
        jm = jm[~np.isnan(jm)]
        d = jm.mean() - jm
        denom = 6.0 * (np.sum(d ** 2) ** 1.5)
        a = float(np.sum(d ** 3) / denom) if denom > 0 else 0.0

        def adj(q):
            z = _phi_inv(q)
            zz = z0 + (z0 + z) / (1.0 - a * (z0 + z))
            return min(max(_phi(zz), 1e-6), 1 - 1e-6)

        lcb = float(np.quantile(bj, adj(alpha)))
        ucb = float(np.quantile(bj, adj(1.0 - alpha)))
        res[name] = (lcb, ucb)
    return res


# ── verdict engine (Part B) ─────────────────────────────────────────────────
RELEVANT, POS_SMALL, POS_UNCERT, EXCL_MDE, UNINFORM = range(5)
_STATE_NAME = {RELEVANT: "RELEVANT", POS_SMALL: "POSITIVE_SMALL",
               POS_UNCERT: "POSITIVE_UNCERTAIN", EXCL_MDE: "EXCLUDES_MDE",
               UNINFORM: "UNINFORMATIVE"}


def component_state(lcb: float, ucb: float, mde: float = spec.MDE) -> int:
    """The five-state partition of §B.3. Exhaustive and mutually exclusive."""
    if math.isnan(lcb) or math.isnan(ucb):
        return UNINFORM
    if lcb >= mde:
        return RELEVANT
    if lcb > 0.0:
        return POS_SMALL if ucb < mde else POS_UNCERT
    return EXCL_MDE if ucb < mde else UNINFORM


def verdict_L2(sR: int, sPC: int) -> str:
    """The §B.4 truth table. Pure function, zero free parameters (I-26)."""
    if sR == EXCL_MDE and sPC == EXCL_MDE:
        return "REFUTED_BOTH"
    if sR == EXCL_MDE or sPC == EXCL_MDE:
        return "REFUTED_RELEVANCE"
    if sR == UNINFORM or sPC == UNINFORM:
        return "INCONCLUSIVE"
    # both components have LCB > 0 here
    if sR == RELEVANT and sPC == RELEVANT:
        return "SUPPORTED_RELEVANT"
    if sR == POS_SMALL or sPC == POS_SMALL:
        return "BELOW_RELEVANCE"
    return "SUPPORTED_UNCERTAIN"


SUPPORTED_SET = {"SUPPORTED_RELEVANT", "SUPPORTED_UNCERTAIN"}


def evaluate(dc: np.ndarray, seed: int, alpha: float = spec.ALPHA,
             B: int = spec.BOOTSTRAP_B, mde: float = spec.MDE) -> dict:
    """Full L2 evaluation from per-day counts."""
    dR, dPC = deltas(dc)
    bnd = bca_bounds(dc, alpha, B, seed)
    sR = component_state(*bnd["R"], mde)
    sPC = component_state(*bnd["PC"], mde)
    return {
        "delta_R": dR, "delta_PC": dPC,
        "phi_hat": min(dR, dPC) if not (math.isnan(dR) or math.isnan(dPC)) else float("nan"),
        "ci_R": bnd["R"], "ci_PC": bnd["PC"],
        "state_R": _STATE_NAME[sR], "state_PC": _STATE_NAME[sPC],
        "verdict": verdict_L2(sR, sPC),
    }
