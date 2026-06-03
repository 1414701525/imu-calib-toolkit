function value = get_nested_or_default(S, pathParts, defaultValue)
%GET_NESTED_OR_DEFAULT Traverse nested structs with a default fallback.

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
