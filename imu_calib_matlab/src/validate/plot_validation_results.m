function handles = plot_validation_results(data, calib, validation)
%PLOT_VALIDATION_RESULTS Plot validation figures for either full or partial results.

handles = struct();
mode = getfield_or_default(getfield_or_default(validation, 'summary', struct()), 'mode', 'full');
figMain = figure('Name', 'IMU Calibration Validation', 'Color', 'w');
tiledlayout(2, 3, 'Padding', 'compact', 'TileSpacing', 'compact');

ax1 = nexttile; plot_static_gyro_panel(ax1, data, validation);
ax2 = nexttile; plot_static_acc_panel(ax2, data, calib, validation);
ax3 = nexttile; plot_gyro_runs_panel(ax3, validation);
ax4 = nexttile; plot_cg_panel(ax4, calib);
ax5 = nexttile; plot_acc_summary_panel(ax5, validation, mode);
ax6 = nexttile; plot_summary_panel(ax6, calib, validation, mode);

handles.main = figMain;
handles.main_axes = [ax1, ax2, ax3, ax4, ax5, ax6];

allan = get_nested_or_default(validation, {'analysis', 'allan'}, struct());
if isstruct(allan)
    handles = add_allan_figures(handles, allan);
end

tempModels = getfield_or_default(calib, 'temp', struct());
if isstruct(tempModels)
    handles = add_temperature_figures(handles, data, tempModels);
end
end

function plot_static_gyro_panel(ax, data, validation)
axes(ax); %#ok<LAXES>
staticVal = getfield_or_default(validation, 'static', struct());
if isfield(staticVal, 'gyro_debiased') && ~isempty(staticVal.gyro_debiased) && ...
        isfield(data, 'static') && isfield(data.static, 't')
    plot(data.static.t, staticVal.gyro_debiased(:, 1), 'r');
    hold on;
    plot(data.static.t, staticVal.gyro_debiased(:, 2), 'g');
    plot(data.static.t, staticVal.gyro_debiased(:, 3), 'b');
    grid on;
    xlabel('Time [s]');
    ylabel('Gyro after bias removal [rad/s]');
    title('Static Gyro After Bias Removal');
    legend({'x', 'y', 'z'}, 'Location', 'best');
else
    text(0.5, 0.5, 'No static gyro available', 'HorizontalAlignment', 'center');
    axis off;
    title('Static Gyro');
end
end

function plot_static_acc_panel(ax, data, calib, validation)
axes(ax); %#ok<LAXES>
if ~isfield(data, 'static') || ~isfield(data.static, 't') || ~isfield(data.static, 'acc') || isempty(data.static.acc)
    text(0.5, 0.5, 'No static accel available', 'HorizontalAlignment', 'center');
    axis off;
    title('Static Accel Norm');
    return;
end

staticVal = getfield_or_default(validation, 'static', struct());
accNormRaw = getfield_or_default(staticVal, 'acc_norm_raw', []);
if isempty(accNormRaw)
    accNormRaw = sqrt(sum(data.static.acc .^ 2, 2));
end
accNormCorr = getfield_or_default(staticVal, 'acc_norm', []);

