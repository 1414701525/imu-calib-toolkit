function data = load_csv_data(csvDir)
%LOAD_CSV_DATA Load IMU calibration data from a CSV folder, manifest bundle, or a supported single CSV.

if nargin < 1 || isempty(csvDir)
    error('load_csv_data:MissingPath', 'A CSV folder path is required.');
end
if ~isfolder(csvDir) && ~exist(csvDir, 'file')
    error('load_csv_data:PathNotFound', 'CSV folder or file not found: %s', csvDir);
end

layout = resolve_dataset_layout(csvDir);

data = struct();
if ~isempty(layout.staticFile) && exist(layout.staticFile, 'file')
    data.static = load_static_csv(layout.staticFile);
else
    data.static = empty_static_data();
end

if ~isempty(layout.accPosesFile) && exist(layout.accPosesFile, 'file')
    data.accPoses = load_acc_pose_csv(layout.accPosesFile);
else
    data.accPoses = empty_acc_poses();
end
data.acc_poses = data.accPoses;

if ~isempty(layout.gyroRunsFile) && exist(layout.gyroRunsFile, 'file')
    data.gyroRuns = load_gyro_runs_csv(layout.gyroRunsFile);
else
    data.gyroRuns = empty_gyro_runs();
end
data.gyro_runs = data.gyroRuns;

if ~isempty(layout.gsensRunsFile) && exist(layout.gsensRunsFile, 'file')
    data.gsensRuns = load_gsens_runs_csv(layout.gsensRunsFile);
else
    data.gsensRuns = empty_gsens_runs();
end
data.gsens_runs = data.gsensRuns;

data.meta = build_meta(layout, csvDir, data);

if isempty(data.meta.available_blocks)
    error('load_csv_data:NoSupportedBlocksFound', ...
        'No supported IMU calibration CSV blocks were found in: %s', csvDir);
end
end

function layout = resolve_dataset_layout(csvDir)
if exist(csvDir, 'file')
    [~, baseName, ext] = fileparts(csvDir);
    if ~strcmpi(ext, '.csv')
        error('load_csv_data:UnsupportedFileInput', ...
            'If a file path is provided, it must point to a supported CSV file.');
    end

    layout = struct('manifestPath', '', 'staticFile', '', 'accPosesFile', '', ...
        'gyroRunsFile', '', 'gsensRunsFile', '', 'source', '');
    switch lower(baseName)
        case 'static'
            layout.staticFile = csvDir;
            layout.source = 'single_static_csv';
        case 'acc_poses'
            layout.accPosesFile = csvDir;
            layout.source = 'single_acc_poses_csv';
        case 'gyro_runs'
            layout.gyroRunsFile = csvDir;
            layout.source = 'single_gyro_runs_csv';
        case 'gsens_runs'
            layout.gsensRunsFile = csvDir;
            layout.source = 'single_gsens_runs_csv';
        otherwise
            error('load_csv_data:UnsupportedFileInput', ...
                'Direct file input only supports static.csv, acc_poses.csv, gyro_runs.csv, or gsens_runs.csv.');
    end
    return;
end

manifestPath = fullfile(csvDir, 'dataset_manifest.json');
layout = struct();
layout.manifestPath = manifestPath;
layout.staticFile = fullfile(csvDir, 'static.csv');
layout.accPosesFile = fullfile(csvDir, 'acc_poses.csv');
layout.gyroRunsFile = fullfile(csvDir, 'gyro_runs.csv');
layout.gsensRunsFile = fullfile(csvDir, 'gsens_runs.csv');
layout.source = 'legacy_csv_folder';

if ~exist(manifestPath, 'file')
    return;
end

manifest = jsondecode(fileread(manifestPath));
if ~isfield(manifest, 'files') || ~isstruct(manifest.files)
    error('load_csv_data:InvalidManifest', ...
        'Manifest file %s must contain a "files" object.', manifestPath);
end

if isfield(manifest.files, 'static')
    layout.staticFile = fullfile(csvDir, char(string(manifest.files.static)));
else
    layout.staticFile = '';
end
if isfield(manifest.files, 'acc_poses')
    layout.accPosesFile = fullfile(csvDir, char(string(manifest.files.acc_poses)));
else
    layout.accPosesFile = '';
end
if isfield(manifest.files, 'gyro_runs')
    layout.gyroRunsFile = fullfile(csvDir, char(string(manifest.files.gyro_runs)));
else
    layout.gyroRunsFile = '';
