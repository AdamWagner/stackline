local async = require 'stackline.lib.async'

local are_stackline_wins = helpers.schemas.entities.are_stackline_wins
local is_stackline_win = helpers.schemas.entities.is_stackline_win
local is_hs_win = helpers.schemas.entities.is_hs_win
local is_groupedwins = helpers.schemas.entities.is_groupedwins

local function applyFixture(fixturePath)  -- {{{
  if type(fixturePath) == 'string' then
    fixture = require 'spec.fixtures.load'(fixturePath)
  else
    fixture = require 'spec.fixtures.load'()
  end
  hs.window.filter:set(fixture.screen.windows)
  hs.task:set(fixture.stackIndexes)
  return fixture
end  -- }}}

local function startStackline(fixture)  -- {{{
  stackline = require 'stackline.stackline'
  stackline:init(fixture.config)
  -- NOTE: the only way to test various fuzzFactors
  -- (e.g., "disabled") is to pass in config from fixture.
  query = require 'stackline.query'
end  -- }}}

local function makeWindows()  -- {{{
  ws = hs.window.filter:new():getWindows()
  windows = u.map(ws, function(w)
    return stackline.window:new(w)
  end)
end  -- }}}

local function prepareExpected()  -- {{{
    -- Get the appropriate stackId field from summary based on whether fzyFrameDetect is enabled
  local groupKey = stackline.config:get('.features.fzyFrameDetect.enabled')
                    and 'dimensionsFzy'
                    or 'dimensions'

  expected = u.zip(fixture.summary.numWindows, fixture.summary[groupKey])
  return expected
end  -- }}}

local function setupQueryTests()  -- {{{
  hs = helpers.reloadMock()
  fixture = applyFixture()
  startStackline(fixture)
  makeWindows()
  return fixture
end  -- }}}

describe('#module #query', function()

  setup(setupQueryTests)

  it('maps stackline wins', function()  -- {{{
    local ok, err = are_stackline_wins(windows)
    if not ok then error(err) end
  end)  -- }}}

  it('has hs wins', function()  -- {{{
    local ok, err = is_hs_win(windows[1]._win)
    if not ok then error(err) end
  end)  -- }}}

  it('does basic group by stack', function()  -- {{{
    local byStack = query.groupByStack(windows)
    ok, err = is_groupedwins(byStack)
    if not ok then error(err) end
  end)  -- }}}

  it('does basic group by app', function()  -- {{{
    local byStack = query.groupByStack(windows)
      -- NOTE: byApp keys = app names, values = arrays of stackline windows
    local byApp = query.groupByApp(byStack, windows)
    ok, err = is_groupedwins(byApp)
    if not ok then error(err) end
  end)  -- }}}

  it('gets stack indexes from yabai', function()  -- {{{
    local winStackIndexes
    async(function()
      local stackIndexResponse = query.getWinStackIdxs()
      winStackIndexes = hs.json.decode(stackIndexResponse)
        -- winStackIndexes['226'] = 99   -- sanity-check that async tests work by intentionally breaking something
    end)
      -- NOTE: will always pass when assert() is *inside* of async(…) func, so keep outside.
    assert.same(fixture.stackIndexes, winStackIndexes)
  end)  -- }}}

  -- NOTE: avoid assigning vars using _G.varname = … in setup() or before_each()
        -- describe() blocks manage their own scope, which assigning to _G subverts
  u.each(helpers.scenario.getFixturePaths(), function(fixturePath)

    describe('', function()

      setup(function()
        -- NOTE: extracting these fns to a local helper fn breaks subsequent tests.
        -- TODO: Find out how to extract these setup fns without breaking subsequent tests
        hs = helpers.reloadMock()
        fixture = applyFixture(fixturePath)
        startStackline(fixture)
        makeWindows()

        byStack = query.groupByStack(windows)
        expected = prepareExpected()
        io.write('\n\nSCENARIO: ' .. fixture.meta.description) -- separate each scenario in the output
      end)

      describe('byStack', function()

        it('correct num grps', function()
          local byStack = query.groupByStack(windows)
          assert.same(fixture.summary.numStacks, u.len(byStack))
        end)

        describe('num wins in grp', function()

          for _, v in pairs(expected) do -- for each stack
            local numWin, stackId = v[1], v[2]
            local thisStack = byStack[stackId]
            local testDescription = stackId .. ' (exp ' .. numWin .. ', got ' .. #thisStack .. ')'
            it(testDescription, function()
              assert.same(numWin, #thisStack)
            end)
          end
        end) -- describe: num wins in grp

      end) -- byStack block

      describe('byApp', function()

        it('correct num grps', function()
          local byApp = query.groupByApp(byStack, windows)
          local appCount = {}
          for k,v in pairs(byApp) do
            appCount[k] = u.len(v)
          end
          assert.same(appCount, fixture.summary.appCount)
        end)

      end) -- byApp block
    end) -- empty describe('') to setup tests

  end) -- each scenario
end) -- end #module #query
