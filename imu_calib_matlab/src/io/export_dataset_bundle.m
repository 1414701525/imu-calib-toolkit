function written = export_dataset_bundle(data, outDir, varargin)
%EXPORT_DATASET_BUNDLE Export dataset struct to the manifest + CSV bundle layout.
%
% By default the new accelerometer bundle omits per-pose reference vectors.

opts = parse_options(varargin{:});

if nargin < 2 || isempty(outDir)
    error('export_dataset_bundle:MissingOutputDir', 'Output directory is required.');
end
if ~isstruct(data)
    error('export_dataset_bundle:InvalidData', 'Input data must be a struct.');
end
if ~isfolder(outDir)
    mkdir(outDir);
end

staticPath = fullfile(outDir, 'static.csv');
accPosesPath = fullfile(outDir, 'acc_poses.csv');
gyroRunsPath = fullfile(outDir, 'gyro_runs.csv');
gsensRunsPath = fullfile(outDir, 'gsens_runs.csv');
manifestPath = fullfile(outDir, 'dataset_manifest.json');

write_static_csv(data.static, staticPath);
write_acc_poses_csv(getfield_any(data, {'accPoses', 'acc_poses'}, []), accPosesPath, opts.include_legacy_reference_columns);
write_gyro_runs_csv(getfield_any(data, {'gyroRuns', 'gyro_runs'}, []), gyroRunsPath);

gsensRuns = getfield_any(data, {'gsensRuns', 'gsens_runs'}, []);
hasGsens = ~isempty(gsensRuns);
if hasGsens
    write_gsens_runs_csv(gsensRuns, gsensRunsPath);
elseif exist(gsensRunsPath, 'file')
    delete(gsensRunsPath);
end

manifest = struct();
manifest.format = 'imu_calib_bundle';
manifest.version = 1;
manifest.files = struct();
manifest.files.static = 'static.csv';
manifest.files.acc_poses = 'acc_poses.csv';
manifest.files.gyro_runs = 'gyro_runs.csv';
if hasGsens
    manifest.files.gsens_runs = 'gsens_runs.csv';
end

fid = fopen(manifestPath, 'w');
if fid < 0
    error('export_dataset_bundle:ManifestOpenFailed', ...
        'Could not open manifest file for writing: %s', manifestPath);
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', jsonencode(manifest));

written = struct('root', outDir, 'manifest', manifestPath);
end

function opts = parse_options(varargin)
opts = struct('include_legacy_reference_columns', false);
if mod(numel(varargin), 2) ~= 0
    error('export_dataset_bundle:InvalidInput', ...
        'Optional arguments must be provided as name/value pairs.');
end
for k = 1:2:numel(varargin)
    name = lower(char(varargin{k}));
    value = varargin{k + 1};
    switch name
        case 'include_legacy_reference_columns'
            opts.include_legacy_reference_columns = logical(value);
        otherwise
            error('export_dataset_bundle:UnknownOption', ...
                'Unknown option "%s".', char(varargin{k}));
    end
end
end

function write_static_csv(staticData, filePath)
validateattributes(staticData.gyro, {'numeric'}, {'2d', 'ncols', 3}, mfilename, 'data.static.gyro');
validateattributes(staticData.acc, {'numeric'}, {'2d', 'ncols', 3}, mfilename, 'data.static.acc');
validateattributes(staticData.t, {'numeric'}, {'column'}, mfilename, 'data.static.t');
if size(staticData.gyro, 1) ~= numel(staticData.t) || size(staticData.acc, 1) ~= numel(staticData.t)
    error('export_dataset_bundle:StaticLengthMismatch', ...
        'static.t, static.gyro, and static.acc must have matching lengths.');
end

T = table(staticData.t, staticData.gyro(:, 1), staticData.gyro(:, 2), staticData.gyro(:, 3), ...
          staticData.acc(:, 1), staticData.acc(:, 2), staticData.acc(:, 3), ...
          'VariableNames', {'t', 'gx', 'gy', 'gz', 'ax', 'ay', 'az'});
if isfield(staticData, 'temp') && ~isempty(staticData.temp)
    T.temp = staticData.temp(:);
end
writetable(T, filePath);
end

function write_acc_poses_csv(accPoses, filePath, includeLegacyReferenceColumns)
numPoses = numel(accPoses);
pose_name = strings(numPoses, 1);
acc_x = zeros(numPoses, 1);
acc_y = zeros(numPoses, 1);
acc_z = zeros(numPoses, 1);
hasLegacy = false;
ref_x = zeros(numPoses, 1);
ref_y = zeros(numPoses, 1);
ref_z = zeros(numPoses, 1);

