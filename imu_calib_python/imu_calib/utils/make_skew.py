from __future__ import annotations

import numpy as np

from .math_utils import as_vector3


def make_skew(v: np.ndarray) -> np.ndarray:
    """Construct a 3x3 skew-symmetric matrix from a 3-vector."""
    x, y, z = as_vector3(v, "v")
    return np.array(
        [
            [0.0, -z, y],
            [z, 0.0, -x],
            [-y, x, 0.0],
        ],
        dtype=float,
    )
