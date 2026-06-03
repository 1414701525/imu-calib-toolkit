from __future__ import annotations

from typing import Any

import numpy as np


def get_temperature_model_status(temp_block: dict | None) -> str:
    if not isinstance(temp_block, dict):
        return "not_available"

    statuses: list[str] = []
    for key in ("bg_model", "ba_model"):
        model = _get_temp_model(temp_block, key)
        if isinstance(model, dict) and model:
            if model.get("valid", False):
                statuses.append(f"{key}=valid")
            elif model.get("low_confidence", False):
                statuses.append(f"{key}=low_confidence")
            else:
                statuses.append(f"{key}=invalid")
    return ", ".join(statuses) if statuses else "not_available"


def get_allan_status(analysis: dict | None) -> str:
    allan = analysis.get("allan") if isinstance(analysis, dict) else None
    if not isinstance(allan, dict):
        return "not_available"

    status = "not_available"
    for block in allan.values():
        if isinstance(block, dict) and "valid" in block:
            if block["valid"]:
                return "available"
            status = "invalid_or_short_data"
    return status


def build_summary_payload(results) -> dict[str, Any]:
    temp_block = results.calib.get("temp", {}) if getattr(results, "calib", None) else {}
    validation_summary = results.validation.get("summary", {}) if getattr(results, "validation", None) else {}

    return {
        "model": getattr(results, "model", {}),
        "core_outputs": _to_json_ready(_build_core_outputs(results, temp_block)),
        "summary": _to_json_ready(validation_summary),
        "temperature_model": _to_json_ready(_build_temperature_snapshot(temp_block)),
        "meta": _to_json_ready(getattr(results, "meta", {})),
    }


def _build_core_outputs(results, temp_block: dict) -> dict[str, Any]:
    acc = results.calib.get("acc", {}) if getattr(results, "calib", None) else {}
    gyr = results.calib.get("gyr", {}) if getattr(results, "calib", None) else {}

    return {
        "bg": results.calib.get("bg") if getattr(results, "calib", None) else None,
        "ba": acc.get("ba"),
        "gravity_magnitude": acc.get("gravity_magnitude"),
        "Ca": acc.get("Ca"),
        "Cg": gyr.get("Cg"),
        "Gg": gyr.get("Gg"),
        "temperature_model_status": get_temperature_model_status(temp_block),
        "allan_status": get_allan_status(getattr(results, "analysis", {})),
    }


def _build_temperature_snapshot(temp_block: dict) -> dict[str, Any]:
    if not isinstance(temp_block, dict):
        return {}
    return {
        "reference_temperature": _get_model_file(temp_block).get("reference_temperature"),
        "temperature_range": _get_model_file(temp_block).get("temperature_range"),
        "extrapolation_mode": _get_model_file(temp_block).get("extrapolation_mode"),
        "bg_model": _get_temp_model(temp_block, "bg_model"),
        "ba_model": _get_temp_model(temp_block, "ba_model"),
        "message": temp_block.get("message", ""),
    }


def _get_temp_model(temp_block: dict, key: str) -> dict[str, Any]:
    alias_map = {
        "bg_model": "bgModel",
        "ba_model": "baModel",
    }
    value = temp_block.get(key)
    if isinstance(value, dict) and value:
        return value
    alias = alias_map.get(key)
    alias_value = temp_block.get(alias) if alias is not None else None
    return alias_value if isinstance(alias_value, dict) else {}


def _get_model_file(temp_block: dict) -> dict[str, Any]:
    value = temp_block.get("model_file")
    if isinstance(value, dict) and value:
        return value
    alias_value = temp_block.get("modelFile")
    return alias_value if isinstance(alias_value, dict) else {}


def _to_json_ready(obj: Any) -> Any:
    if isinstance(obj, np.ndarray):
        return obj.tolist()
    if isinstance(obj, (np.floating, np.integer)):
        return obj.item()
    if isinstance(obj, dict):
        return {str(k): _to_json_ready(v) for k, v in obj.items()}
    if isinstance(obj, (list, tuple)):
        return [_to_json_ready(item) for item in obj]
    return obj
