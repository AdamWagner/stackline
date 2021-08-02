--[[ Q: Can tables be automatically linked / kept in sync with user data (e.g., an hs.window)? {{{
     - https://github.com/castle-xyz/share.lua/blob/master/state.lua
     - https://github.com/tianmao888sdo/KTLuaFramework/blob/master/Assets/core/LuaScripts/luacode/common/util/util.lua
 }}} ]]

-- TODO: Reconcile with ./framed.lua

local class = require 'lib.class'

local FrameSet = class('FrameSet'):use('AutoGroupable') -- TODO: `AutoGroupable` should be a separate class, not a mixin

function FrameSet:new(windows)
  -- When looking up a key on `self.groups`, return value at key where self.matcher(key) is `true`
  -- When setting a key on `self.groups`, append to existing list (when self.matcher(key) is an extant key) or create a new list with element.
  self.groups = self:autogroup({ matcher = self.matchers.fuzzy })

  self:add(windows)
end

function FrameSet:setCompare(fn)
  self.compare = fn
end

function FrameSet:add(windows)
  windows = u.isnt.array(windows) and {windows} or windows

  for _, win in pairs(windows) do
    if not win.frame then break end
    self.groups[win:frame()] = win
  end
end

FrameSet.fuzzFactor = 20

FrameSet.matchers = {
  equal = u.equal,
  inside = function(f1, f2)
    return f2:inside(f1)
  end,
  insideFuzzy = function(f1, f2)
    return f2:inside(
      u.rect_grow(FrameSet.fuzzFactor, f1)
    )
  end,
  fuzzy = function(f1, f2)
    for k in pairs(f1) do
      if math.abs(f1[k] - f2[k]) > FrameSet.fuzzFactor then
        return false
      end
    end
    return true
  end
}

return FrameSet
