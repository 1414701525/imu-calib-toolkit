function result = validate_calibration(data, calib, varargin)
%VALIDATE_CALIBRATION Validate calibration outputs on the available dataset.

requiredFields = {'bg', 'Ca', 'ba', 'Cg'};
for i = 1:numel(requiredFields)
    if ~isfield(calib, requiredFields{i})
        error('validate_calibration:MissingCalibField', ...
            'calib is missing required field "%s".', requiredFields{i});
    end
end

opts = parse_options(varargin{:});
caRcond = rcond(calib.Ca);
cgRcond = rcond(calib.Cg);
if ~isfinite(caRcond) || caRcond < 1e-12
    error('validate_calibration:IllConditionedCa', ...
        'calib.Ca is numerically singular or nearly singular (rcond = %.3e).', caRcond);
end
if ~isfinite(cgRcond) || cgRcond < 1e-12
    error('validate_calibration:IllConditionedCg', ...
        'calib.Cg is numerically singular or nearly singular (rcond = %.3e).', cgRcond);
end

rawStatic = struct('gyro', data.static.gyro, 'acc', data.static.acc);
if isfield(data.static, 'temp') && ~isempty(data.static.temp)
    rawStatic.temp = data.static.temp;
end
correctedStatic = apply_imu_calibration(rawStatic, calib, 'options', opts.options);

accNormRaw = sqrt(sum(data.static.acc .^ 2, 2));
accNormCorr = sqrt(sum(correctedStatic.acc .^ 2, 2));
gravityValue = getfield_or_default(calib, 'gravity_magnitude', []);
if isempty(gravityValue)
    gravityValue = opts.options.acc_calibration.gravity_magnitude;
end
g0 = double(gravityValue);

accPoses = getfield_any(data, {'accPoses', 'acc_poses'}, []);
numPoses = numel(accPoses);
poseChecks = repmat(struct('pose_name', '', ...
                           'raw_mean', zeros(3, 1), ...
                           'corrected_mean', zeros(3, 1), ...
                           'raw_norm', 0, ...
                           'corrected_norm', 0, ...
                           'norm_error_before', 0, ...
                           'norm_error_after', 0, ...
                           'legacy_reference_residual', [], ...
                           'legacy_reference_residual_norm', NaN), numPoses, 1);
for i = 1:numPoses
    accMean = accPoses(i).acc_mean(:);
    corrected = calib.Ca * (accMean - calib.ba(:));
    rawNorm = norm(accMean);
    correctedNorm = norm(corrected);

    poseChecks(i).pose_name = get_pose_name(accPoses(i), i);
    poseChecks(i).raw_mean = accMean;
    poseChecks(i).corrected_mean = corrected;
    poseChecks(i).raw_norm = rawNorm;
    poseChecks(i).corrected_norm = correctedNorm;
    poseChecks(i).norm_error_before = rawNorm - g0;
    poseChecks(i).norm_error_after = correctedNorm - g0;

    if isfield(accPoses(i), 'a_ref') && ~isempty(accPoses(i).a_ref)
        legacyResidual = accMean - ((calib.Ca \ accPoses(i).a_ref(:)) + calib.ba(:));
        poseChecks(i).legacy_reference_residual = legacyResidual;
        poseChecks(i).legacy_reference_residual_norm = norm(legacyResidual);
    end
end

gyroRuns = getfield_any(data, {'gyroRuns', 'gyro_runs'}, []);
numRuns = numel(gyroRuns);
gyroChecks = repmat(struct('axis', 'x', ...
                           'dir', 1, ...
                           'dtheta_raw', zeros(3, 1), ...
                           'dtheta_corrected', zeros(3, 1), ...
                           'dtheta_pred', zeros(3, 1), ...
                           'error_before', zeros(3, 1), ...
                           'error_after', zeros(3, 1), ...
                           'residual_norm_before', 0, ...
                           'residual_norm_after', 0, ...
                           'used_manual_idx_ss', false), numRuns, 1);
