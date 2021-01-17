-- Doc-commented in table.lua...
local function clone (t, nometa)
  local u = {}
  if not nometa then
    setmetatable (u, getmetatable (t))
  end
  for i, v in pairs (t) do
    u[i] = v
  end
  return u
end

-- Doc-commented in table.lua...
local function clone_rename (map, t)
  local r = clone (t)
  for i, v in pairs (map) do
    r[v] = t[i]
    r[i] = nil
  end
  return r
end

-- Doc-commented in table.lua...
local function merge (t, u)
  for i, v in pairs (u) do
    t[i] = v
  end
  return t
end

local new -- forward declaration

-- Doc-commented in list.lua...
local function append (l, x)
  local r = {unpack (l)}
  table.insert (r, x)
  return r
end

-- Doc-commented in list.lua...
local function compare (l, m)
  for i = 1, math.min (#l, #m) do
    if l[i] < m[i] then
      return -1
    elseif l[i] > m[i] then
      return 1
    end
  end
  if #l < #m then
    return -1
  elseif #l > #m then
    return 1
  end
  return 0
end

-- Doc-commented in list.lua...
local function elems (l)
  local n = 0
  return function (l)
    n = n + 1
    if n <= #l then
      return l[n]
    end
  end,
  l, true
end

--- Concatenate lists.
-- @param ... lists
-- @return `{l<sub>1</sub>[1], ...,
-- l<sub>1</sub>[#l<sub>1</sub>], ..., l<sub>n</sub>[1], ...,
-- l<sub>n</sub>[#l<sub>n</sub>]}`
local function concat (...)
  local r = new ()
  for l in elems ({...}) do
    for v in elems (l) do
      table.insert (r, v)
    end
  end
  return r
end

local function _leaves (it, tr)
  local function visit (n)
    if type (n) == "table" then
      for _, v in it (n) do
        visit (v)
      end
    else
      coroutine.yield (n)
    end
  end
  return coroutine.wrap (visit), tr
end

-- Metamethods for lists
-- It would be nice to define this in `list.lua`, but then we
-- couldn't keep `new` here, and other modules that really only
-- need `list.new` (as opposed to the entire `std.list` API) get
-- caught in a dependency loop.
local metatable = {
  -- list .. table = list.concat
  __concat = concat,

  -- list == list retains its referential meaning
  --
  -- list < list = list.compare returns < 0
  __lt = function (l, m) return compare (l, m) < 0 end,

  -- list <= list = list.compare returns <= 0
  __le = function (l, m) return compare (l, m) <= 0 end,

  __append = append,
}

--- List constructor.
-- Needed in order to use metamethods.
-- @param t list (as a table), or nil for empty list
-- @return list (with list metamethods)
function new (t)
  return setmetatable (t or {}, metatable)
end


-- Doc-commented in tree.lua...
local function ileaves (tr)
  assert (type (tr) == "table",
  "bad argument #1 to 'ileaves' (table expected, got " .. type (tr) .. ")")
  return _leaves (ipairs, tr)
end

-- Doc-commented in tree.lua...
local function leaves (tr)
  assert (type (tr) == "table",
  "bad argument #1 to 'leaves' (table expected, got " .. type (tr) .. ")")
  return _leaves (pairs, tr)
end

local base = {
  append       = append,
  clone        = clone,
  clone_rename = clone_rename,
  compare      = compare,
  concat       = concat,
  elems        = elems,
  ileaves      = ileaves,
  leaves       = leaves,
  merge        = merge,
  new          = new,

  -- list metatable
  _list_mt     = metatable,
}




--[[--
Container object.

A container is a @{std.object} with no methods.  It's functionality is
instead defined by its *meta*methods.

Where an Object uses the `\_\_index` metatable entry to hold object
methods, a Container stores its contents using `\_\_index`, preventing
it from having methods in there too.

Although there are no actual methods, Containers are free to use
metamethods (`\_\_index`, `\_\_sub`, etc) and, like Objects, can supply
module functions by listing them in `\_functions`.  Also, since a
@{std.container} is a @{std.object}, it can be passed to the
@{std.object} module functions, or anywhere else a @{std.object} is
expected.

Container derived objects returned directly from a `require` statement
may also provide module functions, which can be called only from the
initial prototype object returned by `require`, but are **not** passed
on to derived objects during cloning:

> Container = require "std.container"
> x = Container {}
> = Container.prototype (x)
Object
> = x.prototype (o)
stdin:1: attempt to call field 'prototype' (a nil value)
...

To add functions like this to your own prototype objects, pass a table
of the module functions in the `_functions` private field before
cloning, and those functions will not be inherited by clones.

Container = require "std.container"
Graph = Container {
  _type = "Graph",
  _functions = {
    nodes = function (graph)
      local n = 0
      for _ in pairs (graph) do n = n + 1 end
      return n
    end,
  },
}
g = Graph { "node1", "node2" }
= Graph.nodes (g)
2
= g.nodes
nil

When making your own prototypes, start from @{std.container} if you
want to access the contents of your objects with the `[]` operator, or
@{std.object} if you want to access the functionality of your objects
with named object methods.

@classmod std.container
]]



local clone, merge = base.clone, base.merge


local ModuleFunction = {
  __call     = function (self, ...) return self.call (...) end,
}


--- Mark a function not to be copied into clones.
--
-- It responds to `type` with `table`, but otherwise behaves like a
-- regular function.  Marking uncopied module functions in-situ like this
-- (as opposed to doing book keeping in the metatable) means that we
-- don't have to create a new metatable with the book keeping removed for
-- cloned objects, we can just share our existing metatable directly.
-- @func fn a function
-- @treturn functable a callable functable for `fn`
local function modulefunction (fn)
  return setmetatable ({_type = "modulefunction", call = fn}, ModuleFunction)
end


--- Return `obj` with references to the fields of `src` merged in.
-- @static
-- @tparam table obj destination object
-- @tparam table src fields to copy int clone
-- @tparam[opt={}] table map `{old_key=new_key, ...}`
-- @treturn table `obj` with non-private fields from `src` merged, and
--   a metatable with private fields (if any) merged, both sets of keys
--   renamed according to `map`
-- @see std.object.mapfields
local function mapfields (obj, src)
  local mt = getmetatable (obj) or {}

  -- Map key pairs.
  for k, v in pairs (src) do
    local key, dst = k, obj

    -- change dst from obj to mt if key starts with '_'
    if type(key) == "string" and key:sub(1, 1) == "_" then
      dst = mt
    end

    dst[key] = v
  end

  -- Inject module functions.
  for k, v in pairs (src._functions or {}) do
    obj[k] = modulefunction (v)
  end

  -- Only set non-empty metatable.
  if next (mt) then
    setmetatable (obj, mt)
  end
  return obj
end


-- Type of this container.
-- @static
-- @tparam  std.container o  an container
-- @treturn string        type of the container
-- @see std.object.prototype
local function prototype (o)
  return (getmetatable (o) or {})._type or type (o)
end


--- Container prototype.
-- @table std.container
-- @string[opt="Container"] _type type of Container, returned by
--   @{std.object.prototype}
-- @tfield table|function _init a table of field names, or
--   initialisation function, used by @{__call}
-- @tfield nil|table _functions a table of module functions not copied
--   by @{std.object.__call}
local metatable = {
  _type = "Container",
  _init = {},

  --- Return a clone of this container.
  -- @function __call
  -- @param x a table if prototype `_init` is a table, otherwise first
  --   argument for a function type `_init`
  -- @param ... any additional arguments for `_init`
  -- @treturn std.container a clone of the called container.
  -- @see std.object:__call
  __call = function (self, x, ...)
    local mt     = getmetatable(self)
    local obj_mt = mt
    local obj    = {}

    -- This is the slowest part of cloning for any objects that have
    -- a lot of fields to test and copy.  If you need to clone a lot of
    -- objects from a prototype with several module functions, it's much
    -- faster to clone objects from each other than the prototype!
    for k, v in pairs(self) do
      if type(v) ~= "table" or v._type ~= "modulefunction" then
        obj[k] = v
      end
    end

    if type(mt._init) == "table" then
      obj = mapfields(obj, x, mt._init)
    else
      obj = mt._init(obj, x, ...)
    end

    -- If a metatable was set in init ↑, then merge our fields
    if next (getmetatable(obj) or {}) then
      obj_mt = merge( 
        clone(mt), 
        getmetatable(obj)
      )

      -- Merge object methods if both are tables
      if type(obj_mt.__index) == "table" 
          and type((mt or {}).__index) == "table" 
          then

          obj_mt.__index = merge(clone(mt.__index), obj_mt.__index)
      end
    end

      return setmetatable(obj, obj_mt)
    end,




    --- Return a table representation of this container.
    -- @function __totable
    -- @treturn table a shallow copy of non-private container fields
    -- @see std.object:__totable
    __totable  = function (self)
      local t = {}
      for k, v in pairs (self) do
        if type (k) ~= "string" or k:sub (1, 1) ~= "_" then
          t[k] = v
        end
      end
      return t
    end,
  }

  return setmetatable ({

    -- Normally, these are set and wrapped automatically during cloning.
    -- But, we have to bootstrap the first object, so in this one instance
    -- it has to be done manually.

    mapfields = modulefunction (mapfields),
    prototype = modulefunction (prototype),
  }, metatable)
