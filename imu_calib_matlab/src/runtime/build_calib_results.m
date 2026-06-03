function results = build_calib_results(data, components, varargin)
%BUILD_CALIB_RESULTS Assemble a unified calibration results struct.

if nargin < 2 || ~isstruct(components)
    error('build_calib_results:InvalidInput', ...
        'components must be provided as a struct.');
end

opts = parse_options(varargin{:});
accInfo = getfield_or_default(components, 'accInfo', getfield_or_default(components, 'acc_info', struct()));
gravityMagnitude = getfield_or_default(components, 'gravity_magnitude', []);
if isempty(gravityMagnitude) && isstruct(accInfo) && isfield(accInfo, 'gravity_magnitude')
    gravityMagnitude = accInfo.gravity_magnitude;
end

results = struct();
results.data = data;
results.options = opts.options;

results.model = struct();
results.model.forward = struct('acc', opts.options.model.forward_acc, 'gyr', opts.options.model.forward_gyro);
results.model.inverse = struct('acc', opts.options.model.inverse_acc, 'gyr', opts.options.model.inverse_gyro);
results.model.gsens_term = opts.options.model.gsens_term;
results.model.gsens_definition = opts.options.model.gsens_definition;
results.model.notes = opts.options.model.notes;

results.calib = struct();
results.calib.bg = getfield_or_default(components, 'bg', []);
results.calib.noiseStats = getfield_or_default(components, 'noiseStats', getfield_or_default(components, 'noise_stats', struct()));
results.calib.noise_stats = results.calib.noiseStats;

results.calib.acc = struct();
results.calib.acc.Ca = getfield_or_default(components, 'Ca', []);
results.calib.acc.ba = getfield_or_default(components, 'ba', []);
results.calib.acc.Sa = getfield_or_default(components, 'Sa', []);
results.calib.acc.Ma = getfield_or_default(components, 'Ma', []);
results.calib.acc.gravity_magnitude = gravityMagnitude;
results.calib.acc.info = accInfo;

results.calib.gyr = struct();
results.calib.gyr.Cg = getfield_or_default(components, 'Cg', []);
results.calib.gyr.Kg = getfield_or_default(components, 'Kg', []);
results.calib.gyr.Mg = getfield_or_default(components, 'Mg', []);
results.calib.gyr.Gg = getfield_or_default(components, 'Gg', []);
results.calib.gyr.biasInfo = getfield_or_default(components, 'biasInfo', getfield_or_default(components, 'bias_info', struct()));
results.calib.gyr.bias_info = results.calib.gyr.biasInfo;
results.calib.gyr.fitInfo = getfield_or_default(components, 'gyroInfo', getfield_or_default(components, 'gyro_info', struct()));
results.calib.gyr.fit_info = results.calib.gyr.fitInfo;
results.calib.gyr.gsensInfo = getfield_or_default(components, 'gsensInfo', getfield_or_default(components, 'gsens_info', struct()));
results.calib.gyr.gsens_info = results.calib.gyr.gsensInfo;

results.calib.temp = struct();
results.calib.temp.bgModel = getfield_or_default(components, 'tempBgModel', getfield_or_default(components, 'temp_bg_model', struct()));
results.calib.temp.baModel = getfield_or_default(components, 'tempBaModel', getfield_or_default(components, 'temp_ba_model', struct()));
results.calib.temp.bg_model = results.calib.temp.bgModel;
results.calib.temp.ba_model = results.calib.temp.baModel;
results.calib.temp.modelFile = getfield_or_default(components, 'temperatureModel', getfield_or_default(components, 'temperature_model', struct()));
results.calib.temp.model_file = results.calib.temp.modelFile;
results.calib.temp.message = getfield_or_default(components, 'tempMessage', getfield_or_default(components, 'temp_message', 'Temperature model not evaluated yet.'));
results.calib.temp.bias_at_temperature = [];

results.analysis = getfield_or_default(components, 'analysis', struct());
results.validation = getfield_or_default(components, 'validation', struct());
results.meta = getfield_or_default(components, 'meta', struct());
results.truth = getfield_or_default(components, 'truth', []);

results.compat = struct();
results.compat.flatCalib = struct();
results.compat.flatCalib.bg = results.calib.bg;
results.compat.flatCalib.noise = results.calib.noiseStats;
results.compat.flatCalib.noise_stats = results.calib.noiseStats;
results.compat.flatCalib.Ca = results.calib.acc.Ca;
results.compat.flatCalib.ba = results.calib.acc.ba;
results.compat.flatCalib.Sa = results.calib.acc.Sa;
results.compat.flatCalib.Ma = results.calib.acc.Ma;
results.compat.flatCalib.gravity_magnitude = results.calib.acc.gravity_magnitude;
results.compat.flatCalib.Cg = results.calib.gyr.Cg;
results.compat.flatCalib.Kg = results.calib.gyr.Kg;
results.compat.flatCalib.Mg = results.calib.gyr.Mg;
results.compat.flatCalib.Gg = results.calib.gyr.Gg;
results.compat.flatCalib.temp = results.calib.temp;
results.compat.flatCalib.accInfo = results.calib.acc.info;
results.compat.flatCalib.acc_info = results.calib.acc.info;
results.compat.flatCalib.gyroInfo = results.calib.gyr.fitInfo;
results.compat.flatCalib.gyro_info = results.calib.gyr.fitInfo;
results.compat.flatCalib.gsensInfo = results.calib.gyr.gsensInfo;
results.compat.flatCalib.gsens_info = results.calib.gyr.gsensInfo;
results.compat.flatCalib.meta = results.meta;
end

function opts = parse_options(varargin)
opts = struct();
opts.options = default_calib_options();
if mod(numel(varargin), 2) ~= 0
    error('build_calib_results:InvalidInput', ...
        'Optional arguments must be provided as name/value pairs.');
end
for k = 1:2:numel(varargin)
    name = lower(char(varargin{k}));
    value = varargin{k + 1};
    switch name
        case 'options'
            opts.options = value;
        otherwise
            error('build_calib_results:UnknownOption', ...
                'Unknown option "%s".', char(varargin{k}));
    end
end
end
