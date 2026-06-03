function written = save_calibration_results(results, outputPath, varargin)
%SAVE_CALIBRATION_RESULTS Save calibration results to a directory or MAT file.
%
% Directory mode outputs:
%   calibration_results.mat
%   calibration_summary.json
%   calibration_arrays.mat

if nargin < 2 || isempty(outputPath)
    error('save_calibration_results:MissingPath', ...
        'A target directory or MAT file path is required.');
end

opts = parse_options(varargin{:});
[rootDir, matPath, mode] = resolve_output_path(outputPath);
written = struct('root', rootDir);

save(matPath, 'results');
written.mat = matPath;

if opts.save_json_summary
    summaryPath = fullfile(rootDir, 'calibration_summary.json');
    payload = build_result_summary(results);
    jsonText = jsonencode(to_json_ready(payload));
    fid = fopen(summaryPath, 'w');
    if fid < 0
        error('save_calibration_results:OpenFailed', ...
            'Could not open JSON summary file for writing: %s', summaryPath);
    end
    cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, '%s', jsonText);
    written.json_summary = summaryPath;
end

if opts.save_arrays_mat
    arraysPath = fullfile(rootDir, 'calibration_arrays.mat');
    bg = get_nested_or_default(results, {'calib', 'bg'}, []);
    Ca = get_nested_or_default(results, {'calib', 'acc', 'Ca'}, []);
    ba = get_nested_or_default(results, {'calib', 'acc', 'ba'}, []);
    Sa = get_nested_or_default(results, {'calib', 'acc', 'Sa'}, []);
    Ma = get_nested_or_default(results, {'calib', 'acc', 'Ma'}, []);
    gravity_magnitude = get_nested_or_default(results, {'calib', 'acc', 'gravity_magnitude'}, []);
    Cg = get_nested_or_default(results, {'calib', 'gyr', 'Cg'}, []);
    Kg = get_nested_or_default(results, {'calib', 'gyr', 'Kg'}, []);
    Mg = get_nested_or_default(results, {'calib', 'gyr', 'Mg'}, []);
    Gg = get_nested_or_default(results, {'calib', 'gyr', 'Gg'}, []);
    save(arraysPath, 'bg', 'Ca', 'ba', 'Sa', 'Ma', 'gravity_magnitude', 'Cg', 'Kg', 'Mg', 'Gg');
    written.arrays_mat = arraysPath;
end

if strcmp(mode, 'file') && opts.save_summary_txt
    write_summary_text(results, fullfile(rootDir, 'calibration_summary.txt'));
    written.summary_txt = fullfile(rootDir, 'calibration_summary.txt');
elseif opts.save_summary_txt
    write_summary_text(results, fullfile(rootDir, 'calibration_summary.txt'));
    written.summary_txt = fullfile(rootDir, 'calibration_summary.txt');
end
end

function opts = parse_options(varargin)
opts = struct();
opts.save_json_summary = true;
opts.save_arrays_mat = true;
opts.save_summary_txt = false;

if mod(numel(varargin), 2) ~= 0
    error('save_calibration_results:InvalidInput', ...
        'Optional arguments must be provided as name/value pairs.');
end
for k = 1:2:numel(varargin)
    name = lower(char(varargin{k}));
    value = varargin{k + 1};
    switch name
        case 'save_json_summary'
            opts.save_json_summary = logical(value);
        case 'save_arrays_mat'
            opts.save_arrays_mat = logical(value);
        case 'save_summary_txt'
            opts.save_summary_txt = logical(value);
        otherwise
            error('save_calibration_results:UnknownOption', ...
                'Unknown option "%s".', char(varargin{k}));
    end
end
end

function [rootDir, matPath, mode] = resolve_output_path(outputPath)
outputPath = char(string(outputPath));
[folderPath, baseName, ext] = fileparts(outputPath);
if strcmpi(ext, '.mat')
    if isempty(folderPath)
        folderPath = pwd;
    end
    if ~exist(folderPath, 'dir')
        mkdir(folderPath);
    end
    rootDir = folderPath;
    matPath = fullfile(folderPath, [baseName, '.mat']);
    mode = 'file';
    return;
end

rootDir = outputPath;
if ~exist(rootDir, 'dir')
    mkdir(rootDir);
end
matPath = fullfile(rootDir, 'calibration_results.mat');
mode = 'dir';
end

function ready = to_json_ready(obj)
if isnumeric(obj) || islogical(obj)
    if isscalar(obj)
        ready = obj;
    else
        ready = obj;
    end
elseif ischar(obj) || isstring(obj)
    ready = char(string(obj));
elseif iscell(obj)
    ready = cellfun(@to_json_ready, obj, 'UniformOutput', false);
elseif isstruct(obj)
    ready = struct();
    fields = fieldnames(obj);
    for i = 1:numel(fields)
        ready.(fields{i}) = to_json_ready(obj.(fields{i}));
    end
else
    ready = obj;
end
end

function write_summary_text(results, txtPath)
fid = fopen(txtPath, 'w');
if fid < 0
    error('save_calibration_results:OpenFailed', ...
        'Could not open summary file for writing: %s', txtPath);
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid, 'Calibration Summary\n');
fprintf(fid, '===================\n');
if isfield(results, 'model')
    fprintf(fid, 'Forward gyro model : %s\n', results.model.forward.gyr);
    fprintf(fid, 'Inverse gyro model : %s\n', results.model.inverse.gyr);
    fprintf(fid, 'Forward acc model  : %s\n', results.model.forward.acc);
    fprintf(fid, 'Inverse acc model  : %s\n', results.model.inverse.acc);
end
bg = get_nested_or_default(results, {'calib', 'bg'}, []);
if ~isempty(bg)
    fprintf(fid, 'bg = [%g %g %g]\n', bg(1), bg(2), bg(3));
end
ba = get_nested_or_default(results, {'calib', 'acc', 'ba'}, []);
if ~isempty(ba)
    fprintf(fid, 'ba = [%g %g %g]\n', ba(1), ba(2), ba(3));
end
summary = get_nested_or_default(results, {'validation', 'summary'}, struct());
if isstruct(summary) && ~isempty(fieldnames(summary))
    fprintf(fid, '\nValidation summary available in results.validation.summary\n');
end
end
