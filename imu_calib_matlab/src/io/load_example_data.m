function [data, truth, meta] = load_example_data(varargin)
%LOAD_EXAMPLE_DATA Load or generate deterministic synthetic IMU calibration data.

opts = parse_options(varargin{:});
projectRoot = fileparts(fileparts(mfilename('fullpath')));
matPath = fullfile(projectRoot, 'data', 'example_dataset.mat');

if exist(matPath, 'file') && ~opts.forceRegenerate
    try
        S = load(matPath, 'data', 'truth', 'meta');
        data = S.data;
        truth = S.truth;
        meta = S.meta;
        return;
    catch
    end
end

[data, truth, meta] = generate_synthetic_dataset();
meta.mat_path = matPath;

if opts.saveToMat
    try
        save(matPath, 'data', 'truth', 'meta');
    catch ME
        warning('load_example_data:SaveFailed', ...
            'Could not save example_dataset.mat: %s', ME.message);
    end
end
end

function opts = parse_options(varargin)
opts.forceRegenerate = false;
opts.saveToMat = true;
if mod(numel(varargin), 2) ~= 0
    error('load_example_data:InvalidInput', ...
        'Optional arguments must be provided as name/value pairs.');
end
for k = 1:2:numel(varargin)
    name = lower(char(varargin{k}));
    value = varargin{k + 1};
    switch name
        case 'forceregenerate'
            opts.forceRegenerate = logical(value);
        case 'savetomat'
            opts.saveToMat = logical(value);
        otherwise
            error('load_example_data:UnknownOption', ...
                'Unknown option "%s".', char(varargin{k}));
    end
end
end

function [data, truth, meta] = generate_synthetic_dataset()
prevRngState = rng;
rngCleanup = onCleanup(@() rng(prevRngState)); %#ok<NASGU>
rng(42, 'twister');

g0 = 9.80665;
truth = struct();
truth.g0 = g0;
truth.Sa_true = diag([1.0120, 0.9930, 1.0080]);
truth.Ma_true = [1.0, 0.0120, -0.0080; ...
                 0.0, 1.0,  0.0110; ...
                 0.0, 0.0,  1.0];
truth.Ca_true = truth.Sa_true * truth.Ma_true;
truth.ba_true = [0.0800; -0.0500; 0.1200];

truth.Kg_true = diag([0.0120, -0.0090, 0.0070]);
truth.Mg_true = [0.0000,  0.0040, -0.0030; ...
                -0.0020,  0.0000,  0.0050; ...
                 0.0030, -0.0040,  0.0000];
truth.Cg_true = eye(3) + truth.Kg_true + truth.Mg_true;
truth.bg_true = [0.0080; -0.0060; 0.0040];
truth.Gg_true = zeros(3);

noise = struct();
noise.gyro_std = [0.0012; 0.0014; 0.0011];
noise.acc_std = [0.0300; 0.0280; 0.0320];
truth.noise = noise;

data = struct();
data.static = generate_static_segment(truth);
data.accPoses = generate_acc_poses(truth);
data.acc_poses = data.accPoses;
data.gyroRuns = generate_gyro_runs(truth);
data.gyro_runs = data.gyroRuns;
data.gsensRuns = empty_gsens_runs();
data.gsens_runs = data.gsensRuns;

meta = struct();
meta.source = 'synthetic';
meta.generated_at = datestr(now, 30);
meta.rng_seed = 42;
meta.description = 'Deterministic synthetic IMU calibration dataset.';
meta.num_acc_poses = numel(data.accPoses);
meta.num_gyro_runs = numel(data.gyroRuns);
meta.mat_path = '';
end

function staticData = generate_static_segment(truth)
fs = 100;
duration = 60;
N = fs * duration;
t = (0:N-1).' / fs;

