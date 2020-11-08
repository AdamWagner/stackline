return {
    -- constants
    configdir = os.getenv('HOME') .. '/.hammerspoon',

    -- geometry, inspect, and fnutils *can* be required directly!
    -- they neither directly nor indirectly depend on 'internal.so' files
    geometry = require 'hs.geometry',
    inspect = require 'hs.inspect',
    fnutils = require 'hs.fnutils',

    -- The rest are custom mocks
    appfinder = require 'spec.hammerMocks.appfinder',
    application = require 'spec.hammerMocks.application',
    canvas = require 'spec.hammerMocks.canvas',
    event = require 'spec.hammerMocks.event',
    eventtap = require 'spec.hammerMocks.eventtap',
    image = require 'spec.hammerMocks.image',
    ipc = { localPort = function() end },
    json = require 'spec.hammerMocks.json', -- luarocks module. NOT == stackline.lib.json (which is dkjson… such a mess)
    logger = require 'spec.hammerMocks.logger',
    notify = require 'spec.hammerMocks.notify',
    screen = require 'spec.hammerMocks.screen',
    spaces = require 'spec.hammerMocks.spaces',
    task = require 'spec.hammerMocks.task',
    timer = require 'spec.hammerMocks.timer',
    window = require 'spec.hammerMocks.window',
}
