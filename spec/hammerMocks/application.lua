local prop = require 'spec.hammerMocks.utils.prop'

--[[ NOTES {{{
__eq           = <function 1>,
__gc           = <function 2>,
__index        = <table 1>,
__name         = "hs.application",
__tostring     = <function 3>,
__type         = "hs.application",
_activate      = <function 4>,
_bringtofront  = <function 5>,

activate       = <function 6>,
allWindows     = <function 7>,
bundleID       = <function 8>,
findMenuItem   = <function 9>,
findWindow     = <function 10>,
focusedWindow  = <function 11>,
getMenuItems   = <function 12>,
getWindow      = <function 13>,
hide           = <function 14>,
isApplication  = <function 15>,
isFrontmost    = <function 16>,
isHidden       = <function 17>,
isRunning      = <function 18>,
isUnresponsive = <function 19>,
isWindow       = <function 20>,
kill           = <function 21>,
kill9          = <function 22>,
kind           = <function 23>,
mainWindow     = <function 24>,
name           = <function 25>,
newWatcher     = <function 26>,
path           = <function 27>,
pid            = <function 28>,
role           = <function 29>,
selectMenuItem = <function 30>,
selectedText   = <function 31>,
setFrontmost   = <function 32>,
title          = <function 25>,
unhide         = <function 33>,
visibleWindows = <function 34>
]]  -- }}}

application = {}

application.__data = {
  bundleIDs = setmetatable({
    ['kitty'] = "net.kovidgoyal.kitty",
    ['Google Chrome'] = "com.google.Chrome",
    ['Finder'] = "com.apple.finder",
  }, {__index = 'com.default.bundleid'})
}
application.__defaults = {}
application.__defaults.name = 'kitty'

function application:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    o.name      = o.name or self.__defaults.name
    o.bundleID  = o.bundleID or self.__data.bundleIDs[o.name]
    return prop.wrap(o)
end

return application
