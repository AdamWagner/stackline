--[[
Collection mixin: keyed storage and standard iteration for container classes.
Inserted into the __index chain so that Stack and Stackmanager inherit a
consistent interface — add/remove/clear, get/has/count/first, each/map/filter/find/any.

Usage:
  local MyClass = setmetatable({}, Collection)
  MyClass.__index = MyClass

Items are stored in self._items = {[id] = item}. Each item must have an .id field.
]]

local Collection = {}
Collection.__index = Collection

-- Storage -------------------------------------------------------------------

function Collection:add(item)
    if not self._items then self._items = {} end
    self._items[item.id] = item
end

function Collection:remove(id)
    if self._items then self._items[id] = nil end
end

function Collection:clear()
    self._items = {}
end

-- Lookup --------------------------------------------------------------------

function Collection:get(id)
    if not self._items then return id and nil or {} end
    if id then return self._items[id] end
    return u.values(self._items)
end

function Collection:has(id)
    return self._items ~= nil and self._items[id] ~= nil
end

function Collection:count()
    if not self._items then return 0 end
    return u.length(self._items)
end

function Collection:first()
    if not self._items then return nil end
    local _, item = next(self._items)
    return item
end

-- Iteration -----------------------------------------------------------------

function Collection:each(fn)
    u.each(self:get(), fn)
end

function Collection:map(fn)
    return u.map(self:get(), fn)
end

function Collection:filter(fn)
    return u.filter(self:get(), fn)
end

function Collection:find(fn)
    for _, item in pairs(self._items or {}) do
        if fn(item) then return item end
    end
end

function Collection:any(fn)
    return u.any(self:get(), fn)
end

-- Debug ---------------------------------------------------------------------

function Collection:__tostring()
    return ('<Collection: %d items>'):format(self:count())
end

return Collection
