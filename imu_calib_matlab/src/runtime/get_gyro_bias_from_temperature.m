function [bgT, info] = get_gyro_bias_from_temperature(temp, bgConst, tempModel)
%GET_GYRO_BIAS_FROM_TEMPERATURE Evaluate bg(T) with constant-bias fallback.

[bgT, info] = get_bias_from_temperature(temp, bgConst, tempModel, 'target_name', 'bg');
end
