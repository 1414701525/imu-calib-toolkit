from __future__ import annotations

import json
import pickle
from pathlib import Path

import numpy as np

from imu_calib.runtime.result_summary import build_summary_payload


def save_calibration_results(
    results,
    output_dir: str | Path,
    *,
    save_pickle: bool = True,
    save_json_summary: bool = True,
    save_npz: bool = True,
) -> dict[str, str]:
    """Save calibration results to a directory.

    Outputs:
    - calibration_results.pkl : full Python object graph for same-project reuse
    - calibration_summary.json: lightweight human-readable summary
    - calibration_arrays.npz  : key arrays for numerical inspection
    """

    root = Path(output_dir).expanduser().resolve()
    root.mkdir(parents=True, exist_ok=True)

    written: dict[str, str] = {"root": str(root)}

    if save_pickle:
        pickle_path = root / "calibration_results.pkl"
        with pickle_path.open("wb") as f:
            pickle.dump(results, f)
        written["pickle"] = str(pickle_path)

    if save_json_summary:
        summary_path = root / "calibration_summary.json"
        payload = build_summary_payload(results)
        summary_path.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")
        written["json_summary"] = str(summary_path)

    if save_npz:
        npz_path = root / "calibration_arrays.npz"
        acc = results.calib.get("acc", {}) if getattr(results, "calib", None) else {}
        gyr = results.calib.get("gyr", {}) if getattr(results, "calib", None) else {}
        np.savez(
            npz_path,
            bg=_as_array(results.calib.get("bg") if getattr(results, "calib", None) else None),
            Ca=_as_array(acc.get("Ca")),
            ba=_as_array(acc.get("ba")),
            Sa=_as_array(acc.get("Sa")),
            Ma=_as_array(acc.get("Ma")),
            gravity_magnitude=_as_array(acc.get("gravity_magnitude")),
            Cg=_as_array(gyr.get("Cg")),
            Kg=_as_array(gyr.get("Kg")),
            Mg=_as_array(gyr.get("Mg")),
            Gg=_as_array(gyr.get("Gg")),
        )
        written["npz"] = str(npz_path)

    return written


def _as_array(value):
    if value is None:
        return np.asarray([])
    return np.asarray(value, dtype=float)
