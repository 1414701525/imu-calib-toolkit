function model = fit_accel_temperature_bias_model(varargin)
%FIT_ACCEL_TEMPERATURE_BIAS_MODEL Fit ba(T) with fixed Ca.

combined = fit_temperature_bias_models(varargin{:}, 'fit_gyro', false, 'fit_acc', true);
model = combined.acc;
end