end
if isfield(manifest.files, 'gsens_runs')
    layout.gsensRunsFile = fullfile(csvDir, char(string(manifest.files.gsens_runs)));
else
    layout.gsensRunsFile = '';
end
layout.source = 'manifest_bundle';
end

function meta = build_meta(layout, inputPath, data)
availableBlocks = {};
if ~isempty(data.static.gyro)
    availableBlocks{end + 1} = 'static'; %#ok<AGROW>
end
if ~isempty(data.accPoses)
    availableBlocks{end + 1} = 'acc_poses'; %#ok<AGROW>
end
if ~isempty(data.gyroRuns)
    availableBlocks{end + 1} = 'gyro_runs'; %#ok<AGROW>
end
if ~isempty(data.gsensRuns)
    availableBlocks{end + 1} = 'gsens_runs'; %#ok<AGROW>
end

missingFiles = {};
if ~ismember('static', availableBlocks)
    missingFiles{end + 1} = 'static.csv'; %#ok<AGROW>
end
if ~ismember('acc_poses', availableBlocks)
    missingFiles{end + 1} = 'acc_poses.csv'; %#ok<AGROW>
end
if ~ismember('gyro_runs', availableBlocks)
    missingFiles{end + 1} = 'gyro_runs.csv'; %#ok<AGROW>
end
if ~ismember('gsens_runs', availableBlocks)
    missingFiles{end + 1} = 'gsens_runs.csv'; %#ok<AGROW>
end

messages = {};
switch layout.source
    case 'single_static_csv'
        messages{end + 1} = 'Loaded static.csv directly. Only static-dependent modules are immediately available.'; %#ok<AGROW>
    case 'single_acc_poses_csv'
        messages{end + 1} = 'Loaded acc_poses.csv directly. Only accelerometer multi-pose calibration is immediately available.'; %#ok<AGROW>
    case 'single_gyro_runs_csv'
        messages{end + 1} = 'Loaded gyro_runs.csv directly. Gyro Cg calibration still requires bg or static.gyro.'; %#ok<AGROW>
    case 'single_gsens_runs_csv'
        messages{end + 1} = 'Loaded gsens_runs.csv directly. Gg fitting still requires bg and Cg.'; %#ok<AGROW>
    otherwise
        if isempty(missingFiles)
            messages{end + 1} = 'Loaded all standard dataset blocks.'; %#ok<AGROW>
        else
            messages{end + 1} = sprintf('Loaded partial dataset. Missing files: %s.', strjoin(missingFiles, ', ')); %#ok<AGROW>
        end
end

availableTasks = derive_available_tasks(availableBlocks);
meta = struct();
meta.source = layout.source;
meta.input_path = inputPath;
meta.manifest = layout.manifestPath;
meta.has_static = ismember('static', availableBlocks);
meta.has_acc_poses = ismember('acc_poses', availableBlocks);
meta.has_gyro_runs = ismember('gyro_runs', availableBlocks);
meta.has_gsens_runs = ismember('gsens_runs', availableBlocks);
meta.available_blocks = availableBlocks;
meta.missing_files = missingFiles;
meta.messages = messages;
meta.available_tasks = availableTasks;
end

function tasks = derive_available_tasks(availableBlocks)
tasks = {};
blockSet = availableBlocks;
if ismember('static', blockSet)
    tasks = [tasks, {'gyro_bias', 'noise_stats', 'allan_analysis', 'temperature_fit', 'acc_calibration_from_static'}]; %#ok<AGROW>
end
if ismember('acc_poses', blockSet)
    tasks{end + 1} = 'acc_calibration'; %#ok<AGROW>
end
if ismember('gyro_runs', blockSet)
    tasks{end + 1} = 'gyro_calibration_requires_bg'; %#ok<AGROW>
end
if ismember('gsens_runs', blockSet)
    tasks{end + 1} = 'gsens_fit_requires_bg_and_Cg'; %#ok<AGROW>
end
end

function staticData = load_static_csv(filePath)
T = read_csv_table(filePath);
required = {'t', 'gx', 'gy', 'gz', 'ax', 'ay', 'az'};
require_columns(T, required, filePath);
assert_no_missing(T, required, filePath);

staticData = struct();
staticData.t = as_numeric_column(T.t, 't', filePath);
validate_time_vector(staticData.t, filePath);
staticData.gyro = [as_numeric_column(T.gx, 'gx', filePath), ...
                   as_numeric_column(T.gy, 'gy', filePath), ...
                   as_numeric_column(T.gz, 'gz', filePath)];