aCorr = [0; 0; truth.g0];
gyroMean = repmat(truth.bg_true.', N, 1);
rawAccMean = truth.Ca_true \ aCorr;
accMean = repmat((rawAccMean + truth.ba_true).', N, 1);

gyro = gyroMean + randn(N, 3) .* repmat(truth.noise.gyro_std.', N, 1);
acc = accMean + randn(N, 3) .* repmat(truth.noise.acc_std.', N, 1);
temp = 25 + 0.15 * sin(2 * pi * 0.01 * t);

staticData = struct();
staticData.t = t;
staticData.gyro = gyro;
staticData.acc = acc;
staticData.temp = temp;
end

function accPoses = generate_acc_poses(truth)
dirs = [ ...
     1,  0,  0;
    -1,  0,  0;
     0,  1,  0;
     0, -1,  0;
     0,  0,  1;
     0,  0, -1;
     1,  1,  1;
     1, -1,  1;
    -1,  1,  1;
    -1, -1,  1;
     1,  1, -1;
    -1,  1, -1];

names = { ...
    '+X', '-X', '+Y', '-Y', '+Z', '-Z', ...
    'diag_111', 'diag_1m11', 'diag_m111', 'diag_mm11', ...
    'diag_11m1', 'diag_m11m1'};

numPoses = size(dirs, 1);
accPoses = repmat(struct('acc_mean', zeros(3, 1), ...
                         'a_ref', [], ...
                         'pose_name', ''), numPoses, 1);

for i = 1:numPoses
    unitDir = dirs(i, :).';
    unitDir = unitDir / norm(unitDir);
    aCorr = truth.g0 * unitDir;
    rawAccMean = truth.Ca_true \ aCorr;
    accMean = rawAccMean + truth.ba_true + 0.008 * randn(3, 1);

    accPoses(i).acc_mean = accMean;
    accPoses(i).a_ref = [];
    accPoses(i).pose_name = names{i};
end
end

function gyroRuns = generate_gyro_runs(truth)
fs = 200;
rampTime = 0.5;
configs = [ ...
    0.70, 3.0;
    1.05, 2.2];
axesList = 'xyz';
dirs = [1, -1];

numRuns = numel(axesList) * numel(dirs) * size(configs, 1);
gyroRuns = repmat(struct('axis', 'x', ...
                         'dir', 1, ...
                         'gyro', zeros(0, 3), ...
                         't', zeros(0, 1), ...
                         'theta_ref', zeros(3, 1), ...
                         'idx_ss', false(0, 1)), numRuns, 1);

runIdx = 1;
for a = 1:numel(axesList)
    axisName = axesList(a);
    e = zeros(3, 1);
    e(a) = 1;
    for d = 1:numel(dirs)
        dirSign = dirs(d);
        for c = 1:size(configs, 1)
            rate = configs(c, 1);
            steadyTime = configs(c, 2);

            nRamp = round(rampTime * fs);
            nSteady = round(steadyTime * fs);
            omegaScalar = [linspace(0, dirSign * rate, nRamp), ...
                           dirSign * rate * ones(1, nSteady), ...
                           linspace(dirSign * rate, 0, nRamp)].';
            N = numel(omegaScalar);
            t = (0:N-1).' / fs;

            omegaRef = omegaScalar * e.';
            gyroIdeal = (truth.Cg_true * omegaRef.').';
            gyro = gyroIdeal + repmat(truth.bg_true.', N, 1) + ...
                randn(N, 3) .* repmat(truth.noise.gyro_std.', N, 1);

            idx_ss = false(N, 1);
            idx_ss((nRamp + 1):(nRamp + nSteady)) = true;
            theta_ref = e * (dirSign * rate * steadyTime);

            gyroRuns(runIdx).axis = axisName;
            gyroRuns(runIdx).dir = dirSign;
            gyroRuns(runIdx).gyro = gyro;
            gyroRuns(runIdx).t = t;
            gyroRuns(runIdx).theta_ref = theta_ref;
            gyroRuns(runIdx).idx_ss = idx_ss;
            runIdx = runIdx + 1;
        end
    end
end
end

function gsensRuns = empty_gsens_runs()
gsensRuns = repmat(struct('gyro', zeros(0, 3), ...
                          'acc_ref', zeros(0, 3), ...
                          'omega_ref', zeros(0, 3), ...
                          't', zeros(0, 1)), 0, 1);
end
