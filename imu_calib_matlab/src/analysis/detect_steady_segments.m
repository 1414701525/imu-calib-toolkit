function result = detect_steady_segments(t, gyro, varargin)
%DETECT_STEADY_SEGMENTS Detect steady rotation segments from gyro data.
% Usage:
%   result = detect_steady_segments(t, gyro)
%
% Output:
%   result.mask         : [N x 1] logical
%   result.segments     : [M x 2] start/end indices
%   result.quality      : struct with thresholds and summary

validateattributes(t, {'numeric'}, {'column', 'finite', 'nonempty'}, mfilename, 't', 1);
validateattributes(gyro, {'numeric'}, {'2d', 'ncols', 3, 'finite', 'nonempty'}, mfilename, 'gyro', 2);

if size(gyro, 1) ~= numel(t)
    error('detect_steady_segments:LengthMismatch', ...
        't and gyro must have matching lengths.');
end

opts = parse_options(varargin{:});
dt = median(diff(t));
win = max(3, round(opts.steady_window_sec / dt));

gyroNorm = sqrt(sum(gyro .^ 2, 2));
gyroStd = moving_std_scalar(gyroNorm, win);
gyroMean = moving_mean_scalar(gyroNorm, win);

mask = (gyroMean > opts.gyro_norm_threshold) & (gyroStd <= opts.gyro_std_threshold);
segments = logical_mask_to_segments(mask, round(opts.min_segment_sec / dt));

result = struct();
result.mask = mask;
result.segments = segments;
result.quality = struct();
result.quality.window_samples = win;
result.quality.gyro_norm_threshold = opts.gyro_norm_threshold;
result.quality.gyro_std_threshold = opts.gyro_std_threshold;
result.quality.num_segments = size(segments, 1);
end

function opts = parse_options(varargin)
defaults = default_calib_options();
opts = defaults.segmentation;

if mod(numel(varargin), 2) ~= 0
    error('detect_steady_segments:InvalidInput', ...
        'Optional arguments must be provided as name/value pairs.');
end

for k = 1:2:numel(varargin)
    name = lower(char(varargin{k}));
    value = varargin{k + 1};
    switch name
        case 'steady_window_sec'
            opts.steady_window_sec = double(value);
        case 'gyro_norm_threshold'
            opts.gyro_norm_threshold = double(value);
        case 'gyro_std_threshold'
            opts.gyro_std_threshold = double(value);
        case 'min_segment_sec'
            opts.min_segment_sec = double(value);
        otherwise
            error('detect_steady_segments:UnknownOption', ...
                'Unknown option "%s".', char(varargin{k}));
    end
end
end

function m = moving_mean_scalar(x, win)
m = zeros(size(x));
halfWin = floor(win / 2);
for i = 1:numel(x)
    i0 = max(1, i - halfWin);
    i1 = min(numel(x), i + halfWin);
    m(i) = mean(x(i0:i1));
end
end

function s = moving_std_scalar(x, win)
s = zeros(size(x));
halfWin = floor(win / 2);
for i = 1:numel(x)
    i0 = max(1, i - halfWin);
    i1 = min(numel(x), i + halfWin);
    s(i) = std(x(i0:i1));
end
end

function segments = logical_mask_to_segments(mask, minLen)
d = diff([false; mask(:); false]);
starts = find(d == 1);
ends = find(d == -1) - 1;
keep = (ends - starts + 1) >= minLen;
segments = [starts(keep), ends(keep)];
end
