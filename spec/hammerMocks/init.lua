--[[
 == Mock Hammerspoon modules ==
]]
return {
  -- These real hs modules do NOT depend on 'internal.so' files, so *can* be required directly!
  -- NOTE: package.path must include '/Applications/Hammerspoon.app/Contents/Resources/extensions/'
  geometry = require 'hs.geometry',
  inspect = require 'hs.inspect',
  fnutils = require 'hs.fnutils',
  watchable = require 'hs.watchable',
  utf8 = require 'hs.utf8',

  -- The remaining hammerspoon modules require custom mocks
  json = require 'hammerMocks.json', -- https://github.com/rxi/json.lua
  logger = require 'hammerMocks.logger',
  window = require 'hammerMocks.window',
  console = {
    printStyledtext = print,
    historySize = function() end,
  },

  -- constants
  configdir = os.getenv('HOME') .. '/.hammerspoon',
}
