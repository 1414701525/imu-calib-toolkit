from __future__ import annotations

import numpy as np

from imu_calib.utils.math_utils import check_matrix_well_conditioned


def split_km(Cg: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Split Cg according to the project convention Cg = I + Kg + Mg."""
    check_matrix_well_conditioned(Cg, "Cg")
    Kg = np.diag(np.diag(Cg) - 1.0)
    Mg = Cg - np.eye(3) - Kg
    return Kg, Mg
