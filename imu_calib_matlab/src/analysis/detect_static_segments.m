function result = detect_static_segments(t, gyro, acc, varargin)
%DETECT_STATIC_SEGMENTS Detect static segments from gyro and accelerometer data.
% Usage:
%   result = detect_static_segments(t, gyro, acc)
%
% Output:
%   result.mask         : [N x 1] logical
%   result.segments     : [M x 2] start/end indices
%   result.quality      : struct with thresholds and summary

validateattributes(t, {'numeric'}, {'column', 'finite', 'nonempty'}, mfilename, 't', 1);
validateattributes(gyro, {'numeric'}, {'2d', 'ncols', 3, 'finite', 'nonempty'}, mfilename, 'gyro', 2);
validateattributes(acc, {'numeric'}, {'2d', 'ncols', 3, 'finite', 'nonempty'}, mfilename, 'acc', 3);

if size(gyro, 1) ~= numel(t) || size(acc, 1) ~= numel(t)
    error('detect_static_segments:LengthMismatch', ...
        't, gyro, and acc must have matching lengths.');
end

opts = parse_options(varargin{:});
dt = median(diff(t));
win = max(3, round(opts.static_window_sec / dt));

gyroNorm = sqrt(sum(gyro .^ 2, 2));
gyroStd = moving_std_scalar(gyroNorm, win);
accMag = sqrt(sum(acc .^ 2, 2));
accStd = moving_std_scalar(accMag, win);

mask = (gyroNorm <= opts.gyro_norm_threshold) & ...
       (gyroStd <= opts.gyro_std_threshold) & ...
       (accStd <= opts.acc_std_threshold);

segments = logical_mask_to_segments(mask, round(opts.min_segment_sec / dt));

result = struct();
result.mask = mask;
result.segments = segments;
result.quality = struct();
result.quality.window_samples = win;
result.quality.gyro_norm_threshold = opts.gyro_norm_threshold;
result.quality.gyro_std_threshold = opts.gyro_std_threshold;
result.quality.acc_std_threshold = opts.acc_std_threshold;
result.quality.num_segments = size(segments, 1);
end

function opts = parse_options(varargin)
defaults = default_calib_options();
opts = defaults.segmentation;

if mod(numel(varargin), 2) ~= 0
    error('detect_static_segments:InvalidInput', ...
        'Optional arguments must be provided as name/value pairs.');
end

for k = 1:2:numel(varargin)
    name = lower(char(varargin{k}));
    value = varargin{k + 1};
    switch name
        case 'static_window_sec'
            opts.static_window_sec = double(value);
        case 'gyro_norm_threshold'
            opts.gyro_norm_threshold = double(value);
        case 'gyro_std_threshold'
            opts.gyro_std_threshold = double(value);
        case 'acc_std_threshold'
            opts.acc_std_threshold = double(value);
        case 'min_segment_sec'
            opts.min_segment_sec = double(value);
        otherwise
            error('detect_static_segments:UnknownOption', ...
                'Unknown option "%s".', char(varargin{k}));
    end
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
