function missing = require_inputs(S, requiredPaths)
%REQUIRE_INPUTS Check whether nested struct fields required by a task exist and are non-empty.
% Usage:
%   missing = require_inputs(data, {'static.gyro', 'static.t'})

if nargin < 2 || isempty(requiredPaths)
    missing = {};
    return;
end

if ~iscell(requiredPaths)
    requiredPaths = {requiredPaths};
end

missing = {};
for i = 1:numel(requiredPaths)
    if ~has_nested_value(S, requiredPaths{i})
        missing{end + 1} = char(string(requiredPaths{i})); %#ok<AGROW>
    end
end
end

function tf = has_nested_value(S, pathStr)
tf = true;
parts = strsplit(char(pathStr), '.');
current = S;
for i = 1:numel(parts)
    if ~isstruct(current) || ~isfield(current, parts{i})
        tf = false;
        return;
    end
    current = current.(parts{i});
end

if isempty(current)
    tf = false;
end
end
