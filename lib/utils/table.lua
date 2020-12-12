-- Inspo:
--     https://github.com/leegao/AMX2D/blob/master/core/table.lua

local function indexByEquality(self, x) 
  for k,v in pairs(self) do 
    if k == x then 
      return v 
    end 
  end 
end

function table.length(t)  -- {{{
	local n = 0
	for k, v in pairs(t) do
		n = n+1
	end
	return n
end  -- }}}

function table.find(t, o)  -- {{{
	for k, v in pairs(t) do
		if v == o then
			return k
		end
	end
end  -- }}}

function table.flatten(tbl)  -- {{{
    local function flatten(tbl, mdepth, depth, prefix, res, circ)   -- {{{
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
                    else   -- set value except circular referenced value
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
    end   -- }}}

    local maxdepth = 0
    local circularRef = {[tostring(tbl)] = true}
    local prefix = ''
    local result = {}

    return flatten(tbl, maxdepth, 1, prefix, result, circularRef)
end  -- }}}

function table.merge(t1, t2)  -- {{{
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
end  -- }}}

function table.extend(fromTable, toTable)  -- {{{
    if not fromTable or not toTable then error("table can't be nil") end

    function _extend(fT, tT)
        for k, v in pairs(fT) do
            if type(fT[k]) == "table" and type(tT[k]) == "table" then
                tT[k] = _extend(fT[k], tT[k])
            elseif type(fT[k]) == "table" then
                tT[k] = _extend(fT[k], {})
            else
                tT[k] = v
            end
        end
        return tT
    end

    return _extend(fromTable, toTable)
end  -- }}}

function table.slice(obj, start, finish)  -- {{{
    if (#obj == 0) or (start == finish) then return {} end
    local _finish = finish or (#obj + 1)

    local output = {}
    for i = (start or 1), (_finish - 1) do
      table.insert(output, obj[i])
    end

    return output
end  -- }}}

function table.reduce(obj, callback, memo)  -- {{{
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
end  -- }}}

function table.groupBy(tbl, by)  -- {{{
  assert(tbl ~= nil, 'table to groupBy must not be nil')

  -- assume identity if no 'by' is passed
  if by == nil then by = function(x) return x end end

    function reducer(accumulator, current)
      assert(type(accumulator) == 'table', 'reducer accumulator must be a table')

      local result

      if type(by) == 'function' then result = by(current)
      elseif type(by) == 'string'  then result = current[by]
      end

      if not accumulator[result] then
        accumulator[result] = {}
      end

      table.insert(accumulator[result], current)
      return accumulator
    end

    local accumulator = setmetatable({}, { __index = indexByEquality })
    local result = table.reduce(tbl, reducer, accumulator)

    -- if keys are table, return values instead
    if type(u.keys(result)[1]) == 'table' then
      return u.values(result)
    end

    return result
end  -- }}}

function table.seperate(t)  -- {{{
	local itab = {}
	local tab = {}
	for k, v in pairs(t) do
		if type(k) == "number" then
			itab[k] = v
		else
			tab[k] = v
		end
	end
	return itab, tab
end  -- }}}

function table.join(t1, t2, o)  -- {{{
	local tab = t1
	for k, v in pairs(t2) do
		if (t1[k] and o) or not (t1[k]) then
			tab[k] = v
		end
	end
	return tab
end  -- }}}

function table.invert(t, _i)  -- {{{
	local tab = {}
	for k, v in pairs(t) do
		if type(v) == "table" and not _i then
			for _k, _v in pairs(v) do
				tab[_v] = k
			end
		else
			if not tab[v] then
				tab[v] = k
			else
				if not (type(tab[v]) == "table") then
					tab[v] = {tab[v], k}
				else
					table.insert(tab[v], k)
				end
			end
		end
	end
	return tab
end  -- }}}

function table.ascend(x, y)  -- {{{
	return x<y
end  -- }}}

function table.descend(x, y)  -- {{{
	return x>y
end  -- }}}

function table.ssort(t,f)  -- {{{
	if not f then f = table.ascend end
	local i=1
	local x, _x = table.seperate(t)
	local n = table.length(x)
	while i<=n do
		local m,j=i,i+1
		while j<=n do
			if f(x[j],x[m]) then m=j end
			j=j+1
		end
		x[i],x[m]=x[m],x[i]			  -- swap x[i] and x[m]
		i=i+1
	end
	return table.join(x, _x, false)
end  -- }}}

-- function table.sort(t, f)  -- {{{
-- 	return table.seperate(table.ssort(t, f))
-- end  -- }}}

function table.diff(t1, t2, opts, currDepth)  -- {{{
  -- (potential) opts keys:
  --    - depth
  --    - keys (in t1, t2) to ignore when computing diff
  -- See also /Users/adamwagner/Programming/Projects/stackline/lib/utils/comparison.lua:146

  opts = opts or {}
  opts.ignore = opts.ignore or {}
  -- opts.maxDepth = opts.maxDepth or 10

  local diff = {
    changed = {},
    removed = {},
    new = {},
    same = {},
    skipped = {},
    child = {},
  }

  -- local depth = currDepth or 0
  -- print('depth:', depth, 'out of', opts.maxDepth)

  local function shouldSkip(k,v)
    if v == nil
       or u.is_userdata(v)
       or u.is_function(v)
       -- or depth >= opts.maxDepth
        then
      return true
    end

    if type(k)=='string' and
      (k:startsWith('_kvo') or u.includes(opts.ignore, k)) then
      return true
    end
  end

  --[[
    IMPORTANT! When using multiple key/value observers,
    (e.g., stackline/lib/kvo.lua)
    using `v` in this loop will reference an *outdated* value.
    *Always* use `t1[k]` instead of `v`
  ]]

  for k, v in pairs(t1) do
    local skip = shouldSkip(k, t1[k]) or shouldSkip(k,t2[k])
    local tt1, tt2 = type(t1[k]), type(t2[k])

    if skip then
      diff.skipped[k] = true
    end

    if type(t1[k])=='table' and type(t2[k])=='table' and not skip then
      diff.child[k] = table.diff(t1[k], t2[k], opts)
    end

    if t2[k] == nil and not skip then
      diff.removed[k] = t1[k]
    end

    if not (t2[k] == t1[k]) and not skip then
      diff.changed[k] = {old = t1[k], new = t2[k]}
    end

    if t2[k] == t1[k] and not skip then
      diff.same[k] = v
    end

  end

  for k, v in pairs(t2) do
    if not (diff.changed[k] or diff.removed[k] or diff.same[k] or diff.skipped[k] or diff.child[k]) then
      diff.new[k] = v
    end
  end

  return diff
end  -- }}}

function table.changed(t1, t2, opts)  -- {{{
  local diff = table.diff(t1, t2, opts)
  local simple_diff = {}
  for k,v in pairs(diff.changed) do
    if diff.child[k] then
      simple_diff[k] = diff.child[k].changed or true
    end
  end
  return simple_diff
end  -- }}}

