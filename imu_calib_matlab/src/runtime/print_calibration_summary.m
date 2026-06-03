function print_calibration_summary(results)
%PRINT_CALIBRATION_SUMMARY Print a concise summary of calibration results.

if nargin < 1 || ~isstruct(results)
    error('print_calibration_summary:InvalidInput', ...
        'results must be a struct.');
end

fprintf('\nCalibration Summary\n');
fprintf('-------------------\n');
summaryPayload = build_result_summary(results);

if isfield(results, 'model')
    fprintf('Forward gyro model : %s\n', results.model.forward.gyr);
    fprintf('Inverse gyro model : %s\n', results.model.inverse.gyr);
    fprintf('Forward acc model  : %s\n', results.model.forward.acc);
    fprintf('Inverse acc model  : %s\n', results.model.inverse.acc);
    fprintf('Gg input term      : %s\n', results.model.gsens_term);
end

if isfield(results, 'calib') && isfield(results.calib, 'bg') && ~isempty(results.calib.bg)
    print_vector3('bg [rad/s]', results.calib.bg);
end

if isfield(results, 'calib') && isfield(results.calib, 'acc')
    acc = results.calib.acc;
    if isfield(acc, 'Ca') && ~isempty(acc.Ca)
        print_matrix3('Ca', acc.Ca);
        fprintf('rcond(Ca) = %.3e\n', rcond(acc.Ca));
    end
    if isfield(acc, 'Sa') && ~isempty(acc.Sa)
        print_matrix3('Sa', acc.Sa);
    end
    if isfield(acc, 'Ma') && ~isempty(acc.Ma)
        print_matrix3('Ma', acc.Ma);
    end
    if isfield(acc, 'ba') && ~isempty(acc.ba)
        print_vector3('ba [m/s^2]', acc.ba);
    end
    if isfield(acc, 'gravity_magnitude') && ~isempty(acc.gravity_magnitude)
        fprintf('gravity_magnitude  : %.6g\n', acc.gravity_magnitude);
    end
end

if isfield(results, 'calib') && isfield(results.calib, 'gyr')
    gyr = results.calib.gyr;
    if isfield(gyr, 'Cg') && ~isempty(gyr.Cg)
        print_matrix3('Cg', gyr.Cg);
        fprintf('rcond(Cg) = %.3e\n', rcond(gyr.Cg));
    end
    if isfield(gyr, 'Kg') && ~isempty(gyr.Kg)
        print_matrix3('Kg', gyr.Kg);
    end
    if isfield(gyr, 'Mg') && ~isempty(gyr.Mg)
        print_matrix3('Mg', gyr.Mg);
    end
    if isfield(gyr, 'Gg') && ~isempty(gyr.Gg)
        print_matrix3('Gg', gyr.Gg);
    end
end

if isfield(results, 'validation') && isfield(results.validation, 'summary')
    fprintf('Validation summary:\n');
    print_expanded_validation_summary(results.validation.summary);
end

if isfield(results, 'calib') && isfield(results.calib, 'temp') && isstruct(results.calib.temp)
    print_temperature_model_summary(getfield_or_default(results.calib.temp, 'bgModel', struct()), 'bgModel');
    print_temperature_model_summary(getfield_or_default(results.calib.temp, 'baModel', struct()), 'baModel');
    if isfield(results.calib.temp, 'message') && ~isempty(results.calib.temp.message)
        fprintf('Temperature model message: %s\n', char(string(results.calib.temp.message)));
    end
end

if isfield(results, 'analysis') && isfield(results.analysis, 'allan') && isstruct(results.analysis.allan)
    print_allan_summary(results.analysis.allan);
end
if isstruct(summaryPayload) && isfield(summaryPayload, 'core_outputs')
    fprintf('Summary temp state : %s\n', char(string(summaryPayload.core_outputs.temperature_model_status)));
    fprintf('Summary Allan state: %s\n', char(string(summaryPayload.core_outputs.allan_status)));
end
end

function print_expanded_validation_summary(summary)
if isfield(summary, 'mode') && ~isempty(summary.mode)
    fprintf('  mode                        : %s\n', char(string(summary.mode)));
end
if isfield(summary, 'num_static_samples') && ~isempty(summary.num_static_samples)
    fprintf('  num_static_samples          : %d\n', summary.num_static_samples);
end
if isfield(summary, 'available_blocks') && ~isempty(summary.available_blocks)
    fprintf('  available_blocks            : %s\n', stringify_list(summary.available_blocks));
end
if isfield(summary, 'completed_modules') && ~isempty(summary.completed_modules)
    fprintf('  completed_modules           : %s\n', stringify_list(summary.completed_modules));
end
if isfield(summary, 'static_gyro_mean_after_bias') && ~isempty(summary.static_gyro_mean_after_bias)
    print_vector3('  static_gyro_mean_after_bias [rad/s]', summary.static_gyro_mean_after_bias);
end
if isfield(summary, 'static_gyro_rms_after_bias') && ~isempty(summary.static_gyro_rms_after_bias)
    print_vector3('  static_gyro_rms_after_bias [rad/s]', summary.static_gyro_rms_after_bias);
end
print_scalar_if_present(summary, 'static_acc_norm_mean', '  static_acc_norm_mean [m/s^2]');
print_scalar_if_present(summary, 'static_acc_norm_std', '  static_acc_norm_std [m/s^2]');
print_scalar_if_present(summary, 'static_acc_norm_mean_before', '  static_acc_norm_mean_before [m/s^2]');
print_scalar_if_present(summary, 'static_acc_norm_mean_after', '  static_acc_norm_mean_after [m/s^2]');
print_scalar_if_present(summary, 'static_acc_norm_std_before', '  static_acc_norm_std_before [m/s^2]');
print_scalar_if_present(summary, 'static_acc_norm_std_after', '  static_acc_norm_std_after [m/s^2]');
if isfield(summary, 'gyro_std') && ~isempty(summary.gyro_std)
    print_vector3('  gyro_std [rad/s]', summary.gyro_std);
