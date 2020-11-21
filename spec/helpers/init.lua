require 'lib.updatePackagePath'
require 'spec.helpers.assertions'
assert, match, spy, mock = require 'luassert', require 'luassert.match', require 'luassert.spy', require 'luassert.mock'

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

local function methodSpy(obj, methodName) -- {{{
  -- build 2 spies (called / called with) for an object with self:method() methods
  local spy = spy.on(obj, methodName)

  local function method_was_called_with(params)
    params = u.isarray(params) and params or table.pack(params)
    return assert.spy(spy).was_called_with(
                    match.is_ref(obj),
                    table.unpack(params))
  end

  return assert.spy(spy).was_called, method_was_called_with
end -- }}}

_G.helpers = {
  scenario = require 'spec.helpers.scenario',
  reloadMock = reloadMock,
  methodSpy = methodSpy,
}
