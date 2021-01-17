-- INSPO
--   https://github.com/pawel-miczka/mta-lua-collections/blob/master/collection.lua
--   https://github.com/sorcerykid/collections/blob/master/init.lua
--   https://github.com/renatomaia/loop-collections/tree/master/lua/loop/collection
--   https://github.com/kurapica/PLoop

-- {{{ Testing data / exmaple
--[[
data = {
  {
  name='JohnDoe',
  age = 33,
  friends = {
    {name='bob'},
    {name='michelle'},
    {name='JaneDoe'},
    {name='sandy'},
    {name='cindy'},
    }
  },
  {
  name='JaneDoe',
  age = 36,
  friends = {
    {name='bob'},
    {name='michelle'},
    {name='JaneDoe'},
    {name='sandy'},
    {name='cindy'},
    }
  },
  {
  name='bob',
  age = 55,
  friends = {
    {name='bob'},
    {name='michelle'},
    {name='JaneDoe'},
    {name='sandy'},
    {name='cindy'},
    }
  },
  type = 'example',
  version = 1.05
}

a = u.dcopy(data)
b = u.dcopy(data)
Container = require 'lib.Container'
r = Container(data)

]]
-- }}}

local u = require 'lib.utils'
local Class = require 'lib.Class'

-- Container
local Container = Class()

function Container:__index(k)
  return rawget(self, k)
end


function Container:new(o)
  for k,v in pairs(o or {}) do
    self[k] = v
  end
  return self
end

function Container:attr(key, val)  -- {{{
    -- Set private attributes that are returned when access directly, but not when iterating {{{
    -- Example:
    --   Box = Container:new()
    --   Box.attr('type', 'Box')
    --   Box.type
    --      → 'Box'
    --   Box:print()
    --      → {} }}}
  getmetatable(self)[key] = val
  return self
end  -- }}}

function Container:size(makeFlat)  -- {{{
  --- Counts the number of 1st-level values by default
  --   Can optionally and run self:unnest() before counting

  local toCount
  if makeFlat then toCount = self:flatten(self) end

  local i = 0
  for _,_ in pairs(toCount or self) do i = i + 1 end
  return i
end

Container.len = Container.size
-- }}}

function Container:push(value) -- {{{
    table.insert(self, value)
    return self
end-- }}}

function Container:set(key, value) -- {{{
    table.insert(self, key, value)
    return self
end-- }}}

function Container:clone(t) -- {{{
  return setmetatable(t or self, getmetatable(self))
end-- }}}

function Container:copy() -- {{{
  return u.deepcopy(self)
end-- }}}

function Container:raw() -- {{{
  return u.copy(self)
end-- }}}

function Container:values() -- {{{
  return self:clone(u.values(self))
end-- }}}

function Container:keys() -- {{{
  return self:clone(u.keys(self))
end-- }}}

function Container:contains(val) -- {{{
  return self:clone(u.contains(self, val))
end-- }}}

function Container:each(fn) -- {{{
  return self:clone(u.each(self, fn))
end-- }}}

function Container:filter(fn) -- {{{
  return self:clone(u.filter(self, fn))
end-- }}}

function Container:pipe(...) -- {{{
  return self:clone(u.pipe(...)(self))
end-- }}}

function Container:where(key, value) -- {{{
  -- print(self[1])
  -- print(type(self[1]))
  -- if self[1]==nil or type(self[1]~='table') then
  if self[1]==nil then
    print(':where(…) requires Container to be a table of tables')
    return self
  end

  local result = self:filter(function(tbl)
    return tbl[key] == value
  end)

  return #result == 1
    and result[1]
    or self:clone(result)
end-- }}}

function Container:map(...) -- {{{
  return self:clone(u.map(self, ...))
end-- }}}

function Container:transform(...) -- {{{
  for k,v in pairs(u.map(self, ...)) do
    self[k] = v
  end
  return self
end-- }}}

function Container:join(sep) -- {{{
  local space = ' '
  local seperator = sep or space
  return table.concat(self, seperator)
end-- }}}

function Container:flatten(depth) -- {{{
  return self:new(u.flatten(self, depth))
end-- }}}

function Container:unnest() -- {{{
  return self:new(u.unnest(self))
end-- }}}

function Container:print(_depth) -- {{{
  u.printBox(self, _depth)
  return self
end-- }}}

function Container:__call(...)
  return self:clone(...)
end

return Container
