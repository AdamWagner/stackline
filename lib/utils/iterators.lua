local fnutils = hs.fnutils

local iscallable = function(x) -- Add non-builtin type checkers {{{
    if type(x)=='function' then return true end
    local mt = getmetatable(x)
    return mt and mt.__call~=nil
end -- }}}


local M = {}

-- == Alias hs.fnutils methods ==
--[[ These fns aren't used because they don't meet my needs as-is.
    u.each         = hs.fnutils.each
    u.map          = hs.fnutils.map
    u.filter       = hs.fnutils.filter
    u.contains     = hs.fnutils.Contains
]]
M.reduce       = fnutils.reduce
M.concat       = fnutils.concat
M.sortByKeys   = fnutils.sortByKeys
M.sortByValues = fnutils.sortByKeyValues

function M.rawpairs(tbl)  -- {{{
  return next, tbl, nil 
end  -- }}}

function M.each(t, f) -- Replaces hs.fnutils.each b/c: Passes key as 2nd param {{{
  if type(t)~='table' or type(f)~='function' then return t end
  for k, v in pairs(t) do
    f(v, k)
  end
end -- }}}

local function iteratee(x) --[[ {{{
  Shortcuts for writing common map & filter funcs by simply passing a string or table.
  This turns out to be extremely useful.
  See also https://github.com/rxi/lume#iteratee-functions.
     - M.map(x, 'key')                           -> get list of values at 'key'
     - M.filter(x, {key1='special', key2=true }) -> get collection elements that match the key,val pairs specified
  ]]

  if x==nil then return M.identity end -- Use identity fn if 'x' is nil
  if u.is.callable(x) then return x end -- Return as-is if 'x' is callable


  if type(x)=='table' then
    return function(el)
      for k, v in pairs(x) do
        if el[k] ~= v then return false end
      end
      return true
    end
  end

  -- Otherwise, assume x is a 'string' and simply lookup 'x' on each element in collection
  return function(el) return el[x] end
end -- }}}

--[[ == M.map(t, fn) NOTES, TESTS, TODOS == {{{

  = TESTS = 
  -- Setup by creating stackline window objects
  ws = M.map(hs.window.filter(), stackline.window:call('new'))

  -- Pluck keys of child tables with string 'fn' arg:
  appnames = M.map(ws, 'app') -- -> { "Hammerspoon", "Google Chrome", "Google Chrome", "kitty", "kitty" }

  TODO: If table is list-like & values are strings, delegate to M.pick(...)
  TODO: Doesn't work with 'map': M.map(tbl, {'id', 'app', 'frame'}) does not pluck id,app,frame keys
  TODO: Pass multiple string values to filter each child table to those keys:
        e.g., appnames_and_ids = M.map(ws, 'app', 'id') -- -> { {id=123, app="Hammerspoon"}, {id=456, app="Google Chrome", ...}
 }}} ]]

local function makeMapper(iter) --[[ {{{
  Factory fn to produce mappers {{{
  NOTE: This exists primarily because `hs.fnutils.map` *only* maps values, not keys. Also, the `iteratee` capabilities are nice.
  NOTE: return v, k from map fn to map *both* values & keys
  mapping fn prototyped as `f (v, k)`

  Adapted from: https://github.com/Yonaba/Moses/blob/master/moses.lua#L395
  }}} ]]
  iter = iter or M.rawpairs -- default to 'rawpairs', but can be given custom iter

  return function(t, fn)
    t         = t or {}
    fn        = iteratee(fn)
    local res = {}

    for k,v in iter(t) do
      local r1, r2 = fn(v, k)
      local newKey = r2 and r1 or k  -- If 2nd retval nil, use original key 'k'
      local newVal = r2 and r2 or r1 -- If 2nd retval not nil, *newVal* is **second** retval, otherwise the first
      res[newKey] = newVal
    end

    return res
  end
end -- }}} }}}

M.map = makeMapper(pairs) -- use as u.map(tbl, funcOrTable)

M.imap = makeMapper(ipairs) -- us as u.imap(tbl, funcOrTable)

--[[ == M.filter(t, fn) NOTES, TESTS, TODOS == {{{
  param `fn` may be a function OR a table.  If it's a table, it's treated as a filter specification

  = TESTS =
  -- Setup by creating stackline window objects
    function new_win(w) return stackline.window:new(w) end
    ws = M.map(stackline.wf:getWindows(), new_win)

  -- Filter by specifying key,val pairs in table
    only_kitty = M.filter(ws, { app = 'kitty'})

  -- Filter by specifying key,val pairs in table
    only_kitty = M.filter(ws, { app = 'kitty'})           -- single key,val
    only_kitty = M.filter(ws, { app = 'kitty', id = 532)  -- multiple key,val

  -- Filter by increasingly specific specifications
    items = {
      {height = 10, weight = 8, price = 500},
      {height = 10, weight = 15, price = 700},
      {height = 15, weight = 15, price = 3000},
      {height = 10, weight = 8, price = 3000},
    }

    M.filter(items, {height = 10})   -- => {items[1], items[2], items[4]}
    M.filter(items, {weight = 15})   -- => {items[2], items[3]}
    M.filter(items, {prince = 3000}) -- => {items[3], items[4]}

    M.filter(items, {height = 10, weight = 15, prince = 700}) -- => {items[2]}

  TODO: Support nested functions as values.
    E.g., to find elements with app = kitty and a title that contains 'nvim':
    M.filter(ws, { app = 'kitty', title = function(x) return x:find('nvim') end })

 }}} ]]

function M.filter(t, fn) -- }}}
    return fnutils.filter(t, iteratee(fn))
end-- }}}

function M.ifilter(t, fn) -- }}}
    return fnutils.ifilter(t, iteratee(fn))
end-- }}}

function M.filterKeys(t, fn) -- {{{
  local matches = {}
  for k, v in M.rawpairs(t or {}) do
    if fn(v, k) then matches[k] = v end
  end
  return matches
end -- }}}

return M
