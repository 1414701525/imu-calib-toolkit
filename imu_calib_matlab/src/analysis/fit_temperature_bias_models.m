function result = fit_temperature_bias_models(varargin)
%FIT_TEMPERATURE_BIAS_MODELS Fit gyro and/or accel temperature bias models.
%
% Two-layer architecture:
%   1. Estimate discrete per-temperature bias samples.
%   2. Fit continuous bg(T) / ba(T) models from those samples.

params = parse_inputs(varargin{:});
tempOpts = get_temperature_options(params.options);
accOpts = get_acc_options(params.options);

method = choose_value(params.method, tempOpts.method);
referenceTemperatureMode = choose_value(params.reference_temperature_mode, tempOpts.reference_temperature_mode);
extrapolationMode = choose_value(params.extrapolation_mode, tempOpts.extrapolation_mode);
minTempSpan = choose_value(params.min_temp_span, tempOpts.min_temp_span);
minSamples = choose_value(params.min_samples, tempOpts.min_samples);
binWidthDegC = choose_value(params.bin_width_degC, tempOpts.bin_width_degC);
minBinSamples = choose_value(params.min_bin_samples, tempOpts.min_bin_samples);
minValidBins = choose_value(params.min_valid_bins, tempOpts.min_valid_bins);
accMinBinPoseCount = choose_value(params.acc_min_bin_pose_count, tempOpts.acc_min_bin_pose_count);
accMinPoseRank = choose_value(params.acc_min_pose_rank, tempOpts.acc_min_pose_rank);
gravityMagnitude = choose_value(params.gravity_magnitude, accOpts.gravity_magnitude);

referenceTemperature = resolve_reference_temperature(params.temp, referenceTemperatureMode);
temperatureRange = resolve_temperature_range(params.temp);

result = struct();
result.reference_temperature = referenceTemperature;
result.temperature_range = temperatureRange;
result.extrapolation_mode = char(string(extrapolationMode));
result.gyro = make_invalid_model('bg', 'Gyro temperature model was not requested.');
result.acc = make_invalid_model('ba', 'Accel temperature model was not requested.');
result.message = 'Temperature model fitting completed.';

if params.fit_gyro
    result.gyro = fit_gyro_temperature_bias_model( ...
        'static_gyro', params.static_gyro, ...
        'temp', params.temp, ...
        'method', method, ...
        'reference_temperature', referenceTemperature, ...
        'extrapolation_mode', extrapolationMode, ...
        'min_temp_span', minTempSpan, ...
        'min_samples', minSamples, ...
        'bin_width_degC', binWidthDegC, ...
        'min_bin_samples', minBinSamples, ...
        'min_valid_bins', minValidBins, ...
        'options', params.options);
end

if params.fit_acc
    result.acc = fit_accel_temperature_bias_model( ...
        'static_acc', params.static_acc, ...
        'temp', params.temp, ...
        'static_data', params.static_data, ...
        'Ca', params.Ca, ...
        'ba0', params.ba0, ...
        'gravity_magnitude', gravityMagnitude, ...
        'method', method, ...
        'reference_temperature', referenceTemperature, ...
        'extrapolation_mode', extrapolationMode, ...
        'min_temp_span', minTempSpan, ...
        'min_samples', minSamples, ...
        'bin_width_degC', binWidthDegC, ...
        'min_bin_samples', minBinSamples, ...
        'min_valid_bins', minValidBins, ...
        'min_bin_pose_count', accMinBinPoseCount, ...
        'min_pose_rank', accMinPoseRank, ...
        'options', params.options);
end
end

function params = parse_inputs(varargin)
defaults = default_calib_options();
params = struct();
params.static_gyro = [];
params.static_acc = [];
params.temp = [];
params.static_data = [];
params.Ca = [];
params.ba0 = [];
params.gravity_magnitude = [];
params.method = [];
params.reference_temperature_mode = [];
params.extrapolation_mode = [];
params.min_temp_span = [];
params.min_samples = [];
params.bin_width_degC = [];
params.min_bin_samples = [];
params.min_valid_bins = [];
params.acc_min_bin_pose_count = [];
params.acc_min_pose_rank = [];
params.options = defaults;
params.fit_gyro = true;
params.fit_acc = true;

if mod(numel(varargin), 2) ~= 0
    error('fit_temperature_bias_models:InvalidInput', ...
        'Optional arguments must be provided as name/value pairs.');
