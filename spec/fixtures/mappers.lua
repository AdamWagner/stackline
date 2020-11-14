--[[
Map stacks, groups, windows, and apps into serializable data to be stored in fixture.

Highly coupled with design of hammerMocks: The mocks expect certain data in a certain way.
  These mappers prepare live data for serialization into a fixture
    to later be loaded into a mock hammerspoon module.
--]] local function handleScreen(w) -- {{{
  local hasWin = w._win
  local hasScreen = hasWin and w._win.screen
  if not hasScreen then
    return nil
  end

  local screen = {id = w._win:screen():id(), frame = w._win:screen():frame()}
  return screen
end -- }}}

local function plainWindowMapper(w) -- {{{
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
end -- }}}

local M = {}

function M.window(w) -- {{{
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

function M.stack(stack) -- {{{
  return {
    id = stack.id,
    windows = u.map(stack.windows, function(w)
      return {
        app = w.app,
        title = w.title,

        frame = w.frame.table,
        focus = w.focus,
        screenFrame = w._win:screen():frame().table,

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

function M.group(group) -- {{{
  return u.map(group, plainWindowMapper)
end -- }}}

function M.app(appWindows) -- {{{
  local obj = {}
  for app, group in pairs(appWindows) do
    print("app")
    u.p(app)
    obj[app] = u.map(group, plainWindowMapper)
  end
  return obj
end -- }}}

function M.screen(screen)
  return {
    id = screen:id(),
    name = screen:name(),
    frame = screen:frame().table,
    fullFrame = screen:fullFrame().table,
    windows = u.map(stackline.wf:getWindows(), M.window),
  }
end

return M