plot(data.static.t, accNormRaw, '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 0.9);
hold on;
if ~isempty(accNormCorr)
    plot(data.static.t, accNormCorr, 'k', 'LineWidth', 1.0);
end

g0Line = getfield_or_default(calib, 'gravity_magnitude', []);
if isempty(g0Line)
    g0Line = default_calib_options().acc_calibration.gravity_magnitude;
end
yline(g0Line, '--r', 'Reference |a|');

grid on;
xlabel('Time [s]');
ylabel('Accel norm [m/s^2]');
title('Static Accel Norm');
if ~isempty(accNormCorr)
    legend({'Raw', 'Corrected', 'Reference |a|'}, 'Location', 'best');
else
    legend({'Raw', 'Reference |a|'}, 'Location', 'best');
end
end

function plot_gyro_runs_panel(ax, validation)
axes(ax); %#ok<LAXES>
gyroRuns = getfield_any(validation, {'gyro_runs', 'gyroRuns'}, []);
if ~isempty(gyroRuns)
    beforeVals = [gyroRuns.residual_norm_before].';
    afterVals = [gyroRuns.residual_norm_after].';
    bar([beforeVals, afterVals]);
    grid on;
    ylabel('||dtheta error|| [rad]');
    title('Gyro dtheta Error Before/After');
    legend({'Before', 'After'}, 'Location', 'best');
else
    text(0.5, 0.5, 'No gyro runs available', 'HorizontalAlignment', 'center');
    axis off;
    title('Gyro dtheta Error');
end
end

function plot_cg_panel(ax, calib)
axes(ax); %#ok<LAXES>
if isfield(calib, 'Cg') && ~isempty(calib.Cg)
    imagesc(calib.Cg);
    axis equal tight;
    colorbar;
    title('Cg Heatmap');
    xlabel('Reference axis');
    ylabel('Measured axis');
    set(gca, 'XTick', 1:3, 'XTickLabel', {'x', 'y', 'z'});
    set(gca, 'YTick', 1:3, 'YTickLabel', {'x', 'y', 'z'});
    for r = 1:3
        for c = 1:3
            text(c, r, sprintf('%.4f', calib.Cg(r, c)), ...
                'HorizontalAlignment', 'center', 'Color', 'w', 'FontWeight', 'bold');
        end
    end
else
    text(0.5, 0.5, 'Cg unavailable in partial mode', 'HorizontalAlignment', 'center');
    axis off;
    title('Cg Heatmap');
end
end

function plot_acc_summary_panel(ax, validation, mode)
axes(ax); %#ok<LAXES>
summary = getfield_or_default(validation, 'summary', struct());
if strcmp(mode, 'full') && isfield(summary, 'static_acc_norm_mean_before') && isfield(summary, 'static_acc_norm_mean_after')
    bar([summary.static_acc_norm_mean_before, summary.static_acc_norm_mean_after; ...
         summary.static_acc_norm_std_before, summary.static_acc_norm_std_after]);
    grid on;
    set(gca, 'XTick', 1:2, 'XTickLabel', {'Mean |a|', 'Std |a|'});
    legend({'Before', 'After'}, 'Location', 'best');
    title('Static Accel Summary');
elseif isfield(summary, 'static_acc_norm_mean') && ~isempty(summary.static_acc_norm_mean)
    bar([summary.static_acc_norm_mean; summary.static_acc_norm_std]);
    grid on;
    set(gca, 'XTick', 1:2, 'XTickLabel', {'Mean |a|', 'Std |a|'});
    title('Static Accel Summary');
else
    text(0.5, 0.5, 'No accel summary available', 'HorizontalAlignment', 'center');
    axis off;
    title('Static Accel Summary');
end
end

function plot_summary_panel(ax, calib, validation, mode)
axes(ax); %#ok<LAXES>
summary = getfield_or_default(validation, 'summary', struct());
lines = {sprintf('mode = %s', mode), ...
         sprintf('available_blocks = %s', stringify_list(getfield_or_default(summary, 'available_blocks', {}))), ...
         sprintf('completed_modules = %s', stringify_list(getfield_or_default(summary, 'completed_modules', {}))), ...
         sprintf('temp_status = %s', char(string(getfield_or_default(summary, 'temperature_model_status', 'n/a')))), ...
         sprintf('allan_status = %s', char(string(getfield_or_default(summary, 'allan_status', 'n/a'))))};
if isfield(summary, 'static_gyro_rms_after_bias') && ~isempty(summary.static_gyro_rms_after_bias)
    v = summary.static_gyro_rms_after_bias(:);
    lines{end + 1} = sprintf('gyro RMS after bias = [%.3g %.3g %.3g]', v(1), v(2), v(3)); %#ok<AGROW>
end
if isfield(summary, 'Ca_rcond') && ~isempty(summary.Ca_rcond)
    lines{end + 1} = sprintf('rcond(Ca) = %.3e', summary.Ca_rcond); %#ok<AGROW>
end
if isfield(summary, 'Cg_rcond') && ~isempty(summary.Cg_rcond)
    lines{end + 1} = sprintf('rcond(Cg) = %.3e', summary.Cg_rcond); %#ok<AGROW>
end
axis off;
title('Summary');
y = 0.92;
for i = 1:numel(lines)
    text(0.05, y, lines{i}, 'Units', 'normalized');
    y = y - 0.12;
end
end

function handles = add_allan_figures(handles, allan)
if isfield(allan, 'gyro') && isstruct(allan.gyro) && isfield(allan.gyro, 'valid') && allan.gyro.valid
    figGyro = figure('Name', 'Gyro Allan Deviation', 'Color', 'w');
    loglog(allan.gyro.tau, allan.gyro.adev(:, 1), 'r');
    hold on;
    loglog(allan.gyro.tau, allan.gyro.adev(:, 2), 'g');
    loglog(allan.gyro.tau, allan.gyro.adev(:, 3), 'b');
    grid on;
    xlabel('\tau [s]');
    ylabel('Allan deviation');
    title('Gyro Allan Deviation');
    legend({'x', 'y', 'z'}, 'Location', 'best');
    handles.allan_gyro = figGyro;
end

if isfield(allan, 'acc') && isstruct(allan.acc) && isfield(allan.acc, 'valid') && allan.acc.valid
    figAcc = figure('Name', 'Accel Allan Deviation', 'Color', 'w');
    loglog(allan.acc.tau, allan.acc.adev(:, 1), 'r');
    hold on;
    loglog(allan.acc.tau, allan.acc.adev(:, 2), 'g');
    loglog(allan.acc.tau, allan.acc.adev(:, 3), 'b');
    grid on;
    xlabel('\tau [s]');
    ylabel('Allan deviation');
    title('Accel Allan Deviation');
    legend({'x', 'y', 'z'}, 'Location', 'best');
    handles.allan_acc = figAcc;
end
end

function handles = add_temperature_figures(handles, data, tempModels)
if ~isfield(data, 'static') || ~isfield(data.static, 'temp') || isempty(data.static.temp)
    return;
end

bgModel = getfield_or_default(tempModels, 'bgModel', getfield_or_default(tempModels, 'bg_model', struct()));
if isstruct(bgModel) && isfield(bgModel, 'valid') && bgModel.valid
    handles.temperature_gyro = add_temperature_figure(data, bgModel, 'bg');
end

baModel = getfield_or_default(tempModels, 'baModel', getfield_or_default(tempModels, 'ba_model', struct()));
if isstruct(baModel) && isfield(baModel, 'valid') && baModel.valid
    handles.temperature_acc = add_temperature_figure(data, baModel, 'ba');
end
end

function figTemp = add_temperature_figure(data, model, target)
if strcmp(target, 'bg')
    [biasT, ~] = get_gyro_bias_from_temperature(data.static.temp(:), model.reference_bg, model);
    values = data.static.gyro;
    figName = 'Gyro Temperature Bias Model';
    prefix = 'bg';
    yunit = '[rad/s]';
else
    [biasT, ~] = get_accel_bias_from_temperature(data.static.temp(:), model.reference_ba, model);
    values = data.static.acc;
    figName = 'Accel Temperature Bias Model';
    prefix = 'ba';
    yunit = '[m/s^2]';
end

figTemp = figure('Name', figName, 'Color', 'w');
for axisIdx = 1:3
    subplot(3, 1, axisIdx);
    scatter(data.static.temp(:), values(:, axisIdx), 8, '.');
    hold on;
    [tempSorted, idx] = sort(data.static.temp(:));
    plot(tempSorted, biasT(idx, axisIdx), 'LineWidth', 1.2);
    grid on;
    xlabel('Temperature');
    ylabel(sprintf('%s_%d %s', prefix, axisIdx, yunit));
    title(sprintf('%s(T) axis %d', prefix, axisIdx));
end
end

function value = getfield_or_default(S, fieldName, defaultValue)
if isstruct(S) && isfield(S, fieldName)
    value = S.(fieldName);
else
    value = defaultValue;
end
end

function value = getfield_any(S, names, defaultValue)
value = defaultValue;
if ~isstruct(S)
    return;
end
for i = 1:numel(names)
    if isfield(S, names{i})
        value = S.(names{i});
        return;
    end
end
end

function value = get_nested_or_default(S, pathParts, defaultValue)
value = defaultValue;
current = S;
for i = 1:numel(pathParts)
    if ~isstruct(current) || ~isfield(current, pathParts{i})
        return;
    end
    current = current.(pathParts{i});
end
value = current;
end

function text = stringify_list(value)
if iscell(value)
    if isempty(value)
        text = '[]';
    else
        text = strjoin(cellfun(@(x) char(string(x)), value, 'UniformOutput', false), ', ');
    end
else
    text = char(string(value));
end
end
