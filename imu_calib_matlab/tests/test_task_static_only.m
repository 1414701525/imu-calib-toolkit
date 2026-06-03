% test_task_static_only
% 中文说明：
%   验证只提供 static 数据时，任务层仍可独立完成：
%   1. 陀螺 bias 估计
%   2. 静态噪声统计
%   3. Allan 分析
%   同时不要求 accPoses / gyroRuns / gsensRuns 存在。
clear;
clc;

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(projectRoot, 'src')));

[data, ~] = load_example_data('forceRegenerate', true, 'saveToMat', false);
staticOnly = struct('static', data.static);

biasTask = run_gyro_bias(staticOnly);
noiseTask = run_noise_stats(staticOnly);
allanTask = run_allan_analysis(staticOnly);

assert(biasTask.success, 'run_gyro_bias should succeed for static-only input.');
assert(noiseTask.success, 'run_noise_stats should succeed for static-only input.');
assert(allanTask.success, 'run_allan_analysis should succeed for static-only input.');
assert(isempty(biasTask.missing_inputs), 'static-only gyro bias should not report missing inputs.');

fprintf('test_task_static_only passed.\n');
