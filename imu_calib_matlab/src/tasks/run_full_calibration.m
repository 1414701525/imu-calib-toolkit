function task = run_full_calibration(inputData, varargin)
%RUN_FULL_CALIBRATION Run as many calibration/analysis modules as possible.

opts = parse_options(varargin{:});
if ischar(inputData) || isstring(inputData)
    data = load_csv_data(char(string(inputData)));
    inputMode = 'csv_or_manifest';
else
    data = inputData;
    inputMode = 'struct_input';
end

warnings = {};
tasks = struct();

tasks.gyro_bias = run_gyro_bias(data);
if ~tasks.gyro_bias.success
    warnings{end + 1} = tasks.gyro_bias.message; %#ok<AGROW>
end

tasks.noise_stats = run_noise_stats(data);
if ~tasks.noise_stats.success
    warnings{end + 1} = tasks.noise_stats.message; %#ok<AGROW>
end

tasks.acc = run_acc_calibration(data, 'options', opts.options);
if ~tasks.acc.success
    warnings{end + 1} = tasks.acc.message; %#ok<AGROW>
end

bgForGyro = get_nested_or_default(tasks, {'gyro_bias', 'result', 'bg'}, []);
tasks.gyro = run_gyro_calibration(data, 'bg', bgForGyro);
if ~tasks.gyro.success
    warnings{end + 1} = tasks.gyro.message; %#ok<AGROW>
end

if tasks.gyro.success
    tasks.gsens = run_gsens_fit(data, ...
        'bg', get_nested_or_default(tasks, {'gyro', 'result', 'bg_used'}, bgForGyro), ...
        'Cg', get_nested_or_default(tasks, {'gyro', 'result', 'Cg'}, []));
else
    tasks.gsens = make_task_result(false, ...
        'Gg fit skipped because gyro Cg calibration is unavailable.', [], ...
        'missing_inputs', {'Cg'}, ...
        'meta', struct('task_name', 'run_gsens_fit'));
end
if ~tasks.gsens.success
    warnings{end + 1} = tasks.gsens.message; %#ok<AGROW>
end

tasks.allan = run_allan_analysis(data, ...
    'min_samples', opts.options.allan.min_samples, ...
    'num_tau', opts.options.allan.num_tau, ...
    'tau_mode', opts.options.allan.tau_mode, ...
    'validity_message_if_short', opts.options.allan.validity_message_if_short);
if ~tasks.allan.success
    warnings{end + 1} = tasks.allan.message; %#ok<AGROW>
end

tasks.temperature = run_temperature_fit(data, ...
    'target', opts.options.temperature.target, ...
    'Ca', get_nested_or_default(tasks, {'acc', 'result', 'Ca'}, []), ...
    'ba', get_nested_or_default(tasks, {'acc', 'result', 'ba'}, []), ...
    'method', opts.options.temperature.method, ...
    'reference_temperature_mode', opts.options.temperature.reference_temperature_mode, ...
    'extrapolation_mode', opts.options.temperature.extrapolation_mode, ...
    'min_temp_span', opts.options.temperature.min_temp_span, ...
    'min_samples', opts.options.temperature.min_samples, ...
    'bin_width_degC', opts.options.temperature.bin_width_degC, ...
    'min_bin_samples', opts.options.temperature.min_bin_samples, ...
    'min_valid_bins', opts.options.temperature.min_valid_bins, ...
    'acc_min_bin_pose_count', opts.options.temperature.acc_min_bin_pose_count, ...
    'acc_min_pose_rank', opts.options.temperature.acc_min_pose_rank, ...
    'gravity_magnitude', opts.options.acc_calibration.gravity_magnitude, ...
    'options', opts.options);
if ~tasks.temperature.success
    warnings{end + 1} = tasks.temperature.message; %#ok<AGROW>
end

