% test_apply_calibration
% Validate the unified inverse calibration entry point.

clear;
clc;

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(projectRoot, 'src')));

[data, truth] = load_example_data('forceRegenerate', true, 'saveToMat', false);
[bg, biasInfo] = estimate_gyro_bias(data.static.gyro, 't', data.static.t, 'temp', data.static.temp); %#ok<ASGLU>
noiseStats = estimate_noise_stats(data.static.gyro, data.static.acc); %#ok<NASGU>
[Ca, ba, accInfo] = fit_acc_multi_pose(data.accPoses); %#ok<ASGLU>
[Cg, gyroInfo] = fit_gyro_C_from_angle_increment(data.gyroRuns, bg); %#ok<ASGLU>
[Kg, Mg] = split_KM(Cg); %#ok<ASGLU>
[Gg, gsensInfo] = fit_gyro_g_sensitivity(data.gsensRuns, bg, Cg); %#ok<ASGLU>

calib = struct();
calib.bg = bg;
calib.Ca = Ca;
calib.ba = ba;
calib.Cg = Cg;
calib.Gg = Gg;
calib.temp = struct('bgModel', struct('valid', false, 'message', 'No temp model'), ...
                    'baModel', struct('valid', false, 'message', 'No temp model'));
calib.gravity_magnitude = default_calib_options().acc_calibration.gravity_magnitude;

raw = struct();
raw.gyro = data.static.gyro;
raw.acc = data.static.acc;
raw.temp = data.static.temp;

corrected = apply_imu_calibration(raw, calib);

gyroMeanAfter = mean(corrected.bias_removed_gyro, 1).';
accMeanAfter = mean(corrected.acc, 1).';
accNormError = mean(abs(vecnorm(corrected.acc, 2, 2) - truth.g0));

assert(max(abs(gyroMeanAfter)) < 1e-3, ...
    'apply_imu_calibration failed to remove static gyro bias sufficiently.');
assert(norm(accMeanAfter - [0; 0; truth.g0]) < 0.3, ...
    'apply_imu_calibration produced unreasonable corrected static acceleration.');
assert(accNormError < 0.15, ...
    'apply_imu_calibration should keep corrected static acceleration close to |g|.');
assert(isfield(corrected, 'baT') && isequal(size(corrected.baT, 2), 3), ...
    'apply_imu_calibration should expose ba(T) evaluation results.');

fprintf('test_apply_calibration passed.\n');
