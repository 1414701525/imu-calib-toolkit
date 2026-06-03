% test_acc_fit
% 中文说明：
%   验证加速度计矩阵 Ca 与偏置 ba 的拟合结果是否接近 synthetic 真值。

clear;
clc;

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(projectRoot, 'src')));

[data, truth] = load_example_data('forceRegenerate', true, 'saveToMat', false);
[Ca, ba] = fit_acc_multi_pose(data.accPoses);

caErr = max(abs(Ca(:) - truth.Ca_true(:)));
baErr = max(abs(ba - truth.ba_true));

assert(caErr < 1.5e-2, '加速度计矩阵拟合超出容差，最大绝对误差 = %.6g', caErr);
assert(baErr < 2.0e-2, '加速度计偏置拟合超出容差，最大绝对误差 = %.6g', baErr);

fprintf('test_acc_fit 通过，max |Ca err| = %.6g, max |ba err| = %.6g\n', caErr, baErr);
