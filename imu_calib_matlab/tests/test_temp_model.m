% test_temp_model
% Validate gyro + accel temperature modeling and runtime application.

clear;
clc;

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(projectRoot, 'src')));

[data, ~] = load_example_data('forceRegenerate', true, 'saveToMat', false);

flatTemp = mean(data.static.temp) * ones(size(data.static.temp));
flatModel = fit_temperature_bias_model(data.static.gyro, flatTemp);
assert(~flatModel.valid || flatModel.low_confidence, ...
    'Flat temperature input should produce invalid or low-confidence model.');

accInvalid = fit_accel_temperature_bias_model('static_data', data.static, 'Ca', []);
assert(~accInvalid.valid, 'Accel temperature model should require fixed Ca.');
assert(contains(accInvalid.message, 'Fixed Ca is required'), ...
    'Missing Ca should produce a clear error message.');

[staticData, Ca, baTruth] = make_temperature_static_dataset();
options = default_calib_options();
options.segmentation.static_window_sec = 0.2;
options.segmentation.min_segment_sec = 0.6;
options.segmentation.gyro_norm_threshold = 0.02;
options.segmentation.gyro_std_threshold = 0.01;
options.segmentation.acc_std_threshold = 0.08;

task = run_temperature_fit(struct('static', staticData), ...
    'target', 'both', ...
    'Ca', Ca, ...
    'ba', zeros(3, 1), ...
    'min_temp_span', 4.0, ...
    'min_samples', 50, ...
    'bin_width_degC', 2.0, ...
    'min_bin_samples', 3, ...
    'min_valid_bins', 3, ...
    'acc_min_bin_pose_count', 3, ...
    'acc_min_pose_rank', 2, ...
    'options', options);

assert(task.success, 'run_temperature_fit should succeed for the synthetic joint temperature dataset.');
bgModel = task.result.bgModel;
baModel = task.result.baModel;
assert(bgModel.valid, 'bg(T) model should be valid.');
assert(baModel.valid, 'ba(T) model should be valid.');
assert(bgModel.metrics.num_bins >= 3, 'bg(T) fit should use multiple bins.');
assert(baModel.metrics.num_bins >= 3, 'ba(T) fit should use multiple bins.');

calib = struct();
calib.bg = [0; 0; 0];
calib.ba = [0; 0; 0];
calib.Ca = Ca;
calib.Cg = eye(3);
calib.Gg = zeros(3, 3);
calib.temp = struct('bgModel', bgModel, 'baModel', baModel);

corrected = apply_imu_calibration(struct('gyro', staticData.gyro, 'acc', staticData.acc, 'temp', staticData.temp), calib);
staticMask = vecnorm(staticData.gyro, 2, 2) < 0.02;
correctedNormError = abs(vecnorm(corrected.acc, 2, 2) - 9.80665);
assert(mean(correctedNormError(staticMask)) < 0.05, ...
    'Corrected acceleration norm should stay close to |g| on static samples.');
assert(all(abs(mean(corrected.bias_removed_gyro(staticMask, :), 1)) < 0.01), ...
    'Corrected gyro bias should be close to zero on static samples.');
assert(all(abs(mean(corrected.baT(staticMask, :), 1) - mean(baTruth(staticMask, :), 1)) < 0.15), ...
    'Estimated ba(T) should match the synthetic truth within tolerance.');

fprintf('test_temp_model passed.\n');

function [staticData, Ca, biasTruth] = make_temperature_static_dataset()
rng(1234, 'twister');
g = 9.80665;
tempBins = [15.0; 20.0; 25.0; 30.0];
poses = [g, 0.0, 0.0;
        -g, 0.0, 0.0;
         0.0, g, 0.0;
         0.0, -g, 0.0;
         0.0, 0.0, g;
         0.0, 0.0, -g];
Ca = [1.01, 0.015, -0.01;
      0.0,  0.99,   0.012;
      0.0,  0.0,    1.005];
CaInv = inv(Ca);

t = [];
gyro = [];
acc = [];
temp = [];
biasTruth = [];
dt = 0.05;
idx = 0;
for i = 1:numel(tempBins)
    T = tempBins(i);
    dT = T - 22.0;
    bg = [0.002 + 2e-4 * dT, -0.001 + 1e-4 * dT, 0.0015 - 1.5e-4 * dT];
    ba = [0.05 + 0.01 * dT, -0.02 + 0.005 * dT, 0.03 - 0.008 * dT];
    for p = 1:size(poses, 1)
        rawMean = (CaInv * poses(p, :).') + ba.';
        for k = 1:20
            t(end + 1, 1) = idx * dt; %#ok<AGROW>
            gyro(end + 1, :) = bg + 3e-4 * randn(1, 3); %#ok<AGROW>
            acc(end + 1, :) = rawMean.' + 0.01 * randn(1, 3); %#ok<AGROW>
            temp(end + 1, 1) = T + 0.05 * randn(1, 1); %#ok<AGROW>
            biasTruth(end + 1, :) = ba; %#ok<AGROW>
            idx = idx + 1;
        end
        for k = 1:5
            t(end + 1, 1) = idx * dt; %#ok<AGROW>
            gyro(end + 1, :) = bg + 0.15 * randn(1, 3); %#ok<AGROW>
            acc(end + 1, :) = 0.8 * randn(1, 3); %#ok<AGROW>
            temp(end + 1, 1) = T + 0.05 * randn(1, 1); %#ok<AGROW>
            biasTruth(end + 1, :) = ba; %#ok<AGROW>
            idx = idx + 1;
        end
    end
end

staticData = struct();
staticData.t = t;
staticData.gyro = gyro;
staticData.acc = acc;
staticData.temp = temp;
end
