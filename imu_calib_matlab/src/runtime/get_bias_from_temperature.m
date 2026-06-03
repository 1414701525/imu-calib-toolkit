function [biasT, info] = get_bias_from_temperature(temp, biasConst, tempModel, varargin)
%GET_BIAS_FROM_TEMPERATURE Evaluate a temperature-dependent 3-axis bias model.
% Usage:
%   [biasT, info] = get_bias_from_temperature(temp, biasConst, tempModel)

opts = parse_options(varargin{:});
biasConst = ensure_vector3(biasConst, 'biasConst').';

if nargin < 1 || isempty(temp)
    biasT = biasConst;
    info = struct('valid', false, ...
                  'used_temperature_model', false, ...
                  'out_of_range', false, ...
                  'message', sprintf('Temperature vector not provided. Falling back to constant %s.', opts.target_name));
    return;
end

temp = double(temp(:));
if any(~isfinite(temp))
    error('get_bias_from_temperature:InvalidTemperature', ...
        'temp must contain finite numeric values.');
end

N = numel(temp);
biasT = repmat(biasConst, N, 1);
info = struct('valid', false, ...
              'used_temperature_model', false, ...
              'out_of_range', false, ...
              'message', sprintf('No valid temperature model. Falling back to constant %s.', opts.target_name));

if nargin < 3 || isempty(tempModel) || ~isstruct(tempModel)
    return;
end
if ~isfield(tempModel, 'valid') || ~tempModel.valid
    if isfield(tempModel, 'message') && ~isempty(tempModel.message)
        info.message = char(string(tempModel.message));
    end
    return;
end

[tempEval, rangeInfo] = prepare_temperature_input(temp, tempModel);
modelType = '';
if isfield(tempModel, 'type') && ~isempty(tempModel.type)
    modelType = lower(char(string(tempModel.type)));
end

switch modelType
    case 'poly'
        coeffs = [];
        if isfield(tempModel, 'coeffs') && ~isempty(tempModel.coeffs)
            coeffs = tempModel.coeffs;
        elseif isfield(tempModel, 'coeff') && isstruct(tempModel.coeff) && ...
                isfield(tempModel.coeff, 'poly_coeff')
            coeffs = tempModel.coeff.poly_coeff;
        end
        coeffs = double(coeffs);
        if size(coeffs, 2) ~= 3
            info.message = sprintf( ...
                'Temperature model coeffs must have shape [P x 3]. Falling back to constant %s.', opts.target_name);
            return;
        end
        referenceTemperature = getfield_or_default(tempModel, 'reference_temperature', 0.0);
        dT = tempEval - referenceTemperature;
        for axisIdx = 1:3
            biasT(:, axisIdx) = polyval(coeffs(:, axisIdx).', dT);
        end

    case 'piecewise_linear'
        coeff = getfield_or_default(tempModel, 'coeff', struct());
        breakpoints = getfield_or_default(tempModel, 'breakpoints', getfield_or_default(coeff, 'breakpoints', []));
        values = getfield_or_default(tempModel, 'values', getfield_or_default(coeff, 'values', []));
        breakpoints = double(breakpoints(:));
        values = double(values);
        if size(values, 2) ~= 3 || size(values, 1) ~= numel(breakpoints)
            info.message = sprintf( ...
                'Piecewise temperature model size mismatch. Falling back to constant %s.', opts.target_name);
            return;
        end
        for axisIdx = 1:3
            biasT(:, axisIdx) = interp_with_extrapolation(tempEval, breakpoints, values(:, axisIdx), tempModel);
        end

    otherwise
        info.message = sprintf( ...
            'Unsupported temperature model type "%s". Falling back to constant %s.', ...
            char(string(getfield_or_default(tempModel, 'type', ''))), opts.target_name);
        return;
end

info.valid = true;
info.used_temperature_model = true;
info.out_of_range = rangeInfo.out_of_range;
if isempty(rangeInfo.message)
    info.message = sprintf('Temperature-dependent %s(T) evaluated successfully.', opts.target_name);
else
    info.message = rangeInfo.message;
end
end

function opts = parse_options(varargin)
opts = struct('target_name', 'bias');
if mod(numel(varargin), 2) ~= 0
    error('get_bias_from_temperature:InvalidInput', ...
        'Optional arguments must be provided as name/value pairs.');
end
for k = 1:2:numel(varargin)
    name = lower(char(varargin{k}));
    value = varargin{k + 1};
    switch name
        case 'target_name'
            opts.target_name = char(string(value));
        otherwise
            error('get_bias_from_temperature:UnknownOption', ...
                'Unknown option "%s".', char(varargin{k}));
    end
end
end

function [tempEval, info] = prepare_temperature_input(temp, tempModel)
tempEval = temp;
info = struct('out_of_range', false, 'message', '');
tempRange = getfield_or_default(tempModel, 'temperature_range', [NaN; NaN]);
tempRange = double(tempRange(:));
if numel(tempRange) ~= 2 || any(~isfinite(tempRange))
    return;
end

tmin = tempRange(1);
tmax = tempRange(2);
outOfRange = any(temp < tmin | temp > tmax);
if ~outOfRange
    return;
end

mode = lower(char(string(getfield_or_default(tempModel, 'extrapolation_mode', 'warn_and_clamp'))));
switch mode
    case 'clamp'
        tempEval = min(max(temp, tmin), tmax);
        info.out_of_range = true;
        info.message = 'Input temperature was clamped to the fitted range.';
    case 'warn_and_clamp'
        tempEval = min(max(temp, tmin), tmax);
        info.out_of_range = true;
        info.message = 'Input temperature exceeded the fitted range; values were clamped.';
    case 'extrapolate'
        info.out_of_range = true;
        info.message = 'Input temperature exceeded the fitted range; model extrapolation was used.';
    otherwise
        tempEval = min(max(temp, tmin), tmax);
        info.out_of_range = true;
        info.message = sprintf('Unknown extrapolation mode "%s"; values were clamped.', mode);
end
end

function values = interp_with_extrapolation(x, xp, fp, tempModel)
mode = lower(char(string(getfield_or_default(tempModel, 'extrapolation_mode', 'warn_and_clamp'))));
if numel(xp) < 2
    values = interp1(xp, fp, x, 'linear', 'extrap');
    return;
end

if ismember(mode, {'clamp', 'warn_and_clamp'})
    values = interp1(xp, fp, x, 'linear', 'extrap');
    return;
end

values = interp1(xp, fp, x, 'linear', 'extrap');
end

function value = getfield_or_default(S, fieldName, defaultValue)
if isstruct(S) && isfield(S, fieldName)
    value = S.(fieldName);
else
    value = defaultValue;
end
end

function v = ensure_vector3(v, name)
v = double(v(:));
if numel(v) ~= 3 || any(~isfinite(v))
    error('get_bias_from_temperature:InvalidVector', ...
        '%s must be a finite 3x1 vector.', name);
end
end
