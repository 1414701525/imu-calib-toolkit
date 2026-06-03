function [Cg, info] = fit_gyro_C_from_angle_increment(gyroRuns, bg)
%FIT_GYRO_C_FROM_ANGLE_INCREMENT 用角度增量真值拟合陀螺总矩阵 Cg。
% 用法：
%   [Cg, info] = fit_gyro_C_from_angle_increment(gyroRuns, bg)
%
% 输入：
%   gyroRuns(i).gyro      : [N x 3] 第 i 组实验的陀螺时序
%   gyroRuns(i).t         : [N x 1] 时间戳，要求严格递增
%   gyroRuns(i).theta_ref : [3 x 1] 该组实验的参考角度增量
%   gyroRuns(i).idx_ss    : [N x 1] logical，稳态区间标记
%   bg                    : [3 x 1] 预估陀螺零偏
%
% 模型：
%   dtheta_m = Cg * dtheta_ref
%
% 输出：
%   Cg   : [3 x 3] 陀螺总矩阵
%   info : struct，包含逐 run 积分量、残差、秩和条件数等诊断信息
%
% 关键说明：
% - 当前工程不直接用瞬时角速度做主拟合，而是只取稳态段 idx_ss，
%   对去零偏后的角速度积分，得到 dtheta_m 再拟合。
% - 这样更贴合实验上常见的“总转角真值”获取方式，也能减轻瞬时噪声
%   和启停过渡段对拟合的影响。

if isempty(gyroRuns)
    error('fit_gyro_C_from_angle_increment:EmptyInput', ...
        'gyroRuns must not be empty.');
end

validateattributes(bg, {'numeric'}, {'vector', 'numel', 3, 'finite'}, ...
    mfilename, 'bg', 2);
bg = bg(:);

numRuns = numel(gyroRuns);
A = zeros(3 * numRuns, 9);
y = zeros(3 * numRuns, 1);

runInfo = repmat(struct('axis', 'x', ...
                        'dir', 1, ...
                        'num_ss_samples', 0, ...
                        'dtheta_m', zeros(3, 1), ...
                        'theta_ref', zeros(3, 1), ...
                        'dtheta_pred', zeros(3, 1), ...
                        'residual', zeros(3, 1), ...
                        'residual_norm', 0), numRuns, 1);

for i = 1:numRuns
    run = gyroRuns(i);
    validate_run(run, i);

    t = run.t(:);
    idxSS = logical(run.idx_ss(:));
    gyro = run.gyro;
    thetaRef = run.theta_ref(:);

    if nnz(idxSS) < 2
        error('fit_gyro_C_from_angle_increment:ShortSteadySegment', ...
            'Run %d steady-state segment must contain at least 2 samples.', i);
    end

    tSS = t(idxSS);
    gyroSS = gyro(idxSS, :);
    % 先减去静态零偏，再在稳态区间积分，得到测得的角度增量 dtheta_m。
    gyroCorrected = bsxfun(@minus, gyroSS, bg.');
    dthetaM = trapz(tSS, gyroCorrected, 1).';

    rows = (3 * (i - 1) + 1):(3 * i);
    % 把 3x3 的 Cg 展成 9 维未知量后，可写成标准线性最小二乘形式。
    A(rows, :) = kron(thetaRef.', eye(3));
    y(rows) = dthetaM;

    runInfo(i).axis = run.axis;
    runInfo(i).dir = run.dir;
    runInfo(i).num_ss_samples = nnz(idxSS);
    runInfo(i).dtheta_m = dthetaM;
    runInfo(i).theta_ref = thetaRef;
end

if rank(A) < 9
    error('fit_gyro_C_from_angle_increment:RankDeficient', ...
        'The gyro least-squares system is rank-deficient. Add runs around all axes.');
end

% 当前版本保留基础线性最小二乘实现，便于核对模型与调试。
x = A \ y;
Cg = reshape(x, 3, 3);

cgRcond = rcond(Cg);
if ~isfinite(cgRcond) || cgRcond < 1e-12
    error('fit_gyro_C_from_angle_increment:IllConditionedCg', ...
        'Estimated Cg is numerically singular or nearly singular (rcond = %.3e).', cgRcond);
elseif cgRcond < 1e-8
    warning('fit_gyro_C_from_angle_increment:PoorConditionCg', ...
        'Estimated Cg is poorly conditioned (rcond = %.3e). Results may be unstable.', cgRcond);
end

yHat = A * x;
residualVec = y - yHat;

for i = 1:numRuns
    thetaRef = runInfo(i).theta_ref;
    dthetaPred = Cg * thetaRef;
    % 残差表示“积分得到的测量角增量”与“Cg 预测角增量”的差。
    residual = runInfo(i).dtheta_m - dthetaPred;

    runInfo(i).dtheta_pred = dthetaPred;
    runInfo(i).residual = residual;
    runInfo(i).residual_norm = norm(residual);
end

info = struct();
info.num_runs = numRuns;
info.A_rank = rank(A);
info.A_condition = cond(A);
info.Cg_rcond = cgRcond;
info.residual_vector = residualVec;
info.residual_rms = sqrt(mean(residualVec .^ 2));
info.max_abs_residual = max(abs(residualVec));
info.runs = runInfo;
end

function validate_run(run, idx)
%VALIDATE_RUN 检查单个 gyro run 是否满足求解器输入要求。
requiredFields = {'gyro', 't', 'theta_ref', 'idx_ss', 'axis', 'dir'};
for i = 1:numel(requiredFields)
    if ~isfield(run, requiredFields{i})
        error('fit_gyro_C_from_angle_increment:MissingField', ...
            'Run %d is missing required field "%s".', idx, requiredFields{i});
    end
end

validateattributes(run.gyro, {'numeric'}, {'2d', 'ncols', 3, 'nonempty', 'finite'}, ...
    mfilename, sprintf('gyroRuns(%d).gyro', idx));
validateattributes(run.t, {'numeric'}, {'column', 'nonempty', 'finite'}, ...
    mfilename, sprintf('gyroRuns(%d).t', idx));
validateattributes(run.theta_ref, {'numeric'}, {'vector', 'numel', 3, 'finite'}, ...
    mfilename, sprintf('gyroRuns(%d).theta_ref', idx));

if size(run.gyro, 1) ~= numel(run.t)
    error('fit_gyro_C_from_angle_increment:LengthMismatch', ...
        'Run %d gyro and time length must match.', idx);
end

if numel(run.idx_ss) ~= numel(run.t)
    error('fit_gyro_C_from_angle_increment:IdxLengthMismatch', ...
        'Run %d idx_ss length must match the time vector.', idx);
end

if any(diff(run.t(:)) <= 0)
    error('fit_gyro_C_from_angle_increment:NonMonotonicTime', ...
        'Run %d time vector must be strictly increasing.', idx);
end
end
