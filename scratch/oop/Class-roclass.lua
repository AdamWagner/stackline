-- FROM: https://github.com/optimisticside/roclass/blob/main/src/init.lua
-- good documentation

--[[

EXAMPLE
    Box = Base("Box")
    function Box:new(stuff)
      self._stuff[#self._stuff+1] = stuff
      return self
    end
    function Box:getStuff()
      return self._stuff
    end

    bbox = Box:new({thing = 'envelope', trash = true})
    for k,v in bbox do print(k,v) end -- all the yuckiness prints :(


]]


function create(baseTable, class)
  local specialFields = {
    class = class,
  }

  local metaTable
  metaTable = {
    __index = function(self, index, value)
      local fromClass = metaTable[index]
      if fromClass then
	return fromClass
      end

      local fromProperties = class["get" .. string.upper(string.sub(index, 1, 1)) .. string.sub(index, 2)]
      if fromProperties then
	return fromProperties
      end

      local fromSpecialFields = specialFields[index]
      if fromSpecialFields then
	return fromSpecialFields
      end
    end,

    __newindex = function(self, index, value)
      local fromProperties = class["set" .. string.upper(string.sub(index, 1, 1)) .. string.sub(index, 2)]
      if fromProperties then
	return fromProperties(value)
      end

      baseTable[index] = value
    end,

    __tostring = function()
      return class.className
    end,
  }

  local extendedClasses = {}
  local extendClass

  function extendClass(class)
    if not table.find(extendedClasses, class) then
      extendedClasses[#extendedClasses+1] = class

      for _, superClass in ipairs(class.extends or {}) do
	extendClass(superClass)
      end

      for member, value in pairs(class) do
	metaTable[member] = value
      end
    end
  end

  for _, superClass in ipairs(class.extends or {}) do
    extendClass(superClass)
  end

  for member, value in pairs(class) do
    metaTable[member] = value
  end

  if baseTable and not baseTable._disableInternal then
    for member, value in pairs(baseTable._base or {}) do
      metaTable[member] = value
    end

    for _, superClass in ipairs(baseTable._extends or {}) do
      extendClass(superClass)
    end
  end

  return setmetatable(baseTable or {}, metaTable)
end

function class(name, ...)
  local extends = {...}

  local class = {
    className = name,
    extends = extends,
    create = function(class, baseTable)
      return create(baseTable, class)
    end,
    extend = function(baseClass, className, ...)
      return class(className, baseClass, ...)
    end,
  }

  return setmetatable(class, {
    __call = function(self, ...)
      return self.new and self.new(...)
    end
  })
end

return class
