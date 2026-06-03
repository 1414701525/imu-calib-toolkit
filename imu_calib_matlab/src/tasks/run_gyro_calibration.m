function task = run_gyro_calibration(inputData, varargin)
%RUN_GYRO_CALIBRATION Run gyroscope Cg calibration with minimum required input.
% Minimum input:
%   gyroRuns, bg
% Optional:
%   static.gyro (used to estimate bg if bg is not explicitly provided)

opts = parse_options(varargin{:});
gyroRuns = normalize_gyro_runs(inputData);
if isempty(gyroRuns)
    task = make_task_result(false, 'gyroRuns is required for gyro Cg calibration.', [], ...
        'missing_inputs', {'gyroRuns'}, ...
        'meta', struct('task_name', 'run_gyro_calibration'));
    return;
end

warnings = {};
bg = opts.bg;
if isempty(bg)
    staticData = extract_static(inputData);
    if ~isempty(staticData) && isfield(staticData, 'gyro') && ~isempty(staticData.gyro)
        biasTask = run_gyro_bias(staticData);
        if ~biasTask.success
            task = make_task_result(false, 'bg is required for gyro Cg calibration.', [], ...
                'missing_inputs', {'bg', 'static.gyro'}, ...
                'meta', struct('task_name', 'run_gyro_calibration'));
            return;
        end
        bg = biasTask.result.bg;
        warnings{end + 1} = 'bg was not provided; estimated from static.gyro.'; %#ok<AGROW>
    else
        task = make_task_result(false, 'bg is required for gyro Cg calibration.', [], ...
            'missing_inputs', {'bg'}, ...
            'warnings', {'Provide bg directly or include static.gyro for fallback estimation.'}, ...
            'meta', struct('task_name', 'run_gyro_calibration'));
        return;
    end
end

[Cg, fitInfo] = fit_gyro_C_from_angle_increment(gyroRuns, bg);
[Kg, Mg] = split_KM(Cg);

result = struct();
result.bg_used = bg;
result.Cg = Cg;
result.Kg = Kg;
result.Mg = Mg;
result.fitInfo = fitInfo;

task = make_task_result(true, 'gyro Cg calibration completed successfully.', result, ...
    'warnings', warnings, ...
    'meta', struct('task_name', 'run_gyro_calibration'));
end

function opts = parse_options(varargin)
opts = struct('bg', []);
if mod(numel(varargin), 2) ~= 0
    error('run_gyro_calibration:InvalidInput', ...
        'Optional arguments must be provided as name/value pairs.');
end
for k = 1:2:numel(varargin)
    name = lower(char(varargin{k}));
    value = varargin{k + 1};
    switch name
        case 'bg'
            opts.bg = value;
        otherwise
            error('run_gyro_calibration:UnknownOption', ...
                'Unknown option "%s".', char(varargin{k}));
    end
end
end

function gyroRuns = normalize_gyro_runs(inputData)
if isstruct(inputData) && isfield(inputData, 'gyroRuns')
    gyroRuns = inputData.gyroRuns;
elseif isstruct(inputData) && isfield(inputData, 'gyro_runs')
    gyroRuns = inputData.gyro_runs;
else
    gyroRuns = inputData;
end
end

function staticData = extract_static(inputData)
if isstruct(inputData) && isfield(inputData, 'static')
    staticData = inputData.static;
else
    staticData = [];
end
end
