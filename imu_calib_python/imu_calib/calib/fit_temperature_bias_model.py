from __future__ import annotations

import math

import numpy as np
from scipy.optimize import least_squares

from imu_calib.calib.extract_static_pose_means import extract_static_pose_means
from imu_calib.models.data_structures import StaticData
from imu_calib.runtime.default_calib_options import default_calib_options
from imu_calib.utils.exceptions import ImuCalibError
from imu_calib.utils.math_utils import as_column, as_matrix_n3, as_vector3


def fit_temperature_bias_model(
    static_gyro: np.ndarray,
    temp: np.ndarray | None,
    *,
    method: str | None = None,
    min_temp_span: float | None = None,
    min_samples: int | None = None,
) -> dict:
    """Backward-compatible wrapper for gyro bg(T) fitting.

    Historical callers expect this function to return the gyro-only temperature
    bias model. The new temperature workflow keeps that behavior while exposing
    clearer split interfaces for gyro / accel / combined fitting.
    """

    return fit_gyro_temperature_bias_model(
        static_gyro,
        temp,
        method=method,
        min_temp_span=min_temp_span,
        min_samples=min_samples,
    )


def fit_temperature_bias_models(
    *,
    static_gyro: np.ndarray | None = None,
    static_acc: np.ndarray | None = None,
    temp: np.ndarray | None = None,
    static_data: StaticData | None = None,
    Ca: np.ndarray | None = None,
    ba0: np.ndarray | None = None,
    gravity_magnitude: float | None = None,
    method: str | None = None,
    reference_temperature_mode: str | float | None = None,
    extrapolation_mode: str | None = None,
    min_temp_span: float | None = None,
    min_samples: int | None = None,
    bin_width_degC: float | None = None,
    min_bin_samples: int | None = None,
    min_valid_bins: int | None = None,
    acc_min_bin_pose_count: int | None = None,
    acc_min_pose_rank: int | None = None,
    options: dict | None = None,
    fit_gyro: bool = True,
    fit_acc: bool = True,
) -> dict:
    """Fit gyro and/or accel temperature bias models.

    Two-layer architecture:
    1. Estimate discrete per-temperature bias samples.
    2. Fit continuous bg(T) / ba(T) models from those samples.
    """

    defaults = _temperature_options(options)
    method = defaults["method"] if method is None else str(method)
    reference_temperature_mode = (
        defaults["reference_temperature_mode"] if reference_temperature_mode is None else reference_temperature_mode
    )
    extrapolation_mode = defaults["extrapolation_mode"] if extrapolation_mode is None else str(extrapolation_mode)
    min_temp_span = defaults["min_temp_span"] if min_temp_span is None else float(min_temp_span)
    min_samples = defaults["min_samples"] if min_samples is None else int(min_samples)
    bin_width_degC = defaults["bin_width_degC"] if bin_width_degC is None else float(bin_width_degC)
    min_bin_samples = defaults["min_bin_samples"] if min_bin_samples is None else int(min_bin_samples)
    min_valid_bins = defaults["min_valid_bins"] if min_valid_bins is None else int(min_valid_bins)
    acc_min_bin_pose_count = (
        defaults["acc_min_bin_pose_count"] if acc_min_bin_pose_count is None else int(acc_min_bin_pose_count)
    )
    acc_min_pose_rank = defaults["acc_min_pose_rank"] if acc_min_pose_rank is None else int(acc_min_pose_rank)

    reference_temperature = _resolve_reference_temperature(temp, reference_temperature_mode)
    temp_range = _resolve_temperature_range(temp)

    result = {
        "reference_temperature": reference_temperature,
        "temperature_range": temp_range,
        "extrapolation_mode": extrapolation_mode,
        "gyro": _make_invalid_model("bg", "Gyro temperature model was not requested."),
        "acc": _make_invalid_model("ba", "Accel temperature model was not requested."),
        "message": "Temperature model fitting completed.",
    }

    if fit_gyro:
        result["gyro"] = fit_gyro_temperature_bias_model(
            static_gyro,
            temp,
            method=method,
            reference_temperature=reference_temperature,
            extrapolation_mode=extrapolation_mode,
            min_temp_span=min_temp_span,
            min_samples=min_samples,
            bin_width_degC=bin_width_degC,
            min_bin_samples=min_bin_samples,
            min_valid_bins=min_valid_bins,
        )

    if fit_acc:
        result["acc"] = fit_accel_temperature_bias_model(
            static_acc=static_acc,
            temp=temp,
            static_data=static_data,
            Ca=Ca,
            ba0=ba0,
            gravity_magnitude=gravity_magnitude,
            method=method,
            reference_temperature=reference_temperature,
            extrapolation_mode=extrapolation_mode,
            min_temp_span=min_temp_span,
            min_samples=min_samples,
            bin_width_degC=bin_width_degC,
            min_bin_samples=min_bin_samples,
            min_valid_bins=min_valid_bins,
            min_bin_pose_count=acc_min_bin_pose_count,
            min_pose_rank=acc_min_pose_rank,
            options=options,
        )

    return result


