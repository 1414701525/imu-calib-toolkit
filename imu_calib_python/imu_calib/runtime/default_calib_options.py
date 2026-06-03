from __future__ import annotations


def default_calib_options() -> dict:
    """Create default options aligned with the MATLAB reference project."""
    return {
        "pipeline": {
            "enable_allan": True,
            "enable_temperature_model": True,
            "enable_auto_segment": True,
            "enable_g_sensitivity": True,
            "plot_results": True,
            "save_results": False,
        },
        "model": {
            "forward_gyro": "omega_m = Cg * omega_ref + bg(T) + Gg * f_term + n_g",
            "inverse_gyro": "omega_ref_hat = solve(Cg, omega_m - bg(T) - Gg * f_term)",
            "forward_acc": "a_raw = solve(Ca, a_corr) + ba(T) + n_a",
            "inverse_acc": "a_corr = Ca * (a_raw - ba(T))",
            "gsens_term": "f_term",
            "gsens_definition": (
                "Gg is fitted and applied against the same sensor-axis specific "
                "force term. The fitted residual model uses gsens_runs.acc_ref, "
                "and online compensation must use the same f_term definition."
            ),
            "notes": (
                "Gyro inverse compensation uses solve/left-division semantics. "
                "Accelerometer compensation uses a_corr = Ca * (a_raw - ba(T))."
            ),
        },
        "acc_calibration": {
            "gravity_magnitude": 9.80665,
            "parameterization": "scale_misalignment",
            "fallback_to_diag_only": True,
            "min_pose_count_full": 9,
            "min_pose_count_diag_only": 6,
            "use_legacy_reference_init": True,
            "optimizer_method": "trf",
            "optimizer_loss": "linear",
            "max_nfev": 4000,
            "ftol": 1e-10,
            "xtol": 1e-10,
            "gtol": 1e-10,
        },
        "segmentation": {
            "use_manual_idx_ss_first": True,
            "reestimate_idx_ss": False,
            "static_window_sec": 0.5,
            "steady_window_sec": 0.5,
            "gyro_norm_threshold": 0.03,
            "acc_std_threshold": 0.08,
            "gyro_std_threshold": 0.01,
            "min_segment_sec": 1.0,
            "min_static_segments": 6,
        },
        "temperature": {
            "enabled": True,
            "target": "both",
            "method": "poly2",
            "poly_order": 2,
            "reference_temperature_mode": "mean",
            "extrapolation_mode": "warn_and_clamp",
            "min_temp_span": 2.0,
            "min_samples": 200,
            "bin_width_degC": 2.0,
            "min_bin_samples": 50,
            "min_valid_bins": 3,
            "acc_min_bin_pose_count": 6,
            "acc_min_pose_rank": 2,
            "acc_bias_max_nfev": 2000,
            "acc_bias_ftol": 1e-10,
            "acc_bias_xtol": 1e-10,
            "acc_bias_gtol": 1e-10,
            "allow_low_confidence": True,
        },
        "allan": {
            "enabled": True,
            "min_samples": 256,
            "num_tau": 30,
            "tau_mode": "logspace",
            "validity_message_if_short": "Not enough stationary data for reliable Allan analysis.",
        },
        "gsens": {
            "enabled": True,
            "apply_using": "f_term",
        },
        "validation": {
            "include_allan": True,
            "include_temperature": True,
            "include_gsens": True,
            "include_pre_post_compare": True,
        },
    }
