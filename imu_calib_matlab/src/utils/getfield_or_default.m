function value = getfield_or_default(S, fieldName, defaultValue)
%GETFIELD_OR_DEFAULT Return struct field value when present, otherwise default.

if isstruct(S) && isfield(S, fieldName)
    value = S.(fieldName);
else
    value = defaultValue;
end
end
