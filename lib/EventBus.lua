
--[[ {{{ NOTES
    FROM: https://github.com/hrsh7th/nvim-tuil/tree/master/lua/event
      See in use:
        https://github.com/hrsh7th/nvim-tuil/blob/master/lua/vim/window.lua
        https://github.com/hrsh7th/nvim-tuil/blob/master/lua/vim/autocmd.lua
        https://github.com/hrsh7th/nvim-tuil/blob/master/lua/oop/class.lua


    See also:
      - https://github.com/Paradigm-MP/oof/blob/master/shared/events/shEvents.lua
     - An overall manager thingie: https://github.com/autismuk/Executive/blob/master/system/executive.lua

     - Finally a WoW addon that is useful!
     Callback Handler: https://github.com/HelgesenJan/wowaddons/blob/master/Interface/Addons/ClassicNumbers/Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua

     - Very complex Event Manager
     https://github.com/MayGo/maze-world/blob/master/src/serverStorage/GameAnalytics/Events.lua
        More equally or more complex:
        https://github.com/Hucxley/EventManager/blob/master/EventManager.lua


      -- READING ======================
      Very good Readme about how he designed the Signal Manager
          https://github.com/itsFrank/roblox-signal-manager
          Doesn't matter that it's for Roblox
          Also very recent activity (20 days ago as of 2020-12-22)

    Async event-related libs
      https://github.com/theJ8910/Terrapin/blob/master/modules/async.lua



    ┌──────────────────┐
    │ OBSERVER PATTERN │
    └──────────────────┘
    https://github.com/mum-chen/lua-msg-queue
    Very good Queue design - https://github.com/Gerrard-YNWA/lua-resty-queue/blob/master/lib/resty/queue.lua

    FINALLY! A queue manager that handles batching !! ======================================
    → ;→;→https://github.com/m241dan/davevent/blob/master/eventqueue.lua

    LuaNotify deserves a second look:
    https://github.com/katcipis/luanotify/blob/master/notify/double-queue.lua

    https://github.com/tesselode/talkback


  UNIQUE EXAMPLE of an EVENT-BUS that's designed to be inherited:
    EventSystem.lua https://github.com/jiajixiang/mmorpg_skynet/blob/master/service/Lua/Common/EventSystem.lua
    ↑ ↑ EventSystem is definitely the special thing here..

    It goes with this base class: https://github.com/jiajixiang/mmorpg_skynet/blob/master/service/Lua/Common/BaseClass.lua
    .. .. and weirdly also this GlobalEventMgr.lua ? https://github.com/jiajixiang/mmorpg_skynet/blob/master/service/Lua/Common/GlobalEventSystem.lua
      .. AND this "MessageManager" — which is really what most other event libs are: https://github.com/jiajixiang/mmorpg_skynet/blob/master/service/Lua/Common/Messenger.lua
         AND AND AND a TIMER MANAGER! https://github.com/jiajixiang/mmorpg_skynet/blob/master/service/Lua/Common/TimerManager.lua
         I was really pumped to check out UpdateManager.lua -- but honestly I can't figure out what it's supposed to do. Seems like fluff:
            https://github.com/jiajixiang/mmorpg_skynet/blob/master/service/Lua/Common/UpdateManager.lua
        Ugh, there's ALSO an Event & timer files in the utils dir:
          event.lua: https://github.com/jiajixiang/mmorpg_skynet/blob/master/service/Lua/Common/Util/event.lua
          timer.lua: https://github.com/jiajixiang/mmorpg_skynet/blob/master/service/Lua/Common/Util/Timer.lua

  ALTERNATIVES
    Marshallers & signals
    https://github.com/klokane/loxy/blob/master/loxy/signal.lua

      -- ┌──────────────────────────────────────────────────────────────┐
      -- │ LASH.lua AWESOME
      -- └──────────────────────────────────────────────────────────────┘
      -- The Event lib itself is very similar - despite being called an Observable
      --  But there is so much more than that!
      https://github.com/luoyvhang/client/blob/master/src/packages/lash/core/Observable.lua
      Note that LASH.lua is BIG, practically an Entity Management System for
      vanilla lua. So of course, it also has like a 12-fille FSM:

      For simpler Entity State Management - see https://github.com/tesselode/nata

      This is worth reviewing, tho — it's specifically for giving state to ENTITIES:
          EntityStateMachine.lua: https://github.com/luoyvhang/client/blob/master/src/packages/lash/fsm/EntityStateMachine.lua
      Same goes for Engine.lua:
          Analogous to stackline.manager
          Engine.lua:   https://github.com/luoyvhang/client/blob/master/src/packages/lash/core/Engine.lua

      Separately, this is all part of an app that *might* be affiliated with Cockos?
        Group.lua - compare to stackline.manager -- https://github.com/luoyvhang/client/blob/master/src/app/models/Group.lua
        (??) AppEvent - https://github.com/luoyvhang/client/blob/master/src/app/models/AppEvent.lua
        !!! UPDATE CONTROLLER.lua https://github.com/luoyvhang/client/blob/master/src/app/controllers/UpdateController.lua
        Lots of good event integration in User.lua: https://github.com/luoyvhang/client/blob/master/src/app/models/User.lua

        LIB: PriorityQueue.lua: https://github.com/luoyvhang/client/blob/fa0ac9826a3fae18e09e30ee14cbfeb00c723d1a/src/packages/graph/PriorityQueue.lua

        LIB: Deferred.lua: https://github.com/luoyvhang/client/blob/master/src/packages/deferred.lua
        Framework: Controller.lua (basesclass?): https://github.com/luoyvhang/client/blob/master/src/packages/mvc/Controller.lua


     ┌───────┐
     │ BTree │
     └───────┘
      https://github.com/zh423328/BTree/tree/master/LUA/scripts/app/State

      Shows how State Machine can work with a Class-based entity ssytem:
        https://github.com/zh423328/BTree/blob/master/LUA/scripts/app/State/StateProcess.lua

        --- --- very simply, it seems. ..
        -- ---------------------------------------------------------------------
        self:addNodeEventListener(cc.NODE_EVENT,function(event)
          if event.name == "enter" then
            --todo
            self:onEnter();
          elseif event.name == "exit" then
            self:onExit();
          end
        end)

        function Entity:onEnter()
          self:addNodeEventListener(cc.NODE_ENTER_FRAME_EVENT,function(dt)
            self:update(dt);
          end)
          self:scheduleUpdate();
          self.think=scheduler.scheduleGlobal(function(dt)
            self:updateThink(dt)
          end, 0.1);
        end

        function Entity:onExit()
          self:unscheduleUpdate();
          scheduler.unscheduleGlobal(self.think);
          scheduler.unscheduleGlobal(self.blackBoard.timeoutId);
        end

        function Entity:ChangeStatus(event)
          if self.curState == StateEvent.die then
            return;
          end
          if self.curState == event and event ~= StateEvent.attack then
            --todo
            return;
          end
          if (self.curState == StateEvent.attack or self.curState == StateEvent.skill) and event == StateEvent.hurt then
            return;
          end
          self.fsm:ChangeStatus(self,event);
        end
        -- ---------------------------------------------------------------------


    ALL THE LIBS CONSIDERED / STUDIED
      https://github.com/flameleo11/lua-events/blob/master/emitter.lua
      https://github.com/kitsunies/signal.lua
      https://github.com/prabirshrestha/lua-eventbus
      https://github.com/aimingoo/Events
      https://github.com/RayStudio36/event.lua
      https://github.com/develephant/Eventable
      https://github.com/yfrit/EventSystem
      https://github.com/yfrit/yfritlib
      https://github.com/F-RDY/lua-state-machine/blob/master/src/init.lua
      https://stackoverflow.com/questions/64774828/how-to-extend-lua-metatables-with-something-like-index


    STATE MACHINE LIBS ---------------------------------------------------------

    PeterSohn's *amazing* State Machine, that I think is capable of integrating
    with an event bus, I just don't know how yet
      https://github.com/petersohn/awesome-config/blob/master/home/.config/awesome/StateMachine.lua
      https://github.com/petersohn/awesome-config/blob/master/home/.config/awesome/Process.lua
      https://github.com/petersohn/awesome-config/blob/master/home/.config/awesome/locker.lua
      https://github.com/petersohn/awesome-config/blob/master/home/.config/awesome/async.lua
      https://github.com/petersohn/awesome-config/blob/master/home/.config/awesome/ProcessWidget.lua

      https://github.com/Ozzypig/Modules/blob/master/src/StateMachine/init.lua

 }}} ]]
