from __future__ import annotations

import numpy as np

from imu_calib.calib.split_km import split_km
from imu_calib.tasks.make_task_result import make_task_result


def run_split_km(Cg) -> dict:
    if Cg is None or np.asarray(Cg).size == 0:
        return make_task_result(
            False,
            "Cg is required for Kg/Mg split.",
            None,
            missing_inputs=["Cg"],
            meta={"task_name": "run_split_km"},
        )

    Kg, Mg = split_km(np.asarray(Cg, dtype=float))
    return make_task_result(
        True,
        "Kg/Mg split completed successfully.",
        {"Kg": Kg, "Mg": Mg},
        meta={"task_name": "run_split_km"},
    )