def fit_gyro_temperature_bias_model(
    static_gyro: np.ndarray | None,
    temp: np.ndarray | None,
    *,
    method: str | None = None,
    reference_temperature: float | None = None,
    extrapolation_mode: str | None = None,
    min_temp_span: float | None = None,
    min_samples: int | None = None,
    bin_width_degC: float | None = None,
    min_bin_samples: int | None = None,
    min_valid_bins: int | None = None,
    options: dict | None = None,
) -> dict:
    """Fit bg(T) from static gyro measurements via temperature-bin means."""

    defaults = _temperature_options(options)
    method = defaults["method"] if method is None else str(method)
    extrapolation_mode = defaults["extrapolation_mode"] if extrapolation_mode is None else str(extrapolation_mode)
    min_temp_span = defaults["min_temp_span"] if min_temp_span is None else float(min_temp_span)
    min_samples = defaults["min_samples"] if min_samples is None else int(min_samples)
    bin_width_degC = defaults["bin_width_degC"] if bin_width_degC is None else float(bin_width_degC)
    min_bin_samples = defaults["min_bin_samples"] if min_bin_samples is None else int(min_bin_samples)
    min_valid_bins = defaults["min_valid_bins"] if min_valid_bins is None else int(min_valid_bins)

    if static_gyro is None:
        return _make_invalid_model("bg", "static.gyro is required for gyro temperature fitting.")
    gyro = as_matrix_n3(static_gyro, "static_gyro")
    if temp is None or np.asarray(temp).size == 0:
        return _make_invalid_model("bg", "Temperature data not provided.")

    temp_vec = as_column(np.asarray(temp, dtype=float), "temp")
    if temp_vec.size != gyro.shape[0]:
        raise ImuCalibError("temp length must match static_gyro length.")
    if reference_temperature is None:
        reference_temperature = _resolve_reference_temperature(temp_vec, defaults["reference_temperature_mode"])

    if gyro.shape[0] < min_samples:
        model = _make_invalid_model("bg", f"Not enough samples for temperature fit. Need at least {min_samples}.")
        model["metrics"]["num_points"] = int(gyro.shape[0])
        model["metrics"]["temp_span"] = float(np.max(temp_vec) - np.min(temp_vec))
        return model

    discrete = _estimate_gyro_bias_samples(
        gyro,
        temp_vec,
        bin_width_degC=bin_width_degC,
        min_bin_samples=min_bin_samples,
    )
    return _fit_bias_model_from_samples(
        discrete["temperatures"],
        discrete["bias"],
        target="bg",
        method=method,
        reference_temperature=reference_temperature,
        extrapolation_mode=extrapolation_mode,
        min_temp_span=min_temp_span,
        min_valid_bins=min_valid_bins,
        discrete_meta=discrete["meta"],
    )


