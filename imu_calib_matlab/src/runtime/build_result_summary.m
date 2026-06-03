function payload = build_result_summary(results)
%BUILD_RESULT_SUMMARY Build a compact summary payload for printing and saving.

tempBlock = get_nested_or_default(results, {'calib', 'temp'}, struct());
payload = struct();
payload.model = getfield_or_default(results, 'model', struct());
payload.core_outputs = struct();
payload.core_outputs.bg = get_nested_or_default(results, {'calib', 'bg'}, []);
payload.core_outputs.ba = get_nested_or_default(results, {'calib', 'acc', 'ba'}, []);
payload.core_outputs.gravity_magnitude = get_nested_or_default(results, {'calib', 'acc', 'gravity_magnitude'}, []);
payload.core_outputs.Ca = get_nested_or_default(results, {'calib', 'acc', 'Ca'}, []);
payload.core_outputs.Cg = get_nested_or_default(results, {'calib', 'gyr', 'Cg'}, []);
payload.core_outputs.Gg = get_nested_or_default(results, {'calib', 'gyr', 'Gg'}, []);
payload.core_outputs.temperature_model_status = get_temperature_model_status(tempBlock);
payload.core_outputs.allan_status = get_allan_status(getfield_or_default(results, 'analysis', struct()));
payload.summary = get_nested_or_default(results, {'validation', 'summary'}, struct());
payload.temperature_model = build_temperature_snapshot(tempBlock);
payload.meta = getfield_or_default(results, 'meta', struct());
end

function snapshot = build_temperature_snapshot(tempBlock)
snapshot = struct();
modelFile = getfield_any(tempBlock, {'model_file', 'modelFile'}, struct());
snapshot.reference_temperature = getfield_or_default(modelFile, 'reference_temperature', []);
snapshot.temperature_range = getfield_or_default(modelFile, 'temperature_range', []);
snapshot.extrapolation_mode = getfield_or_default(modelFile, 'extrapolation_mode', '');
snapshot.bg_model = getfield_any(tempBlock, {'bg_model', 'bgModel'}, struct());
snapshot.ba_model = getfield_any(tempBlock, {'ba_model', 'baModel'}, struct());
snapshot.message = getfield_or_default(tempBlock, 'message', '');
end

function status = get_temperature_model_status(tempBlock)
status = 'not_available';
if ~isstruct(tempBlock)
    return;
end

statuses = {};
for i = 1:2
    if i == 1
        key = 'bg_model';
        model = getfield_any(tempBlock, {'bg_model', 'bgModel'}, struct());
    else
        key = 'ba_model';
        model = getfield_any(tempBlock, {'ba_model', 'baModel'}, struct());
    end
    if isstruct(model) && ~isempty(fieldnames(model))
        if isfield(model, 'valid') && model.valid
            statuses{end + 1} = [key, '=valid']; %#ok<AGROW>
        elseif isfield(model, 'low_confidence') && model.low_confidence
            statuses{end + 1} = [key, '=low_confidence']; %#ok<AGROW>
        else
            statuses{end + 1} = [key, '=invalid']; %#ok<AGROW>
        end
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