staticData.acc = [as_numeric_column(T.ax, 'ax', filePath), ...
                  as_numeric_column(T.ay, 'ay', filePath), ...
                  as_numeric_column(T.az, 'az', filePath)];
if ismember('temp', T.Properties.VariableNames)
    assert_no_missing(T, {'temp'}, filePath);
    staticData.temp = as_numeric_column(T.temp, 'temp', filePath);
else
    staticData.temp = [];
end
end

function accPoses = load_acc_pose_csv(filePath)
T = read_csv_table(filePath);
renameBack = struct();
if ~ismember('acc_x', T.Properties.VariableNames) && ismember('ax', T.Properties.VariableNames)
    renameBack.ax = 'acc_x';
end
if ~ismember('acc_y', T.Properties.VariableNames) && ismember('ay', T.Properties.VariableNames)
    renameBack.ay = 'acc_y';
end
if ~ismember('acc_z', T.Properties.VariableNames) && ismember('az', T.Properties.VariableNames)
    renameBack.az = 'acc_z';
end
if ~isempty(fieldnames(renameBack))
    oldNames = fieldnames(renameBack);
    newNames = struct2cell(renameBack);
    for i = 1:numel(oldNames)
        idx = strcmp(T.Properties.VariableNames, oldNames{i});
        T.Properties.VariableNames(idx) = newNames(i);
    end
end

required = {'pose_name', 'acc_x', 'acc_y', 'acc_z'};
require_columns(T, required, filePath);
assert_no_missing(T, required, filePath);

hasAnyLegacy = any(ismember({'ref_x', 'ref_y', 'ref_z'}, T.Properties.VariableNames));
hasAllLegacy = all(ismember({'ref_x', 'ref_y', 'ref_z'}, T.Properties.VariableNames));
if hasAnyLegacy && ~hasAllLegacy
    error('load_csv_data:IncompleteLegacyReference', ...
        '%s must provide ref_x/ref_y/ref_z together if any legacy reference columns are present.', filePath);
end
if hasAllLegacy
    assert_no_missing(T, {'ref_x', 'ref_y', 'ref_z'}, filePath);
end

N = height(T);
accPoses = repmat(struct('acc_mean', zeros(3, 1), ...
                         'a_ref', [], ...
                         'pose_name', ''), N, 1);
for i = 1:N
    accPoses(i).acc_mean = [double(T.acc_x(i)); double(T.acc_y(i)); double(T.acc_z(i))];
    if hasAllLegacy
        accPoses(i).a_ref = [double(T.ref_x(i)); double(T.ref_y(i)); double(T.ref_z(i))];
    else
        accPoses(i).a_ref = [];
    end
    accPoses(i).pose_name = char(string(T.pose_name(i)));
end
end

function gyroRuns = load_gyro_runs_csv(filePath)
T = read_csv_table(filePath);
required = {'run_id', 'axis', 'dir', 't', 'gx', 'gy', 'gz', 'idx_ss', ...
            'theta_ref_x', 'theta_ref_y', 'theta_ref_z'};
require_columns(T, required, filePath);
assert_no_missing(T, required, filePath);

runIds = unique(T.run_id, 'stable');
numRuns = numel(runIds);
gyroRuns = repmat(struct('axis', 'x', ...
                         'dir', 1, ...
                         'gyro', zeros(0, 3), ...
                         't', zeros(0, 1), ...
                         'theta_ref', zeros(3, 1), ...
                         'idx_ss', false(0, 1)), numRuns, 1);