end

for k = 1:2:numel(varargin)
    name = lower(char(varargin{k}));
    value = varargin{k + 1};
    switch name
        case 'static_gyro'
            params.static_gyro = value;
        case 'static_acc'
            params.static_acc = value;
        case 'temp'
            params.temp = value;
        case 'static_data'
            params.static_data = value;
        case 'ca'
            params.Ca = value;
        case 'ba0'
            params.ba0 = value;
        case 'gravity_magnitude'
            params.gravity_magnitude = double(value);
        case 'method'
            params.method = char(string(value));
        case 'reference_temperature_mode'
            params.reference_temperature_mode = value;
        case 'extrapolation_mode'
            params.extrapolation_mode = char(string(value));
        case 'min_temp_span'
            params.min_temp_span = double(value);
        case 'min_samples'
            params.min_samples = double(value);
        case 'bin_width_degc'
            params.bin_width_degC = double(value);
        case 'min_bin_samples'
            params.min_bin_samples = double(value);
        case 'min_valid_bins'
            params.min_valid_bins = double(value);
        case 'acc_min_bin_pose_count'
            params.acc_min_bin_pose_count = double(value);
        case 'acc_min_pose_rank'
            params.acc_min_pose_rank = double(value);
        case 'options'
            params.options = value;
        case 'fit_gyro'
            params.fit_gyro = logical(value);
        case 'fit_acc'
            params.fit_acc = logical(value);
        otherwise
            error('fit_temperature_bias_models:UnknownOption', ...
                'Unknown option "%s".', char(varargin{k}));
    end
end
end

function model = fit_gyro_temperature_bias_model(varargin)
params = parse_single_inputs(varargin{:});
tempOpts = get_temperature_options(params.options);

method = choose_value(params.method, tempOpts.method);
extrapolationMode = choose_value(params.extrapolation_mode, tempOpts.extrapolation_mode);
minTempSpan = choose_value(params.min_temp_span, tempOpts.min_temp_span);
minSamples = choose_value(params.min_samples, tempOpts.min_samples);
binWidthDegC = choose_value(params.bin_width_degC, tempOpts.bin_width_degC);
minBinSamples = choose_value(params.min_bin_samples, tempOpts.min_bin_samples);
minValidBins = choose_value(params.min_valid_bins, tempOpts.min_valid_bins);

if isempty(params.static_gyro)
    model = make_invalid_model('bg', 'static.gyro is required for gyro temperature fitting.');
    return;
end
gyro = ensure_matrix_n3(params.static_gyro, 'static_gyro');
if isempty(params.temp)
    model = make_invalid_model('bg', 'Temperature data not provided.');
    return;
end
temp = ensure_column(params.temp, 'temp');
if numel(temp) ~= size(gyro, 1)
    error('fit_gyro_temperature_bias_model:LengthMismatch', ...
        'temp length must match static_gyro length.');
end

referenceTemperature = params.reference_temperature;
if isempty(referenceTemperature)
    referenceTemperature = resolve_reference_temperature(temp, tempOpts.reference_temperature_mode);
end

if size(gyro, 1) < minSamples
    model = make_invalid_model('bg', sprintf( ...
        'Not enough samples for temperature fit. Need at least %d.', minSamples));
    model.metrics.num_points = size(gyro, 1);
    model.metrics.temp_span = max(temp) - min(temp);
    return;
end

discrete = estimate_gyro_bias_samples(gyro, temp, binWidthDegC, minBinSamples);
model = fit_bias_model_from_samples(discrete.temperatures, discrete.bias, ...
    'target', 'bg', ...
    'method', method, ...
    'reference_temperature', referenceTemperature, ...
    'extrapolation_mode', extrapolationMode, ...
    'min_temp_span', minTempSpan, ...
    'min_valid_bins', minValidBins, ...
    'discrete_meta', discrete.meta);
end

function model = fit_accel_temperature_bias_model(varargin)
params = parse_single_inputs(varargin{:});
tempOpts = get_temperature_options(params.options);
accOpts = get_acc_options(params.options);