for i = 1:numPoses
    pose_name(i) = string(accPoses(i).pose_name);
    accMean = accPoses(i).acc_mean(:);
    acc_x(i) = accMean(1);
    acc_y(i) = accMean(2);
    acc_z(i) = accMean(3);
    if includeLegacyReferenceColumns && isfield(accPoses(i), 'a_ref') && ~isempty(accPoses(i).a_ref)
        aRef = accPoses(i).a_ref(:);
        ref_x(i) = aRef(1);
        ref_y(i) = aRef(2);
        ref_z(i) = aRef(3);
        hasLegacy = true;
    end
end

T = table(pose_name, acc_x, acc_y, acc_z);
if hasLegacy
    T.ref_x = ref_x;
    T.ref_y = ref_y;
    T.ref_z = ref_z;
end
writetable(T, filePath);
end

function write_gyro_runs_csv(gyroRuns, filePath)
run_id = [];
axisCol = strings(0, 1);
dirCol = [];
t = [];
gx = [];
gy = [];
gz = [];
idx_ss = [];
theta_ref_x = [];
theta_ref_y = [];
theta_ref_z = [];
for i = 1:numel(gyroRuns)
    run = gyroRuns(i);
    N = size(run.gyro, 1);
    run_id = [run_id; i * ones(N, 1)]; %#ok<AGROW>
    axisCol = [axisCol; repmat(string(run.axis), N, 1)]; %#ok<AGROW>
    dirCol = [dirCol; run.dir * ones(N, 1)]; %#ok<AGROW>
    t = [t; run.t(:)]; %#ok<AGROW>
    gx = [gx; run.gyro(:, 1)]; %#ok<AGROW>
    gy = [gy; run.gyro(:, 2)]; %#ok<AGROW>
    gz = [gz; run.gyro(:, 3)]; %#ok<AGROW>
    idx_ss = [idx_ss; double(run.idx_ss(:))]; %#ok<AGROW>
    thetaRef = run.theta_ref(:);
    theta_ref_x = [theta_ref_x; thetaRef(1) * ones(N, 1)]; %#ok<AGROW>
    theta_ref_y = [theta_ref_y; thetaRef(2) * ones(N, 1)]; %#ok<AGROW>
    theta_ref_z = [theta_ref_z; thetaRef(3) * ones(N, 1)]; %#ok<AGROW>
end
T = table(run_id, axisCol, dirCol, t, gx, gy, gz, idx_ss, theta_ref_x, theta_ref_y, theta_ref_z, ...
    'VariableNames', {'run_id', 'axis', 'dir', 't', 'gx', 'gy', 'gz', 'idx_ss', ...
                      'theta_ref_x', 'theta_ref_y', 'theta_ref_z'});
writetable(T, filePath);
end

function write_gsens_runs_csv(gsensRuns, filePath)
run_id = [];
t = [];
gx = [];
gy = [];
gz = [];
acc_ref_x = [];
acc_ref_y = [];
acc_ref_z = [];
omega_ref_x = [];
omega_ref_y = [];
omega_ref_z = [];
hasOmega = false;

for i = 1:numel(gsensRuns)
    run = gsensRuns(i);
    N = size(run.gyro, 1);
    run_id = [run_id; i * ones(N, 1)]; %#ok<AGROW>
    t = [t; run.t(:)]; %#ok<AGROW>
    gx = [gx; run.gyro(:, 1)]; %#ok<AGROW>
    gy = [gy; run.gyro(:, 2)]; %#ok<AGROW>
    gz = [gz; run.gyro(:, 3)]; %#ok<AGROW>
    acc_ref_x = [acc_ref_x; run.acc_ref(:, 1)]; %#ok<AGROW>
    acc_ref_y = [acc_ref_y; run.acc_ref(:, 2)]; %#ok<AGROW>
    acc_ref_z = [acc_ref_z; run.acc_ref(:, 3)]; %#ok<AGROW>
    if isfield(run, 'omega_ref') && ~isempty(run.omega_ref)
        hasOmega = true;
        omega_ref_x = [omega_ref_x; run.omega_ref(:, 1)]; %#ok<AGROW>
        omega_ref_y = [omega_ref_y; run.omega_ref(:, 2)]; %#ok<AGROW>
        omega_ref_z = [omega_ref_z; run.omega_ref(:, 3)]; %#ok<AGROW>
    end
end

T = table(run_id, t, gx, gy, gz, acc_ref_x, acc_ref_y, acc_ref_z, ...
    'VariableNames', {'run_id', 't', 'gx', 'gy', 'gz', 'acc_ref_x', 'acc_ref_y', 'acc_ref_z'});
if hasOmega
    T.omega_ref_x = omega_ref_x;
    T.omega_ref_y = omega_ref_y;
    T.omega_ref_z = omega_ref_z;
end
writetable(T, filePath);
end

function value = getfield_any(S, names, defaultValue)
value = defaultValue;
if ~isstruct(S)
    return;
end
for i = 1:numel(names)
    if isfield(S, names{i})
        value = S.(names{i});
        return;
    end
end
end
