% test_task_gyro_only
% 中文说明：
%   验证只提供 gyroRuns 与外部 bg 时，陀螺 Cg 标定模块可以独立运行，
%   不依赖 accPoses 或 gsensRuns。
clear;
clc;

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(projectRoot, 'src')));

[data, truth] = load_example_data('forceRegenerate', true, 'saveToMat', false);
gyroOnly = struct('gyroRuns', data.gyroRuns);

task = run_gyro_calibration(gyroOnly, 'bg', truth.bg_true);

assert(task.success, 'run_gyro_calibration should succeed for gyro-only input when bg is provided.');
assert(isfield(task.result, 'Cg') && isequal(size(task.result.Cg), [3, 3]), ...
    'run_gyro_calibration should return a 3x3 Cg matrix.');
assert(isfield(task.result, 'Kg') && isfield(task.result, 'Mg'), ...
    'run_gyro_calibration should also return Kg and Mg.');

fprintf('test_task_gyro_only passed.\n');
