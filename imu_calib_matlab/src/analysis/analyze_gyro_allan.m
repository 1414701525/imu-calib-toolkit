function allan = analyze_gyro_allan(t, gyro, varargin)
%ANALYZE_GYRO_ALLAN Compute a basic Allan deviation estimate for gyro data.
% Usage:
%   allan = analyze_gyro_allan(t, gyro)

allan = analyze_allan_common(t, gyro, 'gyro', varargin{:});
end
