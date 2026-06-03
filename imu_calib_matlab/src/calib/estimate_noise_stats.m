function stats = estimate_noise_stats(staticGyro, staticAcc)
%ESTIMATE_NOISE_STATS 统计静态陀螺与加速度计的基础噪声指标。
% 用法：
%   stats = estimate_noise_stats(staticGyro, staticAcc)
%
% 输入：
%   staticGyro : [N x 3] 静止段陀螺数据
%   staticAcc  : [N x 3] 静止段加速度计数据
%
% 输出：
%   stats : 结构体，至少包含：
%           - gyro_mean / acc_mean
%           - gyro_std / gyro_var
%           - acc_std  / acc_var
%           - gyro_residual / acc_residual
%
% 说明：
% - 当前函数的定位是“基础噪声统计”，不是 Allan 或 PSD 分析。
% - 为避免把静态偏置直接混入噪声量，本函数先去均值，再计算 std / var。
% - 这样定义 residual 也便于后续 Allan / PSD 模块复用同一份输入口径。

validateattributes(staticGyro, {'numeric'}, {'2d', 'ncols', 3, 'nonempty', 'finite'}, ...
    mfilename, 'staticGyro', 1);
validateattributes(staticAcc, {'numeric'}, {'2d', 'ncols', 3, 'nonempty', 'finite'}, ...
    mfilename, 'staticAcc', 2);

% 这里显式去均值，是为了让“噪声统计”更接近随机波动本身，
% 而不是把系统误差或静态姿态均值一并算进去。
gyroMean = mean(staticGyro, 1);
accMean = mean(staticAcc, 1);
gyroResidual = bsxfun(@minus, staticGyro, gyroMean);
accResidual = bsxfun(@minus, staticAcc, accMean);

stats = struct();
stats.gyro_mean = gyroMean.';
stats.acc_mean = accMean.';
stats.gyro_std = std(gyroResidual, 0, 1).';
stats.gyro_var = var(gyroResidual, 0, 1).';
stats.acc_std = std(accResidual, 0, 1).';
stats.acc_var = var(accResidual, 0, 1).';
stats.num_samples = size(staticGyro, 1);
stats.gyro_residual = gyroResidual;
stats.acc_residual = accResidual;
% Allan / PSD 目前仅保留扩展接口，避免破坏本函数当前的轻量定位。
stats.extensions = struct( ...
    'allan', [], ...
    'psd', [], ...
    'notes', 'Placeholder for future Allan variance / PSD estimation.');
end
