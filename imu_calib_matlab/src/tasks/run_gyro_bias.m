function task = run_gyro_bias(inputData)
%RUN_GYRO_BIAS Run gyroscope static bias estimation using the minimum required input.
% Minimum input:
%   static.gyro
% Optional:
%   static.t, static.temp

staticData = normalize_static_input(inputData);
missing = require_inputs(staticData, {'gyro'});
if ~isempty(missing)
    task = make_task_result(false, 'static.gyro is required for gyro bias estimation.', [], ...
        'missing_inputs', {'static.gyro'}, ...
        'meta', struct('task_name', 'run_gyro_bias'));
    return;
end

t = getfield_or_default(staticData, 't', []); %#ok<GFLD>
temp = getfield_or_default(staticData, 'temp', []); %#ok<GFLD>
[bg, info] = estimate_gyro_bias(staticData.gyro, 't', t, 'temp', temp);

result = struct();
result.bg = bg;
result.stats = info;

task = make_task_result(true, 'gyro bias estimated successfully.', result, ...
    'meta', struct('task_name', 'run_gyro_bias'));
end

function staticData = normalize_static_input(inputData)
if isstruct(inputData) && isfield(inputData, 'static')
    staticData = inputData.static;
else
    staticData = inputData;
end
end

function value = getfield_or_default(S, fieldName, defaultValue)
if isstruct(S) && isfield(S, fieldName)
    value = S.(fieldName);
else
    value = defaultValue;
end
end
