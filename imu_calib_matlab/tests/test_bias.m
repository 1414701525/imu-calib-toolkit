% test_bias
% 中文说明：
%   验证静态陀螺零偏估计结果是否接近 synthetic 真值。

clear;
clc;

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(projectRoot, 'src')));

[data, truth] = load_example_data('forceRegenerate', true, 'saveToMat', false);
bg = estimate_gyro_bias(data.static.gyro);

err = bg - truth.bg_true;
tol = 5e-4;

assert(max(abs(err)) < tol, ...
    '陀螺零偏估计超出容差，最大绝对误差 = %.6g', max(abs(err)));

fprintf('test_bias 通过，最大绝对误差 = %.6g\n', max(abs(err)));
