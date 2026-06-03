% test_full_calibration_partial
% 中文说明：
%   验证完整入口 run_full_calibration 在数据集不完整时仍按“能跑多少跑多少”工作。
%   这里使用只有 accPoses 的输入，期望：
%   1. 不直接崩溃
%   2. 返回 partial 模式
%   3. 至少完成 accelerometer calibration
clear;
clc;

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(projectRoot, 'src')));

[data, ~] = load_example_data('forceRegenerate', true, 'saveToMat', false);
accOnly = struct('accPoses', data.accPoses);

task = run_full_calibration(accOnly);

assert(task.success, 'run_full_calibration should succeed when at least one module can run.');
assert(isfield(task.result, 'results') && isfield(task.result.results, 'validation'), ...
    'run_full_calibration should return results.validation.');
assert(strcmp(task.result.results.validation.summary.mode, 'partial'), ...
    'acc-only run should produce partial validation mode.');
assert(any(strcmp(task.result.results.validation.summary.completed_modules, 'acc_calibration')), ...
    'acc-only run should report acc_calibration as a completed module.');

fprintf('test_full_calibration_partial passed.\n');
