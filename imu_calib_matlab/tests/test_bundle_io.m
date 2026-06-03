% test_bundle_io
% Validate manifest bundle export/load round-trip for the synthetic dataset.

clear;
clc;

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(projectRoot, 'src')));

[data, ~] = load_example_data('forceRegenerate', true, 'saveToMat', false);
tmpDir = tempname;
mkdir(tmpDir);
cleanupObj = onCleanup(@() rmdir(tmpDir, 's')); %#ok<NASGU>

export_dataset_bundle(data, tmpDir);
loaded = load_csv_data(tmpDir);

assert(size(loaded.static.gyro, 1) == size(data.static.gyro, 1), ...
    'Static gyro sample count mismatch after bundle round-trip.');
assert(numel(loaded.accPoses) == numel(data.accPoses), ...
    'Accelerometer pose count mismatch after bundle round-trip.');
assert(numel(loaded.gyroRuns) == numel(data.gyroRuns), ...
    'Gyro run count mismatch after bundle round-trip.');
assert(isempty(loaded.accPoses(1).a_ref), ...
    'Default bundle export should omit legacy acc pose reference columns.');

fprintf('test_bundle_io passed.\n');
