function task = run_gsens_fit(inputData, varargin)
%RUN_GSENS_FIT Run residual-based Gg fitting with minimum required input.
% Minimum input:
%   gsensRuns, Cg, bg

opts = parse_options(varargin{:});
gsensRuns = normalize_gsens_runs(inputData);
if isempty(gsensRuns)
    task = make_task_result(false, 'gsensRuns is required for Gg fitting.', [], ...
        'missing_inputs', {'gsensRuns'}, ...
        'meta', struct('task_name', 'run_gsens_fit'));
    return;
end

missing = {};
if isempty(opts.Cg)
    missing{end + 1} = 'Cg'; %#ok<AGROW>
end
if isempty(opts.bg)
    missing{end + 1} = 'bg'; %#ok<AGROW>
end
if ~isempty(missing)
    task = make_task_result(false, 'Cg and bg are required for Gg fitting.', [], ...
        'missing_inputs', missing, ...
        'meta', struct('task_name', 'run_gsens_fit'));
    return;
end

[Gg, fitInfo] = fit_gyro_g_sensitivity(gsensRuns, opts.bg, opts.Cg);
task = make_task_result(true, 'Gg fitting completed.', ...
    struct('Gg', Gg, 'fitInfo', fitInfo), ...
    'warnings', conditional_warning(fitInfo), ...
    'meta', struct('task_name', 'run_gsens_fit'));
end

function opts = parse_options(varargin)
opts = struct('bg', [], 'Cg', []);
if mod(numel(varargin), 2) ~= 0
    error('run_gsens_fit:InvalidInput', ...
        'Optional arguments must be provided as name/value pairs.');
end
for k = 1:2:numel(varargin)
    name = lower(char(varargin{k}));
    value = varargin{k + 1};
    switch name
        case 'bg'
            opts.bg = value;
        case 'cg'
            opts.Cg = value;
        otherwise
            error('run_gsens_fit:UnknownOption', ...
                'Unknown option "%s".', char(varargin{k}));
    end
end
end

function gsensRuns = normalize_gsens_runs(inputData)
if isstruct(inputData) && isfield(inputData, 'gsensRuns')
    gsensRuns = inputData.gsensRuns;
elseif isstruct(inputData) && isfield(inputData, 'gsens_runs')
    gsensRuns = inputData.gsens_runs;
else
    gsensRuns = inputData;
end
end

function warnings = conditional_warning(fitInfo)
warnings = {};
if isstruct(fitInfo) && isfield(fitInfo, 'valid') && ~fitInfo.valid && isfield(fitInfo, 'message')
    warnings = {fitInfo.message};
end
end
