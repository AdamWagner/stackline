-- ———————————————————————————————————————————————————————————————————————————
-- Mock Hammerspoon module
-- ———————————————————————————————————————————————————————————————————————————

return {
    -- constants
    configdir = os.getenv('HOME') .. '/.hammerspoon',

    -- These real hs modules do NOT depend on 'internal.so' files, so *can* be required directly!
    -- NOTE: package.path must include '/Applications/Hammerspoon.app/Contents/Resources/extensions/'
    geometry = require 'hs.geometry',
    inspect = require 'hs.inspect',
    fnutils = require 'hs.fnutils',
    watchable = require 'hs.watchable',
    tangent = require 'hs.tangent',
    utf8 = require 'hs.utf8',

    -- The rest are custom mocks
    appfinder = require 'hammerMocks.appfinder',
    application = require 'hammerMocks.application',
    canvas = require 'hammerMocks.canvas',
    event = require 'hammerMocks.event',
    eventtap = require 'hammerMocks.eventtap',
    image = require 'hammerMocks.image',
    ipc = { localPort = function() end },
    json = require 'hammerMocks.json', -- luarocks module. NOT == stackline.lib.json (which is dkjson… such a mess)
    logger = require 'hammerMocks.logger',
    notify = require 'hammerMocks.notify',
    screen = require 'hammerMocks.screen',
    spaces = require 'hammerMocks.spaces',
    task = require 'hammerMocks.task',
    timer = require 'hammerMocks.timer',
    window = require 'hammerMocks.window',
}
