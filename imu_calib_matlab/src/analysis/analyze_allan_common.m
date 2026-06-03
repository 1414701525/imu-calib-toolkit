function allan = analyze_allan_common(t, x, sensorType, varargin)
%ANALYZE_ALLAN_COMMON Shared Allan deviation implementation for 3-axis signals.

validateattributes(t, {'numeric'}, {'column', 'nonempty', 'finite'}, mfilename, 't', 1);
validateattributes(x, {'numeric'}, {'2d', 'ncols', 3, 'nonempty', 'finite'}, mfilename, 'x', 2);
if size(x, 1) ~= numel(t)
    error('analyze_allan_common:LengthMismatch', ...
        't and x must have matching lengths.');
end

opts = parse_options(varargin{:});
N = size(x, 1);
dt = median(diff(t));

allan = struct();
allan.valid = false;
allan.sensor_type = sensorType;
allan.message = '';
allan.tau = [];
allan.adev = [];
allan.num_samples = N;

if N < opts.min_samples
    allan.message = opts.validity_message_if_short;
    return;
end

maxM = max(2, floor(N / 10));
if maxM < 2
    allan.message = 'Insufficient data length for Allan deviation.';
    return;
end

switch lower(opts.tau_mode)
    case 'logspace'
        mList = unique(max(1, round(logspace(0, log10(maxM), opts.num_tau))));
    otherwise
        mList = 1:maxM;
end

mList = mList(mList >= 1);
tau = mList(:) * dt;
adev = NaN(numel(mList), 3);

for k = 1:numel(mList)
    m = mList(k);
    clusterCount = floor(N / m);
    if clusterCount < 2
        continue;
    end

    trimmed = x(1:(clusterCount * m), :);
    clustered = squeeze(mean(reshape(trimmed, m, clusterCount, 3), 1));
    if clusterCount == 2 && isvector(clustered)
        clustered = reshape(clustered, 2, 3);
    end

    diffCluster = diff(clustered, 1, 1);
    adev(k, :) = sqrt(0.5 * mean(diffCluster .^ 2, 1));
end

validRows = all(isfinite(adev), 2);
tau = tau(validRows);
adev = adev(validRows, :);

if isempty(tau)
    allan.message = 'Allan deviation could not be estimated from the provided data.';
    return;
end

allan.valid = true;
allan.message = 'Allan deviation estimated using non-overlapping cluster averages.';
allan.tau = tau;
allan.adev = adev;
allan.estimate = estimate_allan_params(tau, adev, sensorType);
end

function opts = parse_options(varargin)
defaults = default_calib_options();
opts = defaults.allan;

if mod(numel(varargin), 2) ~= 0
    error('analyze_allan_common:InvalidInput', ...
        'Optional arguments must be provided as name/value pairs.');
end

for k = 1:2:numel(varargin)
    name = lower(char(varargin{k}));
    value = varargin{k + 1};
    switch name
        case 'min_samples'
            opts.min_samples = double(value);
        case 'num_tau'
            opts.num_tau = double(value);
        case 'tau_mode'
            opts.tau_mode = char(value);
        case 'validity_message_if_short'
            opts.validity_message_if_short = char(value);
        otherwise
            error('analyze_allan_common:UnknownOption', ...
                'Unknown option "%s".', char(varargin{k}));
    end
end
end

function estimate = estimate_allan_params(tau, adev, sensorType)
estimate = struct();
estimate.noise_density = adev(1, :).';
estimate.bias_instability = min(adev, [], 1).';
estimate.random_walk = (adev(end, :) ./ sqrt(tau(end))).';
estimate.confidence = 'low_to_medium';
estimate.notes = sprintf(['Stage-1 %s Allan estimates are coarse summaries intended for ' ...
    'engineering inspection, not high-accuracy metrology.'], sensorType);
end
