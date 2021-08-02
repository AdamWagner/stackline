--[[
== Events.lua ==

ADAPTED FROM:
  - https://github.com/RayStudio36/event.lua/blob/master/event.lua
  - https://github.com/ejmr/Luvent/blob/master/src/Luvent.lua

REFERENCE:
https://github.com/slime73/Lua-Event/blob/master/event.lua
https://github.com/develephant/Eventable/blob/master/Eventable.lua

TESTS {{{

EventBus = require 'lib.utils.events'

actionOpts = {interval = 1, limit = 3}

Bus = EventBus:new(actionOpts)

focusedHandler1 = function() print('window focused handler #1') end
focusedHandler2 = function() print('window focused handler #2') end
unfocusedHandler = function() print('window UNfocused handler') end
movedHandler = function(...) print('window focused MOVED handler') end
movedHandler2 = function(...) print('window focused MOVED handler 2') end


Bus:on('window.focused', focusedHandler1)
Bus:on('window.unfocused', unfocusedHandler)
Bus:on('window.focused', focusedHandler2)
Bus:on('window.focused.moved', movedHandler)
Bus:on('window.focused.moved', movedHandler2)

= TEST: remove only 1 of 2 deeply-nested handlers without removing parent
    a = u.values(Bus.get('window.focused.moved'))[1]
    Bus:remove('window.focused.moved', a)
    -- > Expect a table at `window.focused.moved` with ONE handler instead of 2

= TEST: remove 2nd of 2 deeply-nested handlers & remove parent
    a2 = u.values(Bus.get('window.focused.moved'))[1]
    Bus:remove('window.focused.moved', a2)
    -- > Now there should be no table at `window.focused.moved` at all

Bus:dispatch('windowFocused', u.values(ws)[1][1])

  }}}
]]

--[[ {{{ REF

SO SIMPLE! Research how I can use something simple like this (at least as the base from which to inherit)
    https://github.com/bchtrapp/lua-mvvm/blob/master/Observable.lua
    A 'property' ↓ uses an Observable ↑ as `self`
    https://github.com/bchtrapp/lua-mvvm/blob/master/Property.lua

Tabs with examples of "Property" capabilities. Goal was to make it easy to build dynamic two-way virtual properties that can be get/set with accessors, but call functions.
  oven= Temperature()
  oven.farenheit= 450
  oven.celsius
  -- >> 232.22222222222223
  oven.celsius= 175
  oven.farenheit
  -- >> 347.0
  -- In this example, we set one attribute and the value of another attribute changes to mirror it precisely.

  https://github.com/Person8880/Shine/blob/develop/lua/shine/lib/gui/binding/property.lua
  https://github.com/hkkhkhkhk/Starship-Autoland-XP/blob/main/Autoland/data/init/initProperties.lua
  https://github.com/miwos/firmware-lua/blob/main/lua/Prop.lua
  https://github.com/luada/GameEngine/blob/master/sample/Test/Bin/Debug/base/property.lua

  https://github.com/bchtrapp/lua-mvvm/blob/master/Property.lua
  https://github.com/bchtrapp/lua-mvvm/blob/master/Observable.lua
  https://github.com/AlexKordic/lua-files/blob/master/oo.lua

  https://github.com/CommandPost/CommandPost/blob/develop/src/extensions/cp/prop/init.lua
  https://github.com/al1020119/cocos2dx-C-C-Lua-/blob/master/src/cocos/framework/extends/NodeEx.lua
  https://github.com/al1020119/cocos2dx-C-C-Lua-/blob/master/src/cocos/framework/components/event.lua
  https://github.com/Roblox/TweenService-Editor/blob/master/src/Components/InstanceItem.lua
  https://github.com/weimingtom/lua-files/blob/master/winapi/object.lua
  https://github.com/weimingtom/lua-files/blob/master/winapi/windowclass.lua
  https://github.com/haka-security/haka/blob/develop/lib/haka/lua/lua/class.lua
  https://github.com/ShoesForClues/Buffy-Chip/blob/master/buffy_chip/core/dep/stdplib.lua

 }}} ]]

local class = require 'lib.class'
local path = require 'lib.utils.path'.path
local Action = require 'stackline.modules.Action'

local function epath(name, func) --[[ {{{
  Append the function ID to the name separated by a dot (".")
  If function ID is missing, just use the name as the path
  E.g., 'window.focused.function: 0x50192'
    -> self.events = {window={focused={['function 0x50192']=fn}}}
  ]]
  return path.concat(name, (func and tostring(func)))
end -- }}}

local Bus = class('EventBus')

function Bus:new(opts)
  self.events = {}
  self.actionOpts = opts or {}
  self.get = u.bind(path.get, self.events)
  self.set = u.bind(path.set, self.events)
end

function Bus:on(name, func) --[[ {{{
  Set Action at "path" `epath`, creating intermediary tables if needed.
  name = "window.focused.move" — hierarchy created for each dot-separated segment
  func = "function: 0x50192"  — becomes last key in path
    -> self.events = {window={focused={move={['function 0x50192']=fn}}}}
  ]]
  self.set(
    epath(name, func),
    Action:new(evtPath , func, self)
  )

  return self
end -- }}}

function Bus:remove(evtPath, action) -- {{{
  local evtPath = action.path and action.path or epath(evtPath, action)
  print('evtPath',evtPath)
  self.set(evtPath, nil) -- Set the path for name + func to nil

  -- If event is associated with zero actions, remove entirely
  local parent = path.up(evtPath)

  print('-----------------------------')
  print('parent path:',parent)
  u.p(self.get(parent))
  print('-----------------------------')

  if u.len(self.get(parent)) < 1 then
    self.set(parent, nil)
  end

  return self
end -- }}}

function Bus:dispatch(evtPath, ...) -- {{{
  local handlers = self.get(evtPath) -- lookup handlers by *evtPath* only (we're going to fire all child Actions)
  if not handlers then return end -- short-circuit if there aren't any

  local iterateAll
  iterateAll = function(t, ...)
    for _, a in pairs(t) do
      if u.is.callable(a.invoke) then
        a:invoke(...)

        -- Remove action if it's no longer enabled after being invoked
        -- Actions have a backreference to the bus & store their own path,
        -- so we could perform "remove if diabled" at the end of Action:invoke() instead.
        -- That said, the Bus feels like a more appropriate place for this as of mid-July 2021.
        if not a.enabled then
          self:remove(evtPath, a)
        end

      else

        iterateAll(a) -- `a` is a branch, not a leaf -> recurse
      end
    end
  end

  -- Resursively invoke all handlers at path `evtPath`
  iterateAll(handlers)

  return self
end -- }}}

return Bus