accPlaceholder = repmat(calib.ba(:).', 1, 1);
for i = 1:numRuns
    run = gyroRuns(i);
    [idxSS, usedManual] = get_idx_ss(run, opts.options);
    rawRun = struct('gyro', run.gyro, 'acc', repmat(accPlaceholder, size(run.gyro, 1), 1));
    correctedRun = apply_imu_calibration(rawRun, calib, 'options', opts.options);
    dthetaRaw = trapz(run.t(idxSS), run.gyro(idxSS, :), 1).';
    dthetaCorrected = trapz(run.t(idxSS), correctedRun.gyro(idxSS, :), 1).';
    dthetaPred = run.theta_ref(:);
    errorBefore = dthetaRaw - dthetaPred;
    errorAfter = dthetaCorrected - dthetaPred;

    gyroChecks(i).axis = run.axis;
    gyroChecks(i).dir = run.dir;
    gyroChecks(i).dtheta_raw = dthetaRaw;
    gyroChecks(i).dtheta_corrected = dthetaCorrected;
    gyroChecks(i).dtheta_pred = dthetaPred;
    gyroChecks(i).error_before = errorBefore;
    gyroChecks(i).error_after = errorAfter;
    gyroChecks(i).residual_norm_before = norm(errorBefore);
    gyroChecks(i).residual_norm_after = norm(errorAfter);
    gyroChecks(i).used_manual_idx_ss = usedManual;
end

gsensRuns = getfield_any(data, {'gsensRuns', 'gsens_runs'}, []);
if ~isempty(gsensRuns)
    [beforeRms, afterRms, gsensMessage] = validate_gsens_residuals(gsensRuns, calib, opts.options);
else
    beforeRms = NaN;
    afterRms = NaN;
    gsensMessage = 'No gsens_runs available for residual comparison.';
end

gyroBefore = [gyroChecks.residual_norm_before].';
gyroAfter = [gyroChecks.residual_norm_after].';
poseNormBefore = abs([poseChecks.norm_error_before].');
poseNormAfter = abs([poseChecks.norm_error_after].');

result = struct();
result.static = struct();
result.static.gyro_raw_mean = mean(data.static.gyro, 1).';
result.static.gyro_debiased = correctedStatic.bias_removed_gyro;
result.static.gyro_mean_after_bias = mean(correctedStatic.bias_removed_gyro, 1).';
result.static.gyro_std_after_bias = std(correctedStatic.bias_removed_gyro, 0, 1).';
result.static.gyro_rms_after_bias = sqrt(mean(correctedStatic.bias_removed_gyro .^ 2, 1)).';
result.static.acc_raw = data.static.acc;
result.static.acc_corrected = correctedStatic.acc;
result.static.acc_norm_raw = accNormRaw;
result.static.acc_norm = accNormCorr;
result.static.acc_norm_mean_before = mean(accNormRaw);
result.static.acc_norm_mean_after = mean(accNormCorr);
result.static.acc_norm_std_before = std(accNormRaw, 0, 1);
result.static.acc_norm_std_after = std(accNormCorr, 0, 1);
result.static.acc_norm_error_mean = mean(accNormCorr - g0);
result.static.gravity_magnitude = g0;

result.acc_poses = poseChecks;
result.accPoses = poseChecks;
result.gyro_runs = gyroChecks;
result.gyroRuns = gyroChecks;
result.gsens = struct('residual_rms_before', beforeRms, ...
                      'residual_rms_after', afterRms, ...
                      'message', gsensMessage);
result.analysis = opts.analysis;
result.summary = struct();
result.summary.num_acc_poses = numPoses;
result.summary.num_gyro_runs = numRuns;
result.summary.Ca_rcond = caRcond;
result.summary.Cg_rcond = cgRcond;
result.summary.static_gyro_mean_after_bias = result.static.gyro_mean_after_bias;
result.summary.static_gyro_rms_after_bias = result.static.gyro_rms_after_bias;
result.summary.static_acc_norm_mean_before = result.static.acc_norm_mean_before;
result.summary.static_acc_norm_mean_after = result.static.acc_norm_mean_after;
result.summary.static_acc_norm_std_before = result.static.acc_norm_std_before;
result.summary.static_acc_norm_std_after = result.static.acc_norm_std_after;
result.summary.static_acc_norm_error_mean = result.static.acc_norm_error_mean;
result.summary.acc_pose_norm_error_mean_before = mean(poseNormBefore);
result.summary.acc_pose_norm_error_std_before = std(poseNormBefore, 0, 1);
result.summary.acc_pose_norm_error_max_before = max(poseNormBefore);
result.summary.acc_pose_norm_error_mean_after = mean(poseNormAfter);
result.summary.acc_pose_norm_error_std_after = std(poseNormAfter, 0, 1);
result.summary.acc_pose_norm_error_max_after = max(poseNormAfter);
result.summary.gyro_dtheta_residual_rms_before = sqrt(mean(gyroBefore .^ 2));
result.summary.gyro_dtheta_residual_rms_after = sqrt(mean(gyroAfter .^ 2));
result.summary.gyro_dtheta_residual_max_after = max(gyroAfter);
result.summary.gsens_residual_rms_before = beforeRms;
result.summary.gsens_residual_rms_after = afterRms;
summaryPayload = build_result_summary(struct('calib', calib, 'analysis', opts.analysis));
result.summary.temperature_model_status = summaryPayload.core_outputs.temperature_model_status;
result.summary.allan_status = summaryPayload.core_outputs.allan_status;
end

function opts = parse_options(varargin)
opts = struct();
opts.options = default_calib_options();
opts.analysis = struct();
if mod(numel(varargin), 2) ~= 0
    error('validate_calibration:InvalidInput', ...
        'Optional arguments must be provided as name/value pairs.');
end
for k = 1:2:numel(varargin)
    name = lower(char(varargin{k}));
    value = varargin{k + 1};
    switch name
        case 'options'
            opts.options = value;
        case 'analysis'
            opts.analysis = value;
        otherwise
            error('validate_calibration:UnknownOption', ...
                'Unknown option "%s".', char(varargin{k}));
    end
end
end

function [idxSS, usedManual] = get_idx_ss(run, options)
usedManual = false;
if isfield(run, 'idx_ss') && ~isempty(run.idx_ss) && ...
        options.segmentation.use_manual_idx_ss_first && ~options.segmentation.reestimate_idx_ss
    idxSS = logical(run.idx_ss(:));
    usedManual = true;
    return;
end

detected = detect_steady_segments(run.t(:), run.gyro, ...
    'steady_window_sec', options.segmentation.steady_window_sec, ...
    'gyro_norm_threshold', options.segmentation.gyro_norm_threshold, ...
    'gyro_std_threshold', options.segmentation.gyro_std_threshold, ...
    'min_segment_sec', options.segmentation.min_segment_sec);
idxSS = detected.mask;
if nnz(idxSS) < 2 && isfield(run, 'idx_ss') && ~isempty(run.idx_ss)
    idxSS = logical(run.idx_ss(:));
    usedManual = true;
end
end

function [beforeRms, afterRms, message] = validate_gsens_residuals(gsensRuns, calib, options)
beforeResiduals = [];
afterResiduals = [];
for i = 1:numel(gsensRuns)
    run = gsensRuns(i);
    if isfield(run, 'omega_ref') && ~isempty(run.omega_ref)
        omegaRef = run.omega_ref;
    else
        omegaRef = zeros(size(run.gyro));
    end
    residualBefore = (run.gyro - calib.bg(:).') - (calib.Cg * omegaRef.').';
    beforeResiduals = [beforeResiduals; residualBefore]; %#ok<AGROW>
    if isfield(calib, 'Gg') && ~isempty(calib.Gg) && options.gsens.enabled
        residualAfter = residualBefore - (calib.Gg * run.acc_ref.').';
    else
        residualAfter = residualBefore;
    end
    afterResiduals = [afterResiduals; residualAfter]; %#ok<AGROW>
end
beforeRms = sqrt(mean(beforeResiduals(:) .^ 2));
afterRms = sqrt(mean(afterResiduals(:) .^ 2));
message = 'Compared gsens residual RMS before and after Gg compensation.';
end

function poseName = get_pose_name(pose, idx)
if isfield(pose, 'pose_name') && ~isempty(pose.pose_name)
    poseName = char(string(pose.pose_name));
else
    poseName = sprintf('pose_%02d', idx);
end
end
