% test_task_acc_only
% 中文说明：
%   验证只提供 accPoses 时，加速度计多位置标定模块可以独立运行，
%   且不会要求 static / gyroRuns / gsensRuns 同时存在。
clear;
clc;

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(projectRoot, 'src')));

[data, ~] = load_example_data('forceRegenerate', true, 'saveToMat', false);
accOnly = struct('accPoses', data.accPoses);

task = run_acc_calibration(accOnly);

assert(task.success, 'run_acc_calibration should succeed for acc-only input.');
assert(isfield(task.result, 'Ca') && isequal(size(task.result.Ca), [3, 3]), ...
    'run_acc_calibration should return a 3x3 Ca matrix.');
assert(isfield(task.result, 'ba') && isequal(size(task.result.ba), [3, 1]), ...
    'run_acc_calibration should return a 3x1 ba vector.');

fprintf('test_task_acc_only passed.\n');
