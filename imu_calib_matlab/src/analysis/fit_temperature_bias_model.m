function model = fit_temperature_bias_model(staticGyro, temp, varargin)
%FIT_TEMPERATURE_BIAS_MODEL Backward-compatible wrapper for gyro bg(T).
% Usage:
%   model = fit_temperature_bias_model(staticGyro, temp)

model = fit_gyro_temperature_bias_model( ...
    'static_gyro', staticGyro, ...
    'temp', temp, ...
    varargin{:});
end
