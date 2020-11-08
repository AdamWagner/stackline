local log = helpers.logSetup('mock_spaces')

local spaces = {}
spaces.watcher = {}

function spaces:set(spaces)
  self._spaces = spaces
end

function spaces.watcher.new()
  local sp = {}
  setmetatable(sp, spaces)
  spaces.__index = spaces
  return sp
end

function spaces:start()
  log.d('starting spaces watcher')
end

return spaces
