require 'lib.updatePackagePath'
require 'spec.helpers.assertions'
assert, match, spy, mock = require 'luassert', require 'luassert.match', require 'luassert.spy', require 'luassert.mock'


-- SEE ⭐️ matthewfallshaw/hammerspoon  ⭐️
-- https://github.com/matthewfallshaw/hammerspoon-config/tree/master/spec
-- Has really clean & robust tests for his hammerspoon config!

local function loadBusted()  -- {{{
  require 'busted.runner'()
  _G.describe = require'busted'.describe
  _G.it = require'busted'.it
  _G.pending = require'busted'.pending
  _G.setup = require'busted'.setup
  _G.teardown = require'busted'.teardown
  _G.before_each = require'busted'.before_each
  _G.after_each = require'busted'.after_each
end  -- }}}

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

loadBusted()
require 'lib.updatePackagePath'
_G.hs = reloadMock()

_G.helpers = {
  scenario = require 'spec.helpers.scenario',
  schemas = require 'spec.helpers.schemas',
  loadBusted = loadBusted,
  reloadMock = reloadMock,
  methodSpy = methodSpy,
  test_utils = require 'spec.helpers.test-utils',
}
