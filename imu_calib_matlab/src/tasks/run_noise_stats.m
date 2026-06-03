function task = run_noise_stats(inputData)
%RUN_NOISE_STATS Run static noise statistics using the minimum required input.
% Minimum input:
%   static.gyro
%   static.acc

staticData = normalize_static_input(inputData);
missing = require_inputs(staticData, {'gyro', 'acc'});
if ~isempty(missing)
    task = make_task_result(false, 'static.gyro and static.acc are required for noise statistics.', [], ...
        'missing_inputs', {'static.gyro', 'static.acc'}, ...
        'meta', struct('task_name', 'run_noise_stats'));
    return;
end

noiseStats = estimate_noise_stats(staticData.gyro, staticData.acc);
task = make_task_result(true, 'noise statistics estimated successfully.', ...
    struct('noiseStats', noiseStats), ...
    'meta', struct('task_name', 'run_noise_stats'));
end

function staticData = normalize_static_input(inputData)
if isstruct(inputData) && isfield(inputData, 'static')
    staticData = inputData.static;
else
    staticData = inputData;
end
end
