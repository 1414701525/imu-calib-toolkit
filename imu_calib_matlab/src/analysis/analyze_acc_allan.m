function allan = analyze_acc_allan(t, acc, varargin)
%ANALYZE_ACC_ALLAN Compute a basic Allan deviation estimate for accelerometer data.
% Usage:
%   allan = analyze_acc_allan(t, acc)

allan = analyze_allan_common(t, acc, 'acc', varargin{:});
end
