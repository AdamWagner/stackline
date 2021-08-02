
newproxy = function(t) 
  return setmetatable({
      raw = t or {},
      onSetHandler = function(self, fn) self.onSet = fn end,
      onSet = u.bind(print, 'Setting new value in proxy: ')
    }, 
    {
      __pairs = function(self) return pairs(self.raw) end,
      __index = function(self, name)
        return rawget(self.raw, name)
      end,
      __newindex = function(self, name, nval)
        self.onSet(name, self[name] or 'nil', nval)
        rawset(self.raw, name, nval)
      end,
  })
end
-- MIT Licensed

-- Copyright (c) 2014-2016 Dmitri Voronianski [dmitri.voronianski@gmail.com](mailto:dmitri.voronianski@gmail.com)

-- Permission is hereby granted, free of charge, to any person obtaining
-- a copy of this software and associated documentation files (the
-- 'Software'), to deal in the Software without restriction, including
-- without limitation the rights to use, copy, modify, merge, publish,
-- distribute, sublicense, and/or sell copies of the Software, and to
-- permit persons to whom the Software is furnished to do so, subject to
-- the following conditions:

-- The above copyright notice and this permission notice shall be
-- included in all copies or substantial portions of the Software.

-- THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
-- IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
-- CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
-- TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
-- SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE

local table = require('table')
local lu = {}

--
-- Colections (Tables)
--
function lu.each (t, func)
  -- http://springrts.com/wiki/Lua_Performance#TEST_9:_for-loops
  if lu.isArray(t) then
    local tl = #t
    for i = 1, tl do
      local v = t[i]
      func(v, i, t)
    end
  else
    for k, v in pairs(t) do
      func(v, k, t)
    end
  end
end

function lu.map (t, func)
  local _r = {}

  lu.each(t, function (v, k, l)
    if lu.isArray(t) then
      local val = func(v, k, l)
      if val then
        _r[k] = val
      end
    else
      local val = func(v, k, l)
      table.insert(_r, val)
    end
  end)

  return _r
end

function lu.filter (t, func)
  local _r = {}
  local _i = 1

  lu.each(t, function (v, k)
    if lu.isArray(t) then
      if func(v, k, t) then
        _r[_i] = v
        _i = _i + 1
      end
    else
      if func(v, k, t) then
        table.insert(_r, v)
      end
    end
  end)

  return _r
end

function lu.find (t, func)
  if func == nil then return nil end

  local _r = nil
  lu.any(t, function (v, k, l)
    if func(v, k, l) then
      _r = v
      return true
    end
  end)

  return _r
end

function lu.reduce (t, func, memo)
  local init = memo == nil

  lu.each(t, function (v, k, l)
    if init then
      memo = v
      init = false
    else
      memo = func(memo, v, k, l)
    end
  end)

  if init then
    error('Empty array reduce without initial value')
  end

  return memo
end

function lu.reduceRight (t, func, memo)
  return lu.reduce(lu.reverse(t), func, memo)
end

function lu.where (t, props)
  return lu.select(t, function (val)
    return lu.every(props, function(v, k)
      return val[k] == v
    end)
  end)
end

function lu.every (t, func)
  if lu.isEmpty(t) then return false end

  func = func or lu.identity

  local found = true
  lu.each(t, function(v, k, l)
    if found and not func(v, k, l) then
      found = false
    end
  end)

  return found
end

function lu.some (t, func)
  if lu.isEmpty(t) then return false end

  func = func or lu.identity

  local found = false
  lu.each(t, function (v, k, l)
    if not found and func(v, k, l) then
      found = true
      return found
    end
  end)

  return found
end

function lu.contains (t, val)
  return lu.some(t, function (v)
    return v == val
  end)
end

function lu.size (list, ...)
  local args = {...}

  if not lu.isEmpty(args) then
    return lu.size(args) + 1
  elseif lu.isArray(list) then
    return #list
  elseif lu.isObject(list) then
    local _l = 0
    lu.each(list, function () _l = _l + 1 end)
    return _l
  elseif lu.isString(list) then
    return list:len()
  end

  return 0
end

function lu.sort (t, func)
  table.sort(t, func)
  return t
end

function lu.sortBy (t, func)
  func = func or lu.identity

  local sorting
  if lu.isString(func) then
    sorting = function (a, b)
      return a[func] < b[func]
    end
  else
    sorting = function (a, b)
      if a == nil then return false end
      if b == nil then return true end
      return func(a) < func(b)
    end
  end

  table.sort(t, sorting)
  return t
end

--
-- Arrays
--
function lu.concat (...)
  local values = lu.flatten({...}, true)
  local _r = {}

  lu.each(values, function (v, k)
    _r[k] = v
  end)

  return _r
end

