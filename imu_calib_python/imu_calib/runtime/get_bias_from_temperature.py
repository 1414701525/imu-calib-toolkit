from __future__ import annotations

import numpy as np

from imu_calib.utils.math_utils import as_vector3


def get_bias_from_temperature(
    temp: np.ndarray | None,
    bias_const: np.ndarray,
    temp_model: dict | None = None,
    *,
    target_name: str = "bias",
) -> tuple[np.ndarray, dict]:
    """Evaluate a temperature-dependent 3-axis bias model with fallback."""

    bias_const = as_vector3(bias_const, "bias_const")
    if temp is None or np.asarray(temp).size == 0:
        return bias_const[None, :], {
            "valid": False,
            "used_temperature_model": False,
            "out_of_range": False,
            "message": f"Temperature vector not provided. Falling back to constant {target_name}.",
        }

    temp = np.asarray(temp, dtype=float).reshape(-1)
    N = temp.size
    bias_T = np.tile(bias_const, (N, 1))
    info = {
        "valid": False,
        "used_temperature_model": False,
        "out_of_range": False,
        "message": f"No valid temperature model. Falling back to constant {target_name}.",
    }
    if not temp_model or not isinstance(temp_model, dict):
        return bias_T, info
    if not temp_model.get("valid", False):
        if "message" in temp_model:
            info["message"] = str(temp_model.get("message", info["message"]))
        return bias_T, info

    temp_eval, range_info = _prepare_temperature_input(temp, temp_model)
    model_type = str(temp_model.get("type", "")).lower()
    if model_type == "poly":
        coeffs = np.asarray(
            temp_model.get("coeffs", temp_model.get("coeff", {}).get("poly_coeff", [])),
            dtype=float,
        )
        if coeffs.ndim != 2 or coeffs.shape[1] != 3:
            info["message"] = f"Temperature model coeffs must have shape (P, 3). Falling back to constant {target_name}."
            return bias_T, info
        dT = temp_eval - float(temp_model.get("reference_temperature", 0.0))
        bias_T = np.column_stack([np.polyval(coeffs[:, axis], dT) for axis in range(3)])
    elif model_type == "piecewise_linear":
        coeff = temp_model.get("coeff", {})
        breakpoints = np.asarray(temp_model.get("breakpoints", coeff.get("breakpoints", [])), dtype=float).reshape(-1)
        values = np.asarray(temp_model.get("values", coeff.get("values", [])), dtype=float)
        if values.shape != (breakpoints.size, 3):
            info["message"] = (
                f"Piecewise temperature model size mismatch. Falling back to constant {target_name}."
            )
            return bias_T, info
        bias_T = np.column_stack(
            [_interp_with_extrapolation(temp_eval, breakpoints, values[:, axis], temp_model) for axis in range(3)]
        )
    else:
        info["message"] = (
            f'Unsupported temperature model type "{temp_model.get("type", "")}". Falling back to constant {target_name}.'
        )
        return bias_T, info

    info["valid"] = True
    info["used_temperature_model"] = True
    info["out_of_range"] = bool(range_info["out_of_range"])
    info["message"] = range_info["message"] or f"Temperature-dependent {target_name}(T) evaluated successfully."
    return bias_T, info


def _prepare_temperature_input(temp: np.ndarray, temp_model: dict) -> tuple[np.ndarray, dict]:
    temp = np.asarray(temp, dtype=float).reshape(-1)
    temp_range = temp_model.get("temperature_range", [np.nan, np.nan])
    extrapolation_mode = str(temp_model.get("extrapolation_mode", "warn_and_clamp")).lower()
    if len(temp_range) != 2 or not np.all(np.isfinite(temp_range)):
        return temp, {"out_of_range": False, "message": ""}

    tmin = float(temp_range[0])
    tmax = float(temp_range[1])
    out_of_range = bool(np.any((temp < tmin) | (temp > tmax)))
    if not out_of_range:
        return temp, {"out_of_range": False, "message": ""}

    if extrapolation_mode == "clamp":
        return np.clip(temp, tmin, tmax), {"out_of_range": True, "message": "Input temperature was clamped to the fitted range."}
    if extrapolation_mode == "warn_and_clamp":
        return np.clip(temp, tmin, tmax), {
            "out_of_range": True,
            "message": "Input temperature exceeded the fitted range; values were clamped.",
        }
    if extrapolation_mode == "extrapolate":
        return temp, {"out_of_range": True, "message": "Input temperature exceeded the fitted range; model extrapolation was used."}
    return np.clip(temp, tmin, tmax), {
        "out_of_range": True,
        "message": f'Unknown extrapolation mode "{extrapolation_mode}"; values were clamped.',
    }


def _interp_with_extrapolation(x: np.ndarray, xp: np.ndarray, fp: np.ndarray, temp_model: dict) -> np.ndarray:
    mode = str(temp_model.get("extrapolation_mode", "warn_and_clamp")).lower()
    values = np.interp(x, xp, fp)
    if mode in {"clamp", "warn_and_clamp"} or xp.size < 2:
        return values

    slope_lo = (fp[1] - fp[0]) / (xp[1] - xp[0])
    slope_hi = (fp[-1] - fp[-2]) / (xp[-1] - xp[-2])
    below = x < xp[0]
    above = x > xp[-1]
    if np.any(below):
        values[below] = fp[0] + slope_lo * (x[below] - xp[0])
    if np.any(above):
        values[above] = fp[-1] + slope_hi * (x[above] - xp[-1])
    return values
