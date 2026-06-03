% test_task_gsens_only
% 中文说明：
%   验证只提供 gsensRuns 与外部 Cg / bg 时，Gg 模块可以独立运行。
%   该测试不要求 accPoses、static 或 gyroRuns 同时存在。
clear;
clc;

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(projectRoot, 'src')));

[data, truth] = load_example_data('forceRegenerate', true, 'saveToMat', false);
gsensOnly = struct('gsensRuns', data.gsensRuns);

task = run_gsens_fit(gsensOnly, 'bg', truth.bg_true, 'Cg', truth.Cg_true);

assert(task.success, 'run_gsens_fit should succeed for gsens-only input when Cg and bg are provided.');
assert(isfield(task.result, 'Gg') && isequal(size(task.result.Gg), [3, 3]), ...
    'run_gsens_fit should return a 3x3 Gg matrix.');

fprintf('test_task_gsens_only passed.\n');
