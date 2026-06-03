function task = run_temperature_fit(inputData, varargin)
%RUN_TEMPERATURE_FIT Run temperature fitting for gyro-only, accel-only, or both.

opts = parse_inputs(varargin{:});
tempOpts = opts.options.temperature;
target = lower(char(string(choose_value(opts.target, tempOpts.target))));
staticData = normalize_static_input(inputData);

fitGyro = ismember(target, {'bg', 'gyro', 'both'});
fitAcc = ismember(target, {'ba', 'acc', 'accel', 'acceleration', 'both'});

missing = {};
if isempty(staticData) || ~isfield(staticData, 'temp') || isempty(staticData.temp)
    missing{end + 1} = 'static.temp'; %#ok<AGROW>
end
if fitGyro && (isempty(staticData) || ~isfield(staticData, 'gyro') || isempty(staticData.gyro))
    missing{end + 1} = 'static.gyro'; %#ok<AGROW>
end
if fitAcc
    if isempty(staticData) || ~isfield(staticData, 'acc') || isempty(staticData.acc)
        missing{end + 1} = 'static.acc'; %#ok<AGROW>
    end
    if isempty(opts.Ca)
        missing{end + 1} = 'Ca'; %#ok<AGROW>
    end
end

if ~isempty(missing)
    task = make_task_result(false, ...
        'Temperature fitting inputs are incomplete for the requested target.', [], ...
        'missing_inputs', unique(missing, 'stable'), ...
        'meta', struct('task_name', 'run_temperature_fit', 'target', target));
    return;
end

commonArgs = { ...
    'method', choose_value(opts.method, tempOpts.method), ...
    'reference_temperature_mode', choose_value(opts.reference_temperature_mode, tempOpts.reference_temperature_mode), ...
    'extrapolation_mode', choose_value(opts.extrapolation_mode, tempOpts.extrapolation_mode), ...
    'min_temp_span', choose_value(opts.min_temp_span, tempOpts.min_temp_span), ...
    'min_samples', choose_value(opts.min_samples, tempOpts.min_samples), ...
    'bin_width_degC', choose_value(opts.bin_width_degC, tempOpts.bin_width_degC), ...
    'min_bin_samples', choose_value(opts.min_bin_samples, tempOpts.min_bin_samples), ...
    'min_valid_bins', choose_value(opts.min_valid_bins, tempOpts.min_valid_bins)};

if fitGyro && fitAcc
    combined = fit_temperature_bias_models( ...
        'static_gyro', staticData.gyro, ...
        'static_acc', staticData.acc, ...
        'temp', staticData.temp, ...
        'static_data', staticData, ...
        'Ca', opts.Ca, ...
        'ba0', opts.ba, ...
        'gravity_magnitude', choose_value(opts.gravity_magnitude, opts.options.acc_calibration.gravity_magnitude), ...
        'acc_min_bin_pose_count', choose_value(opts.acc_min_bin_pose_count, tempOpts.acc_min_bin_pose_count), ...
        'acc_min_pose_rank', choose_value(opts.acc_min_pose_rank, tempOpts.acc_min_pose_rank), ...
        'options', opts.options, ...
        'fit_gyro', true, ...
        'fit_acc', true, ...
        commonArgs{:});
    bgModel = combined.gyro;
    baModel = combined.acc;
    modelFile = combined;

elseif fitGyro
    bgModel = fit_gyro_temperature_bias_model( ...
        'static_gyro', staticData.gyro, ...
        'temp', staticData.temp, ...
        'options', opts.options, ...
        commonArgs{:});
    baModel = struct();
    modelFile = struct();
    modelFile.reference_temperature = getfield_or_default(bgModel, 'reference_temperature', NaN);
    modelFile.temperature_range = getfield_or_default(bgModel, 'temperature_range', [NaN; NaN]);
    modelFile.extrapolation_mode = getfield_or_default(bgModel, 'extrapolation_mode', commonArgs{6});
    modelFile.gyro = bgModel;
    modelFile.acc = struct();
    modelFile.message = getfield_or_default(bgModel, 'message', '');

else
    baModel = fit_accel_temperature_bias_model( ...
        'static_acc', staticData.acc, ...
        'temp', staticData.temp, ...
        'static_data', staticData, ...
        'Ca', opts.Ca, ...
        'ba0', opts.ba, ...
        'gravity_magnitude', choose_value(opts.gravity_magnitude, opts.options.acc_calibration.gravity_magnitude), ...
        'min_bin_pose_count', choose_value(opts.acc_min_bin_pose_count, tempOpts.acc_min_bin_pose_count), ...
        'min_pose_rank', choose_value(opts.acc_min_pose_rank, tempOpts.acc_min_pose_rank), ...
        'options', opts.options, ...
        commonArgs{:});
    bgModel = struct();
    modelFile = struct();
    modelFile.reference_temperature = getfield_or_default(baModel, 'reference_temperature', NaN);
    modelFile.temperature_range = getfield_or_default(baModel, 'temperature_range', [NaN; NaN]);
    modelFile.extrapolation_mode = getfield_or_default(baModel, 'extrapolation_mode', commonArgs{6});
    modelFile.gyro = struct();
    modelFile.acc = baModel;
    modelFile.message = getfield_or_default(baModel, 'message', '');
