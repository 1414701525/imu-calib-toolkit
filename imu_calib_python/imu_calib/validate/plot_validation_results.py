from __future__ import annotations

import matplotlib.pyplot as plt
import numpy as np

from imu_calib.models.data_structures import ImuDataset


def plot_validation_results(data: ImuDataset, calib: dict, validation: dict) -> dict:
    """Plot validation figures for either full or partial results."""

    handles: dict[str, plt.Figure] = {}
    mode = validation.get("summary", {}).get("mode", "full")
    handles["main"] = _plot_main_figure(data, calib, validation, mode)

    allan = validation.get("analysis", {}).get("allan")
    if isinstance(allan, dict):
        handles.update(_add_allan_figures(allan))

    temp = calib.get("temp") if isinstance(calib, dict) else None
    if isinstance(temp, dict):
        temp_handles = _add_temperature_figures(data, temp)
        handles.update(temp_handles)
    return handles


def _plot_main_figure(data: ImuDataset, calib: dict, validation: dict, mode: str):
    fig, axes = plt.subplots(2, 3, figsize=(14, 8), num="IMU Calibration Validation")
    ax1, ax2, ax3, ax4, ax5, ax6 = axes.flatten()
    static = validation.get("static", {})
    summary = validation.get("summary", {})

    if data.static is not None and static.get("gyro_debiased") is not None:
        ax1.plot(data.static.t, static["gyro_debiased"][:, 0], "r", label="x")
        ax1.plot(data.static.t, static["gyro_debiased"][:, 1], "g", label="y")
        ax1.plot(data.static.t, static["gyro_debiased"][:, 2], "b", label="z")
        ax1.set_title("Static Gyro After Bias Removal")
        ax1.set_xlabel("Time [s]")
        ax1.set_ylabel("Gyro after bias removal [rad/s]")
        ax1.grid(True)
        ax1.legend()
    else:
        ax1.text(0.5, 0.5, "No static gyro available", ha="center", va="center")
        ax1.axis("off")

    acc_norm_raw = static.get("acc_norm_raw")
    acc_norm_corr = static.get("acc_norm")
    if data.static is not None and acc_norm_raw is not None:
        ax2.plot(data.static.t, acc_norm_raw, "--", color="0.6", label="Raw")
        if acc_norm_corr is not None:
            ax2.plot(data.static.t, acc_norm_corr, "k", label="Corrected")
        g0_line = _resolve_gravity_reference(data, calib, validation)
        if g0_line is not None:
            ax2.axhline(g0_line, color="r", linestyle="--", label="Reference |a|")
        ax2.set_title("Static Accel Norm")
        ax2.set_xlabel("Time [s]")
        ax2.set_ylabel("Accel norm [m/s^2]")
        ax2.grid(True)
        ax2.legend()
    else:
        ax2.text(0.5, 0.5, "No static accel available", ha="center", va="center")
        ax2.axis("off")

    gyro_runs = validation.get("gyro_runs", [])
    if gyro_runs:
        before = np.array([item["residual_norm_before"] for item in gyro_runs])
        after = np.array([item["residual_norm_after"] for item in gyro_runs])
        x = np.arange(before.size)
        width = 0.38
        ax3.bar(x - width / 2, before, width, label="Before")
        ax3.bar(x + width / 2, after, width, label="After")
        ax3.set_title("Gyro dtheta Error Before/After")
        ax3.set_ylabel("||dtheta error|| [rad]")
        ax3.grid(True)
        ax3.legend()
    else:
        ax3.text(0.5, 0.5, "No gyro runs available", ha="center", va="center")
        ax3.axis("off")

    if calib.get("Cg") is not None:
        im = ax4.imshow(calib["Cg"], aspect="equal")
        ax4.set_title("Cg Heatmap")
        ax4.set_xlabel("Reference axis")
        ax4.set_ylabel("Measured axis")
        ax4.set_xticks([0, 1, 2], ["x", "y", "z"])
        ax4.set_yticks([0, 1, 2], ["x", "y", "z"])
        for r in range(3):
            for c in range(3):
                ax4.text(c, r, f"{calib['Cg'][r, c]:.4f}", ha="center", va="center", color="w", fontweight="bold")
        fig.colorbar(im, ax=ax4, fraction=0.046, pad=0.04)
    else:
        ax4.text(0.5, 0.5, "Cg unavailable in partial mode", ha="center", va="center")
        ax4.axis("off")

    if mode == "full" and "static_acc_norm_mean_before" in summary and "static_acc_norm_mean_after" in summary:
        ax5.bar(
            np.arange(2),
            [summary["static_acc_norm_mean_before"], summary["static_acc_norm_std_before"]],
            width=0.35,
            label="Before",
        )
        ax5.bar(
            np.arange(2) + 0.35,
            [summary["static_acc_norm_mean_after"], summary["static_acc_norm_std_after"]],
            width=0.35,
            label="After",
        )
        ax5.set_xticks([0.175, 1.175], ["Mean |a|", "Std |a|"])
        ax5.set_title("Static Accel Summary")
        ax5.grid(True)
        ax5.legend()
    elif summary.get("static_acc_norm_mean") is not None:
        ax5.bar([0, 1], [summary["static_acc_norm_mean"], summary["static_acc_norm_std"]], width=0.5)
        ax5.set_xticks([0, 1], ["Mean |a|", "Std |a|"])
        ax5.set_title("Static Accel Summary")
        ax5.grid(True)
    else:
        ax5.text(0.5, 0.5, "No accel summary available", ha="center", va="center")
        ax5.axis("off")

    ax6.axis("off")
    ax6.set_title("Summary")
    lines = [
        f"mode = {summary.get('mode', mode)}",
        f"available_blocks = {summary.get('available_blocks', [])}",
        f"completed_modules = {summary.get('completed_modules', [])}",
        f"temp_status = {summary.get('temperature_model_status', 'n/a')}",
        f"allan_status = {summary.get('allan_status', 'n/a')}",
    ]
    if summary.get("static_gyro_rms_after_bias") is not None:
        vec = np.asarray(summary["static_gyro_rms_after_bias"], dtype=float).reshape(-1)
        lines.append(f"gyro RMS after bias = [{vec[0]:.3g} {vec[1]:.3g} {vec[2]:.3g}]")
    if "Ca_rcond" in summary and summary.get("Ca_rcond") is not None:
        lines.append(f"rcond(Ca) = {summary['Ca_rcond']:.3e}")
    if "Cg_rcond" in summary and summary.get("Cg_rcond") is not None:
        lines.append(f"rcond(Cg) = {summary['Cg_rcond']:.3e}")
    y = 0.92
    for line in lines:
        ax6.text(0.05, y, line, transform=ax6.transAxes)
        y -= 0.13

    fig.tight_layout()
    return fig


