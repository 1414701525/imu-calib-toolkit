function task = run_split_km(Cg)
%RUN_SPLIT_KM Split Cg into Kg and Mg using only the calibration matrix.

if nargin < 1 || isempty(Cg)
    task = make_task_result(false, 'Cg is required for Kg/Mg split.', [], ...
        'missing_inputs', {'Cg'}, ...
        'meta', struct('task_name', 'run_split_km'));
    return;
end

[Kg, Mg] = split_KM(Cg);
task = make_task_result(true, 'Kg/Mg split completed successfully.', ...
    struct('Kg', Kg, 'Mg', Mg), ...
    'meta', struct('task_name', 'run_split_km'));
end
