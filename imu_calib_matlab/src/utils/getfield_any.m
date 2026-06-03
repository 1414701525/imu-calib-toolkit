function value = getfield_any(S, names, defaultValue)
%GETFIELD_ANY Return the first present field among candidate names.

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
