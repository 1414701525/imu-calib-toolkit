function results = run_from_csv(csvDir, varargin)
%RUN_FROM_CSV Run the calibration pipeline from a CSV folder, manifest bundle, or a single supported CSV file.
% Usage:
%   results = run_from_csv('C:\path\to\csv_folder')
%   results = run_from_csv('C:\path\to\csv_folder', options)
%   results = run_from_csv('C:\path\to\static.csv')
%   results = run_from_csv('C:\path\to\acc_poses.csv')
%
% Notes:
% - This entry no longer requires all CSV files to exist.
% - The loader returns the available data blocks, and the task layer runs
%   only the modules whose minimum dependencies are satisfied.

if nargin < 1 || isempty(csvDir)
    projectRoot = fileparts(mfilename('fullpath'));
    defaultDir = fullfile(projectRoot, 'csv_input');
    error('run_from_csv:MissingInput', ...
        ['Please provide a CSV folder path or a supported CSV file path, for example:\n' ...
         '  results = run_from_csv(''%s'')'], defaultDir);
end

projectRoot = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(projectRoot, 'src')));

if nargin >= 2
    options = varargin{1};
else
    options = default_calib_options();
end

fprintf('\n================ CSV 标定流程开始 ================\n');
task = run_full_calibration(csvDir, 'options', options);
results = task.result.results;

if isfield(results, 'data') && isfield(results.data, 'meta')
    meta = results.data.meta;
    fprintf('[1/8] 数据读取完成: %s\n', csvDir);
    fprintf('       available blocks: static=%d, acc_poses=%d, gyro_runs=%d, gsens_runs=%d\n', ...
        logical(getfield_or_default(meta, 'has_static', false)), ...
        logical(getfield_or_default(meta, 'has_acc_poses', false)), ...
        logical(getfield_or_default(meta, 'has_gyro_runs', false)), ...
        logical(getfield_or_default(meta, 'has_gsens_runs', false)));

    missingFiles = getfield_or_default(meta, 'missing_files', {});
    if ~isempty(missingFiles)
        fprintf('       missing files: %s\n', strjoin(missingFiles, ', '));
    end

    messages = getfield_or_default(meta, 'messages', {});
    for i = 1:numel(messages)
        fprintf('       note: %s\n', messages{i});
    end
end

fprintf('[2-8/8] 各模块已按可用输入独立执行。\n');
if ~isempty(task.warnings)
    fprintf('Warnings:\n');
    for i = 1:numel(task.warnings)
        fprintf('  - %s\n', task.warnings{i});
    end
end
fprintf('\nCSV 数据标定流程结束。\n');
print_calibration_summary(results);

if isfield(options, 'pipeline') && isfield(options.pipeline, 'plot_results') && options.pipeline.plot_results
    try
        plot_validation_results(results.data, results.compat.flatCalib, results.validation); %#ok<NASGU>
    catch ME
        warning('run_from_csv:PlotFailed', ...
            'Validation plotting was skipped because plotting failed: %s', ME.message);
    end
end
end

function value = getfield_or_default(S, fieldName, defaultValue)
if isstruct(S) && isfield(S, fieldName)
    value = S.(fieldName);
else
    value = defaultValue;
end
end
