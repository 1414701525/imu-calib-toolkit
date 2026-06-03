function [Gg, info] = fit_gyro_g_sensitivity(gsensRuns, bg, Cg)
%FIT_GYRO_G_SENSITIVITY 用残差法拟合陀螺 g-灵敏度矩阵 Gg。
% 用法：
%   [Gg, info] = fit_gyro_g_sensitivity(gsensRuns, bg, Cg)
%
% 输入：
%   gsensRuns(i).gyro      : [N x 3] 陀螺原始测量
%   gsensRuns(i).acc_ref   : [N x 3] 用于拟合 Gg 的 specific force 输入项
%   gsensRuns(i).omega_ref : [N x 3] 可选参考角速度
%   bg                     : [3 x 1] 陀螺零偏
%   Cg                     : [3 x 3] 已估计的陀螺总矩阵
%
% 模型：
%   r = omega_m - bg - Cg * omega_ref
%   r ~= Gg * f
%
% 输出：
%   Gg   : [3 x 3] g-灵敏度矩阵
%   info : struct，包含有效性、设计矩阵秩、残差 RMS 等诊断信息
%
% 关键口径：
% - 本函数把 gsensRuns.acc_ref 视为 Gg 的输入项 f。
% - 因此在线补偿阶段也必须对同一种定义的 f 使用该 Gg，
%   否则会产生“拟合定义与补偿定义不一致”的误差。
% - 若数据不足，函数按工程约定返回 zeros(3) 并附带原因说明。

validateattributes(bg, {'numeric'}, {'vector', 'numel', 3, 'finite'}, mfilename, 'bg', 2);
validateattributes(Cg, {'numeric'}, {'size', [3, 3], 'finite'}, mfilename, 'Cg', 3);
bg = bg(:);

if nargin < 1 || isempty(gsensRuns) || numel(gsensRuns) == 0
    Gg = zeros(3);
    info = struct( ...
        'message', 'No gsensRuns provided. Returning zeros(3).', ...
        'valid', false, ...
        'gsens_term', 'sensor_axis_specific_force', ...
        'gsens_definition', ['Gg is fit against gsensRuns.acc_ref and must be applied to the ' ...
                             'same sensor-axis specific force definition online.'], ...
        'num_runs', 0, ...
        'num_samples', 0, ...
        'design_rank', NaN, ...
        'joint_design_rank', NaN, ...
        'joint_design_condition', NaN, ...
        'residual_rms', NaN, ...
        'max_abs_residual', NaN);
    return;
end

numRuns = numel(gsensRuns);
numSamplesPerRun = zeros(numRuns, 1);
for i = 1:numRuns
    validate_gsens_run(gsensRuns(i), i);
    numSamplesPerRun(i) = size(gsensRuns(i).gyro, 1);
end

totalSamples = sum(numSamplesPerRun);
F = zeros(totalSamples, 3);
R = zeros(totalSamples, 3);

