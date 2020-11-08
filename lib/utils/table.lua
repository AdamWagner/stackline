function table.flatten(tbl)
    local function flatten(tbl, mdepth, depth, prefix, res, circ) -- {{{
        local k, v = next(tbl)
        while k do
            local pk = prefix .. k
            if type(v) ~= 'table' then
                res[pk] = v
            else
                local ref = tostring(v)
                if not circ[ref] then
                    if mdepth > 0 and depth >= mdepth then
                        res[pk] = v
                    else -- set value except circular referenced value
                        circ[ref] = true
                        local nextPrefix = pk .. '.'
                        flatten(v, mdepth, depth + 1, nextPrefix, res, circ)
                        circ[ref] = nil
                    end
                end
            end
            k, v = next(tbl, k)
        end
        return res
    end -- }}}

    local maxdepth = 0
    local circularRef = {[tostring(tbl)] = true}
    local prefix = ''
    local result = {}

    return flatten(tbl, maxdepth, 1, prefix, result, circularRef)
end

function table.merge(t1, t2)
    if not t2 then return t1 end
    if not t1 then return t2 end
    for k, v in pairs(t2) do
        if type(v) == "table" then
            if type(t1[k] or false) == "table" then
                table.merge(t1[k] or {}, t2[k] or {})
            else
                t1[k] = v
            end
        else
            t1[k] = v
        end
    end
    return t1
end
