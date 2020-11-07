
-- Begin Query tests
-- ———————————————————————————————————————————————————————————————————————————
describe('#module Query', function()
  before_each(function()  -- {{{
    helpers.setupFile()
    helpers.loadFixture()
    helpers.initStackline()
    asyncTest = helpers.asyncTest
  end)  -- }}}

  it('groups byStack', function() -- {{{
    local expected = state.summary.numStacks

    local byStack, byApp = Query.groupWindows(ws)
    local numStacks = #u.values(byStack)

    assert.is.equal(expected, numStacks)
  end) -- }}}

  describe('byStack', function()
    local expected = state.summary.stacksSummary

    -- u.p(expected[1])
    local byStack, byApp = Query.groupWindows(ws)

    it('dimensions are correct', function() -- {{{
      local expectedStackDims = u.map(expected, function(s)
        return s.id
      end)
      local actualStackDims = u.keys(byStack)
      table.sort(expectedStackDims)
      table.sort(actualStackDims)
      assert.are_same(expectedStackDims, actualStackDims)
    end) -- }}}

    -- FOR EACH STACK
    for k, v in pairs(expected) do
      local match = byStack[v.id]

      it('#' .. k .. ': numWindows', function()  -- {{{
        local actualNumWin = #match
        assert.is_equal(v.numWindows, actualNumWin)
      end)  -- }}}

      -- EACH WINDOW IN STACK
      describe('#' .. k .. ': wfzy eq sid', function() 
        u.each(v.winDims, function(window)   -- u.p(window.frame:getarea()) {{{
          local stackId = stackline.window:makeStackId( {
                frame = function()
                  return window.frame
                end
              })

          local fzyFrame = stackId.fzyFrame
          local winStackId = stackId.stackId
          local stackStackId = v.id

          local template = 'for %s'
          local testName = template:format(window.id)
          it(testName, function()
            assert.are_equal(fzyFrame, stackStackId)
          end)
        end)
      end)  -- }}}

      describe('#' .. k .. ': deltas lt fzzfactor - 2', function()
        -- EACH WINDOW IN STACK
        u.each(v.winDims, function(window)  -- {{{
          local stackId = stackline.window:makeStackId( {
                frame = function()
                  return window.frame
                end
              })

          local fzyFrame = stackId.fzyFrame
          local winStackId = stackId.stackId
          local stackStackId = v.id

          local template = 'for %s'
          local testName = template:format(window.id)

          it(testName, function()
            local function parseStackId(s)
              return u.imap(s:split('|'), function(s) return tonumber(s) end)
            end

            local x = parseStackId(winStackId)
            local y = parseStackId(stackStackId)

            local deltas = u.map(u.zip(x,y), function(pair) 
              return math.abs(pair[1] - pair[2])
            end)

            u.each(deltas, function(d) 
              local fuzzFactor = stackline.config:get('features.fzyFrameDetect.fuzzFactor')
              assert.less_than(fuzzFactor - 2, d)
            end) -- end each delta

          end) -- end fuzzy delta test

         end)  -- end each window }}}

      end)

    end -- end each stack
  end) -- end 'byStack' block

  describe('stack indexes', function()
  -- ASYNC    {{{
  -- https://github.com/Olivine-Labs/busted/issues/545
  -- You'll want to use version 1x, rather than version 2x, for async support.

  -- https://github.com/feltech/feltest
  -- ↑ this DOES support async. :( Oh man 

  -- https://github.com/bluebird75/luaunit/issues/121
  -- ↑ GH Issue about supporting async with luaunit }}}

    it('are retrieved', function() -- {{{
      local actual = asyncTest:run(function()
          local _, stackIndexes = getWinStackIdxs() -- async shell call to yabai
          local ok, parsed = pcall(hs.json.decode, stackIndexes)
            asyncTest:set('resolved', parsed)
          end)

      assert.is_table(actual)
    end) -- }}}

    it('match expectation', function() -- {{{
      local expected = state.stackIndexes

      local actual = asyncTest:run(function()
          local _, stackIndexes = getWinStackIdxs() -- async shell call to yabai
          local ok, parsed = pcall(hs.json.decode, stackIndexes)
            asyncTest:set('resolved', parsed)
          end)

      assert.is_same(actual, expected)

    end) -- }}}
  end)

end)