rowStart = 1;
for i = 1:numRuns
    run = gsensRuns(i);
    gyro = run.gyro;
    accRef = run.acc_ref;

    if isfield(run, 'omega_ref') && ~isempty(run.omega_ref)
        omegaRef = run.omega_ref;
    else
        omegaRef = zeros(size(gyro));
    end

    % 先减去已知的 bg 和 Cg * omega_ref，剩余部分再尝试由 Gg * f 解释。
    modelTerm = (Cg * omegaRef.').';
    residual = bsxfun(@minus, gyro, bg.') - modelTerm;

    rowEnd = rowStart + numSamplesPerRun(i) - 1;
    F(rowStart:rowEnd, :) = accRef;
    R(rowStart:rowEnd, :) = residual;
    rowStart = rowEnd + 1;
end

if totalSamples < 3 || rank(F) < 3
    Gg = zeros(3);
    info = struct( ...
        'message', 'Insufficient gsens excitation. Returning zeros(3).', ...
        'valid', false, ...
        'gsens_term', 'sensor_axis_specific_force', ...
        'gsens_definition', ['Gg is fit against gsensRuns.acc_ref and must be applied to the ' ...
                             'same sensor-axis specific force definition online.'], ...
        'num_runs', numRuns, ...
        'num_samples', totalSamples, ...
        'design_rank', rank(F), ...
        'joint_design_rank', NaN, ...
        'joint_design_condition', NaN, ...
        'residual_rms', NaN, ...
        'max_abs_residual', NaN);
    return;
end

% 显式 9 参数联合最小二乘：
%   vec(r_i) = kron(f_i', I3) * vec(Gg)
% 这样能一次性求出完整的 3x3 Gg，而不是逐轴分别回归。
A = zeros(3 * totalSamples, 9);
y = zeros(3 * totalSamples, 1);
for i = 1:totalSamples
    rows = (3 * (i - 1) + 1):(3 * i);
    A(rows, :) = kron(F(i, :), eye(3));
    y(rows) = R(i, :).';
end

jointRank = rank(A);
if jointRank < 9
    Gg = zeros(3);
    info = struct( ...
        'message', 'Insufficient excitation for joint 9-parameter Gg fit. Returning zeros(3).', ...
        'valid', false, ...
        'gsens_term', 'sensor_axis_specific_force', ...
        'gsens_definition', ['Gg is fit against gsensRuns.acc_ref and must be applied to the ' ...
                             'same sensor-axis specific force definition online.'], ...
        'num_runs', numRuns, ...
        'num_samples', totalSamples, ...
        'design_rank', rank(F), ...
        'joint_design_rank', jointRank, ...
        'joint_design_condition', Inf, ...
        'residual_rms', NaN, ...
        'max_abs_residual', NaN);
    return;
end

x = A \ y;
Gg = reshape(x, 3, 3);

fitResidualVec = y - A * x;
fitResidual = reshape(fitResidualVec, 3, []).';

info = struct();
info.message = 'Gg fitted using joint 9-parameter least squares.';
info.valid = true;
info.gsens_term = 'sensor_axis_specific_force';
info.gsens_definition = ['Gg is fit against gsensRuns.acc_ref and must be applied to the ' ...
                         'same sensor-axis specific force definition online.'];
info.num_runs = numRuns;
info.num_samples = totalSamples;
info.design_rank = rank(F);
info.joint_design_rank = jointRank;
info.joint_design_condition = cond(A);
info.residual_rms = sqrt(mean(fitResidual(:) .^ 2));
info.max_abs_residual = max(abs(fitResidual(:)));
end

function validate_gsens_run(run, idx)
%VALIDATE_GSENS_RUN 检查单个 gsens run 的字段和维度是否合法。
requiredFields = {'gyro', 'acc_ref', 't'};
for i = 1:numel(requiredFields)
    if ~isfield(run, requiredFields{i})
        error('fit_gyro_g_sensitivity:MissingField', ...
            'gsensRuns(%d) is missing field "%s".', idx, requiredFields{i});
    end
end

validateattributes(run.gyro, {'numeric'}, {'2d', 'ncols', 3, 'nonempty', 'finite'}, ...
    mfilename, sprintf('gsensRuns(%d).gyro', idx));
validateattributes(run.acc_ref, {'numeric'}, {'2d', 'ncols', 3, 'nonempty', 'finite'}, ...
    mfilename, sprintf('gsensRuns(%d).acc_ref', idx));
validateattributes(run.t, {'numeric'}, {'column', 'nonempty', 'finite'}, ...
    mfilename, sprintf('gsensRuns(%d).t', idx));

if size(run.gyro, 1) ~= size(run.acc_ref, 1) || size(run.gyro, 1) ~= numel(run.t)
    error('fit_gyro_g_sensitivity:LengthMismatch', ...
        'gsensRuns(%d) fields gyro, acc_ref, and t must have the same length.', idx);
end

if isfield(run, 'omega_ref') && ~isempty(run.omega_ref) && size(run.omega_ref, 1) ~= size(run.gyro, 1)
    error('fit_gyro_g_sensitivity:OmegaRefLengthMismatch', ...
        'gsensRuns(%d).omega_ref length must match gyro length.', idx);
end
end
