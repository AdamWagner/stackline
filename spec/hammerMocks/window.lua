--[[
  == hs.window.* mock ==

  Stackline references to `hs.window.*` modules:
    hs.window
    hs.window.filter
    hs.window.filter.new
    hs.window.focusedwindow
]]

winData = { { -- {{{
    app = "Hammerspoon",
    frame = { h = 1074, w = 626, x = 2302, y = 38 },
    id = 14523
  }, {
    app = "TextEdit",
    frame = { h = 556, w = 626, x = 2302, y = 1127 },
    id = 17194
  }, {
    app = "Notes",
    frame = { h = 555, w = 642, x = 2302, y = 1127 },
    id = 17154
  }, {
    app = "Google Chrome",
    frame = { h = 555, w = 626, x = 2302, y = 1127 },
    id = 16444
  }, {
    app = "kitty",
    frame = { h = 1644, w = 2207, x = 80, y = 38 },
    id = 3791
  }, {
    app = "iTerm2",
    frame = { h = 555, w = 626, x = 2302, y = 1127 },
    id = 16449
  }, {
    app = "Google Chrome",
    frame = { h = 1644, w = 2207, x = 80, y = 38 },
    id = 8942
  }, {
    app = "kitty",
    frame = { h = 1644, w = 2207, x = 80, y = 38 },
    id = 15180
} } -- }}}

local bind = require 'lib.utils.functional'.bind

local description = bind(string.format, 'hs.%s instance: %s')

local function createHsInstance(kind, source)
  local mt = u.dcopy(source)
  mt.__index = mt
  mt.__type = string.format('hs.%s', kind)
  mt.__tostring = description(kind, source.id or 'none')
  return setmetatable({}, mt)
end

local function createApplication(appName)
  return createHsInstance('application', {
    name = function() 
      return appName
    end
  })
end


local function createWindow(w)
  return createHsInstance('window', {
    id = function() return w.id end,
    application = createApplication(w.app),
    frame = function()
      return hs.geometry(w.frame)
    end
  })
end

return {
  filter = function()
    return u.map(winData, createWindow)
  end
}
