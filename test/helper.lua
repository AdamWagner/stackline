local M = {}

if not string.split then
    function string:split(p)
        local sep = p or "%s"
        local parts = {}
        local start = 1

        while true do
            local first, last = self:find(sep, start)
            if not first then
                table.insert(parts, self:sub(start))
                break
            end

            table.insert(parts, self:sub(start, first - 1))
            start = last + 1
        end

        return parts
    end
end

local function is_array(tbl)
    return type(tbl) == "table" and rawget(tbl, 1) ~= nil
end

function M.noop()
end

function M.logger()
    return {
        i = M.noop,
        w = M.noop,
        e = M.noop,
        d = M.noop,
        setLogLevel = M.noop,
    }
end

function M.basic_u()
    local u = {}

    function u.each(tbl, fn)
        for key, value in pairs(tbl or {}) do
            fn(value, key)
        end
    end

    function u.map(tbl, fn)
        local result = {}

        if is_array(tbl) then
            for index, value in ipairs(tbl) do
                result[index] = fn(value, index)
            end
        else
            for key, value in pairs(tbl or {}) do
                result[key] = fn(value, key)
            end
        end

        return result
    end

    function u.filter(tbl, fn)
        local result = {}

        if is_array(tbl) then
            for _, value in ipairs(tbl) do
                if fn(value) then
                    table.insert(result, value)
                end
            end
        else
            for key, value in pairs(tbl or {}) do
                if fn(value, key) then
                    result[key] = value
                end
            end
        end

        return result
    end

    function u.groupBy(tbl, key_or_fn)
        local result = {}
        for _, value in ipairs(tbl or {}) do
            local key = type(key_or_fn) == "function"
                and key_or_fn(value)
                or value[key_or_fn]

            if result[key] == nil then
                result[key] = {}
            end
            table.insert(result[key], value)
        end
        return result
    end

    function u.greaterThan(n)
        return function(tbl)
            return #tbl > n
        end
    end

    function u.length(tbl)
        local count = 0
        for _ in pairs(tbl or {}) do
            count = count + 1
        end
        return count
    end

    function u.values(tbl)
        local values = {}
        for _, value in pairs(tbl or {}) do
            table.insert(values, value)
        end
        return values
    end

    function u.task_cb(fn)
        return function(stdout)
            return fn(stdout)
        end
    end

    function u.partial(fn, ...)
        local preset = {...}
        return function(...)
            local args = {}
            for _, value in ipairs(preset) do
                table.insert(args, value)
            end
            for _, value in ipairs({...}) do
                table.insert(args, value)
            end
            return fn(table.unpack(args))
        end
    end

    function u.roundToNearest(round_to, num)
        return num - num % round_to
    end

    function u.equal(a, b)
        return M.deep_equal(a, b)
    end

    function u.p(...)
        return ...
    end

    return u
end

function M.count_entries(tbl)
    local count = 0
    for _ in pairs(tbl or {}) do
        count = count + 1
    end
    return count
end

function M.deep_equal(a, b)
    if type(a) ~= type(b) then
        return false
    end

    if type(a) ~= "table" then
        return a == b
    end

    for key, value in pairs(a) do
        if not M.deep_equal(value, b[key]) then
            return false
        end
    end

    for key in pairs(b) do
        if a[key] == nil then
            return false
        end
    end

    return true
end

function M.assert_equal(actual, expected, message)
    if actual ~= expected then
        error(message or string.format("expected %s, got %s", tostring(expected), tostring(actual)), 2)
    end
end

function M.assert_true(value, message)
    if not value then
        error(message or "expected condition to be true", 2)
    end
end

function M.reset_modules(...)
    for _, module_name in ipairs({...}) do
        package.loaded[module_name] = nil
    end
end

return M
