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


function table.slice(obj, start, finish)
    if (#obj == 0) or (start == finish) then return {} end
    local _finish = finish or (#obj + 1)

    local output = {}
    for i = (start or 1), (_finish - 1) do
      table.insert(output, obj[i])
    end

    return output
end

function table.reduce(obj, callback, memo)
    local initialIndex = 1
    local _memo = memo

    if _memo == nil then
      initialIndex = 2
      _memo = obj[1]
    end

    for i=initialIndex, #obj do
      _memo = callback(_memo, obj[i], i)
    end

    return _memo
end

function table.groupBy(obj, by)
    function reducer(accumulator, current)
      local result
      if type(by) == 'function' then
          result = by(current)
      elseif type(by) == 'string'  then
          result = current[by]
      end

      if not accumulator[result] then
        accumulator[result] = {}
      end

      table.insert(accumulator[result], current)
      return accumulator
    end

    return table.reduce(obj, reducer, {})
end
