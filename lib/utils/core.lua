local M = {}

M.identity = function(val) return val end

function M.rawpairs(tbl)
  return next, tbl, nil
end

function M.roundToNearest(roundTo, numToRound) 
  return numToRound - numToRound % roundTo
end 

function M.unwrap(tbl) 
  -- Recurseively flatten 'redundant' tables
  -- Distinct from `M.flatten()` as it preserves non-redundant tables
  while type(tbl)=='table' and #tbl==1 do
    tbl = tbl[1]
  end
  return tbl
end 

function M.wrap(...) 
  -- Ensure that all arguments are wrapped in a table
  -- If the 1st and only arg is a table itself, it will be returned as-is
  return M.unwrap({...})
end 

function M.length(x) -- {{{
  local len, ty = 0, type(x)
  local countable = (ty=='table' or ty=='string')
  if not countable then return 0 end
  local meta_len = getmetatable(x) and getmetatable(x).__len

  -- Fallback to builtin operator if input is array, string, or has a __len metamethod
  if u.is.array(x) or u.is.str(x) or meta_len then
    return #x
  end

  for _ in next, x do
    len = len + 1
  end

  return len
end
M.len = M.length -- alias as M.len
-- }}}

function M.keys(t, iter) -- {{{
  local res = {}
  iter = iter or pairs
  for k in iter(t or {}) do
    res[#res + 1] = k
  end
  return res
end -- }}}

function M.values(t, iter) -- {{{
  local res = {}
  iter = iter or pairs
  for _k, v in iter(t or {}) do
    res[#res + 1] = v
  end
  return res
end -- }}}

function M.cb(fn) -- {{{
  return function()
    return fn
  end
end -- }}}

function M.prepareJsonEncode(t) -- {{{
  -- Remove un-encodable values from a lua table (hs.json.encode fails silently when asked to encode functions or userdata)
  --[[ == TEST ==
  query = require 'stackline.query'
  r = query.groupWindows(hs.window.filter())
  encodable = u.prepareJsonEncode(r)
  hs.json.encode(encodable)
  ]]
  return hs.fnutils.map(t, function(v)
    if type(v)=='function' or type(v)=='userdata' then return end
    if type(v)=='boolean' then return tostring(v) end
    if type(v)=='nil' then return 'null' end
    return type(v)=='table'
      and M.prepareJsonEncode(v)
      or v
  end)
end -- }}}

return M
