require 'lib.updatePackagePath'
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

  if not _G['u'] then
    _G['u'] = require 'lib.utils' -- load utils globally
  end

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