function lu.flatten (t, _shallow)
  local shallow = _shallow or false
  local new_flattened
  local _flat = {}

  lu.each(t, function (val, k, l)
    if lu.isTable(val) then
      new_flattened = shallow and val or lu.flatten(val)
      lu.each(new_flattened, function (v) _flat[#_flat+1] = v end)
    else
      _flat[#_flat+1] = val
    end
  end)

  return _flat
end

function lu.reverse (t)
  local length = lu.size(t)
  for i = 1, length / 2, 1 do
    t[i], t[length-i+1] = t[length-i+1], t[i]
  end
  return t
end

function lu.invert (t)
  local _r = {}
  local isArray = lu.isArray(t)
  lu.each(t, function (v, k)
    if isArray then
      _r[v] = k
    else
      _r[k] = v
    end
  end)
  return _r
end

function lu.push(t, ...)
  lu.each({...}, function (v, k)
    t[#t+1] = v
  end)
  return t
end

--
-- Objects
--
function lu.keys (t)
  if not lu.isObject(t) then error('Table is not an object') end
  return lu.map(t, function (v, k)
    return k
  end)
end

function lu.values (t)
  if not lu.isObject(t) then error('Table is not an object') end
  return lu.map(t, function (v)
    return v
  end)
end

function lu.isArray (val)
  return type(val) == 'table' and (val[1] or next(val) == nil)
end

function lu.isObject (val)
  return type(val) == 'table'
end

function lu.isString (val)
  return type(val) == 'string'
end

function lu.isNumber (val)
  return type(val) == 'number'
end

function lu.isFunction (val)
  return type(val) == 'function'
end

function lu.isBoolean (val)
  return type(val) == 'boolean'
end

function lu.toBoolean (val)
  return not not val
end

function lu.isNil (val)
  return val == nil
end

function lu.isEmpty (val)
  if lu.isNil(val) then
    return true
  elseif lu.isArray(val) or lu.isObject(val) then
    return next(val) == nil
  elseif lu.isString(val) then
    return val:len() == 0
  else
    return false
  end
end

function lu.isEqual (tableA, tableB, useMt)
  local typeTabA = type(tableA)
  local typeTabB = type(tableB)

  if typeTabA ~= typeTabB then return false end
  if typeTabA ~= 'table' then return (tableA == tableB) end

  local mtA = getmetatable(tableA)
  local mtB = getmetatable(tableB)

  if useMt then
    if (mtA or mtB) and (mtA.__eq or mtB.__eq) then
      return mtA.__eq(tableA, tableB) or mtB.__eq(tableB, tableA) or (tableA == tableB)
    end
  end

  if lu.size(tableA) ~= lu.size(tableB) then return false end

  for i, v1 in pairs(tableA) do
    local v2 = tableB[i]
    if lu.isNil(v2) or not lu.isEqual(v1,v2,useMt) then return false end
  end

  for i,_ in pairs(tableB) do
    local v2 = tableA[i]
    if lu.isNil(v2) then return false end
  end

  return true
end

--
-- Utility functions
--
function lu.identity (value)
  return value
end

local unique_id_counter = -1
function lu.uniqueId (template)
  unique_id_counter = unique_id_counter + 1

  if not template then
    return unique_id_counter
  end

  if lu.isString(template) then
    return template:format(unique_id_counter)
  end

  if lu.isFunction(template) then
    return template(unique_id_counter)
  end
end

function lu.times (n, func)
  local _r = {}
  for i = 1, n do
    _r[i] = func(i)
  end
  return _r
end

function lu.once (func)
  local _internal = 0
  local _args = {}

  return function (...)
    _internal = _internal+1
    if _internal <=1 then
      _args = {...}
    end
    return func(table.unpack(_args))
  end
end

function lu.functions (t, recurseMetaTable)
  t = t or lu
  local _r = {}

  lu.each(t,function (v, k)
    if lu.isFunction(v) then
      _r[#_r+1] = k
    end
  end)

  if recurseMetaTable then
    local mt = getmetatable(t)

    if mt and mt.__index then
      local mt_methods = lu.functions(mt.__index)
      lu.each(mt_methods, function (fn)
        _r[#_r+1] = fn
      end)
    end
  end

  return lu.sort(_r)
end

local entityMap = {
  escape = {
    ['&'] = '&amp;',
    ['<'] = '&lt;',
    ['>'] = '&gt;',
    ['"'] = '&quot;',
    ["'"] = '&#x27;',
    ['/'] = '&#x2F;'
  }
}
entityMap.unescape = lu.invert(entityMap.escape)

--
-- Aliases
--
lu.isTable  = lu.isObject
lu.forEach  = lu.each
lu.collect  = lu.map
lu.inject = lu.reduce
lu.foldl  = lu.reduce
lu.injectr  = lu.reduceRight
lu.foldr  = lu.reduceRight
lu.select = lu.filter
lu.include  = lu.contains
lu.any    = lu.some
lu.detect = lu.find
lu.all    = lu.every
lu.compare  = lu.isEqual
lu.uid    = lu.uniqueId
lu.mirror = lu.invert
lu.methods  = lu.functions

--
-- Chaining
--
function lu.chain (val)
  return lu(val).chain()
end

local chainable_lu = {}
lu.each(lu.functions(lu), function (name)
  local func = lu[name]
  lu[name] = func

  chainable_lu[name] = function (t, ...)
    local r = func(t._wrapped, ...)
    if lu.isObject(t) and t._chain then
      return lu(r).chain()
    else
      return r
    end
  end
end)

setmetatable(lu, {
  __call = function (t, ...)
    local wrapped = ...
    if lu.isTable(wrapped) and wrapped._wrapped then
      return wrapped
    end

    local instance = setmetatable({}, { __index = chainable_lu })
    function instance.chain ()
      instance._chain = true
      return instance
    end
    function instance.value ()
      return instance._wrapped
    end
    instance._wrapped = wrapped
    return instance
  end
})

return lu
