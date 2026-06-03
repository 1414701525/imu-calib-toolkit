function [poses, info] = extract_static_pose_means(staticData, varargin)
%EXTRACT_STATIC_POSE_MEANS Convert continuous static data into pose means.
% Usage:
%   [poses, info] = extract_static_pose_means(staticData)
%   [poses, info] = extract_static_pose_means(staticData, 'options', options)

if nargin < 1 || ~isstruct(staticData)
    error('extract_static_pose_means:InvalidInput', ...
        'staticData must be provided as a struct.');
end

required = {'t', 'gyro', 'acc'};
for i = 1:numel(required)
    if ~isfield(staticData, required{i}) || isempty(staticData.(required{i}))
        error('extract_static_pose_means:MissingField', ...
            'staticData.%s is required.', required{i});
    end
end

opts = parse_options(varargin{:});
seg = detect_static_segments(staticData.t(:), staticData.gyro, staticData.acc, ...
    'static_window_sec', opts.options.segmentation.static_window_sec, ...
    'gyro_norm_threshold', opts.options.segmentation.gyro_norm_threshold, ...
    'gyro_std_threshold', opts.options.segmentation.gyro_std_threshold, ...
    'acc_std_threshold', opts.options.segmentation.acc_std_threshold, ...
    'min_segment_sec', opts.options.segmentation.min_segment_sec);

segments = seg.segments;
numSegments = size(segments, 1);
poses = repmat(struct('acc_mean', zeros(3, 1), ...
                      'pose_name', '', ...
                      'a_ref', []), numSegments, 1);
segmentRows = repmat(struct('pose_name', '', ...
                            'start_idx', 0, ...
                            'end_idx', 0, ...
                            'num_samples', 0, ...
                            'duration_sec', 0, ...
                            'acc_mean', zeros(3, 1), ...
                            'gyro_mean', zeros(3, 1), ...
                            'temp_mean', []), numSegments, 1);

for idx = 1:numSegments
    startIdx = segments(idx, 1);
    endIdx = segments(idx, 2);
    sl = startIdx:endIdx;

    accMean = mean(staticData.acc(sl, :), 1).';
    gyroMean = mean(staticData.gyro(sl, :), 1).';
    if endIdx > startIdx
        durationSec = double(staticData.t(endIdx) - staticData.t(startIdx));
    else
        durationSec = 0.0;
    end
    poseName = sprintf('static_seg_%02d', idx);

    poses(idx).acc_mean = accMean;
    poses(idx).pose_name = poseName;
    poses(idx).a_ref = [];

    segmentRows(idx).pose_name = poseName;
    segmentRows(idx).start_idx = startIdx;
    segmentRows(idx).end_idx = endIdx;
    segmentRows(idx).num_samples = endIdx - startIdx + 1;
    segmentRows(idx).duration_sec = durationSec;
    segmentRows(idx).acc_mean = accMean;
    segmentRows(idx).gyro_mean = gyroMean;
    if isfield(staticData, 'temp') && ~isempty(staticData.temp)
        segmentRows(idx).temp_mean = mean(staticData.temp(sl));
    else
        segmentRows(idx).temp_mean = [];
    end
end

info = struct();
info.source = 'static_segment_extraction';
info.num_segments = numSegments;
info.segment_rows = segmentRows;
info.quality = seg.quality;
info.messages = {'Static segments were extracted from raw static.acc/static.gyro and converted to pose means.'};
end

function opts = parse_options(varargin)
opts = struct();
opts.options = default_calib_options();

if mod(numel(varargin), 2) ~= 0
    error('extract_static_pose_means:InvalidInput', ...
        'Optional arguments must be provided as name/value pairs.');
end

for k = 1:2:numel(varargin)
    name = lower(char(varargin{k}));
    value = varargin{k + 1};
    switch name
        case 'options'
            if ~isstruct(value)
                error('extract_static_pose_means:InvalidOptions', ...
                    'options must be a struct.');
            end
            opts.options = value;
        otherwise
            error('extract_static_pose_means:UnknownOption', ...
                'Unknown option "%s".', char(varargin{k}));
    end
end
end