method = choose_value(params.method, tempOpts.method);
extrapolationMode = choose_value(params.extrapolation_mode, tempOpts.extrapolation_mode);
minTempSpan = choose_value(params.min_temp_span, tempOpts.min_temp_span);
minSamples = choose_value(params.min_samples, tempOpts.min_samples);
binWidthDegC = choose_value(params.bin_width_degC, tempOpts.bin_width_degC);
minBinSamples = choose_value(params.min_bin_samples, tempOpts.min_bin_samples);
minValidBins = choose_value(params.min_valid_bins, tempOpts.min_valid_bins);
minBinPoseCount = choose_value(params.min_bin_pose_count, tempOpts.acc_min_bin_pose_count);
minPoseRank = choose_value(params.min_pose_rank, tempOpts.acc_min_pose_rank);
gravityMagnitude = choose_value(params.gravity_magnitude, accOpts.gravity_magnitude);

if isempty(params.Ca)
    model = make_invalid_model('ba', 'Fixed Ca is required for accel temperature fitting.');
    return;
end
Ca = double(params.Ca);
if ~isequal(size(Ca), [3, 3])
    error('fit_accel_temperature_bias_model:InvalidCa', ...
        'Ca must have shape [3 x 3].');
end

if isempty(params.static_data)
    if isempty(params.static_acc) || isempty(params.temp)
        model = make_invalid_model('ba', ...
            'static.acc, static.temp, and fixed Ca are required for accel temperature fitting.');
        return;
    end
    staticAcc = ensure_matrix_n3(params.static_acc, 'static_acc');
    temp = ensure_column(params.temp, 'temp');
    if size(staticAcc, 1) ~= numel(temp)
        error('fit_accel_temperature_bias_model:LengthMismatch', ...
            'temp length must match static_acc length.');
    end
    staticData = struct();
    staticData.t = (0:size(staticAcc, 1) - 1).';
    staticData.gyro = zeros(size(staticAcc));
    staticData.acc = staticAcc;
    staticData.temp = temp;
else
    staticData = params.static_data;
    if ~isstruct(staticData) || ~isfield(staticData, 'temp') || isempty(staticData.temp)
        model = make_invalid_model('ba', 'Temperature data not provided.');
        return;
    end
end

if size(staticData.acc, 1) < minSamples
    model = make_invalid_model('ba', sprintf( ...
        'Not enough samples for temperature fit. Need at least %d.', minSamples));
    model.metrics.num_points = size(staticData.acc, 1);
    model.metrics.temp_span = max(staticData.temp) - min(staticData.temp);
    return;
end

referenceTemperature = params.reference_temperature;
if isempty(referenceTemperature)
    referenceTemperature = resolve_reference_temperature(staticData.temp, tempOpts.reference_temperature_mode);
end

if isempty(params.ba0)
    ba0 = zeros(3, 1);
else
    ba0 = ensure_vector3(params.ba0, 'ba0');
end

[~, extractionInfo] = extract_static_pose_means(staticData, 'options', params.options);
discrete = estimate_accel_bias_samples(extractionInfo.segment_rows, ...
    'Ca', Ca, ...
    'gravity_magnitude', gravityMagnitude, ...
    'ba0', ba0, ...
    'bin_width_degC', binWidthDegC, ...
    'min_bin_samples', minBinSamples, ...
    'min_bin_pose_count', minBinPoseCount, ...
    'min_pose_rank', minPoseRank, ...
    'solver_options', tempOpts);

model = fit_bias_model_from_samples(discrete.temperatures, discrete.bias, ...
    'target', 'ba', ...
    'method', method, ...
    'reference_temperature', referenceTemperature, ...
    'extrapolation_mode', extrapolationMode, ...
    'min_temp_span', minTempSpan, ...
    'min_valid_bins', minValidBins, ...
    'discrete_meta', discrete.meta);
model.static_segment_extraction = extractionInfo;
model.metrics.num_static_segments = extractionInfo.num_segments;
model.reference_ba = ba0;
end

function params = parse_single_inputs(varargin)
defaults = default_calib_options();
params = struct();
params.static_gyro = [];
params.static_acc = [];
params.temp = [];
params.static_data = [];
params.Ca = [];
params.ba0 = [];
params.gravity_magnitude = [];
params.method = [];
params.reference_temperature = [];
params.extrapolation_mode = [];
params.min_temp_span = [];
params.min_samples = [];
params.bin_width_degC = [];
params.min_bin_samples = [];
params.min_valid_bins = [];
params.min_bin_pose_count = [];
params.min_pose_rank = [];
params.options = defaults;