--[[  TESTING ------------------------------------------------------------------------ {{{

e = require 'lib.EventBus':new()
e:on('update', function() print('updating test string!') end)
e:on('update', function() print('updating test string!') end)
e:on('fukcing', function() print('test string') end)
e:on('fukcing', function() print('test string more!') end)
e:on('sleeping', function() print('time to sleep now') end)
e:emit('update')

-- }}} ]]
--[[ ALT IMPLMT  -------------------------------------------------------------- {{{

  function Class(...)
    local Parent = (select(1, ...))
    local Class = Parent and setmetatable({}, { __index = Parent }) or {}
    Class.super = Parent

    -- factory
    Class.new = function(...)
      local this = setmetatable({}, { __index = Class })
      Class.init(this, ...)
      return this
    end

    -- default constructor
    function Class.init(self, ...)
      if Class.super then
        Class.super.init(self, ...)
      end
    end

    return Class
  end

 }}}  ]]

local setmt = setmetatable
local getmt = getmetatable

local entry_mt = {
  __call = function(self, ...)
  return self:fn(self, ...)
end
}


local Class = require 'lib.Class'
local Container = require 'lib.Container'

local Emitter = Class()

function Emitter:new()
  self.listeners = Container({})
  return self
end

function Emitter:listener_count(name)
  return #(self.listeners[name] or self.listeners)