components = struct();
components.bg = get_nested_or_default(tasks, {'gyro_bias', 'result', 'bg'}, []);
components.biasInfo = get_nested_or_default(tasks, {'gyro_bias', 'result', 'stats'}, struct());
components.noiseStats = get_nested_or_default(tasks, {'noise_stats', 'result', 'noiseStats'}, struct());
components.Ca = get_nested_or_default(tasks, {'acc', 'result', 'Ca'}, []);
components.ba = get_nested_or_default(tasks, {'acc', 'result', 'ba'}, []);
components.Sa = get_nested_or_default(tasks, {'acc', 'result', 'Sa'}, []);
components.Ma = get_nested_or_default(tasks, {'acc', 'result', 'Ma'}, []);
components.gravity_magnitude = get_nested_or_default(tasks, {'acc', 'result', 'gravity_magnitude'}, []);
components.accInfo = get_nested_or_default(tasks, {'acc', 'result', 'fitInfo'}, struct());
components.Cg = get_nested_or_default(tasks, {'gyro', 'result', 'Cg'}, []);
components.Kg = get_nested_or_default(tasks, {'gyro', 'result', 'Kg'}, []);
components.Mg = get_nested_or_default(tasks, {'gyro', 'result', 'Mg'}, []);
components.Gg = get_nested_or_default(tasks, {'gsens', 'result', 'Gg'}, []);
components.gyroInfo = get_nested_or_default(tasks, {'gyro', 'result', 'fitInfo'}, struct());
components.gsensInfo = get_nested_or_default(tasks, {'gsens', 'result', 'fitInfo'}, struct());
components.tempBgModel = get_nested_or_default(tasks, {'temperature', 'result', 'bgModel'}, struct());
components.tempBaModel = get_nested_or_default(tasks, {'temperature', 'result', 'baModel'}, struct());
components.temperatureModel = get_nested_or_default(tasks, {'temperature', 'result', 'temperatureModel'}, struct());
components.tempMessage = get_nested_or_default(tasks, {'temperature', 'message'}, 'Temperature fit not run.');
components.analysis = struct();
components.analysis.allan = struct();
components.analysis.allan.gyro = get_nested_or_default(tasks, {'allan', 'result', 'gyro_allan'}, []);
components.analysis.allan.acc = get_nested_or_default(tasks, {'allan', 'result', 'acc_allan'}, []);
components.meta = getfield_or_default(data, 'meta', struct());

results = build_calib_results(data, components, 'options', opts.options);

hasStatic = isfield(data, 'meta') && isfield(data.meta, 'has_static') && data.meta.has_static;
hasAccPoses = isfield(data, 'meta') && isfield(data.meta, 'has_acc_poses') && data.meta.has_acc_poses;
hasGyroRuns = isfield(data, 'meta') && isfield(data.meta, 'has_gyro_runs') && data.meta.has_gyro_runs;

if hasStatic && hasAccPoses && hasGyroRuns && ...
        ~isempty(components.bg) && ~isempty(components.Ca) && ~isempty(components.ba) && ~isempty(components.Cg)
    results.validation = validate_calibration(data, results.compat.flatCalib, ...
        'options', opts.options, 'analysis', results.analysis);
    message = 'Full calibration completed successfully.';
    success = true;
else
    results.validation = build_partial_validation(data, components, results.analysis, results.calib.temp);
    completedModules = getfield_or_default(results.validation.summary, 'completed_modules', {});
    success = ~isempty(completedModules);
    if success
        message = 'Partial calibration completed successfully.';
    else
        message = 'No calibration or analysis module could run with the provided inputs.';
    end
end

result = struct();
result.results = results;
result.tasks = tasks;
task = make_task_result(success, message, result, ...
    'warnings', warnings, ...
    'meta', struct('task_name', 'run_full_calibration', 'input_mode', inputMode));
end

function opts = parse_options(varargin)
opts = struct();
opts.options = default_calib_options();
if mod(numel(varargin), 2) ~= 0
    error('run_full_calibration:InvalidInput', ...
        'Optional arguments must be provided as name/value pairs.');
end
for k = 1:2:numel(varargin)
    name = lower(char(varargin{k}));
    value = varargin{k + 1};
    switch name
        case 'options'
            opts.options = value;
        otherwise
            error('run_full_calibration:UnknownOption', ...
                'Unknown option "%s".', char(varargin{k}));
    end
end
end