if mod(numel(varargin), 2) ~= 0
    error('fit_temperature_bias_models:InvalidInput', ...
        'Optional arguments must be provided as name/value pairs.');
end

for k = 1:2:numel(varargin)
    name = lower(char(varargin{k}));
    value = varargin{k + 1};
    switch name
        case 'static_gyro'
            params.static_gyro = value;
        case 'static_acc'
            params.static_acc = value;
        case 'temp'
            params.temp = value;
        case 'static_data'
            params.static_data = value;
        case 'ca'
            params.Ca = value;
        case 'ba0'
            params.ba0 = value;
        case 'gravity_magnitude'
            params.gravity_magnitude = double(value);
        case 'method'
            params.method = char(string(value));
        case 'reference_temperature'
            params.reference_temperature = double(value);
        case 'extrapolation_mode'
            params.extrapolation_mode = char(string(value));
        case 'min_temp_span'
            params.min_temp_span = double(value);
        case 'min_samples'
            params.min_samples = double(value);
        case 'bin_width_degc'
            params.bin_width_degC = double(value);
        case 'min_bin_samples'
            params.min_bin_samples = double(value);
        case 'min_valid_bins'
            params.min_valid_bins = double(value);
        case 'min_bin_pose_count'
            params.min_bin_pose_count = double(value);
        case 'min_pose_rank'
            params.min_pose_rank = double(value);
        case 'options'
            params.options = value;
        otherwise
            error('fit_temperature_bias_models:UnknownOption', ...
                'Unknown option "%s".', char(varargin{k}));
    end
end
end

function discrete = estimate_gyro_bias_samples(gyro, temp, binWidthDegC, minBinSamples)
bins = make_temperature_bins(temp, binWidthDegC);
rows = repmat(make_bin_row_template(), 0, 1);
skipped = repmat(make_bin_row_template(), 0, 1);
for i = 1:numel(bins)
    mask = bins(i).mask;
    count = nnz(mask);
    if count < minBinSamples
        skipped = append_bin(skipped, bins(i), count, 'too_few_samples', NaN, NaN, NaN); %#ok<AGROW>
        continue;
    end
    row = make_bin_row_template();
    row.temperature = mean(temp(mask));
    row.bias = mean(gyro(mask, :), 1).';
    row.num_samples = count;
    row.temperature_range = [min(temp(mask)); max(temp(mask))];
    rows = [rows; row]; %#ok<AGROW>
end

if isempty(rows)
    temperatures = zeros(0, 1);
    bias = zeros(0, 3);
else
    temperatures = reshape([rows.temperature], [], 1);
    bias = reshape([rows.bias], 3, []).';
end

meta = struct();
meta.bins = rows;
meta.skipped_bins = skipped;
discrete = struct('temperatures', temperatures, 'bias', bias, 'meta', meta);
end

function discrete = estimate_accel_bias_samples(segmentRows, varargin)
params = parse_acc_bin_inputs(varargin{:});
if isempty(segmentRows)
    meta = struct('bins', repmat(make_bin_row_template(), 0, 1), 'skipped_bins', repmat(make_bin_row_template(), 0, 1));
    discrete = struct('temperatures', zeros(0, 1), 'bias', zeros(0, 3), 'meta', meta);
    return;
end

rowTemps = nan(numel(segmentRows), 1);
for i = 1:numel(segmentRows)
    if isfield(segmentRows(i), 'temp_mean') && ~isempty(segmentRows(i).temp_mean)
        rowTemps(i) = double(segmentRows(i).temp_mean);
    end
end
temps = rowTemps(isfinite(rowTemps));
if isempty(temps)
    meta = struct('bins', repmat(make_bin_row_template(), 0, 1), 'skipped_bins', repmat(make_bin_row_template(), 0, 1));
    discrete = struct('temperatures', zeros(0, 1), 'bias', zeros(0, 3), 'meta', meta);
    return;
end