for i = 1:numRuns
    idx = isequal_mask(T.run_id, runIds(i));
    Ti = T(idx, :);
    t = as_numeric_column(Ti.t, 't', filePath);
    validate_time_vector(t, filePath);

    axisValue = lower(char(string(Ti.axis(1))));
    if ~ismember(axisValue, {'x', 'y', 'z'})
        error('load_csv_data:InvalidAxis', ...
            'Invalid axis value "%s" in %s. Expected x/y/z.', axisValue, filePath);
    end
    dirValue = double(Ti.dir(1));
    if ~ismember(dirValue, [-1, 1])
        error('load_csv_data:InvalidDir', ...
            'Invalid dir value %.6g in %s. Expected +1 or -1.', dirValue, filePath);
    end

    check_constant_column(Ti.theta_ref_x, 'theta_ref_x', filePath);
    check_constant_column(Ti.theta_ref_y, 'theta_ref_y', filePath);
    check_constant_column(Ti.theta_ref_z, 'theta_ref_z', filePath);

    gyroRuns(i).axis = axisValue;
    gyroRuns(i).dir = dirValue;
    gyroRuns(i).gyro = [double(Ti.gx), double(Ti.gy), double(Ti.gz)];
    gyroRuns(i).t = t;
    gyroRuns(i).theta_ref = [double(Ti.theta_ref_x(1)); double(Ti.theta_ref_y(1)); double(Ti.theta_ref_z(1))];
    idxSS = as_numeric_column(Ti.idx_ss, 'idx_ss', filePath);
    if any(~ismember(idxSS, [0, 1]))
        error('load_csv_data:InvalidIdxSs', ...
            'Column "idx_ss" in %s must contain only 0/1 values.', filePath);
    end
    gyroRuns(i).idx_ss = logical(idxSS);
end
end

function gsensRuns = load_gsens_runs_csv(filePath)
T = read_csv_table(filePath);
required = {'run_id', 't', 'gx', 'gy', 'gz', 'acc_ref_x', 'acc_ref_y', 'acc_ref_z'};
require_columns(T, required, filePath);
assert_no_missing(T, required, filePath);

hasAnyOmega = any(ismember({'omega_ref_x', 'omega_ref_y', 'omega_ref_z'}, T.Properties.VariableNames));
hasAllOmega = all(ismember({'omega_ref_x', 'omega_ref_y', 'omega_ref_z'}, T.Properties.VariableNames));
if hasAnyOmega && ~hasAllOmega
    error('load_csv_data:IncompleteOmegaRef', ...
        'If omega_ref columns are provided in %s, all 3 columns must exist.', filePath);
end
if hasAllOmega
    assert_no_missing(T, {'omega_ref_x', 'omega_ref_y', 'omega_ref_z'}, filePath);
end

runIds = unique(T.run_id, 'stable');
numRuns = numel(runIds);
gsensRuns = repmat(struct('gyro', zeros(0, 3), ...
                          'acc_ref', zeros(0, 3), ...
                          'omega_ref', zeros(0, 3), ...
                          't', zeros(0, 1)), numRuns, 1);

for i = 1:numRuns
    idx = isequal_mask(T.run_id, runIds(i));
    Ti = T(idx, :);
    t = as_numeric_column(Ti.t, 't', filePath);
    validate_time_vector(t, filePath);

    gsensRuns(i).gyro = [double(Ti.gx), double(Ti.gy), double(Ti.gz)];
    gsensRuns(i).acc_ref = [double(Ti.acc_ref_x), double(Ti.acc_ref_y), double(Ti.acc_ref_z)];
    gsensRuns(i).t = t;
    if hasAllOmega
        gsensRuns(i).omega_ref = [double(Ti.omega_ref_x), double(Ti.omega_ref_y), double(Ti.omega_ref_z)];
    else
        gsensRuns(i).omega_ref = zeros(height(Ti), 3);
    end
end
end

function T = read_csv_table(filePath)
assert_file_exists(filePath);
T = readtable(filePath, 'VariableNamingRule', 'preserve');
T = normalize_expected_variable_names(T);
end

function assert_file_exists(filePath)
if ~exist(filePath, 'file')
    error('load_csv_data:FileNotFound', 'Required file not found: %s', filePath);
end
end

function require_columns(T, requiredColumns, filePath)
missing = requiredColumns(~ismember(requiredColumns, T.Properties.VariableNames));
if ~isempty(missing)
    error('load_csv_data:MissingColumns', ...
        'Missing required columns in %s: %s', filePath, strjoin(missing, ', '));
end
end

function assert_no_missing(T, columns, filePath)
for i = 1:numel(columns)
    col = T.(columns{i});
    if any(ismissing(col))
        error('load_csv_data:MissingValues', ...
            'Column "%s" in %s contains missing values.', columns{i}, filePath);
    end
end
end

function x = as_numeric_column(col, columnName, filePath)
x = double(col);
x = x(:);
if any(~isfinite(x))
    error('load_csv_data:InvalidNumeric', ...
        'Column "%s" in %s must contain finite numeric values.', columnName, filePath);
end
end

function validate_time_vector(t, filePath)
if numel(t) < 2
    error('load_csv_data:ShortTimeVector', ...
        'Time vector in %s must contain at least 2 samples.', filePath);