end
if isfield(summary, 'acc_std') && ~isempty(summary.acc_std)
    print_vector3('  acc_std [m/s^2]', summary.acc_std);
end
if isfield(summary, 'temperature_model_status') && ~isempty(summary.temperature_model_status)
    fprintf('  temperature_model_status    : %s\n', char(string(summary.temperature_model_status)));
end
if isfield(summary, 'allan_status') && ~isempty(summary.allan_status)
    fprintf('  allan_status                : %s\n', char(string(summary.allan_status)));
end
end

function print_temperature_model_summary(model, label)
if ~isstruct(model) || isempty(fieldnames(model))
    return;
end

fprintf('%s:\n', label);
print_scalar_if_present(model, 'valid', '  valid');
print_scalar_if_present(model, 'low_confidence', '  low_confidence');
if isfield(model, 'method') && ~isempty(model.method)
    fprintf('  method                     : %s\n', char(string(model.method)));
end
if isfield(model, 'type') && ~isempty(model.type)
    fprintf('  type                       : %s\n', char(string(model.type)));
end
if isfield(model, 'reference_temperature') && ~isempty(model.reference_temperature) && isfinite(model.reference_temperature)
    fprintf('  reference_temperature      : %.6g\n', model.reference_temperature);
end
if isfield(model, 'temperature_range') && ~isempty(model.temperature_range)
    tempRange = double(model.temperature_range(:));
    if numel(tempRange) == 2 && all(isfinite(tempRange))
        fprintf('  temperature_range          : [%.6g, %.6g]\n', tempRange(1), tempRange(2));
    end
end
if isfield(model, 'extrapolation_mode') && ~isempty(model.extrapolation_mode)
    fprintf('  extrapolation_mode         : %s\n', char(string(model.extrapolation_mode)));
end
if isfield(model, 'metrics') && isstruct(model.metrics)
    metrics = model.metrics;
    print_scalar_if_present(metrics, 'temp_span', '  temp_span');
    print_scalar_if_present(metrics, 'num_points', '  num_points');
    print_scalar_if_present(metrics, 'num_bins', '  num_bins');
    print_scalar_if_present(metrics, 'rmse', '  rmse');
    print_scalar_if_present(metrics, 'max_abs_residual', '  max_abs_residual');
end
if isfield(model, 'reference_bg') && ~isempty(model.reference_bg)
    print_vector3('  reference_bg', model.reference_bg);
end
if isfield(model, 'reference_ba') && ~isempty(model.reference_ba)
    print_vector3('  reference_ba', model.reference_ba);
end
if isfield(model, 'residual_rms') && ~isempty(model.residual_rms)
    print_vector3('  residual_rms', model.residual_rms);
end
if isfield(model, 'residual_std') && ~isempty(model.residual_std)
    print_vector3('  residual_std', model.residual_std);
end
if isfield(model, 'message') && ~isempty(model.message)
    fprintf('  message                    : %s\n', char(string(model.message)));
end
end

function print_allan_summary(allanStruct)
fprintf('Allan summary:\n');
if isfield(allanStruct, 'gyro') && isstruct(allanStruct.gyro)
    print_single_allan_summary('gyro', allanStruct.gyro);
end
if isfield(allanStruct, 'acc') && isstruct(allanStruct.acc)
    print_single_allan_summary('acc', allanStruct.acc);
end
end

function print_single_allan_summary(name, allan)
fprintf('  %s:\n', name);
print_scalar_if_present(allan, 'valid', '    valid');
print_scalar_if_present(allan, 'num_samples', '    num_samples');
if isfield(allan, 'tau') && ~isempty(allan.tau)
    fprintf('    tau range [s]            : %.6g -> %.6g (%d points)\n', ...
        allan.tau(1), allan.tau(end), numel(allan.tau));
end
if isfield(allan, 'estimate') && isstruct(allan.estimate)
    est = allan.estimate;
    if isfield(est, 'noise_density') && ~isempty(est.noise_density)
        print_vector3('    noise_density', est.noise_density);
    end
    if isfield(est, 'bias_instability') && ~isempty(est.bias_instability)
        print_vector3('    bias_instability', est.bias_instability);
    end
    if isfield(est, 'random_walk') && ~isempty(est.random_walk)
        print_vector3('    random_walk', est.random_walk);
    end
    if isfield(est, 'confidence') && ~isempty(est.confidence)
        fprintf('    confidence               : %s\n', char(string(est.confidence)));
    end
end
if isfield(allan, 'message') && ~isempty(allan.message)
    fprintf('    message                  : %s\n', char(string(allan.message)));
end
end

function print_vector3(label, value)
v = double(value(:));
if numel(v) == 3
    fprintf('%s : [%.6g, %.6g, %.6g]\n', label, v(1), v(2), v(3));
else
    fprintf('%s : ', label);
    disp(v.');
end
end

function print_matrix3(label, M)
A = double(M);
fprintf('%s :\n', label);
disp(A);
end

function print_scalar_if_present(S, fieldName, label)
if isstruct(S) && isfield(S, fieldName) && ~isempty(S.(fieldName))
    value = S.(fieldName);
    if islogical(value)
        value = double(value);
    end
    if isscalar(value) && isnumeric(value) && isfinite(value)
        fprintf('%s : %.6g\n', label, double(value));
    end
end
end

function text = stringify_list(value)
if iscell(value)
    text = strjoin(cellfun(@(x) char(string(x)), value, 'UniformOutput', false), ', ');
else
    text = char(string(value));
end
end
