% demo_export_bundle
% 中文说明：
%   将 synthetic 示例数据导出为统一交换格式：
%   dataset_manifest.json + 多个 CSV 文件。
%   该格式用于 MATLAB / Python 之间共享同一组实验数据。

clear;
clc;

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(projectRoot, 'src')));

[data, ~, ~] = load_example_data('saveToMat', true);
outDir = fullfile(projectRoot, 'data', 'example_bundle');

export_dataset_bundle(data, outDir);

fprintf('统一交换格式数据已导出到:\n%s\n', outDir);