def fit_accel_temperature_bias_model(
    *,
    static_acc: np.ndarray | None = None,
    temp: np.ndarray | None = None,
    static_data: StaticData | None = None,
    Ca: np.ndarray | None = None,
    ba0: np.ndarray | None = None,
    gravity_magnitude: float | None = None,
    method: str | None = None,
    reference_temperature: float | None = None,
    extrapolation_mode: str | None = None,
    min_temp_span: float | None = None,
    min_samples: int | None = None,
    bin_width_degC: float | None = None,
    min_bin_samples: int | None = None,
    min_valid_bins: int | None = None,
    min_bin_pose_count: int | None = None,
    min_pose_rank: int | None = None,
    options: dict | None = None,
) -> dict:
    """Fit ba(T) with fixed Ca and per-temperature multi-pose bias estimation."""

    defaults = _temperature_options(options)
    acc_defaults = _acc_calibration_options(options)
    method = defaults["method"] if method is None else str(method)
    extrapolation_mode = defaults["extrapolation_mode"] if extrapolation_mode is None else str(extrapolation_mode)
    min_temp_span = defaults["min_temp_span"] if min_temp_span is None else float(min_temp_span)
    min_samples = defaults["min_samples"] if min_samples is None else int(min_samples)
    bin_width_degC = defaults["bin_width_degC"] if bin_width_degC is None else float(bin_width_degC)
    min_bin_samples = defaults["min_bin_samples"] if min_bin_samples is None else int(min_bin_samples)
    min_valid_bins = defaults["min_valid_bins"] if min_valid_bins is None else int(min_valid_bins)
    min_bin_pose_count = defaults["acc_min_bin_pose_count"] if min_bin_pose_count is None else int(min_bin_pose_count)
    min_pose_rank = defaults["acc_min_pose_rank"] if min_pose_rank is None else int(min_pose_rank)
    gravity_magnitude = (
        acc_defaults["gravity_magnitude"] if gravity_magnitude is None else float(gravity_magnitude)
    )

    if Ca is None:
        return _make_invalid_model("ba", "Fixed Ca is required for accel temperature fitting.")
    Ca = np.asarray(Ca, dtype=float)
    if Ca.shape != (3, 3):
        raise ImuCalibError("Ca must have shape (3, 3).")

    if static_data is None:
        if static_acc is None or temp is None:
            return _make_invalid_model(
                "ba",
                "static.acc, static.temp, and fixed Ca are required for accel temperature fitting.",
            )
        static_acc = as_matrix_n3(static_acc, "static_acc")
        temp_vec = as_column(np.asarray(temp, dtype=float), "temp")
        if static_acc.shape[0] != temp_vec.size:
            raise ImuCalibError("temp length must match static_acc length.")
        static_data = StaticData(t=np.arange(static_acc.shape[0], dtype=float), gyro=np.zeros_like(static_acc), acc=static_acc, temp=temp_vec)
    elif static_data.temp is None:
        return _make_invalid_model("ba", "Temperature data not provided.")

    if static_data.acc.shape[0] < min_samples:
        model = _make_invalid_model("ba", f"Not enough samples for temperature fit. Need at least {min_samples}.")
        model["metrics"]["num_points"] = int(static_data.acc.shape[0])
        if static_data.temp is not None:
            model["metrics"]["temp_span"] = float(np.max(static_data.temp) - np.min(static_data.temp))
        return model

    if reference_temperature is None:
        reference_temperature = _resolve_reference_temperature(static_data.temp, defaults["reference_temperature_mode"])

    pose_means, extraction_info = extract_static_pose_means(static_data, options=options)
    discrete = _estimate_accel_bias_samples(
        extraction_info["segment_rows"],
        Ca=Ca,
        gravity_magnitude=gravity_magnitude,
        ba0=np.zeros(3, dtype=float) if ba0 is None else as_vector3(ba0, "ba0"),
        bin_width_degC=bin_width_degC,
        min_bin_samples=min_bin_samples,
        min_bin_pose_count=min_bin_pose_count,
        min_pose_rank=min_pose_rank,
        solver_options=defaults,
    )
    model = _fit_bias_model_from_samples(
        discrete["temperatures"],
        discrete["bias"],
        target="ba",
        method=method,
        reference_temperature=reference_temperature,
        extrapolation_mode=extrapolation_mode,
        min_temp_span=min_temp_span,
        min_valid_bins=min_valid_bins,
        discrete_meta=discrete["meta"],
    )
    model["static_segment_extraction"] = extraction_info
    model["metrics"]["num_static_segments"] = int(extraction_info.get("num_segments", 0))
    model["reference_ba"] = np.zeros(3, dtype=float) if ba0 is None else as_vector3(ba0, "ba0")
    return model


