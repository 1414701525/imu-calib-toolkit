function [baT, info] = get_accel_bias_from_temperature(temp, baConst, tempModel)
%GET_ACCEL_BIAS_FROM_TEMPERATURE Evaluate ba(T) with constant-bias fallback.

[baT, info] = get_bias_from_temperature(temp, baConst, tempModel, 'target_name', 'ba');
end
