function corrected = apply_imu_calibration(raw, calib, varargin)
%APPLY_IMU_CALIBRATION Apply inverse IMU calibration using the current model.
%
% Runtime compensation:
%   a_corr = Ca * (a_raw - ba(T))
%   omega_ref_hat = Cg \ (omega_m - bg(T) - Gg * f_term)

if nargin < 2
    error('apply_imu_calibration:InvalidInput', ...
        'raw and calib are required.');
end

validate_raw(raw);
validate_calib(calib);
opts = parse_options(varargin{:});

gyro = double(raw.gyro);
acc = double(raw.acc);
bg = ensure_vector3(calib.bg, 'calib.bg').';
ba = ensure_vector3(calib.ba, 'calib.ba').';
Ca = double(calib.Ca);
Cg = double(calib.Cg);
hasGg = isfield(calib, 'Gg') && ~isempty(calib.Gg);
if hasGg
    Gg = double(calib.Gg);
else
    Gg = zeros(3, 3);
end

tempVector = [];
if isfield(raw, 'temp') && ~isempty(raw.temp)
    tempVector = double(raw.temp(:));
    if numel(tempVector) ~= size(gyro, 1)
        error('apply_imu_calibration:TemperatureLengthMismatch', ...
            'raw.temp length must match raw.gyro sample count.');
    end
end

tempBlock = struct();
if isfield(calib, 'temp') && isstruct(calib.temp)
    tempBlock = calib.temp;
end
bgModel = getfield_any(tempBlock, {'bg_model', 'bgModel'}, struct());
baModel = getfield_any(tempBlock, {'ba_model', 'baModel'}, struct());

[baT, accTempInfo] = get_accel_bias_from_temperature(tempVector, ba, baModel);
if size(baT, 1) == 1 && size(acc, 1) > 1
    baT = repmat(baT, size(acc, 1), 1);
end
accBiasRemoved = acc - baT;
accCalibrated = (Ca * accBiasRemoved.').';

[bgT, gyroTempInfo] = get_gyro_bias_from_temperature(tempVector, bg, bgModel);
if size(bgT, 1) == 1 && size(gyro, 1) > 1
    bgT = repmat(bgT, size(gyro, 1), 1);
end
gyroBiasRemoved = gyro - bgT;

fTerm = accCalibrated;
gTerm = zeros(size(gyroBiasRemoved));
gsensInfo = struct('applied', false, ...
                   'message', 'Gg compensation disabled or unavailable.');
if opts.options.gsens.enabled && hasGg
    gTerm = (Gg * fTerm.').';
    gsensInfo.applied = true;
    gsensInfo.message = 'Applied Gg compensation using calibrated accelerometer as f_term.';
end

gyroModelRemoved = gyroBiasRemoved - gTerm;
gyroCalibrated = (Cg \ gyroModelRemoved.').';

corrected = struct();
corrected.raw = raw;
corrected.acc = accCalibrated;
corrected.gyro = gyroCalibrated;
corrected.bias_removed_gyro = gyroBiasRemoved;
corrected.gsens_removed_gyro = gyroModelRemoved;
corrected.bgT = bgT;
corrected.baT = baT;
corrected.f_term = fTerm;
corrected.g_term = gTerm;
corrected.model = struct();
corrected.model.forward_gyro = opts.options.model.forward_gyro;
corrected.model.inverse_gyro = opts.options.model.inverse_gyro;
corrected.model.forward_acc = opts.options.model.forward_acc;
corrected.model.inverse_acc = opts.options.model.inverse_acc;
corrected.model.gsens_term = opts.options.model.gsens_term;
corrected.info = struct();
corrected.info.temperature = struct('gyro', gyroTempInfo, 'acc', accTempInfo);
corrected.info.gsens = gsensInfo;
corrected.info.notes = ['Accelerometer compensation uses Ca * (a_raw - ba(T)); ' ...
    'gyro compensation uses Cg \\ (omega_m - bg(T) - Gg * f_term).'];
end

function validate_raw(raw)
required = {'gyro', 'acc'};
for i = 1:numel(required)
    if ~isfield(raw, required{i})
        error('apply_imu_calibration:MissingRawField', ...
            'raw is missing required field "%s".', required{i});
    end
end

validateattributes(raw.gyro, {'numeric'}, {'2d', 'ncols', 3, 'nonempty', 'finite'}, ...
    mfilename, 'raw.gyro');
validateattributes(raw.acc, {'numeric'}, {'2d', 'ncols', 3, 'nonempty', 'finite'}, ...
    mfilename, 'raw.acc');
if size(raw.gyro, 1) ~= size(raw.acc, 1)
    error('apply_imu_calibration:LengthMismatch', ...
        'raw.gyro and raw.acc must have the same number of samples.');
end
if isfield(raw, 'temp') && ~isempty(raw.temp)
    validateattributes(raw.temp, {'numeric'}, {'column', 'finite', 'numel', size(raw.gyro, 1)}, ...
        mfilename, 'raw.temp');
end
end

function validate_calib(calib)
required = {'bg', 'Ca', 'ba', 'Cg'};
for i = 1:numel(required)
    if ~isfield(calib, required{i})
        error('apply_imu_calibration:MissingCalibField', ...
            'calib is missing required field "%s".', required{i});
    end
end

validateattributes(calib.bg, {'numeric'}, {'vector', 'numel', 3, 'finite'}, mfilename, 'calib.bg');
validateattributes(calib.ba, {'numeric'}, {'vector', 'numel', 3, 'finite'}, mfilename, 'calib.ba');
validateattributes(calib.Ca, {'numeric'}, {'size', [3, 3], 'finite'}, mfilename, 'calib.Ca');
validateattributes(calib.Cg, {'numeric'}, {'size', [3, 3], 'finite'}, mfilename, 'calib.Cg');
if rcond(calib.Ca) < 1e-12
    error('apply_imu_calibration:IllConditionedCa', ...
        'calib.Ca is numerically singular or nearly singular.');
end
if rcond(calib.Cg) < 1e-12
    error('apply_imu_calibration:IllConditionedCg', ...
        'calib.Cg is numerically singular or nearly singular.');
end
end

function opts = parse_options(varargin)
opts = struct();
opts.options = default_calib_options();
if mod(numel(varargin), 2) ~= 0
    error('apply_imu_calibration:InvalidInput', ...
        'Optional arguments must be provided as name/value pairs.');
end
for k = 1:2:numel(varargin)
    name = lower(char(varargin{k}));
    value = varargin{k + 1};
    switch name
        case 'options'
            opts.options = value;
        otherwise
            error('apply_imu_calibration:UnknownOption', ...
                'Unknown option "%s".', char(varargin{k}));
    end
end
end

function v = ensure_vector3(v, name)
v = double(v(:));
if numel(v) ~= 3 || any(~isfinite(v))
    error('apply_imu_calibration:InvalidVector', ...
        '%s must be a finite 3x1 vector.', name);
end
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