def _estimate_gyro_bias_samples(
    gyro: np.ndarray,
    temp: np.ndarray,
    *,
    bin_width_degC: float,
    min_bin_samples: int,
) -> dict:
    samples = []
    skipped = []
    for bin_info in _make_temperature_bins(temp, bin_width_degC):
        mask = bin_info["mask"]
        count = int(np.count_nonzero(mask))
        if count < min_bin_samples:
            skipped.append({**bin_info, "num_samples": count, "reason": "too_few_samples"})
            continue
        samples.append(
            {
                "temperature": float(np.mean(temp[mask])),
                "bias": np.mean(gyro[mask, :], axis=0),
                "num_samples": count,
                "temperature_range": [float(np.min(temp[mask])), float(np.max(temp[mask]))],
            }
        )
    temperatures = np.array([item["temperature"] for item in samples], dtype=float)
    bias = np.vstack([item["bias"] for item in samples]) if samples else np.zeros((0, 3), dtype=float)
    meta = {"bins": samples, "skipped_bins": skipped}
    return {"temperatures": temperatures, "bias": bias, "meta": meta}


def _estimate_accel_bias_samples(
    segment_rows: list[dict],
    *,
    Ca: np.ndarray,
    gravity_magnitude: float,
    ba0: np.ndarray,
    bin_width_degC: float,
    min_bin_samples: int,
    min_bin_pose_count: int,
    min_pose_rank: int,
    solver_options: dict,
) -> dict:
    if not segment_rows:
        return {"temperatures": np.zeros(0), "bias": np.zeros((0, 3)), "meta": {"bins": [], "skipped_bins": []}}

    temps = np.array([row["temp_mean"] for row in segment_rows if row.get("temp_mean") is not None], dtype=float)
    if temps.size == 0:
        return {"temperatures": np.zeros(0), "bias": np.zeros((0, 3)), "meta": {"bins": [], "skipped_bins": []}}

    samples = []
    skipped = []
    row_temps = np.array([row.get("temp_mean", np.nan) for row in segment_rows], dtype=float)
    for bin_info in _make_temperature_bins(temps, bin_width_degC):
        mask_rows = np.isfinite(row_temps) & (row_temps >= bin_info["lower"]) & (row_temps < bin_info["upper"])
        selected = [row for row, keep in zip(segment_rows, mask_rows) if keep]
        count = len(selected)
        if count < max(min_bin_samples, min_bin_pose_count):
            skipped.append({**bin_info, "num_samples": count, "reason": "too_few_pose_samples"})
            continue

        raw_means = np.vstack([np.asarray(row["acc_mean"], dtype=float).reshape(3) for row in selected])
        pose_rank = int(np.linalg.matrix_rank(raw_means - raw_means.mean(axis=0, keepdims=True)))
        if pose_rank < min_pose_rank:
            skipped.append({**bin_info, "num_samples": count, "pose_rank": pose_rank, "reason": "insufficient_pose_diversity"})
            continue

        b_hat, metrics = _estimate_accel_bias_for_bin(
            raw_means,
            Ca=Ca,
            gravity_magnitude=gravity_magnitude,
            b0=ba0,
            solver_options=solver_options,
        )
        if not metrics["success"]:
            skipped.append({**bin_info, "num_samples": count, "pose_rank": pose_rank, "reason": metrics["message"]})
            continue

        samples.append(
            {
                "temperature": float(np.mean([row["temp_mean"] for row in selected])),
                "bias": b_hat,
                "num_samples": count,
                "pose_rank": pose_rank,
                "rmse": metrics["rmse"],
                "max_abs_residual": metrics["max_abs_residual"],
                "temperature_range": [
                    float(min(row["temp_mean"] for row in selected)),
                    float(max(row["temp_mean"] for row in selected)),
                ],
            }
        )

    temperatures = np.array([item["temperature"] for item in samples], dtype=float)
    bias = np.vstack([item["bias"] for item in samples]) if samples else np.zeros((0, 3), dtype=float)
    meta = {"bins": samples, "skipped_bins": skipped}
    return {"temperatures": temperatures, "bias": bias, "meta": meta}