end

warnings = {};
if isstruct(bgModel) && isfield(bgModel, 'low_confidence') && bgModel.low_confidence
    warnings{end + 1} = bgModel.message; %#ok<AGROW>
end
if isstruct(baModel) && isfield(baModel, 'low_confidence') && baModel.low_confidence
    warnings{end + 1} = baModel.message; %#ok<AGROW>
end

metrics = struct();
metrics.target = target;
metrics.reference_temperature = getfield_or_default(modelFile, 'reference_temperature', NaN);
metrics.temperature_range = getfield_or_default(modelFile, 'temperature_range', [NaN; NaN]);
metrics.gyro_valid = isstruct(bgModel) && isfield(bgModel, 'valid') && bgModel.valid;
metrics.acc_valid = isstruct(baModel) && isfield(baModel, 'valid') && baModel.valid;

result = struct();
result.bgModel = bgModel;
result.baModel = baModel;
result.temperatureModel = modelFile;
result.metrics = metrics;

task = make_task_result(true, build_message(bgModel, baModel, target), result, ...
    'warnings', warnings, ...
    'meta', struct('task_name', 'run_temperature_fit', 'target', target));
end

function opts = parse_inputs(varargin)
opts = struct();
opts.options = default_calib_options();
opts.target = [];
opts.Ca = [];
opts.ba = [];
opts.method = [];
opts.reference_temperature_mode = [];
opts.extrapolation_mode = [];
opts.min_temp_span = [];
opts.min_samples = [];
opts.bin_width_degC = [];
opts.min_bin_samples = [];
opts.min_valid_bins = [];
opts.acc_min_bin_pose_count = [];
opts.acc_min_pose_rank = [];
opts.gravity_magnitude = [];

if mod(numel(varargin), 2) ~= 0
    error('run_temperature_fit:InvalidInput', ...
        'Optional arguments must be provided as name/value pairs.');
end
for k = 1:2:numel(varargin)
    name = lower(char(varargin{k}));
    value = varargin{k + 1};
    switch name
        case 'target'
            opts.target = value;
        case 'ca'
            opts.Ca = value;
        case 'ba'
            opts.ba = value;
        case 'method'
            opts.method = value;
        case 'reference_temperature_mode'
            opts.reference_temperature_mode = value;
        case 'extrapolation_mode'
            opts.extrapolation_mode = value;
        case 'min_temp_span'
            opts.min_temp_span = value;
        case 'min_samples'
            opts.min_samples = value;
        case 'bin_width_degc'
            opts.bin_width_degC = value;
        case 'min_bin_samples'
            opts.min_bin_samples = value;
        case 'min_valid_bins'
            opts.min_valid_bins = value;
        case 'acc_min_bin_pose_count'
            opts.acc_min_bin_pose_count = value;
        case 'acc_min_pose_rank'
            opts.acc_min_pose_rank = value;
        case 'gravity_magnitude'
            opts.gravity_magnitude = value;
        case 'options'
            opts.options = value;
        otherwise
            error('run_temperature_fit:UnknownOption', ...
                'Unknown option "%s".', char(varargin{k}));
    end
end
end

function staticData = normalize_static_input(inputData)
staticData = [];
if isstruct(inputData) && isfield(inputData, 'static') && isstruct(inputData.static)
    staticData = inputData.static;
elseif isstruct(inputData)
    staticData = inputData;
end
end

function message = build_message(bgModel, baModel, target)
parts = {};
if ismember(target, {'bg', 'gyro', 'both'}) && isstruct(bgModel)
    parts{end + 1} = sprintf('gyro=%s', model_status(bgModel)); %#ok<AGROW>
end
if ismember(target, {'ba', 'acc', 'accel', 'acceleration', 'both'}) && isstruct(baModel)
    parts{end + 1} = sprintf('acc=%s', model_status(baModel)); %#ok<AGROW>
end
message = sprintf('temperature bias fit completed (%s).', strjoin(parts, ', '));
end

function status = model_status(model)
if isempty(model)
    status = 'not_run';
elseif isfield(model, 'valid') && model.valid
    status = 'valid';
elseif isfield(model, 'low_confidence') && model.low_confidence
    status = 'low_confidence';
else
    status = 'invalid';
end
end

function value = choose_value(value, defaultValue)
if isempty(value)
    value = defaultValue;
end
end

function value = getfield_or_default(S, fieldName, defaultValue)
if isstruct(S) && isfield(S, fieldName)
    value = S.(fieldName);
else
    value = defaultValue;
end
end
