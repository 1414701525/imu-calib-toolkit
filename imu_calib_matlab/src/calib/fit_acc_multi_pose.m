function [Ca, ba, info] = fit_acc_multi_pose(accPoses, varargin)
%FIT_ACC_MULTI_POSE Fit accelerometer Ca / ba using gravity-norm constraints.
% Usage:
%   [Ca, ba, info] = fit_acc_multi_pose(accPoses)
%   [Ca, ba, info] = fit_acc_multi_pose(accPoses, 'options', options)
%   [Ca, ba, info] = fit_acc_multi_pose(accPoses, 'gravity_magnitude', 9.80665)
%
% New model:
%   a_corr = Ca * (a_raw - ba)
% with static multi-pose constraint:
%   ||a_corr|| = g

if nargin < 1 || isempty(accPoses)
    error('fit_acc_multi_pose:EmptyInput', 'accPoses must not be empty.');
end

opts = parse_options(varargin{:});
accOpts = opts.options.acc_calibration;
g = opts.gravity_magnitude;
if isempty(g)
    g = accOpts.gravity_magnitude;
end
if ~isscalar(g) || ~isfinite(g) || g <= 0
    error('fit_acc_multi_pose:InvalidGravity', ...
        'gravity_magnitude must be a positive finite scalar.');
end

numPoses = numel(accPoses);
rawMeans = zeros(numPoses, 3);
hasLegacyRefs = false;
for i = 1:numPoses
    rawMeans(i, :) = ensure_vector3(get_struct_field(accPoses(i), 'acc_mean', []), ...
        sprintf('accPoses(%d).acc_mean', i)).';
    if isfield(accPoses(i), 'a_ref') && ~isempty(accPoses(i).a_ref)
        hasLegacyRefs = true;
    end
end

[parameterization, warningsList] = resolve_parameterization(numPoses, accOpts);
[theta0, initInfo] = build_initial_guess(accPoses, rawMeans, g, parameterization, accOpts);
[theta, solverInfo] = solve_problem(theta0, rawMeans, g, parameterization, accOpts);
[ba, Ca, Sa, Ma] = unpack_parameters(theta, parameterization);

caRcond = rcond(Ca);
if ~isfinite(caRcond) || caRcond < 1e-12
    error('fit_acc_multi_pose:IllConditionedCa', ...
        'Estimated Ca is numerically singular or nearly singular (rcond = %.3e).', caRcond);
elseif caRcond < 1e-8
    warning('fit_acc_multi_pose:PoorConditionCa', ...
        'Estimated Ca is poorly conditioned (rcond = %.3e). Results may be unstable.', caRcond);
end

