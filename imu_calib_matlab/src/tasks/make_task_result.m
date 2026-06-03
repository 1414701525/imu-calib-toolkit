function taskResult = make_task_result(success, message, result, varargin)
%MAKE_TASK_RESULT Create a unified task result struct for modular execution.
% Usage:
%   taskResult = make_task_result(success, message, result)
%   taskResult = make_task_result(..., 'warnings', {...}, 'missing_inputs', {...}, 'meta', struct())

taskResult = struct();
taskResult.success = logical(success);
taskResult.valid = taskResult.success;
taskResult.message = char(string(message));
taskResult.warnings = {};
taskResult.missing_inputs = {};
taskResult.result = result;
taskResult.meta = struct();

if mod(numel(varargin), 2) ~= 0
    error('make_task_result:InvalidInput', ...
        'Optional arguments must be provided as name/value pairs.');
end

for k = 1:2:numel(varargin)
    name = lower(char(varargin{k}));
    value = varargin{k + 1};
    switch name
        case 'warnings'
            taskResult.warnings = ensure_cellstr(value);
        case 'missing_inputs'
            taskResult.missing_inputs = ensure_cellstr(value);
        case 'meta'
            if ~isstruct(value)
                error('make_task_result:InvalidMeta', 'meta must be a struct.');
            end
            taskResult.meta = value;
        otherwise
            error('make_task_result:UnknownOption', ...
                'Unknown option "%s".', char(varargin{k}));
    end
end
end

function out = ensure_cellstr(value)
if isempty(value)
    out = {};
elseif iscell(value)
    out = cellfun(@(x) char(string(x)), value, 'UniformOutput', false);
else
    out = {char(string(value))};
end
end
