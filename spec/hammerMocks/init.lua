return {
    -- constants
    configdir = os.getenv('HOME') .. '/.hammerspoon',

    -- geometry, in, and fnutils *can* be required directly!
    -- they neither directly nor indirectly depend on 'internal.so' files
    geometry = require 'hs.geometry',
    inspect = require 'hs.inspect',
    fnutils = require 'hs.fnutils',

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
