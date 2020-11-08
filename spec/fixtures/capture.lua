-- INSTRUCTIONS
--  1. Open Hammerspoon console
--  2. Paste in console:
--      capture = require 'stackline.spec.fixtures.capture'
--  3. Execute
--      'capture.screenState()'
--      'capture.managerIngest()'
--  4. A new file with the requested data be created in stackline/tests/fixtures/data/{filename}.lua

-- REFERENCE:
--  /Applications/Hammerspoon.app/Contents/Resources/extensions/
local converter = require 'lib.save'

local fixtureDataPath = os.getenv('HOME') ..  '/.hammerspoon/stackline/tests/fixtures/data'
local yabaiScriptPath = os.getenv('HOME') ..  '/.hammerspoon/stackline/bin/yabai-get-stack-idx'

numberWordMap = setmetatable({ -- {{{
  "one", "two", "three", "four", "five",
  "six", "seven", "eight", "nine", "ten",
  "eleven", "twelve", "thirteen", "fourteen", "fifteen",
  "sixteen", "seventeen", "eighteen", "nineteen", "twenty",
}, {
  __index = function(_, k) -- special case for zero & anything more than 20
    return k == 0 and 'zero' or 'more than twenty'
  end,
}) -- }}}

local state = {}

-- return empty table if state.key doesn't exist
setmetatable(state, {
  __index = function()
    return {}
  end,
})

local function windowMapper(w) -- {{{
  return {
    id = w:id(),
    title = w:title(),
    application = {name = w:application():name()},
    frame = w:frame().table,

    -- NOT a native hs.window instance method!
    isFocused = hs.window.focusedWindow():id() == w:id(),

    -- I don't *think* these are used by stackline, but seems reasonable that
    -- they might be, so capturing them here
    isApplication = w:isApplication(),
    isFullScreen = w:isFullScreen(),
    isMaximizable = w:isMaximizable(),
    isMinimized = w:isMinimized(),
    isStandard = w:isStandard(),
    isVisible = w:isVisible(),
  }
end -- }}}

local function stackMapper(stack) -- {{{
  return {
    id = stack.id,
    windows = u.map(stack.windows, function(w)
      return {
        app = w.app,
        title = w.title,

        frame = w.frame.table,
        focus = w.focus,
        screenFrame = w.screenFrame.table,

        stackIdx = w.stackIdx,

        iconRadius = w.iconRadius,
        icon_rect = w.icon_rect,
        indicator_rect = w.indicator_rect,
        width = w.width,

        stackFocus = w.stackFocus,
        stackId = w.stackId,
        stackIdFzy = w.stackIdFzy,

        stack = {id = w.stack.id, numWindows = #w.stack.windows},
      }
    end),
  }
end -- }}}

function handleScreen(w)  -- {{{
  local hasWin = w._win
  local hasScreen = hasWin and w._win.screen
  if not hasScreen then return nil end

  local screen = { id =  w._win:screen():id(), frame = w._win:screen():frame() }
  return screen
end  -- }}}

function plainWindowMapper(w)  -- {{{
  return {
    _win = {},
    id = w.id,
    app = w.app,
    title = w.title,

    frame = w.frame,
    screen = handleScreen(w),

    stackId = w.stackId,
    stackIdFzy = w.stackIdFzy,
    stackIdx = w.stackIdx,
    topLeft = w.topLeft,
  }
end  -- }}}

local function groupMapper(group)   -- {{{
  return u.map(group, plainWindowMapper)
end  -- }}}

function appMapper(appWindows)  -- {{{
  local obj = {}
  for app,group in pairs(appWindows) do
    print("app")
    u.p(app)
    obj[app] = u.map(group, plainWindowMapper)
  end
  return obj
end  -- }}}

local function randomFilename() -- {{{
  local t = {}
  for i = 1, 10 do
    table.insert(t, string.char(math.random(97, 122)))
  end
  return string.format("%s_%s", table.concat(t), os.time())
end -- }}}

local function makeFilename(data)  -- {{{
  local countWindows = numberWordMap[u.reduce(data.numWindows, function(a, b) return a + b end)]
  local countStacks = numberWordMap[data.numStacks]

  return string.format('%s_stacks_%s_windows_%s', countStacks, countWindows, u.uniqueHash(data))
end  -- }}}

local function cache_state(stackIdxs) -- {{{
  local screen = hs.screen.mainScreen()
  local ws = stackline.wf:getWindows()

  state.stackIndexes = stackIdxs or nil

  state.screen = {
    id = screen:id(),
    name = screen:name(),
    frame = screen:frame().table,
    fullFrame = screen:fullFrame().table,
    windows = u.map(ws, windowMapper),
  }

  state.config = stackline.config:get()
  state.stackline = u.map(stackline.manager:get(), stackMapper)

  local summary = stackline.manager:getSummary()
  summary.topLeft = nil -- duplicative ofdimensions'. Convenient in app, but extra weight here b/c of unique hash
  state.summary = summary

  local filepath = string.format('%s/screen_state/%s.lua', fixtureDataPath, makeFilename(summary))

  converter.convertTable(state, filepath)
  return state
end -- }}}

local function save_state_to_fixture()  -- {{{
  return hs.task.new(yabaiScriptPath, function(_, stdout, _)
    local result = hs.json.decode(stdout)
    return cache_state(result)
  end):start():waitUntilExit()
end  -- }}}

local function save_manager_ingest(windowGroups, appWindows, shouldClean)  -- {{{
  -- u.pheader('window groups')
  -- u.p(windowGroups)
  print('-----------------\n\n\n')
  u.p(appWindows)
    local args = {
        windowGroups = u.map(windowGroups, groupMapper),
        appWindows = appMapper(appWindows),
        shouldClean = shouldClean,
    }
    -- u.p(args)
    local filename = string.format('%s_groups_%s_appwindows_%s', u.length(windowGroups), u.length(appWindows), u.uniqueHash(args))
    local filepath = string.format('%s/manager_ingest/%s.lua', fixtureDataPath, filename)
    converter.convertTable(args, filepath)
    return args
end  -- }}}

return {
  screenState = save_state_to_fixture,
  managerIngest = save_manager_ingest,
}

