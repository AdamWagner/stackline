local observe = require 'lib.kvo'
local u = require 'stackline.lib.utils'

randObj = {}  -- {{{
function randObj:new(id)
  local o = {
    id = id,
    app = math.random(),
    focus = math.random() > 0.5 and true or false,
    frame = {
      x = math.random(),
      y = math.random(),
      w = math.random(),
      h = math.random(),
    }
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

function randObj:update()
  self.blah = 'test'
  -- u.pheader('before ' .. self.id)
  -- u.p(self.frame)
  self.focus = math.random() > 0.5 and true or false
  self.frame = {
    x = math.random(),
    y = math.random(),
    w = math.random(),
    h = math.random(),
  }
  -- u.pheader('after ' .. self.id)
  -- u.p(self.frame)
  return self
end  -- }}}

function onStackChange(key, old, new)  -- {{{
  print('\n\n-----------\n onStackChange running:', key, 'was set\n\n')

  local ignore = {'stack', 'otherAppWindows', 'indicator'}

  -- local diff = table.diff(old, new)
  -- u.p(diff)
  -- local diff = table.diff(oldFrame, newFrame, {ignore=ignore})

--   local stackIdDiff = {
--     old = diff.changed['1351'].old.stackId,
--     new = diff.changed['1351'].new.stackId,
--     child = diff.child['1351'].changed.stackId,
--   }
--   print(hs.inspect(stackIdDiff))

  local simpleDiff = table.changed(old, new, { ignore=ignore })
  u.p(simpleDiff)
end  -- }}}

local Stack = {}

function Stack:new(stackedWindows) -- {{{
  local s = {}
  s.windows = {}
  s.focus = false

  for k,v in pairs(stackedWindows) do
    s.windows[tostring(v.id)] = v
    -- s.windows[tostring(v.id)] = randObj:new(tostring(v.id))
  end
    -- local s = { {{{
    --     windows = stackedWindows,
    --     focus = false,
    -- } }}}
    -- setmetatable(self, getmetatable(s))
    setmetatable(s, self)
    self.__index = self

    s = observe.add(s, 'windows', onStackChange)
    -- s = observe.add(s, 'focus', onStackChange)
    return s
end -- }}}

function Stack:update()  -- {{{
  print('Stack:update() starting')
  print('Stack:update() BEFORE assigning .windows')

  self.windows = u.map(self.windows, function(w)

    -- return w:update() -- will cause new == old !!
    -- NOTE: Beware of causing 'new' == 'old' in onStackChange():
    -- If the window is updated directly, the current stack is mutated when each
    -- window is updated, so when the onChange handler is invoked when
    -- self.windows is assigned, 'new' and 'old' will always be the same.

    -- Copying the Window instance before triggering
    -- the update fixes the new == old issue…
    -- … but causes another: the observer on the window is lost.
    -- TODO: figure out how to clone table while *preserving* the observer
    local x = u.clone(w)
    return x:update()
  end)


  return self
  -- self.history:push(state)
end  -- }}}

function Stack:get() -- {{{
    return self.windows
end -- }}}

function Stack:frame() -- {{{
   -- All stacked windows have the same dimensions, so the 1st win frame is == to the stack's frame
   -- FIXME: This assumption is incorrect when:
   --     1. the 1st window has min-size < stack width. See ./query.lua:104
   --     2. the application constrains window sizes (e.g., iTerm2)
   return self.windows[1]._win:frame()
end -- }}}

function Stack:isFocused(opts) -- {{{
  opts = opts or {}
  local isFocused = u.any(self.windows, function(w)
    return w:isFocused()
  end)
  if opts.commit then self.focus = isFocused end
  self.focus = isFocused
  return isFocused
end -- }}}

function Stack:eachWin(fn) -- {{{
   for _idx, win in pairs(self.windows) do
       fn(win)
   end
end -- }}}

function Stack:resetAllIndicators() -- {{{
   self:eachWin(function(win)
       win:setupIndicator()
   end)
end -- }}}

function Stack:redrawAllIndicators(opts) -- {{{
   -- TODO: eliminate need for opts.except arg redraws all indicators *except* the window with the given id
   opts = opts or {}
   self:eachWin(function(win)
       if win.id ~= opts.except then
           win.indicator:redraw()
       end
   end)
end -- }}}

function Stack:deleteAllIndicators() -- {{{
   self:eachWin(function(win)
       win:deleteIndicator()
   end)
end -- }}}

function Stack:getWindowByPoint(point) -- {{{
   local foundWin = u.filter(self.windows, function(w)
       local indicatorEls = w.indicator.canvas:canvasElements()
       local wFrame = hs.geometry.rect(indicatorEls[1].frame)
       return point:inside(wFrame)
   end)

   if #foundWin > 0 then
       return foundWin[1]
   end
 end -- }}}

-- function Stack:__tostring()  -- {{{
--   return hs.inspect({
--     focus = self.focus,
--     id = u.values(self.windows)[1].stackId,
--     idFzy = u.values(self.windows)[1].stackIdFzy,
--     numWin = #self.windows
--   })
-- end  -- }}}

return Stack

