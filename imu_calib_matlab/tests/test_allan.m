% test_allan
% Validate Allan analysis modules on the synthetic static dataset.

clear;
clc;

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(projectRoot, 'src')));

[data, ~] = load_example_data('forceRegenerate', true, 'saveToMat', false);

gyroAllan = analyze_gyro_allan(data.static.t, data.static.gyro);
accAllan = analyze_acc_allan(data.static.t, data.static.acc);

assert(isfield(gyroAllan, 'valid') && isfield(gyroAllan, 'message'), ...
    'Gyro Allan output missing required status fields.');
assert(isfield(accAllan, 'valid') && isfield(accAllan, 'message'), ...
    'Accel Allan output missing required status fields.');

if gyroAllan.valid
    assert(~isempty(gyroAllan.tau) && ~isempty(gyroAllan.adev), ...
        'Valid gyro Allan result must contain tau and adev.');
end

if accAllan.valid
    assert(~isempty(accAllan.tau) && ~isempty(accAllan.adev), ...
        'Valid accel Allan result must contain tau and adev.');
end

fprintf('test_allan passed.\n');
