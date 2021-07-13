--[[
== types.lua ==
  e.g., u.is[type], u.all[type](), u.none[type]()
  Flexible lookup by name.

  Examples of "string" & "function"
    1. u.is.str,    u.M.is.func
    2. u.is.string, u.is['function'] -- reserved words must be in square brackets
    3. u.isstring,  u.isfunction
    4. u.isstr,     u.isfunc

  Typecheck collections
    - u.is.all.table(..)
    - u.is.none.tables(..) or u.M.is.no.tables(...)
    - u.is.any.table(..)

  REFERENCE: {{{
    https://github.com/CommandPost/CommandPost/blob/develop/src/extensions/cp/M.is.lua

  TODO
    Write typechecker for: Array of tables
  }}}
]]

local fn = hs.fnutils
local u = {
  keys = require 'lib.utils.core'.keys
}

local function primitive(typeName)
	return function(value)
		local valueType = type(value)
		if valueType == typeName then
			return true
        end
		return false, ('%s expected, got %s'):format(typeName, valueType)
	end
end

local builtin = {
   bool = 'boolean',
   num = 'number',
   str = 'string',
   tbl = 'table',
   func = 'function',
   userdata = 'userdata',
}

------------------------------------------------------------------------------------------------------------------------

local M = {}

M.is =  fn.map(builtin, primitive) -- Automatically build builtin type checkers

M.is.callable = function(x) -- Add non-builtin type checkers
    if type(x)=='function' then return true end
    local mt = getmetatable(x)
    return mt and mt.__call~=nil
end

M.is.empty      = function(x) return u.len(x)==0 end -- NOTE: length(x) returns 0 when next(x)==nil
M.is.truthy     = function(x) return x~=nil and x~=false end
M.is.functable  = function(x) return M.is.tbl(x) and M.is.callable(x) end -- A table that can be called like a function
M.is.overnested = function(x) return M.is.tbl(x) and M.is.tbl(x[1]) and u.len(x)==1 end -- e.g., {{1,2,3}} -> true
M.is.json       = function(x) return type(x)=='string' and x:find('{') and x:find('}') end
M.is.instanceof = function(cls, x) return getmetatable(x)==cls end

M.is.metamethod = function(key) -- {{{
  local metamethods = { -- {{{
    __add = true,      __sub = true,       __mul = true,       __div = true,
    __mod = true,      __pow = true,       __unm = true,       __concat = true,
    __len = true,      __eq = true,        __lt = true,        __le = true,
    __tostring = true, __pairs = true,     __ipairs = true,    __gc = true,
    __index = true,    __newindex = true,  __metatable = true, __idiv = true,
    __band = true,     __bor = true,       __bxor = true,      __bnot = true,
    __shl = true,      __shr = true,       __close = true,     __call = true,
  }   -- }}}
  return metamethods[key]
end -- }}}

M.is.array = function(x) --[[ {{{
  REFERENCE / INSPO / TEST / PERF: {{{
     https://stackoverflow.com/questions/7526223/how-do-i-know-if-a-table-is-an-array
     Alternative: detect type: array, dict, mixed: https://github.com/HuotChu/ArrayForLua/blob/master/Array.lua#L24

   TEST
      u.M.is.array{}                             --> true (just an opinion that empty tbl should be considered array-lik)
      u.M.is.array{1, 2, 3}                      --> true
      u.M.is.array{1, 2, 3, nil}                 --> true (we don't care about last val)
      u.M.is.array{a = 1, b = 2, c = 3}          --> false
      u.M.is.array{1, 2, 3, a = 1, b = 2, c = 3} --> false
      u.M.is.array{1, 2, 3, nil, 5}              --> false

   PERF
      When compared to 3 other algos on Stackoverflow (some of which seem like they'd be simpler / more efficient),
      the verison below wins easily on macbook pro 2018. This version is ~2.5x faster than any I've found.

  }}} ]]
  -- Iterate using *pairs* and increment index
  -- If a nil value is found, it's not an array
  -- This should short-circuit quite early, and so should out-perform methods that require a full iteration of the table
  local i = 0
  for _ in u.rawpairs(x) do
     i = i + 1
     if rawget(x,i) == nil then return false end
  end
  return true
end -- }}}

M.is.dict = function(x) --[[ {{{
  If the given table has exactly zero keys using the '#' operator
  and has >0 keys, then it's a pure "dict"-style table. ]]
  return M.is.tbl(x) and not M.is.array(x) and not M.is.empty(x)
end -- }}}

M.is.mixedtable = function(x) --[[ {{{
  If the given table has exactly zero keys using the '#' operator
  and has >0 keys, then it's a pure "dict"-style table. ]]
  local nlen, klen = #x, #u.keys(x)
  return M.is.tbl(x) and nlen>0 and klen~=0 and klen~=nlen
end -- }}}

M.is.collection = function(x, of) --[[ {{{
  A collection is an array-like table having exclusively other tables as children
  @param x: the input to be checked
  @param of: an optional string param matching one of the keys on 'is' ]]

  if not M.is.array(x) then return false end

  of = M.is.str(of)
     and M.is.all[of] -- use one of the builtin "all" typecheckers
     or M.is.all.tables  -- or fallback to identity fn

  if not of(table.unpack(x)) then
     return false
  end

  return true
end -- }}}

-- Build all, none, and some collection type checkers
M.is.all, M.is.none, M.is.any = {}, {}, {}
M.is.no = M.is.none -- Alias 'none' to 'no' as well. E.g., u.M.is.no.tables(...)

fn.ieach(u.keys(is), function(k)
   M.is.all[k] = function(...) return u.all({...}, is[k]) end
   M.is.any[k] = function(...) return u.any({...}, is[k]) end
   M.is.none[k] = function(...) return u.none({...}, is[k]) end
end)

-- Prepare `M.is.nt`
M.is.nt = {}

for k,fn in pairs(M.is) do
  if M.is.func(fn) then 
    M.is.nt[k] = function(v) return not fn(v) end
  end
end

function M.allTypes(t) -- FROM: https://github.com/UlisseMini/luaStruct/blob/master/struct.lua
  local types = {}

  for k, v in pairs(t) do
    types[k] = M.is.tbl(v) 
      and u.allTypes(v)
      or type(v)
  end

  return types
end

return M