def _estimate_accel_bias_for_bin(
    raw_means: np.ndarray,
    *,
    Ca: np.ndarray,
    gravity_magnitude: float,
    b0: np.ndarray,
    solver_options: dict,
) -> tuple[np.ndarray, dict]:
    def residual(theta: np.ndarray) -> np.ndarray:
        corrected = (Ca @ (raw_means - theta.reshape(1, 3)).T).T
        return np.linalg.norm(corrected, axis=1) - gravity_magnitude

    result = least_squares(
        residual,
        x0=np.asarray(b0, dtype=float).reshape(3),
        method="trf",
        max_nfev=int(solver_options["acc_bias_max_nfev"]),
        ftol=float(solver_options["acc_bias_ftol"]),
        xtol=float(solver_options["acc_bias_xtol"]),
        gtol=float(solver_options["acc_bias_gtol"]),
    )
    rmse = float(np.sqrt(np.mean(result.fun**2))) if result.fun.size else 0.0
    max_abs_residual = float(np.max(np.abs(result.fun))) if result.fun.size else 0.0
    metrics = {
        "success": bool(result.success),
        "rmse": rmse,
        "max_abs_residual": max_abs_residual,
        "message": result.message,
        "nfev": int(result.nfev),
    }
    return result.x.reshape(3), metrics


def _fit_bias_model_from_samples(
    temperatures: np.ndarray,
    bias_samples: np.ndarray,
    *,
    target: str,
    method: str,
    reference_temperature: float,
    extrapolation_mode: str,
    min_temp_span: float,
    min_valid_bins: int,
    discrete_meta: dict,
) -> dict:
    if temperatures.size == 0:
        return _make_invalid_model(target, f"No valid temperature bins were found for {target}(T) fitting.")
    if temperatures.size != bias_samples.shape[0]:
        raise ImuCalibError("temperatures and bias_samples row count must match.")

    temp_span = float(np.max(temperatures) - np.min(temperatures))
    temp_range = [float(np.min(temperatures)), float(np.max(temperatures))]
    if temperatures.size < min_valid_bins:
        model = _make_invalid_model(target, f"Need at least {min_valid_bins} valid temperature bins for stable fitting.")
        if temp_span < min_temp_span:
            model["low_confidence"] = True
            model["message"] = (
                f"Temperature span {temp_span:.3f} is too small for a reliable {target}(T) fit."
            )
        model["metrics"].update({"temp_span": temp_span, "num_points": int(temperatures.size), "num_bins": int(temperatures.size)})
        model["temperature_range"] = temp_range
        model["reference_temperature"] = float(reference_temperature)
        model["extrapolation_mode"] = extrapolation_mode
        model["discrete_samples"] = {"temperature": temperatures, "bias": bias_samples}
        model["discrete_meta"] = discrete_meta
        return model

    low_confidence = temp_span < min_temp_span
    dT = np.asarray(temperatures, dtype=float) - float(reference_temperature)
    method_l = str(method).lower()
    if method_l in {"poly1", "poly2", "poly3"}:
        order = int(method_l[-1])
        coeffs = np.zeros((order + 1, 3), dtype=float)
        fitted = np.zeros_like(bias_samples, dtype=float)
        for axis_idx in range(3):
            coeffs[:, axis_idx] = np.polyfit(dT, bias_samples[:, axis_idx], order)
            fitted[:, axis_idx] = np.polyval(coeffs[:, axis_idx], dT)
        model_type = "poly"
        coeff = {"poly_coeff": coeffs}
        extra = {"coeffs": coeffs, "poly_order": order}
    elif method_l == "piecewise_linear":
        order = 1
        breakpoints = np.asarray(temperatures, dtype=float)
        values = np.asarray(bias_samples, dtype=float)
        fitted = values.copy()
        model_type = "piecewise_linear"
        coeff = {"breakpoints": breakpoints, "values": values}
        extra = {"breakpoints": breakpoints, "values": values, "poly_order": order}
    else:
        raise ImuCalibError(f'Unsupported temperature model method "{method}".')

    residual = bias_samples - fitted
    rmse = float(np.sqrt(np.mean(residual**2))) if residual.size else 0.0
    max_abs_residual = float(np.max(np.abs(residual))) if residual.size else 0.0
    metrics = {
        "temp_span": temp_span,
        "num_points": int(bias_samples.shape[0]),
        "num_bins": int(temperatures.size),
        "rmse": rmse,
        "max_abs_residual": max_abs_residual,
    }
    message = f"{target}(T) model fitted successfully."
    if low_confidence:
        message = f"{target}(T) fit completed, but the temperature span is too small for high confidence."

    model = {
        "enabled": True,
        "valid": True,
        "low_confidence": bool(low_confidence),
        "target": target,
        "type": model_type,
        "model_type": method_l,
        "method": method_l,
        "reference_temperature": float(reference_temperature),
        "temperature_range": temp_range,
        "extrapolation_mode": extrapolation_mode,
        "coeff": coeff,
        "metrics": metrics,
        "message": message,
        "discrete_samples": {"temperature": temperatures, "bias": bias_samples},
        "discrete_meta": discrete_meta,
        "residual_rms": np.sqrt(np.mean(residual**2, axis=0)) if residual.size else np.full(3, np.nan),
        "residual_std": np.std(residual, axis=0, ddof=0) if residual.size else np.full(3, np.nan),
    }
    if target == "bg":
        model["reference_bg"] = np.mean(bias_samples, axis=0)
    else:
        model["reference_ba"] = np.mean(bias_samples, axis=0)
    model.update(extra)
    return model


