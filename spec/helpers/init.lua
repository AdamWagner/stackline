package.path = package.path .. '/usr/local/lib/lua/5.3/?.lua;'
package.path = package.path .. '/Users/adamwagner/.hammerspoon/?.lua;'
package.path = package.path .. '/Users/adamwagner/.hammerspoon/?/init.lua;'
package.path = package.path .. '/Users/adamwagner/.hammerspoon/stackline/?.lua;'
package.path = package.path .. '/Users/adamwagner/.hammerspoon/stackline/?/init.lua;'
package.path = package.path .. '/Applications/Hammerspoon.app/Contents/Resources/extensions/?/init.lua;'

require 'spec.helpers.assertions'
assert, match, spy = require 'luassert', require 'luassert.match', require 'luassert.spy'

local function reloadMock() -- {{{
  hs = nil
  _G.hs = nil
  for k, _ in pairs(package.loaded) do
    local hsmock = k:match('hammerMocks')
    if hsmock then
      package.loaded[k] = nil
    end
  end

  _G['u'] = require 'stackline.lib.utils' -- load utils globally
  local hammer = require 'spec.hammerMocks' -- return hammerspon mocks
  _G['hammer'] = hammer
  _G['hs'] = hammer
  return hammer
end -- }}}

local function methodSpy(obj, methodName, args) -- {{{
  local spy = spy.on(obj, methodName)
  local result = obj[methodName](obj, table.unpack(args))
  assert.spy(spy).was_called()
  assert.spy(spy).was_called_with(match.is_ref(obj), table.unpack(args))
  return result
end -- }}}

_G.helpers = {
  reloadMock = reloadMock,
  methodSpy = methodSpy,
}