bins = make_temperature_bins(temps, params.bin_width_degC);
rows = repmat(make_bin_row_template(), 0, 1);
skipped = repmat(make_bin_row_template(), 0, 1);
for i = 1:numel(bins)
    if bins(i).is_last
        maskRows = isfinite(rowTemps) & rowTemps >= bins(i).lower & rowTemps <= bins(i).upper;
    else
        maskRows = isfinite(rowTemps) & rowTemps >= bins(i).lower & rowTemps < bins(i).upper;
    end
    selected = segmentRows(maskRows);
    count = numel(selected);
    if count < max(params.min_bin_samples, params.min_bin_pose_count)
        skipped = append_bin(skipped, bins(i), count, 'too_few_pose_samples', NaN, NaN, NaN); %#ok<AGROW>
        continue;
    end

    rawMeans = zeros(count, 3);
    tempMeans = zeros(count, 1);
    for j = 1:count
        rawMeans(j, :) = ensure_vector3(selected(j).acc_mean, sprintf('segmentRows(%d).acc_mean', j)).';
        tempMeans(j) = selected(j).temp_mean;
    end

    centered = rawMeans - mean(rawMeans, 1);
    poseRank = rank(centered);
    if poseRank < params.min_pose_rank
        skipped = append_bin(skipped, bins(i), count, 'insufficient_pose_diversity', poseRank, NaN, NaN); %#ok<AGROW>
        continue;
    end

    [bHat, metrics] = estimate_accel_bias_for_bin(rawMeans, params.Ca, params.gravity_magnitude, ...
        params.ba0, params.solver_options);
    if ~metrics.success
        skipped = append_bin(skipped, bins(i), count, metrics.message, poseRank, metrics.rmse, metrics.max_abs_residual); %#ok<AGROW>
        continue;
    end

    row = make_bin_row_template();
    row.temperature = mean(tempMeans);
    row.bias = bHat;
    row.num_samples = count;
    row.pose_rank = poseRank;
    row.rmse = metrics.rmse;
    row.max_abs_residual = metrics.max_abs_residual;
    row.temperature_range = [min(tempMeans); max(tempMeans)];
    rows = [rows; row]; %#ok<AGROW>
end

if isempty(rows)
    temperatures = zeros(0, 1);
    bias = zeros(0, 3);
else
    temperatures = reshape([rows.temperature], [], 1);
    bias = reshape([rows.bias], 3, []).';
end

meta = struct();
meta.bins = rows;
meta.skipped_bins = skipped;
discrete = struct('temperatures', temperatures, 'bias', bias, 'meta', meta);
end

function params = parse_acc_bin_inputs(varargin)
params = struct();
params.Ca = [];
params.gravity_magnitude = 9.80665;
params.ba0 = zeros(3, 1);
params.bin_width_degC = 2.0;
params.min_bin_samples = 50;
params.min_bin_pose_count = 6;
params.min_pose_rank = 2;
params.solver_options = get_temperature_options(default_calib_options());

if mod(numel(varargin), 2) ~= 0
    error('fit_temperature_bias_models:InvalidInput', ...
        'Optional arguments must be provided as name/value pairs.');
end

for k = 1:2:numel(varargin)
    name = lower(char(varargin{k}));
    value = varargin{k + 1};
    switch name
        case 'ca'
            params.Ca = value;
        case 'gravity_magnitude'
            params.gravity_magnitude = double(value);
        case 'ba0'
            params.ba0 = ensure_vector3(value, 'ba0');
        case 'bin_width_degc'
            params.bin_width_degC = double(value);
        case 'min_bin_samples'
            params.min_bin_samples = double(value);
        case 'min_bin_pose_count'
            params.min_bin_pose_count = double(value);
        case 'min_pose_rank'
            params.min_pose_rank = double(value);
        case 'solver_options'
            params.solver_options = value;
        otherwise
            error('fit_temperature_bias_models:UnknownOption', ...
                'Unknown option "%s".', char(varargin{k}));
    end
end
end