def _temperature_options(options: dict | None) -> dict:
    return (default_calib_options() if options is None else options)["temperature"]


def _acc_calibration_options(options: dict | None) -> dict:
    return (default_calib_options() if options is None else options)["acc_calibration"]


def _resolve_reference_temperature(temp: np.ndarray | None, mode_or_value) -> float:
    if temp is None or np.asarray(temp).size == 0:
        return float("nan")
    temp = np.asarray(temp, dtype=float).reshape(-1)
    if isinstance(mode_or_value, (int, float)) and np.isfinite(mode_or_value):
        return float(mode_or_value)
    mode = "mean" if mode_or_value is None else str(mode_or_value).lower()
    if mode == "mean":
        return float(np.mean(temp))
    if mode == "median":
        return float(np.median(temp))
    if mode == "min":
        return float(np.min(temp))
    if mode == "max":
        return float(np.max(temp))
    raise ImuCalibError(f'Unsupported reference_temperature_mode "{mode_or_value}".')


def _resolve_temperature_range(temp: np.ndarray | None) -> list[float]:
    if temp is None or np.asarray(temp).size == 0:
        return [float("nan"), float("nan")]
    temp = np.asarray(temp, dtype=float).reshape(-1)
    return [float(np.min(temp)), float(np.max(temp))]


def _make_temperature_bins(temp: np.ndarray, bin_width_degC: float) -> list[dict]:
    temp = np.asarray(temp, dtype=float).reshape(-1)
    if temp.size == 0:
        return []
    if bin_width_degC <= 0:
        raise ImuCalibError("bin_width_degC must be positive.")
    lower = math.floor(float(np.min(temp)) / bin_width_degC) * bin_width_degC
    upper = math.ceil(float(np.max(temp)) / bin_width_degC) * bin_width_degC
    edges = np.arange(lower, upper + bin_width_degC, bin_width_degC, dtype=float)
    if edges.size < 2:
        edges = np.array([lower, lower + bin_width_degC], dtype=float)
    bins = []
    for idx in range(edges.size - 1):
        lo = float(edges[idx])
        hi = float(edges[idx + 1])
        if idx == edges.size - 2:
            mask = (temp >= lo) & (temp <= hi)
        else:
            mask = (temp >= lo) & (temp < hi)
        bins.append({"index": idx, "lower": lo, "upper": hi, "mask": mask})
    return bins


def _make_invalid_model(target: str, message: str) -> dict:
    return {
        "enabled": False,
        "valid": False,
        "low_confidence": False,
        "target": target,
        "type": "",
        "model_type": "",
        "method": "",
        "reference_temperature": float("nan"),
        "temperature_range": [float("nan"), float("nan")],
        "extrapolation_mode": "warn_and_clamp",
        "coeff": {},
        "metrics": {
            "temp_span": float("nan"),
            "num_points": 0,
            "num_bins": 0,
            "rmse": float("nan"),
            "max_abs_residual": float("nan"),
        },
        "message": message,
        "discrete_samples": {"temperature": np.zeros(0), "bias": np.zeros((0, 3))},
        "discrete_meta": {"bins": [], "skipped_bins": []},
        "residual_rms": np.array([np.nan, np.nan, np.nan], dtype=float),
        "residual_std": np.array([np.nan, np.nan, np.nan], dtype=float),
        "reference_bg": np.array([np.nan, np.nan, np.nan], dtype=float) if target == "bg" else None,
        "reference_ba": np.array([np.nan, np.nan, np.nan], dtype=float) if target == "ba" else None,
        "coeffs": np.zeros((0, 3), dtype=float),
        "poly_order": 0,
    }
