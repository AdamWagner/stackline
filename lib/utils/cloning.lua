local M = {}

function M.copyShallow(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

function M.copyDeep(obj, seen)
    -- from https://gist.githubusercontent.com/tylerneylon/81333721109155b2d244/raw/5d610d32f493939e56efa6bebbcd2018873fb38c/copy.lua
    -- The issue here is that the following code will call itself
    -- indefinitely and ultimately cause a stack overflow:
    --
    -- local my_t = {}
    -- my_t.a = my_t
    -- local t_copy = copy2(my_t)
    --
    -- This happens to both copy1 and copy2, which each try to make
    -- a copy of my_t.a, which involves making a copy of my_t.a.a,
    -- which involves making a copy of my_t.a.a.a, etc. The
    -- recursive table my_t is perfectly legal, and it's possible to
    -- make a deep_copy function that can handle this by tracking
    -- which tables it has already started to copy.
    --
    -- Thanks to @mnemnion for pointing out that we should not call
    -- setmetatable() until we're doing copying values; otherwise we
    -- may accidentally trigger a custom __index() or __newindex()!

    -- Handle non-tables and previously-seen tables.
    if type(obj) ~= 'table' then
        return obj
    end
    if seen and seen[obj] then
        return seen[obj]
    end

    -- New table; mark it as seen and copy recursively.
    local s = seen or {}
    local res = {}
    s[obj] = res
    for k, v in pairs(obj) do
        res[M.copyDeep(k, s)] = M.copyDeep(v, s)
    end
    return setmetatable(res, getmetatable(obj))
end

return M
