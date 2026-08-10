"""
SPEC-LVL-001 v0.3 — sealed parameters.

Every constant here carries its governance status from Part G:
    F   FROZEN
    FT  FROZEN FOR THIS EXPERIMENT — FUTURE TUNABLE
    D   DERIVED / NON-TUNABLE (mathematical consequence)
    L   LOCKED BY EXISTING DECISION (DEC-LOCK-001)
    P   PROPOSED — human-approved 2026-08-09

No value in this module may be selected against market data. Any change is a
VARIANT: one unit of hypothesis budget, new preregistration, virgin data.
"""

# ── geometry ────────────────────────────────────────────────────────────────
GRID_PIPS       = 10      # FT  focal grid (Osler: "rates ending in 0")
FOCAL100_PIPS   = 100     # FT  strong focal class (Osler: "ending in 00")
U_PIPS          = 4       # FT  displacement threshold
u_PIPS          = 1       # FT  penetration threshold
CONTROL_PIPS    = 5       # D   forced: c-U>=1 and c+U<=g-1  =>  c=5

# levels (focal ∪ control) all lie on the 5-pip lattice
STEP_PIPS       = 5       # D   = CONTROL_PIPS, half the focal grid

# ── time ────────────────────────────────────────────────────────────────────
TIMEOUT_SEC     = 24 * 3600   # FT  race timeout, calendar time
GAP_SEC         = 3600        # FT  market gap: inter-tick interval > 1h

# ── H-INFO ──────────────────────────────────────────────────────────────────
HINFO_WINDOW_SEC = 24 * 3600  # FT
HINFO_WARMUP     = 250        # FT  SE(median) < 10% sigma  =>  n > 157
HINFO_MIN_COV    = 0.80       # FT  minimum M5 bar coverage
HINFO_QUANTILES  = 2          # FT
M5_BARS_PER_DAY  = 288        # D

# ── statistics ──────────────────────────────────────────────────────────────
MDE             = 0.02        # P   HD-3 approved
ALPHA           = 0.05 / 3    # F   HD-6 approved: Bonferroni over 3-hypothesis family
POWER           = 0.80        # F
BOOTSTRAP_B     = 10_000      # F
SEED_BASE       = 20260809    # F   sealed in preregistration

# ── adversarial controls ────────────────────────────────────────────────────
N_MC_SEP        = 500         # D   from inflation factor 2x (HD-8 approved)
SEP_INFLATION   = 2.0         # P   HD-8 approved
INJECT_MULT     = 3.0         # D   C-POS injects 3 x MDE

# ── power Monte Carlo ───────────────────────────────────────────────────────
MC_RHO_GRID     = (0.00, 0.05, 0.10, 0.20)          # P  HD-9 approved
MC_M_GRID       = (5, 10, 25, 50)                    # P  HD-9 approved
N_MC_POWER      = 2000                               # F
N_LADDER        = (12_000, 18_000, 25_000, 35_000, 50_000, 70_000, 100_000)  # F

# ── outcome categories ──────────────────────────────────────────────────────
REVERSAL      = 0   # touch race resolved back to L-U
PEN_REJECT    = 1   # penetrated, cross race resolved to L-u
PEN_CONTINUE  = 2   # penetrated, cross race resolved to L+U
UNRESOLVED    = 3   # timeout
SKIPPED_GAP   = 4   # market gap during either race
SKIPPED_DISORD = 5  # out-of-order tick

RESOLVED = (REVERSAL, PEN_REJECT, PEN_CONTINUE)   # the only denominator members

# ── level classes ───────────────────────────────────────────────────────────
CLS_CONTROL = 0
CLS_FOCAL   = 1

# ── H-INFO strata ───────────────────────────────────────────────────────────
HI_LOW = 0
HI_HIGH = 1
HI_UNCLASSIFIED = 2


def pip_points(digits: int) -> int:
    """1 pip expressed in integer points. Derived from the symbol, never chosen."""
    if digits in (3, 5):
        return 10
    if digits in (2, 4):
        return 1
    raise ValueError(f"unsupported Digits={digits}")


class Geometry:
    """Integer point geometry for one symbol. No floating point anywhere."""

    def __init__(self, digits: int):
        self.digits = digits
        self.pip = pip_points(digits)
        self.step = STEP_PIPS * self.pip        # spacing of the level lattice
        self.grid = GRID_PIPS * self.pip
        self.focal100 = FOCAL100_PIPS * self.pip
        self.U = U_PIPS * self.pip
        self.u = u_PIPS * self.pip
        # I-09 / I-10 verified at construction
        assert self.U < self.grid // 2, "I-09 violated: U >= g/2"
        assert CONTROL_PIPS * self.pip - self.U >= 1, "I-10 violated (lower)"
        assert CONTROL_PIPS * self.pip + self.U <= self.grid - 1, "I-10 violated (upper)"

    def level_class(self, level_points: int) -> int:
        """FOCAL iff the level is a multiple of the focal grid. Pure integer test."""
        return CLS_FOCAL if level_points % self.grid == 0 else CLS_CONTROL

    def is_focal100(self, level_points: int) -> bool:
        return level_points % self.focal100 == 0