end

-- SEE AceHook.lua: https://github.com/Taroven/Axis/blob/master/Libs/AceHook-3.0/AceHook-3.0.lua
-- It's old, but seems potentially relevant
function Emitter:on(name, fn)
  self.listeners[name] = self.listeners[name] or {}

  local entry = setmt({

    -- Event name as string
    name = name,

    -- Called when event of `name` ↑ is emitted
    -- This entry itself will be available in the params of the fired event.
    fn = fn,

    -- ↓ NOTE: I'm not going to implement `subject` or `observer` for now and wait
    -- to see if they're really needed

    -- Identifies the observed entity (e.g., Window, Stack, etc)
    -- How will this be set? If this behavior is added to Etities, will `self`
    -- here be the entity itself, or still the EventBus?  Essentially — will
    -- observers need to explicitly identify themselves?

    -- subject = subject, -- TODO (maybe?)

    -- what is this? The ID of the observer, or tostring(observer), or .. ?
    -- It needs to enable the observer to get a list of all registered onChnge listeners, tho.

    -- observer = observer,-- TODO (maybe?)
    -- !! See here — this is implemented: https://github.com/hgiesel/lua-observer


    -- primarily just to call the fn when the entry itself is called
  }, entry_mt)

  table.insert(self.listeners[name], entry)

  -- respond with "off switch" for observer to store
  return function() self:off(name, fn) end


  -- NOTE:it might be best to NEVER implement the more complex "Handler is a table" idea..
  --    See: https://github.com/CommandPost/CommandPost/blob/develop/src/extensions/hs/tangent/init.lua#L1379
  --    function mod.mt:handle(messageID, handlerFn)

         --[[ See how similar this is to the original event handler "register" fn, before I complicated it ↑
          local cmdHandlers = self._handlers[messageID]
            if not cmdHandlers then
              cmdHandlers = {}
              self._handlers[messageID] = cmdHandlers
            end
            insert(cmdHandlers, handlerFn)
          end
         ]]
end


-- NOTE: :once() may be implemented later
-- function Emitter:once(name, listener)
--   local callback = function(...)
--     self:off(name, listener)
--     listener(...)
--   end
--   self:on(name, callback)
-- end
--
function Emitter:off(name, ...)
  self.listeners[name] = self.listeners[name] or {}

  local listener = (select(1, ...))
  if listener ~= nil then
    self.listeners[name] = {}
  else
    for i, v in ipairs(self.listeners[name]) do
      if v == listener then
        table.remove(self.listeners[name], i)
        break
      end
    end
  end
end

function Emitter:emit(name, ...)

  self.listeners[name] = self.listeners[name] or {}

  local get = function(modifier)
    local key = modifier and name .. ':' .. modifier or name
    local entries = self.listeners[name]
    print('entry name is: ', name)
    return ipairs(entries or {})
  end

  for _, entry in get('before') do
    print('calling :before() stuff...\n\n')
    entry(...)
  end

  for _, entry in get() do
    print('THE REAL SHOW')
    entry(...)
  end

  for _, entry in get('after') do
    print('\n\ncalling :after() stuff...')
    entry(...)
  end

end

return Emitter