def _resolve_gravity_reference(data: ImuDataset, calib: dict, validation: dict) -> float | None:
    """Resolve the accel norm reference without requiring legacy a_ref fields."""
    static = validation.get("static", {}) if isinstance(validation, dict) else {}
    candidates = [static.get("gravity_magnitude")]
    if isinstance(calib, dict):
        candidates.append(calib.get("gravity_magnitude"))
        acc = calib.get("acc")
        if isinstance(acc, dict):
            candidates.append(acc.get("gravity_magnitude"))
    for value in candidates:
        if value is None:
            continue
        arr = np.asarray(value, dtype=float).reshape(-1)
        if arr.size == 1 and np.isfinite(arr[0]):
            return float(arr[0])

    legacy_refs = [
        float(np.linalg.norm(np.asarray(p.a_ref, dtype=float).reshape(3)))
        for p in data.acc_poses
        if getattr(p, "a_ref", None) is not None
    ]
    if legacy_refs:
        return float(np.mean(legacy_refs))
    return None


def _add_allan_figures(allan: dict) -> dict:
    handles: dict[str, plt.Figure] = {}
    if isinstance(allan.get("gyro"), dict) and allan["gyro"].get("valid", False):
        fig = plt.figure("Gyro Allan Deviation", figsize=(7, 5))
        for axis, color in enumerate(("r", "g", "b")):
            plt.loglog(allan["gyro"]["tau"], allan["gyro"]["adev"][:, axis], color=color, label=["x", "y", "z"][axis])
        plt.grid(True)
        plt.xlabel("tau [s]")
        plt.ylabel("Allan deviation")
        plt.title("Gyro Allan Deviation")
        plt.legend()
        handles["allan_gyro"] = fig
    if isinstance(allan.get("acc"), dict) and allan["acc"].get("valid", False):
        fig = plt.figure("Accel Allan Deviation", figsize=(7, 5))
        for axis, color in enumerate(("r", "g", "b")):
            plt.loglog(allan["acc"]["tau"], allan["acc"]["adev"][:, axis], color=color, label=["x", "y", "z"][axis])
        plt.grid(True)
        plt.xlabel("tau [s]")
        plt.ylabel("Allan deviation")
        plt.title("Accel Allan Deviation")
        plt.legend()
        handles["allan_acc"] = fig
    return handles


def _add_temperature_figures(data: ImuDataset, temp_models: dict) -> dict:
    handles: dict[str, plt.Figure] = {}
    if data.static is None or data.static.temp is None:
        return handles
    bg_model = temp_models.get("bg_model") if isinstance(temp_models, dict) else None
    ba_model = temp_models.get("ba_model") if isinstance(temp_models, dict) else None
    if isinstance(bg_model, dict) and bg_model.get("valid", False):
        fig = _add_temperature_figure(data, bg_model, target="bg")
        if fig is not None:
            handles["temperature_gyro"] = fig
    if isinstance(ba_model, dict) and ba_model.get("valid", False):
        fig = _add_temperature_figure(data, ba_model, target="ba")
        if fig is not None:
            handles["temperature_acc"] = fig
    return handles


def _add_temperature_figure(data: ImuDataset, model: dict, *, target: str):
    from imu_calib.runtime.get_gyro_bias_from_temperature import get_gyro_bias_from_temperature
    from imu_calib.runtime.get_accel_bias_from_temperature import get_accel_bias_from_temperature

    if target == "bg":
        biasT, _ = get_gyro_bias_from_temperature(data.static.temp, model["reference_bg"], model)
        values = data.static.gyro
        title = "Gyro Temperature Bias Model"
        yunit = "[rad/s]"
        prefix = "bg"
    else:
        biasT, _ = get_accel_bias_from_temperature(data.static.temp, model["reference_ba"], model)
        values = data.static.acc
        title = "Accel Temperature Bias Model"
        yunit = "[m/s^2]"
        prefix = "ba"
    fig, axes = plt.subplots(3, 1, figsize=(7, 8), num=title)
    temp = np.asarray(data.static.temp, dtype=float)
    order = np.argsort(temp)
    temp_sorted = temp[order]
    for axis_idx, ax in enumerate(axes):
        ax.scatter(temp, values[:, axis_idx], s=8, marker=".")
        ax.plot(temp_sorted, biasT[order, axis_idx], linewidth=1.2)
        ax.grid(True)
        ax.set_xlabel("Temperature")
        ax.set_ylabel(f"{prefix}_{axis_idx + 1} {yunit}")
        ax.set_title(f"{prefix}(T) axis {axis_idx + 1}")
    fig.tight_layout()
    return fig
