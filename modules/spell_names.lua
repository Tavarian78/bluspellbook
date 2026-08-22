local names = {};

function names.english(value)
    if (type(value) == 'string') then return value; end
    if (value == nil) then return nil; end
    local ok, name = pcall(function () return value[1] or value[0]; end);
    return ok and type(name) == 'string' and name or nil;
end

function names.key(value)
    local name = names.english(value) or '';
    return name:lower():gsub('[^%w]', '');
end

return names;
