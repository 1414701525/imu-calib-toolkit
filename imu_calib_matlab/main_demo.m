% MAIN_DEMO Synthetic demo entry for the MATLAB IMU calibration project.

clear;
clc;
close all;

projectRoot = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(projectRoot, 'src')));

fprintf('\n================ IMU 标定示例开始 ================\n');
options = default_calib_options();
[data, truth, meta] = load_example_data('saveToMat', true);
fprintf('[1/3] 已加载 synthetic 数据：%s\n', meta.mat_path);

task = run_full_calibration(data, 'options', options);
results = task.result.results;
fprintf('[2/3] 全流程任务执行结束：%s\n', task.message);

if options.pipeline.plot_results
    plot_validation_results(results.data, results.compat.flatCalib, results.validation); %#ok<NASGU>
end
fprintf('[3/3] 验证与绘图完成。\n');

print_calibration_summary(results);
if ~isempty(truth)
    fprintf('\n与 synthetic 真值的对比：\n');
    fprintf('max|bg - bg_true| = %.6g\n', max(abs(results.calib.bg - truth.bg_true)));
    fprintf('max|Ca - Ca_true| = %.6g\n', max(abs(results.calib.acc.Ca(:) - truth.Ca_true(:))));
    fprintf('max|ba - ba_true| = %.6g\n', max(abs(results.calib.acc.ba - truth.ba_true)));
    fprintf('max|Cg - Cg_true| = %.6g\n', max(abs(results.calib.gyr.Cg(:) - truth.Cg_true(:))));
end
