from __future__ import annotations

from imu_calib.models.calib_results import CalibrationResults
from imu_calib.runtime.default_calib_options import default_calib_options


def build_calib_results(data, components: dict, options: dict | None = None) -> CalibrationResults:
    """Assemble a unified calibration result object."""
    options = default_calib_options() if options is None else options
    acc_info = components.get("acc_info", {}) or {}
    gravity_magnitude = components.get("gravity_magnitude")
    if gravity_magnitude is None and isinstance(acc_info, dict):
        gravity_magnitude = acc_info.get("gravity_magnitude")

    model = {
        "forward": {
            "acc": options["model"]["forward_acc"],
            "gyr": options["model"]["forward_gyro"],
        },
        "inverse": {
            "acc": options["model"]["inverse_acc"],
            "gyr": options["model"]["inverse_gyro"],
        },
        "gsens_term": options["model"]["gsens_term"],
        "gsens_definition": options["model"]["gsens_definition"],
        "notes": options["model"]["notes"],
    }

    calib = {
        "bg": components.get("bg"),
        "noise_stats": components.get("noise_stats", {}),
        "noiseStats": components.get("noise_stats", {}),
        "acc": {
            "Ca": components.get("Ca"),
            "ba": components.get("ba"),
            "Sa": components.get("Sa"),
            "Ma": components.get("Ma"),
            "gravity_magnitude": gravity_magnitude,
            "info": acc_info,
        },
        "gyr": {
            "Cg": components.get("Cg"),
            "Kg": components.get("Kg"),
            "Mg": components.get("Mg"),
            "Gg": components.get("Gg"),
            "bias_info": components.get("bias_info", {}),
            "biasInfo": components.get("bias_info", {}),
            "fit_info": components.get("gyro_info", {}),
            "fitInfo": components.get("gyro_info", {}),
            "gsens_info": components.get("gsens_info", {}),
            "gsensInfo": components.get("gsens_info", {}),
        },
        "temp": {
            "bg_model": components.get("temp_bg_model", {}),
            "bgModel": components.get("temp_bg_model", {}),
            "ba_model": components.get("temp_ba_model", {}),
            "baModel": components.get("temp_ba_model", {}),
            "model_file": components.get("temperature_model", {}),
            "modelFile": components.get("temperature_model", {}),
            "message": components.get("temp_message", "Temperature model not evaluated yet."),
            "bias_at_temperature": None,
        },
    }

    compat_flat = {
        "bg": calib["bg"],
        "noise": calib["noise_stats"],
        "noise_stats": calib["noise_stats"],
        "Ca": calib["acc"]["Ca"],
        "ba": calib["acc"]["ba"],
        "Sa": calib["acc"]["Sa"],
        "Ma": calib["acc"]["Ma"],
        "gravity_magnitude": calib["acc"]["gravity_magnitude"],
        "Cg": calib["gyr"]["Cg"],
        "Kg": calib["gyr"]["Kg"],
        "Mg": calib["gyr"]["Mg"],
        "Gg": calib["gyr"]["Gg"],
        "temp": calib["temp"],
        "acc_info": calib["acc"]["info"],
        "accInfo": calib["acc"]["info"],
        "gyro_info": calib["gyr"]["fit_info"],
        "gyroInfo": calib["gyr"]["fit_info"],
        "gsens_info": calib["gyr"]["gsens_info"],
        "gsensInfo": calib["gyr"]["gsens_info"],
    }

    return CalibrationResults(
        data=data,
        options=options,
        model=model,
        calib=calib,
        analysis=components.get("analysis", {}),
        validation=components.get("validation", {}),
        meta=components.get("meta", {}),
        truth=components.get("truth"),
        compat={"flat_calib": compat_flat},
    )
