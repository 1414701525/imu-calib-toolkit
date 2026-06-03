% test_gyro_fit
% 中文说明：
%   验证基于角度增量拟合的陀螺总矩阵 Cg 是否接近 synthetic 真值。

clear;
clc;

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(projectRoot, 'src')));

[data, truth] = load_example_data('forceRegenerate', true, 'saveToMat', false);
bg = estimate_gyro_bias(data.static.gyro);
[Cg, info] = fit_gyro_C_from_angle_increment(data.gyroRuns, bg); %#ok<ASGLU>

cgErr = max(abs(Cg(:) - truth.Cg_true(:)));

assert(cgErr < 7e-3, '陀螺总矩阵拟合超出容差，最大绝对误差 = %.6g', cgErr);

fprintf('test_gyro_fit 通过，max |Cg err| = %.6g\n', cgErr);
