local M = {}

function M.invoke(instance, name, ...)
    -- FIXME: This doesn't work, but it seems like it should
    --        attempt to index a nil value (local 'instance')
    return function(instance, ...)
        if instance[name] then
            instance[name](instance, ...)
        end
    end
end

function M.cb(fn)
    return function()
        return fn
    end
end

function M.partial(f, ...)
    local unpack = unpack or table.unpack
    local a = {...}
    local a_len = select("#", ...)
    return function(...)
        local tmp = {...}
        local tmp_len = select("#", ...)
        -- Merge arg lists
        for i = 1, tmp_len do
            a[a_len + i] = tmp[i]
        end
        return f(unpack(a, 1, a_len + tmp_len))
    end
end


function M.sleep(s)  -- {{{
  local ntime = os.clock() + s/10
  repeat until os.clock() > ntime
end  -- }}}

return M