end
if any(diff(t) <= 0)
    error('load_csv_data:NonMonotonicTime', ...
        'Time vector in %s must be strictly increasing.', filePath);
end
end

function check_constant_column(col, columnName, filePath)
values = double(col);
if max(abs(values - values(1))) > 1e-12
    error('load_csv_data:NonConstantColumn', ...
        'Column "%s" in %s must stay constant within each run.', columnName, filePath);
end
end

function mask = isequal_mask(values, target)
if iscell(target) && isscalar(target)
    target = target{1};
end
if iscell(values)
    mask = cellfun(@(x) isequal(x, target), values);
elseif isstring(values) || iscategorical(values)
    mask = values == target;
else
    mask = values == target;
end
mask = logical(mask);
end

function T = normalize_expected_variable_names(T)
originalNames = T.Properties.VariableNames;
normalizedNames = originalNames;
for i = 1:numel(originalNames)
    key = lower(strtrim(originalNames{i}));
    key = regexprep(key, '\s+', '');
    key = regexprep(key, '[\(\)\[\]\{\}]', '');
    key = strrep(key, '-', '_');
    mapped = map_column_alias(key);
    if ~isempty(mapped)
        normalizedNames{i} = mapped;
    end
end
T.Properties.VariableNames = matlab.lang.makeUniqueStrings(normalizedNames);
end

function mapped = map_column_alias(key)
mapping = containers.Map();
mapping('t') = 't';
mapping('time') = 't';
mapping('times') = 't';
mapping('gx') = 'gx';
mapping('gyrox') = 'gx';
mapping('gyro_x') = 'gx';
mapping('gyroxrad/s') = 'gx';
mapping('gxrad/s') = 'gx';
mapping('gy') = 'gy';
mapping('gyroy') = 'gy';
mapping('gyro_y') = 'gy';
mapping('gyroyrad/s') = 'gy';
mapping('gyrad/s') = 'gy';
mapping('gz') = 'gz';
mapping('gyroz') = 'gz';
mapping('gyro_z') = 'gz';
mapping('gyrozrad/s') = 'gz';
mapping('gzrad/s') = 'gz';
mapping('ax') = 'ax';
mapping('accx') = 'ax';
mapping('acc_x') = 'ax';
mapping('accelx') = 'ax';
mapping('accel_x') = 'ax';
mapping('axm/s^2') = 'ax';
mapping('ay') = 'ay';
mapping('accy') = 'ay';
mapping('acc_y') = 'ay';
mapping('accely') = 'ay';
mapping('accel_y') = 'ay';
mapping('aym/s^2') = 'ay';
mapping('az') = 'az';
mapping('accz') = 'az';
mapping('acc_z') = 'az';
mapping('accelz') = 'az';
mapping('accel_z') = 'az';
mapping('azm/s^2') = 'az';

passthrough = {'temp', 'axis', 'dir', 'run_id', 'pose_name', ...
               'acc_x', 'acc_y', 'acc_z', 'ref_x', 'ref_y', 'ref_z', ...
               'theta_ref_x', 'theta_ref_y', 'theta_ref_z', ...
               'acc_ref_x', 'acc_ref_y', 'acc_ref_z', ...
               'omega_ref_x', 'omega_ref_y', 'omega_ref_z', 'idx_ss'};

if isKey(mapping, key)
    mapped = mapping(key);
elseif ismember(key, passthrough)
    mapped = key;
else
    mapped = '';
end
end

function accPoses = empty_acc_poses()
accPoses = repmat(struct('acc_mean', zeros(3, 1), ...
                         'a_ref', [], ...
                         'pose_name', ''), 0, 1);
end

function staticData = empty_static_data()
staticData = struct();
staticData.t = zeros(0, 1);
staticData.gyro = zeros(0, 3);
staticData.acc = zeros(0, 3);
staticData.temp = zeros(0, 1);
end

function gyroRuns = empty_gyro_runs()
gyroRuns = repmat(struct('axis', 'x', ...
                         'dir', 1, ...
                         'gyro', zeros(0, 3), ...
                         't', zeros(0, 1), ...
                         'theta_ref', zeros(3, 1), ...
                         'idx_ss', false(0, 1)), 0, 1);
end

function gsensRuns = empty_gsens_runs()
gsensRuns = repmat(struct('gyro', zeros(0, 3), ...
                          'acc_ref', zeros(0, 3), ...
                          'omega_ref', zeros(0, 3), ...
                          't', zeros(0, 1)), 0, 1);
end
