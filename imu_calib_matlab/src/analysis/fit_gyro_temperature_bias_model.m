function model = fit_gyro_temperature_bias_model(varargin)
%FIT_GYRO_TEMPERATURE_BIAS_MODEL Fit bg(T) from static gyro data.

combined = fit_temperature_bias_models(varargin{:}, 'fit_gyro', true, 'fit_acc', false);
model = combined.gyro;
end
