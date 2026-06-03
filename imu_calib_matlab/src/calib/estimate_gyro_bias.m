function [bg, info] = estimate_gyro_bias(staticGyro, varargin)
%ESTIMATE_GYRO_BIAS 用静止段数据估计陀螺零偏 bg。
% 用法：
%   bg = estimate_gyro_bias(staticGyro)
%   [bg, info] = estimate_gyro_bias(staticGyro)
%   [bg, info] = estimate_gyro_bias(staticGyro, 't', t, 'temp', temp)
%
% 输入：
%   staticGyro : [N x 3] 静止状态下采集的陀螺输出，单位通常为 rad/s
%
% 可选 name/value 输入：
%   't'        : [N x 1] 时间戳，用于记录该静止段覆盖的时间范围
%   'temp'     : [N x 1] 温度序列，用于记录该静止段的温度范围
%
% 输出：
%   bg         : [3 x 1] 估计得到的陀螺零偏
%   info       : 统计信息结构体，供摘要打印、验证和报告使用
%
% 实现假设：
% - 输入数据对应“近似静止”时段，真实角速度应接近 0。
% - 在这一假设下，静止段均值可视为 bias 主估计，剩余量主要反映噪声。
%
% 相关文件：
% - main_demo.m / run_from_csv.m：调用本函数构建基础标定链路
% - fit_gyro_C_from_angle_increment.m：后续会先减去这里估计的 bg 再积分

validateattributes(staticGyro, {'numeric'}, {'2d', 'ncols', 3, 'nonempty', 'finite'}, ...
    mfilename, 'staticGyro', 1);

opts = parse_options(size(staticGyro, 1), varargin{:});

% 当前工程默认采用“静止段均值 = 零偏估计”的基础工程近似。
% 这样做简单直接，也与后续用静止残差评估噪声的流程保持一致。
bg = mean(staticGyro, 1).';
residual = bsxfun(@minus, staticGyro, bg.');

info = struct();
info.num_samples = size(staticGyro, 1);
info.mean = bg;
info.std = std(residual, 0, 1).';
info.var = var(residual, 0, 1).';
info.rms = sqrt(mean(staticGyro .^ 2, 1)).';
info.residual_rms = sqrt(mean(residual .^ 2, 1)).';
info.max_abs_residual = max(abs(residual), [], 1).';
info.time_span = [];
info.temp_range = [];

if ~isempty(opts.t)
    info.time_span = [opts.t(1); opts.t(end)];
end

if ~isempty(opts.temp)
    info.temp_range = [min(opts.temp); max(opts.temp)];
end
end

function opts = parse_options(expectedLength, varargin)
%PARSE_OPTIONS 解析可选输入，并检查长度是否与样本数一致。
opts = struct('t', [], 'temp', []);

if mod(numel(varargin), 2) ~= 0
    error('estimate_gyro_bias:InvalidInput', ...
        'Optional arguments must be provided as name/value pairs.');
end

for k = 1:2:numel(varargin)
    name = lower(char(varargin{k}));
    value = varargin{k + 1};
    switch name
        case 't'
            validateattributes(value, {'numeric'}, {'column', 'finite', 'numel', expectedLength}, ...
                mfilename, 't');
            opts.t = value(:);
        case 'temp'
            validateattributes(value, {'numeric'}, {'column', 'finite', 'numel', expectedLength}, ...
                mfilename, 'temp');
            opts.temp = value(:);
        otherwise
            error('estimate_gyro_bias:UnknownOption', ...
                'Unknown option "%s".', char(varargin{k}));
    end
end
end
