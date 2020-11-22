local M = {}

function M.getStackIdsKey()    -- {{{
      -- Get the appropriate stackId field from summary based on whether fzyFrameDetect is enabled
  local groupKey = stackline.config:get('.features.fzyFrameDetect.enabled')
                    and 'dimensionsFzy'
                    or 'dimensions'
  return groupKey
end    -- }}}

function M.applyFixture(fixturePath)  -- {{{
  if type(fixturePath) == 'string' then
    fixture = require 'spec.fixtures.load'(fixturePath)
  else
    fixture = require 'spec.fixtures.load'()
  end
  hs.window.filter:set(fixture.screen.windows)
  hs.task:set(fixture.stackIndexes)
  return fixture
end  -- }}}

function M.startStackline(fixture)  -- {{{
  stackline = require 'stackline.stackline'
  stackline:init(fixture.config)
  -- NOTE: the only way to test various fuzzFactors
  -- (e.g., "disabled") is to pass in config from fixture.
  query = require 'stackline.query'
end  -- }}}

function M.makeWindows()  -- {{{
  ws = hs.window.filter:new():getWindows()
  windows = u.map(ws, function(w)
    return stackline.window:new(w)
  end)
end  -- }}}

function M.prepareExpected()  -- {{{
  return u.zip(
    fixture.summary.numWindows,
    fixture.summary[M.getStackIdsKey()]
  )
end  -- }}}

return M
