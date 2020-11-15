-- INSTRUCTIONS: CAPTURE LIVE STATE → FIXTURE DATA
--  1. Open Hammerspoon console
--  2. Paste in console:
--  3. Execute
--      capture = require 'stackline.spec.fixtures.capture'
--      'capture.screenState()'
--      'capture.managerIngest()'
--  4. A new file with the requested data be created in stackline/tests/fixtures/data/{filename}.lua
-- -----------------------------------------------------------------------------
--
-- general utils
local async = require 'stackline.lib.async'

-- fixture capture helpers
local mappers = require 'spec.fixtures.mappers'
local converter = require 'spec.fixtures.file-writer'

-- stackline modules
local Query = require 'stackline.stackline.query'

-- Constants
local HS_PATH = os.getenv('HOME') .. '/.hammerspoon'
local FIXTURE_DATA_PATH = HS_PATH .. '/stackline/spec/fixtures/data'
local YABAI_SCRIPT_PATH = HS_PATH .. '/stackline/bin/yabai-get-stack-idx'

-- ———————————————————————————————————————————————————————————————————————————
-- Capture state → fixture data
-- ———————————————————————————————————————————————————————————————————————————
local function makeFilename(data) -- {{{
  local countWindows = u.numberWordMap[u.reduce(data.numWindows, function(a, b) return a + b end)]
  local countStacks = u.numberWordMap[data.numStacks]

  return string.format('%s_S__%s_W_%s', countStacks, countWindows, u.uniqueHash(data))
end -- }}}

local function get_screen_state(stackIdxs) -- {{{
  local state = {}

  state.screen = mappers.screen(hs.screen.mainScreen())
  state.config = stackline.config:get()
  state.stackline = u.map(stackline.manager:get(), mappers.stack)
  state.stackIndexes = stackIdxs or nil
  state.summary = stackline.manager:getSummary()
  state.summary.topLeft = nil -- duplicative ofdimensions'. Convenient in app, but extra weight here b/c of unique hash

  state.meta = {
    num_total_wins = #state.screen.windows,
    num_stacked_wins = u.reduce(state.summary.numWindows, function(a,b) return a+b end),
    num_stacks = state.summary.numStacks,
  }

  return state
end -- }}}

local function screen_state_fixture() -- {{{
  async(function()
    -- build state
    local winStackIndexes = hs.json.decode(Query.getWinStackIdxs())
    local state = get_screen_state(winStackIndexes)

    -- make dynamic fixture filepath
    local filename = makeFilename(state.summary) -- make filename using stackline summary
    local filepath = string.format('%s/screen_state/%s.lua', FIXTURE_DATA_PATH, filename)

    -- write to file
    converter.convertTable(state, filepath)
  end)
end -- }}}

return {
  screenState = screen_state_fixture,
  -- managerIngest = save_manager_ingest,
}

-- TODO: Remove if remains unsued after 2020-11-14 -----------------------------
-- local function save_manager_ingest(windowGroups, appWindows, shouldClean) -- {{{
--   u.pheader('window groups')
--   u.p(windowGroups)

--   print('-----------------\n\n\n')
--   u.pheader('app windows')
--   u.p(appWindows)

--   print('-----------------\n\n\n')
--   u.pheader('shouldClean')
--   u.p(shouldClean)

--   local args = {
--     windowGroups = u.map(windowGroups, mappers.group),
--     appWindows = u.map(appWindows, mappers.app),
--     shouldClean = shouldClean,
--   }
--   u.p(args)
--   local filename = string.format('%s_groups_%s_appwindows_%s', u.length(windowGroups),
--       u.length(appWindows), u.uniqueHash(args))
--   local filepath = string.format('%s/manager_ingest/%s.lua', FIXTURE_DATA_PATH, filename)
--   converter.convertTable(args, filepath)
--   return args
-- end -- }}}

