function options = default_calib_options()
%DEFAULT_CALIB_OPTIONS Create default options for the calibration pipeline.
% Usage:
%   options = default_calib_options()

options = struct();

options.pipeline = struct();
options.pipeline.enable_allan = true;
options.pipeline.enable_temperature_model = true;
options.pipeline.enable_auto_segment = true;
options.pipeline.enable_g_sensitivity = true;
options.pipeline.plot_results = true;
options.pipeline.save_results = false;

options.model = struct();
options.model.forward_gyro = 'omega_m = Cg * omega_ref + bg(T) + Gg * f_term + n_g';
options.model.inverse_gyro = 'omega_ref_hat = Cg \\ (omega_m - bg(T) - Gg * f_term)';
options.model.forward_acc = 'a_raw = Ca^{-1} * a_corr + ba(T) + n_a';
options.model.inverse_acc = 'a_corr = Ca * (a_raw - ba(T))';
options.model.gsens_term = 'f_term';
options.model.gsens_definition = ['Gg is fitted and applied against the same sensor-axis specific ' ...
    'force term. The fitted residual model uses gsensRuns.acc_ref, and online compensation ' ...
    'must use the same f_term definition.'];
options.model.notes = ['Gyro inverse compensation uses left-division / solve semantics. ' ...
    'Accelerometer compensation uses a_corr = Ca * (a_raw - ba(T)).'];

options.acc_calibration = struct();
options.acc_calibration.gravity_magnitude = 9.80665;
options.acc_calibration.parameterization = 'scale_misalignment';
options.acc_calibration.fallback_to_diag_only = true;
options.acc_calibration.min_pose_count_full = 9;
options.acc_calibration.min_pose_count_diag_only = 6;
options.acc_calibration.use_legacy_reference_init = true;
options.acc_calibration.optimizer_method = 'fminsearch_or_lsqnonlin';
options.acc_calibration.optimizer_loss = 'linear';
options.acc_calibration.max_nfev = 4000;
options.acc_calibration.ftol = 1e-10;
options.acc_calibration.xtol = 1e-10;
options.acc_calibration.gtol = 1e-10;

options.segmentation = struct();
options.segmentation.use_manual_idx_ss_first = true;
options.segmentation.reestimate_idx_ss = false;
options.segmentation.static_window_sec = 0.5;
options.segmentation.steady_window_sec = 0.5;
options.segmentation.gyro_norm_threshold = 0.03;
options.segmentation.acc_std_threshold = 0.08;
options.segmentation.gyro_std_threshold = 0.01;
options.segmentation.min_segment_sec = 1.0;
options.segmentation.min_static_segments = 6;

options.temperature = struct();
options.temperature.enabled = true;
options.temperature.target = 'both';
options.temperature.method = 'poly2';
options.temperature.poly_order = 2;
options.temperature.reference_temperature_mode = 'mean';
options.temperature.extrapolation_mode = 'warn_and_clamp';
options.temperature.min_temp_span = 2.0;
options.temperature.min_samples = 200;
options.temperature.bin_width_degC = 2.0;
options.temperature.min_bin_samples = 50;
options.temperature.min_valid_bins = 3;
options.temperature.acc_min_bin_pose_count = 6;
options.temperature.acc_min_pose_rank = 2;
options.temperature.acc_bias_max_nfev = 2000;
options.temperature.acc_bias_ftol = 1e-10;
options.temperature.acc_bias_xtol = 1e-10;
options.temperature.acc_bias_gtol = 1e-10;
options.temperature.allow_low_confidence = true;

options.allan = struct();
options.allan.enabled = true;
options.allan.min_samples = 256;
options.allan.num_tau = 30;
options.allan.tau_mode = 'logspace';
options.allan.validity_message_if_short = 'Not enough stationary data for reliable Allan analysis.';

options.gsens = struct();
options.gsens.enabled = true;
options.gsens.apply_using = 'f_term';

options.validation = struct();
options.validation.include_allan = true;
options.validation.include_temperature = true;
options.validation.include_gsens = true;
options.validation.include_pre_post_compare = true;
end
