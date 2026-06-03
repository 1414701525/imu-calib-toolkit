function task = run_allan_analysis(inputData, varargin)
%RUN_ALLAN_ANALYSIS Run Allan deviation analysis using only the available static signals.
% Minimum input:
%   static.t and at least one of static.gyro / static.acc

opts = parse_options(varargin{:});
staticData = normalize_static_input(inputData);
missing = require_inputs(staticData, {'t'});
if ~isempty(missing)
    task = make_task_result(false, 'static.t is required for Allan analysis.', [], ...
        'missing_inputs', {'static.t'}, ...
        'meta', struct('task_name', 'run_allan_analysis'));
    return;
end

hasGyro = isfield(staticData, 'gyro') && ~isempty(staticData.gyro);
hasAcc = isfield(staticData, 'acc') && ~isempty(staticData.acc);
if ~hasGyro && ~hasAcc
    task = make_task_result(false, 'At least one of static.gyro or static.acc is required for Allan analysis.', [], ...
        'missing_inputs', {'static.gyro or static.acc'}, ...
        'meta', struct('task_name', 'run_allan_analysis'));
    return;
end

result = struct();
warnings = {};
if hasGyro
    result.gyro_allan = analyze_gyro_allan(staticData.t, staticData.gyro, varargin{:});
else
    result.gyro_allan = [];
    warnings{end + 1} = 'static.gyro not provided; gyro Allan analysis skipped.'; %#ok<AGROW>
end
if hasAcc
    result.acc_allan = analyze_acc_allan(staticData.t, staticData.acc, varargin{:});
else
    result.acc_allan = [];
    warnings{end + 1} = 'static.acc not provided; accelerometer Allan analysis skipped.'; %#ok<AGROW>
end

task = make_task_result(true, 'Allan analysis completed.', result, ...
    'warnings', warnings, ...
    'meta', struct('task_name', 'run_allan_analysis'));
end

function opts = parse_options(varargin) %#ok<DEFNU>
opts = varargin; %#ok<NASGU>
end

function staticData = normalize_static_input(inputData)
if isstruct(inputData) && isfield(inputData, 'static')
    staticData = inputData.static;
else
    staticData = inputData;
end
end
