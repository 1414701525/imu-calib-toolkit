% test_partial_loader
% 中文说明：
%   验证 load_csv_data 支持部分文件存在的情况。
%   这里检查两种典型场景：
%   1. 目录里只有 static.csv
%   2. 目录里只有 acc_poses.csv
clear;
clc;

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(projectRoot, 'src')));

tmpRoot = tempname;
mkdir(tmpRoot);

cleanupObj = onCleanup(@() cleanup_temp_dir(tmpRoot));

%% Case 1: static only
case1 = fullfile(tmpRoot, 'case_static_only');
mkdir(case1);
Tstatic = table( ...
    (0:4).', ...
    zeros(5, 1), zeros(5, 1), zeros(5, 1), ...
    zeros(5, 1), zeros(5, 1), 9.81 * ones(5, 1), ...
    'VariableNames', {'t', 'gx', 'gy', 'gz', 'ax', 'ay', 'az'});
writetable(Tstatic, fullfile(case1, 'static.csv'));

data1 = load_csv_data(case1);
assert(data1.meta.has_static, 'static-only folder should load static block.');
assert(~data1.meta.has_acc_poses, 'static-only folder should not report accPoses.');
assert(~data1.meta.has_gyro_runs, 'static-only folder should not report gyroRuns.');

%% Case 2: acc poses only
case2 = fullfile(tmpRoot, 'case_acc_only');
mkdir(case2);
Tacc = table( ...
    ["+X"; "-X"], ...
    [9.81; -9.81], [0; 0], [0; 0], ...
    'VariableNames', {'pose_name', 'acc_x', 'acc_y', 'acc_z'});
writetable(Tacc, fullfile(case2, 'acc_poses.csv'));

data2 = load_csv_data(case2);
assert(~data2.meta.has_static, 'acc-only folder should not report static block.');
assert(data2.meta.has_acc_poses, 'acc-only folder should load accPoses block.');
assert(~data2.meta.has_gyro_runs, 'acc-only folder should not report gyroRuns.');
assert(isempty(data2.accPoses(1).a_ref), 'New acc_poses loader should not require legacy reference columns.');

fprintf('test_partial_loader passed.\n');

function cleanup_temp_dir(pathStr)
if exist(pathStr, 'dir')
    rmdir(pathStr, 's');
end
end
