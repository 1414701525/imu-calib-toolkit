function task = run_acc_calibration(inputData, varargin)
%RUN_ACC_CALIBRATION Run accelerometer calibration using the new workflow.
% Accepted inputs:
%   - accPoses / acc_poses: pre-computed pose means
%   - static: continuous raw data; static segments will be extracted automatically

opts = parse_options(varargin{:});
[accPoses, extractionInfo, source] = normalize_acc_input(inputData, opts.options);

if isempty(accPoses)
    task = make_task_result(false, ...
        'Accelerometer calibration requires accPoses / acc_poses or raw static data with detectable static segments.', [], ...
        'missing_inputs', {'accPoses_or_static_segments'}, ...
        'meta', struct('task_name', 'run_acc_calibration', 'source', source));
    return;
end

if ~isempty(extractionInfo)
    minSegments = opts.options.segmentation.min_static_segments;
    numSegments = extractionInfo.num_segments;
    if numSegments < minSegments
        task = make_task_result(false, ...
            sprintf(['Not enough static segments were extracted for accelerometer calibration. ' ...
                     'Detected %d, but at least %d are recommended.'], numSegments, minSegments), [], ...
            'warnings', extractionInfo.messages, ...
            'missing_inputs', {'static_segments'}, ...
            'meta', struct('task_name', 'run_acc_calibration', 'source', source));
        return;
    end
end

try
    [Ca, ba, fitInfo] = fit_acc_multi_pose(accPoses, ...
        'gravity_magnitude', opts.options.acc_calibration.gravity_magnitude, ...
        'options', opts.options);
catch ME
    warnList = {};
    if ~isempty(extractionInfo)
        warnList = extractionInfo.messages;
    end
    task = make_task_result(false, ME.message, [], ...
        'warnings', warnList, ...
        'meta', struct('task_name', 'run_acc_calibration', 'source', source));
    return;
end

if ~isempty(extractionInfo)
    fitInfo.static_segment_extraction = extractionInfo;
end

warnings = {};
if ~isempty(extractionInfo)
    warnings = [warnings, extractionInfo.messages]; %#ok<AGROW>
end
if isfield(fitInfo, 'warnings') && ~isempty(fitInfo.warnings)
    warnings = [warnings, fitInfo.warnings(:).']; %#ok<AGROW>
end
if detect_legacy_refs(accPoses)
    warnings{end + 1} = ...
        'Legacy reference vectors were detected. They are deprecated and were only used for initialization compatibility.'; %#ok<AGROW>
end

result = struct();
result.Ca = Ca;
result.ba = ba;
result.Sa = fitInfo.Sa;
result.Ma = fitInfo.Ma;
result.gravity_magnitude = fitInfo.gravity_magnitude;
result.fitInfo = fitInfo;

task = make_task_result(true, 'accelerometer calibration completed successfully.', result, ...
    'warnings', warnings, ...
    'meta', struct('task_name', 'run_acc_calibration', 'source', source));
end

function opts = parse_options(varargin)
opts = struct();
opts.options = default_calib_options();
if mod(numel(varargin), 2) ~= 0
    error('run_acc_calibration:InvalidInput', ...
        'Optional arguments must be provided as name/value pairs.');
end
for k = 1:2:numel(varargin)
    name = lower(char(varargin{k}));
    value = varargin{k + 1};
    switch name
        case 'options'
            opts.options = value;
        otherwise
            error('run_acc_calibration:UnknownOption', ...
                'Unknown option "%s".', char(varargin{k}));
    end
end
end

function [accPoses, extractionInfo, source] = normalize_acc_input(inputData, options)
accPoses = [];
extractionInfo = [];
source = 'direct_input';

if isstruct(inputData)
    if isfield(inputData, 'accPoses') && ~isempty(inputData.accPoses)
        accPoses = inputData.accPoses;
        source = 'dataset.accPoses';
        return;
    end
    if isfield(inputData, 'acc_poses') && ~isempty(inputData.acc_poses)
        accPoses = inputData.acc_poses;
        source = 'dataset.acc_poses';
        return;
    end
    if isfield(inputData, 'static') && ~isempty(inputData.static) && isstruct(inputData.static)
        [accPoses, extractionInfo] = extract_static_pose_means(inputData.static, 'options', options);
        source = 'dataset.static';
        return;
    end
end

if numel(inputData) > 0 && isstruct(inputData)
    accPoses = inputData;
end
end

function tf = detect_legacy_refs(accPoses)
tf = false;
for i = 1:numel(accPoses)
    if isfield(accPoses(i), 'a_ref') && ~isempty(accPoses(i).a_ref)
        tf = true;
        return;
    end
end
end