function [bHat, metrics] = estimate_accel_bias_for_bin(rawMeans, Ca, gravityMagnitude, b0, solverOptions)
residualFun = @(b) vecnorm((Ca * (rawMeans - b(:).').').', 2, 2) - gravityMagnitude;

if exist('lsqnonlin', 'file') == 2
    lsqOpts = optimoptions('lsqnonlin', ...
        'Display', 'off', ...
        'FunctionTolerance', double(solverOptions.acc_bias_ftol), ...
        'StepTolerance', double(solverOptions.acc_bias_xtol), ...
        'OptimalityTolerance', double(solverOptions.acc_bias_gtol), ...
        'MaxFunctionEvaluations', double(solverOptions.acc_bias_max_nfev));
    [x, residual, ~, exitflag, output] = lsqnonlin(residualFun, b0(:), [], [], lsqOpts); %#ok<ASGLU>
    bHat = x(:);
    metrics = struct();
    metrics.success = exitflag > 0;
    metrics.rmse = sqrt(mean(residual .^ 2));
    metrics.max_abs_residual = max(abs(residual));
    metrics.message = char(string(output.message));
    metrics.nfev = get_field_or_default(output, 'funcCount', NaN);
    return;
end

objective = @(b) sum(residualFun(b) .^ 2);
fmOpts = optimset('Display', 'off', ...
    'TolX', double(solverOptions.acc_bias_xtol), ...
    'TolFun', double(solverOptions.acc_bias_ftol), ...
    'MaxIter', double(solverOptions.acc_bias_max_nfev), ...
    'MaxFunEvals', double(solverOptions.acc_bias_max_nfev));
[x, ~, exitflag, output] = fminsearch(objective, b0(:), fmOpts); %#ok<ASGLU>
residual = residualFun(x);
bHat = x(:);
metrics = struct();
metrics.success = exitflag > 0;
metrics.rmse = sqrt(mean(residual .^ 2));
metrics.max_abs_residual = max(abs(residual));
metrics.message = char(string(output.message));
metrics.nfev = get_field_or_default(output, 'funcCount', NaN);
end

function model = fit_bias_model_from_samples(temperatures, biasSamples, varargin)
params = parse_fit_model_inputs(varargin{:});
if isempty(temperatures)
    model = make_invalid_model(params.target, ...
        sprintf('No valid temperature bins were found for %s(T) fitting.', params.target));
    return;
end

temperatures = ensure_column(temperatures, 'temperatures');
biasSamples = ensure_matrix_n3(biasSamples, 'biasSamples');
if numel(temperatures) ~= size(biasSamples, 1)
    error('fit_temperature_bias_models:LengthMismatch', ...
        'temperatures and biasSamples row count must match.');
end

tempSpan = max(temperatures) - min(temperatures);
tempRange = [min(temperatures); max(temperatures)];
if numel(temperatures) < params.min_valid_bins
    model = make_invalid_model(params.target, sprintf( ...
        'Need at least %d valid temperature bins for stable fitting.', params.min_valid_bins));
    if tempSpan < params.min_temp_span
        model.low_confidence = true;
        model.message = sprintf( ...
            'Temperature span %.3f is too small for a reliable %s(T) fit.', tempSpan, params.target);
    end
    model.metrics.temp_span = tempSpan;
    model.metrics.num_points = size(biasSamples, 1);
    model.metrics.num_bins = numel(temperatures);
    model.temperature_range = tempRange;
    model.reference_temperature = params.reference_temperature;
    model.extrapolation_mode = params.extrapolation_mode;
    model.discrete_samples = struct('temperature', temperatures, 'bias', biasSamples);
    model.discrete_meta = params.discrete_meta;
    return;
end

lowConfidence = tempSpan < params.min_temp_span;
methodLower = lower(char(string(params.method)));
referenceTemperature = double(params.reference_temperature);
dT = temperatures - referenceTemperature;

switch methodLower
    case {'poly1', 'poly2', 'poly3'}
        polyOrder = sscanf(methodLower, 'poly%d');
        coeffs = zeros(polyOrder + 1, 3);
        fitted = zeros(size(biasSamples));
        for axisIdx = 1:3
            coeffs(:, axisIdx) = polyfit(dT, biasSamples(:, axisIdx), polyOrder).';
            fitted(:, axisIdx) = polyval(coeffs(:, axisIdx).', dT);
        end
        modelType = 'poly';
        coeff = struct('poly_coeff', coeffs);
        extra = struct('coeffs', coeffs, 'poly_order', polyOrder);

    case 'piecewise_linear'
        breakpoints = temperatures;
        values = biasSamples;
        fitted = values;
        modelType = 'piecewise_linear';
        coeff = struct('breakpoints', breakpoints, 'values', values);
        extra = struct('breakpoints', breakpoints, 'values', values, 'poly_order', 1);

    otherwise
        error('fit_temperature_bias_models:UnsupportedMethod', ...
            'Unsupported temperature model method "%s".', params.method);
end

residual = biasSamples - fitted;
rmse = sqrt(mean(residual(:) .^ 2));
maxAbsResidual = max(abs(residual(:)));
metrics = struct();
metrics.temp_span = tempSpan;
metrics.num_points = size(biasSamples, 1);
metrics.num_bins = numel(temperatures);
metrics.rmse = rmse;
metrics.max_abs_residual = maxAbsResidual;

message = sprintf('%s(T) model fitted successfully.', params.target);
if lowConfidence
    message = sprintf('%s(T) fit completed, but the temperature span is too small for high confidence.', params.target);
end

model = struct();
model.enabled = true;
model.valid = true;
model.low_confidence = logical(lowConfidence);
model.target = params.target;
model.type = modelType;
model.model_type = methodLower;
model.method = methodLower;
model.reference_temperature = referenceTemperature;
model.temperature_range = tempRange;
model.extrapolation_mode = params.extrapolation_mode;
model.coeff = coeff;
model.metrics = metrics;
model.message = message;
model.discrete_samples = struct('temperature', temperatures, 'bias', biasSamples);
model.discrete_meta = params.discrete_meta;
model.residual_rms = sqrt(mean(residual .^ 2, 1)).';
model.residual_std = std(residual, 0, 1).';
if strcmp(params.target, 'bg')
    model.reference_bg = mean(biasSamples, 1).';
    model.reference_ba = [];
else
    model.reference_bg = [];
    model.reference_ba = mean(biasSamples, 1).';
end
fields = fieldnames(extra);
for i = 1:numel(fields)
    model.(fields{i}) = extra.(fields{i});
end
end

function params = parse_fit_model_inputs(varargin)
params = struct();
params.target = 'bg';
params.method = 'poly2';
params.reference_temperature = NaN;
params.extrapolation_mode = 'warn_and_clamp';
params.min_temp_span = 2.0;
params.min_valid_bins = 3;
params.discrete_meta = struct('bins', [], 'skipped_bins', []);

if mod(numel(varargin), 2) ~= 0
    error('fit_temperature_bias_models:InvalidInput', ...
        'Optional arguments must be provided as name/value pairs.');
end

for k = 1:2:numel(varargin)
    name = lower(char(varargin{k}));
    value = varargin{k + 1};
    switch name
        case 'target'
            params.target = char(string(value));
        case 'method'
            params.method = char(string(value));
        case 'reference_temperature'
            params.reference_temperature = double(value);
        case 'extrapolation_mode'
            params.extrapolation_mode = char(string(value));
        case 'min_temp_span'
            params.min_temp_span = double(value);
        case 'min_valid_bins'
            params.min_valid_bins = double(value);
        case 'discrete_meta'
            params.discrete_meta = value;
        otherwise
            error('fit_temperature_bias_models:UnknownOption', ...
                'Unknown option "%s".', char(varargin{k}));
    end
end
end

function bins = make_temperature_bins(temp, binWidthDegC)
temp = ensure_column(temp, 'temp');
if isempty(temp)
    bins = repmat(struct('index', 0, 'lower', 0, 'upper', 0, 'mask', false(0, 1), 'is_last', false), 0, 1);
    return;
end
if ~isscalar(binWidthDegC) || ~isfinite(binWidthDegC) || binWidthDegC <= 0
    error('fit_temperature_bias_models:InvalidBinWidth', ...
        'bin_width_degC must be positive.');
end

lowerEdge = floor(min(temp) / binWidthDegC) * binWidthDegC;
upperEdge = ceil(max(temp) / binWidthDegC) * binWidthDegC;
edges = (lowerEdge:binWidthDegC:(upperEdge + binWidthDegC)).';
if numel(edges) < 2
    edges = [lowerEdge; lowerEdge + binWidthDegC];
end

numBins = numel(edges) - 1;
bins = repmat(struct('index', 0, 'lower', 0, 'upper', 0, 'mask', false(numel(temp), 1), 'is_last', false), numBins, 1);
for i = 1:numBins
    lo = edges(i);
    hi = edges(i + 1);
    isLast = i == numBins;
    if isLast
        mask = temp >= lo & temp <= hi;
    else
        mask = temp >= lo & temp < hi;
    end
    bins(i).index = i - 1;
    bins(i).lower = lo;
    bins(i).upper = hi;
    bins(i).mask = mask;
    bins(i).is_last = isLast;
end
end

function row = append_bin(rows, binInfo, count, reason, poseRank, rmse, maxAbsResidual)
row = rows;
entry = make_bin_row_template();
entry.index = binInfo.index;
entry.lower = binInfo.lower;
entry.upper = binInfo.upper;
entry.num_samples = count;
entry.reason = reason;
entry.pose_rank = poseRank;
entry.rmse = rmse;
entry.max_abs_residual = maxAbsResidual;
row = [row; entry];
end

function row = make_bin_row_template()
row = struct('index', NaN, ...
             'lower', NaN, ...
             'upper', NaN, ...
             'temperature', NaN, ...
             'bias', zeros(3, 1), ...
             'num_samples', 0, ...
             'temperature_range', [NaN; NaN], ...
             'pose_rank', NaN, ...
             'rmse', NaN, ...
             'max_abs_residual', NaN, ...
             'reason', '');
end

function model = make_invalid_model(target, message)
model = struct();
model.enabled = false;
model.valid = false;
model.low_confidence = false;
model.target = target;
model.type = '';
model.model_type = '';
model.method = '';
model.reference_temperature = NaN;
model.temperature_range = [NaN; NaN];
model.extrapolation_mode = 'warn_and_clamp';
model.coeff = struct();
model.metrics = struct('temp_span', NaN, 'num_points', 0, 'num_bins', 0, 'rmse', NaN, 'max_abs_residual', NaN);
model.message = message;
model.discrete_samples = struct('temperature', zeros(0, 1), 'bias', zeros(0, 3));
model.discrete_meta = struct('bins', [], 'skipped_bins', []);
model.residual_rms = [NaN; NaN; NaN];
model.residual_std = [NaN; NaN; NaN];
if strcmp(target, 'bg')
    model.reference_bg = [NaN; NaN; NaN];
    model.reference_ba = [];
else
    model.reference_bg = [];
    model.reference_ba = [NaN; NaN; NaN];
end
model.coeffs = zeros(0, 3);
model.poly_order = 0;
end

function tempOpts = get_temperature_options(options)
tempOpts = options.temperature;
end

function accOpts = get_acc_options(options)
accOpts = options.acc_calibration;
end

function referenceTemperature = resolve_reference_temperature(temp, modeOrValue)
if isempty(temp)
    referenceTemperature = NaN;
    return;
end
temp = ensure_column(temp, 'temp');
if isnumeric(modeOrValue) && isscalar(modeOrValue) && isfinite(modeOrValue)
    referenceTemperature = double(modeOrValue);
    return;
end

mode = 'mean';
if ~isempty(modeOrValue)
    mode = lower(char(string(modeOrValue)));
end
switch mode
    case 'mean'
        referenceTemperature = mean(temp);
    case 'median'
        referenceTemperature = median(temp);
    case 'min'
        referenceTemperature = min(temp);
    case 'max'
        referenceTemperature = max(temp);
    otherwise
        error('fit_temperature_bias_models:UnsupportedReferenceTemperatureMode', ...
            'Unsupported reference_temperature_mode "%s".', char(string(modeOrValue)));
end
end

function temperatureRange = resolve_temperature_range(temp)
if isempty(temp)
    temperatureRange = [NaN; NaN];
    return;
end
temp = ensure_column(temp, 'temp');
temperatureRange = [min(temp); max(temp)];
end

function value = choose_value(value, defaultValue)
if isempty(value)
    value = defaultValue;
end
end

function value = get_field_or_default(S, fieldName, defaultValue)
if isstruct(S) && isfield(S, fieldName)
    value = S.(fieldName);
else
    value = defaultValue;
end
end

function x = ensure_column(x, name)
x = double(x(:));
if any(~isfinite(x))
    error('fit_temperature_bias_models:InvalidVector', ...
        '%s must contain finite numeric values.', name);
end
end

function X = ensure_matrix_n3(X, name)
X = double(X);
if ~ismatrix(X) || size(X, 2) ~= 3 || any(~isfinite(X(:)))
    error('fit_temperature_bias_models:InvalidMatrix', ...
        '%s must be a finite [N x 3] matrix.', name);
end
end

function v = ensure_vector3(v, name)
v = double(v(:));
if numel(v) ~= 3 || any(~isfinite(v))
    error('fit_temperature_bias_models:InvalidVector', ...
        '%s must be a finite 3x1 vector.', name);
end
end