corrected = (Ca * (rawMeans - ba.').').';
rawNorms = vecnorm(rawMeans, 2, 2);
correctedNorms = vecnorm(corrected, 2, 2);
normErrorBefore = rawNorms - g;
normErrorAfter = correctedNorms - g;
residualVector = normErrorAfter;

poseMetrics = repmat(struct('pose_name', '', ...
                            'raw_mean', zeros(3, 1), ...
                            'corrected_mean', zeros(3, 1), ...
                            'raw_norm', 0, ...
                            'corrected_norm', 0, ...
                            'norm_error_before', 0, ...
                            'norm_error_after', 0, ...
                            'legacy_reference_available', false), numPoses, 1);
for i = 1:numPoses
    poseMetrics(i).pose_name = get_pose_name(accPoses(i), i);
    poseMetrics(i).raw_mean = rawMeans(i, :).';
    poseMetrics(i).corrected_mean = corrected(i, :).';
    poseMetrics(i).raw_norm = rawNorms(i);
    poseMetrics(i).corrected_norm = correctedNorms(i);
    poseMetrics(i).norm_error_before = normErrorBefore(i);
    poseMetrics(i).norm_error_after = normErrorAfter(i);
    poseMetrics(i).legacy_reference_available = isfield(accPoses(i), 'a_ref') && ~isempty(accPoses(i).a_ref);
end

info = struct();
info.method = 'static_multi_pose_gravity_constraint';
info.parameterization = parameterization;
info.num_poses = numPoses;
info.gravity_magnitude = g;
info.optimizer_success = solverInfo.success;
info.optimizer_status = solverInfo.status;
info.optimizer_message = solverInfo.message;
info.num_function_evals = solverInfo.nfev;
info.final_cost = solverInfo.cost;
info.optimality = solverInfo.optimality;
info.Ca_rcond = caRcond;
info.Sa = Sa;
info.Ma = Ma;
info.residual_vector = residualVector;
info.residual_rms = sqrt(mean(residualVector .^ 2));
info.max_abs_residual = max(abs(residualVector));
info.raw_norm_mean = mean(rawNorms);
info.raw_norm_std = std(rawNorms, 0, 1);
info.corrected_norm_mean = mean(correctedNorms);
info.corrected_norm_std = std(correctedNorms, 0, 1);
info.norm_error_mean_before = mean(abs(normErrorBefore));
info.norm_error_std_before = std(abs(normErrorBefore), 0, 1);
info.norm_error_max_before = max(abs(normErrorBefore));
info.norm_error_mean_after = mean(abs(normErrorAfter));
info.norm_error_std_after = std(abs(normErrorAfter), 0, 1);
info.norm_error_max_after = max(abs(normErrorAfter));
info.poseMetrics = poseMetrics;
info.initialization = initInfo;
info.warnings = warningsList;
info.legacy_reference_available = hasLegacyRefs;
end

function opts = parse_options(varargin)
opts = struct();
opts.options = default_calib_options();
opts.gravity_magnitude = [];

if mod(numel(varargin), 2) ~= 0
    error('fit_acc_multi_pose:InvalidInput', ...
        'Optional arguments must be provided as name/value pairs.');
end

for k = 1:2:numel(varargin)
    name = lower(char(varargin{k}));
    value = varargin{k + 1};
    switch name
        case 'options'
            if ~isstruct(value)
                error('fit_acc_multi_pose:InvalidOptions', ...
                    'options must be a struct.');
            end
            opts.options = value;
        case 'gravity_magnitude'
            opts.gravity_magnitude = double(value);
        otherwise
            error('fit_acc_multi_pose:UnknownOption', ...
                'Unknown option "%s".', char(varargin{k}));
    end
end
end

function [parameterization, warningsList] = resolve_parameterization(numPoses, accOpts)
warningsList = {};
requested = char(string(accOpts.parameterization));
minFull = double(accOpts.min_pose_count_full);
minDiag = double(accOpts.min_pose_count_diag_only);

if strcmpi(requested, 'diag_only')
    if numPoses < minDiag
        error('fit_acc_multi_pose:TooFewPoses', ...
            'At least %d static pose means are required for diag_only accelerometer calibration.', minDiag);
    end
    parameterization = 'diag_only';
    return;
end

if ~strcmpi(requested, 'scale_misalignment')
    error('fit_acc_multi_pose:UnsupportedParameterization', ...
        'Unsupported accelerometer parameterization "%s".', requested);
end

if numPoses >= minFull
    parameterization = 'scale_misalignment';
    return;
end

if logical(accOpts.fallback_to_diag_only) && numPoses >= minDiag
    parameterization = 'diag_only';
    warningsList{end + 1} = ...
        'Not enough pose means for full scale+misalignment fit; automatically fell back to diag_only.'; %#ok<AGROW>
    return;
end

error('fit_acc_multi_pose:TooFewPoses', ...
    'At least %d static pose means are required for scale_misalignment accelerometer calibration.', minFull);
end

function [theta0, initInfo] = build_initial_guess(accPoses, rawMeans, gravityMagnitude, parameterization, accOpts)
initInfo = struct();
initInfo.source = 'range_based';
initInfo.legacy_reference_init_used = false;
initInfo.legacy_reference_available = false;

b0 = 0.5 * (max(rawMeans, [], 1) + min(rawMeans, [], 1));
halfRange = 0.5 * (max(rawMeans, [], 1) - min(rawMeans, [], 1));
halfRange = max(halfRange, 1e-3);
s0 = gravityMagnitude ./ halfRange;
m0 = zeros(1, 3);

legacyRefs = false(numel(accPoses), 1);
for i = 1:numel(accPoses)
    legacyRefs(i) = isfield(accPoses(i), 'a_ref') && ~isempty(accPoses(i).a_ref);
end
if all(legacyRefs) && logical(accOpts.use_legacy_reference_init)
    legacy = legacy_reference_initial_guess(accPoses);
    if ~isempty(legacy)
        b0 = legacy.ba(:).';
        s0 = legacy.s0(:).';
        m0 = legacy.m0(:).';
        initInfo.source = 'legacy_reference_linear_init';
        initInfo.legacy_reference_init_used = true;
        initInfo.legacy_reference_available = true;
    end
elseif any(legacyRefs)
    initInfo.legacy_reference_available = true;
end

logS0 = log(max(s0, 1e-6));
if strcmp(parameterization, 'diag_only')
    theta0 = [b0, logS0];
else
    theta0 = [b0, logS0, atanh(max(min(m0 / 0.5, 0.999999), -0.999999))];
end
theta0 = theta0(:);
end

function legacy = legacy_reference_initial_guess(accPoses)
legacy = [];
numPoses = numel(accPoses);
A = zeros(3 * numPoses, 12);
y = zeros(3 * numPoses, 1);

for i = 1:numPoses
    if ~isfield(accPoses(i), 'a_ref') || isempty(accPoses(i).a_ref)
        return;
    end
    accMean = ensure_vector3(accPoses(i).acc_mean, sprintf('accPoses(%d).acc_mean', i));
    aRef = ensure_vector3(accPoses(i).a_ref, sprintf('accPoses(%d).a_ref', i));
    rows = (3 * (i - 1) + 1):(3 * i);
    A(rows, :) = [kron(aRef.', eye(3)), eye(3)];
    y(rows) = accMean;
end

if rank(A) < 12
    return;
end

x = A \ y;
CaForward = reshape(x(1:9), 3, 3);
ba = x(10:12);
if any(~isfinite(CaForward(:))) || any(~isfinite(ba))
    return;
end

Cinit = CaForward \ eye(3);
diagVals = diag(Cinit);
diagVals(abs(diagVals) < 1e-6) = 1e-6;
s0 = abs(diagVals);
m0 = [Cinit(1, 2) / s0(1); ...
      Cinit(1, 3) / s0(1); ...
      Cinit(2, 3) / s0(2)];
legacy = struct('ba', ba, 's0', s0, 'm0', m0);
end

function [theta, solverInfo] = solve_problem(theta0, rawMeans, gravityMagnitude, parameterization, accOpts)
residualFun = @(thetaVec) residual_vector(thetaVec, rawMeans, gravityMagnitude, parameterization);

if exist('lsqnonlin', 'file') == 2
    lsqOpts = optimoptions('lsqnonlin', ...
        'Display', 'off', ...
        'FunctionTolerance', double(accOpts.ftol), ...
        'StepTolerance', double(accOpts.xtol), ...
        'OptimalityTolerance', double(accOpts.gtol), ...
        'MaxFunctionEvaluations', double(accOpts.max_nfev));
    [theta, residual, resnorm, exitflag, output] = lsqnonlin(residualFun, theta0, [], [], lsqOpts); %#ok<ASGLU>
    solverInfo = struct();
    solverInfo.success = exitflag > 0;
    solverInfo.status = exitflag;
    solverInfo.message = char(string(output.message));
    solverInfo.nfev = get_struct_field(output, 'funcCount', NaN);
    solverInfo.cost = 0.5 * sum(residual .^ 2);
    solverInfo.optimality = get_struct_field(output, 'firstorderopt', NaN);
    return;
end

objective = @(thetaVec) sum(residualFun(thetaVec) .^ 2);
fmOpts = optimset('Display', 'off', ...
    'TolX', double(accOpts.xtol), ...
    'TolFun', double(accOpts.ftol), ...
    'MaxIter', double(accOpts.max_nfev), ...
    'MaxFunEvals', double(accOpts.max_nfev));
[theta, fval, exitflag, output] = fminsearch(objective, theta0, fmOpts); %#ok<ASGLU>
solverInfo = struct();
solverInfo.success = exitflag > 0;
solverInfo.status = exitflag;
solverInfo.message = char(string(output.message));
solverInfo.nfev = get_struct_field(output, 'funcCount', NaN);
solverInfo.cost = 0.5 * fval;
solverInfo.optimality = NaN;
end

function r = residual_vector(theta, rawMeans, gravityMagnitude, parameterization)
[b, C] = unpack_parameters(theta, parameterization);
corrected = (C * (rawMeans - b.').').';
r = vecnorm(corrected, 2, 2) - gravityMagnitude;
end

function [ba, Ca, Sa, Ma] = unpack_parameters(theta, parameterization)
theta = theta(:);
ba = theta(1:3);
scales = exp(theta(4:6));
Sa = diag(scales);
Ma = eye(3);
if strcmp(parameterization, 'scale_misalignment')
    m = 0.5 * tanh(theta(7:9));
    Ma(1, 2) = m(1);
    Ma(1, 3) = m(2);
    Ma(2, 3) = m(3);
elseif ~strcmp(parameterization, 'diag_only')
    error('fit_acc_multi_pose:UnsupportedParameterization', ...
        'Unsupported accelerometer parameterization "%s".', parameterization);
end
Ca = Sa * Ma;
end

function value = get_struct_field(S, fieldName, defaultValue)
if isstruct(S) && isfield(S, fieldName)
    value = S.(fieldName);
else
    value = defaultValue;
end
end

function v = ensure_vector3(value, valueName)
v = double(value(:));
if numel(v) ~= 3 || any(~isfinite(v))
    error('fit_acc_multi_pose:InvalidVector', ...
        '%s must be a finite 3x1 vector.', valueName);
end
end

function poseName = get_pose_name(pose, idx)
if isfield(pose, 'pose_name') && ~isempty(pose.pose_name)
    poseName = char(string(pose.pose_name));
else
    poseName = sprintf('pose_%02d', idx);
end
end
