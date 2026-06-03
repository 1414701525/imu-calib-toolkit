function result = build_partial_validation(data, components, analysis, tempInfo)
%BUILD_PARTIAL_VALIDATION Build validation summary for partial datasets.

result = struct();
result.message = ['Partial dataset detected. Only modules with satisfied minimum inputs were run. ' ...
                  'See task results and warnings for unavailable modules.'];
result.static = struct();
staticData = getfield_or_default(data, 'static', struct());

if isfield(staticData, 'gyro') && ~isempty(staticData.gyro)
    result.static.gyro_raw_mean = mean(staticData.gyro, 1).';
    if ~isempty(getfield_or_default(components, 'bg', []))
        result.static.gyro_debiased = staticData.gyro - components.bg(:).';
        result.static.gyro_mean_after_bias = mean(result.static.gyro_debiased, 1).';
        result.static.gyro_rms_after_bias = sqrt(mean(result.static.gyro_debiased .^ 2, 1)).';
    else
        result.static.gyro_debiased = [];
        result.static.gyro_mean_after_bias = [];
        result.static.gyro_rms_after_bias = [];
    end
else
    result.static.gyro_raw_mean = [];
    result.static.gyro_debiased = [];
    result.static.gyro_mean_after_bias = [];
    result.static.gyro_rms_after_bias = [];
end

if isfield(staticData, 'acc') && ~isempty(staticData.acc)
    result.static.acc_norm_raw = sqrt(sum(staticData.acc .^ 2, 2));
else
    result.static.acc_norm_raw = [];
end
result.analysis = analysis;

summary = struct();
summary.mode = 'partial';
if isfield(staticData, 'gyro')
    summary.num_static_samples = size(staticData.gyro, 1);
else
    summary.num_static_samples = 0;
end
summary.static_gyro_mean_after_bias = result.static.gyro_mean_after_bias;
summary.static_gyro_rms_after_bias = result.static.gyro_rms_after_bias;
if isempty(result.static.acc_norm_raw)
    summary.static_acc_norm_mean = [];
    summary.static_acc_norm_std = [];
else
    summary.static_acc_norm_mean = mean(result.static.acc_norm_raw);
    summary.static_acc_norm_std = std(result.static.acc_norm_raw, 0, 1);
end
summary.gyro_std = getfield_or_default(getfield_or_default(components, 'noiseStats', ...
    getfield_or_default(components, 'noise_stats', struct())), 'gyro_std', []);
summary.acc_std = getfield_or_default(getfield_or_default(components, 'noiseStats', ...
    getfield_or_default(components, 'noise_stats', struct())), 'acc_std', []);
summary.available_blocks = getfield_or_default(getfield_or_default(data, 'meta', struct()), 'available_blocks', {});
summary.completed_modules = get_completed_modules(components, analysis, tempInfo);
summary.temperature_model_status = get_temperature_model_status(tempInfo);
summary.allan_status = get_allan_status(analysis);
result.summary = summary;
end

function modules = get_completed_modules(components, analysis, tempInfo)
modules = {};
tempStatus = get_temperature_model_status(tempInfo);
if ~isempty(getfield_or_default(components, 'bg', []))
    modules{end + 1} = 'gyro_bias'; %#ok<AGROW>
end
if ~isempty(fieldnames(getfield_or_default(components, 'noiseStats', getfield_or_default(components, 'noise_stats', struct()))))
    modules{end + 1} = 'noise_stats'; %#ok<AGROW>
end
if ~isempty(getfield_or_default(components, 'Ca', []))
    modules{end + 1} = 'acc_calibration'; %#ok<AGROW>
end
if ~isempty(getfield_or_default(components, 'Cg', []))
    modules{end + 1} = 'gyro_calibration'; %#ok<AGROW>
end
if ~isempty(getfield_or_default(components, 'Gg', []))
    modules{end + 1} = 'gsens_fit'; %#ok<AGROW>
end
if strcmp(get_allan_status(analysis), 'available')
    modules{end + 1} = 'allan_analysis'; %#ok<AGROW>
end
if ~strcmp(tempStatus, 'not_available')
    modules{end + 1} = 'temperature_fit'; %#ok<AGROW>
end
end

function status = get_temperature_model_status(tempInfo)
status = 'not_available';
if ~isstruct(tempInfo)
    return;
end

statuses = {};
bgModel = getfield_any(tempInfo, {'bgModel', 'bg_model'}, struct());
if isstruct(bgModel) && ~isempty(fieldnames(bgModel))
    if isfield(bgModel, 'valid') && bgModel.valid
        statuses{end + 1} = 'bg_model=valid'; %#ok<AGROW>
    elseif isfield(bgModel, 'low_confidence') && bgModel.low_confidence
        statuses{end + 1} = 'bg_model=low_confidence'; %#ok<AGROW>
    else
        statuses{end + 1} = 'bg_model=invalid'; %#ok<AGROW>
    end
end

baModel = getfield_any(tempInfo, {'baModel', 'ba_model'}, struct());
if isstruct(baModel) && ~isempty(fieldnames(baModel))
    if isfield(baModel, 'valid') && baModel.valid
        statuses{end + 1} = 'ba_model=valid'; %#ok<AGROW>
    elseif isfield(baModel, 'low_confidence') && baModel.low_confidence
        statuses{end + 1} = 'ba_model=low_confidence'; %#ok<AGROW>
    else
        statuses{end + 1} = 'ba_model=invalid'; %#ok<AGROW>
    end
end

if ~isempty(statuses)
    status = strjoin(statuses, ', ');
end
end

function status = get_allan_status(analysis)
status = 'not_available';
if isstruct(analysis) && isfield(analysis, 'allan')
    allan = analysis.allan;
    subfields = fieldnames(allan);
    for i = 1:numel(subfields)
        block = allan.(subfields{i});
        if isstruct(block) && isfield(block, 'valid')
            if block.valid
                status = 'available';
                return;
            else
                status = 'invalid_or_short_data';
            end
        end
    end
end
end
