% demo_generate_data
% 中文说明：
%   强制重新生成 synthetic 示例数据，并保存到 data/example_dataset.mat。
%   当需要更新示例数据或检查真值参数时，可单独运行本脚本。

clear;
clc;

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(projectRoot, 'src')));

[data, truth, meta] = load_example_data('forceRegenerate', true, 'saveToMat', true); %#ok<ASGLU>

fprintf('Synthetic 示例数据已生成并保存到:\n%s\n', meta.mat_path);
fprintf('加速度计姿态数量: %d\n', numel(data.accPoses));
fprintf('陀螺实验组数量: %d\n', numel(data.gyroRuns));
fprintf('示例真值 bg:\n');
disp(truth.bg_true);
