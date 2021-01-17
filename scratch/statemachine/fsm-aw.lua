
--[[


  TimedQueue & Corresponding State Machine
  https://github.com/LPGhatguy/ld27-fast-food/blob/main/ussuri/misc/timed_queue.lua
  https://github.com/LPGhatguy/ld27-fast-food/blob/main/ussuri/misc/state_machine.lua
    https://github.com/jlandron/Breakout/blob/master/BreakoutAndroid/StartGamedev-170112-win/src/states/BaseState.lua



    StateComponmentMapping: https://github.com/luoyvhang/client/blob/master/src/packages/lash/fsm/StateComponentMapping.lua
        From "Lash.lua": https://github.com/luoyvhang/client/tree/master/src/packages/lash

  POKER GAME Examples of State Machines being integrated with a Base Class  {{{
      https://github.com/water158/newniuniu/blob/master/client/newbainiu/src/framework/ql/mvc/BaseModel.lua

          BaseController: https://github.com/water158/newniuniu/blob/master/client/newbainiu/src/framework/ql/mvc/BaseController.lua
          BaseData (Observers!!): https://github.com/water158/newniuniu/blob/master/client/newbainiu/src/framework/ql/mvc/BaseData.lua
          BaseScene: https://github.com/water158/newniuniu/blob/master/client/newbainiu/src/framework/ql/mvc/BaseScene.lua
          BaseView: https://github.com/water158/newniuniu/blob/master/client/newbainiu/src/framework/ql/mvc/BaseView.lua
          init.lua: https://github.com/water158/newniuniu/blob/master/client/newbainiu/src/framework/ql/mvc/init.lua

          ++++---  PLUS ---++++
          An EventDisapatcher to fit right in!
            https://github.com/water158/newniuniu/blob/master/client/newbainiu/src/framework/ql/EventDispatcher.lua
              Note there is some complicated event-related stuff in their misc.lua file:
                https://github.com/water158/newniuniu/blob/master/client/newbainiu/src/framework/ql/functions.lua#L139

          So far, all links are from the "framework" subdir. To see it *really* in use:
                  GameService.lua     : https  ://github.com/water158/newniuniu/blob/master/client/newbainiu/src/app/service/GameService.lua
                  PlayerController.lua: https  ://github.com/water158/newniuniu/blob/master/client/newbainiu/src/app/controllers/PlayingController.lua
                  Poker.lua           :   https://github.com/water158/newniuniu/blob/master/client/newbainiu/src/app/models/Poker.lua


                  -- -----------------------------------
                  function Poker:onCreate()
                    self:setStateMachineEnable(true)

                    -- 分解牌值
                    if self.value_ then
                      self.point_ = Poker.getPokerPoint(self.value_)
                      self.color_ = Poker.getPokerColor(self.value_)
                    end

                  end

                  -- @override
                  function Poker:onSetFSMEvents(events)
                    self:addFSMEvent(events, "start", "none", "idle")
                    self:addFSMEvent(events, "select", "idle", "selected")
                    self:addFSMEvent(events, "unselect", "selected", "idle")
                    self:addFSMEvent(events, "play", {"idle", "unselect", "selected", "played"}, "played") -- 可能会出现已经打出牌的同时掉线
                    self:addFSMEvent(events, "remove", "played", "removed")
                  end

                  -- ———————————————————————————————————————————————————————————
                  -- LOOK! This guy uses a :set() method to manually fire onChange events
                  -- I should probably consider this instead of trying to be too clever on my first attempt
                  -- ———————————————————————————————————————————————————————————
                  function Poker:setValue(value)
                    if self.value_ ~= value then
                      self.value_ = value
                      if value ~= POKER_UNKNOWN then
                        self.point_ = Poker.getPokerPoint(value)
                        self.color_ = Poker.getPokerColor(value)
                      end
                      self:dispatchEvent({name=Poker.EVENT_CHANGE_VALUE, value=value})
                    end
                  end

                  -- -----------------------------------
                  function Poker:isSelected()
                    return self:isState(Poker.STATE_SELECTED)
                  end

                  function Poker:onSelect_(event)
                    printf("@选择扑克, value=%d, point=%d, color=%d", self.value_, self.point_, self.color_)
                    self:dispatchEvent({name = Poker.EVENT_SELECT})
                  end
                  -- -----------------------------------


          But, the INIT files are *sooooper clean*
          They really just require the children. NO coordination. That is very nice.
              Actually - not quite. Tht's just the *framework* files.
              Still, the real App.lua file is pretty short / clear:
              App.lua https://github.com/water158/newniuniu/blob/master/client/newbainiu/src/app/MyApp.lua


          This is really neat.

            -- ------------------------------------------------
                function EventDispatcher:__onUpdate(dt)
                  if #self._eventQueue == 0 then return end

                  local event = self._eventQueue[1]

                  if event.pendingBefore > 0 then event.pendingBefore = event.pendingBefore - dt
                  ---
                  --- *more stuff*
                  ---
            -- ------------------------------------------------

      -- ------------------------------------------------
      function BaseModel:setStateMachineEnable(enable)
        if enable and not self._fsm then
          self:addComponent("components.behavior.StateMachine")
          self._fsm = self:getComponent("components.behavior.StateMachine")

          local _events, _callbacks = {}, {}
          if self.onSetFSMEvents then
            self:onSetFSMEvents(_events)
          end
          if self.onSetFSMCallbacks then
            self:onSetFSMCallbacks(_callbacks)
          end
          self._fsm:setupState({events=_events, callbacks=_callbacks})
        else
          self:removeComponent(self._fsm)
          self._fsm = nil
        end
      end


      function BaseModel:addFSMCallback(_callbacks, _name, _handler)
	_callbacks[_name] = handler(self, _handler)
      end

        function BaseModel:doEvent(event, ...)
          if self._fsm then
            return self._fsm:doEvent(event, ...)
          else
            printError("no enable State Machine!")
          end
        end

        function BaseModel:setState(state)
          if self._fsm then
            self._fsm.current_ = state
          else
            printError("no enable State Machine!")
          end
        end
      -- ------------------------------------------------
      }}}



  Good example of what a real "State" module might look like for a specific state (like 'walking', or 'dead')
   https://github.com/jiajixiang/mmorpg_skynet/blob/master/service/game/scene/ai/state/DeadState.lua

  Others:
    https://github.com/arliang/TradeSkillMaster/blob/master/LibTSM/Util/FSMClasses/Machine.lua
    Very recent activity (Dec 2020) https://github.com/anhsirkrishna/ForgottenTales/tree/main/src
      Lots of EntityState-this-and-that, but probably not worth reviewing
          →       For simpler Entity State Management - see https://github.com/tesselode/nata
                Also see this from the same guy: https://github.com/tesselode/charm. Just good design patterns to learn from
                Same goes for this: https://github.com/tesselode/boxer/blob/master/boxer.lua


  Another
  https://github.com/ShourinPaul/2DGameswithLove2D/blob/main/Fifty-Bird/states/BaseState.lua
  https://github.com/ShourinPaul/2DGameswithLove2D/blob/main/Fifty-Bird/states/CountdownState.lua
  https://github.com/jlandron/Breakout/blob/master/BreakoutAndroid/StartGamedev-170112-win/src/StateMachine.lua
  https://github.com/jlandron/Breakout/blob/master/BreakoutAndroid/StartGamedev-170112-win/src/states/PlayState.lua
  https://github.com/ShourinPaul/2DGameswithLove2D/blob/main/Fifty-Bird/states/PlayState.lua
  https://github.com/ShourinPaul/2DGameswithLove2D/blob/main/Fifty-Bird/Bird.lua
  https://github.com/jlandron/Breakout/blob/master/BreakoutAndroid/StartGamedev-170112-win/src/states/ServeState.lua
  https://github.com/jlandron/Breakout/blob/master/BreakoutAndroid/StartGamedev-170112-win/src/states/PaddleSelectState.lua

  Main game file (i.e., stackline.lua)
  https://github.com/sedx876/Lua-FlappyBird/blob/45043ca7bb9099e67e86c22c0f95d58a8dfc7c03/bird8/main.lua

  E.g., ------------
     -- initialize state machine with all state-returning functions
      gStateMachine = StateMachine {
          ['title'] = function() return TitleScreenState() end,
          ['countdown'] = function() return CountdownState() end,
          ['play'] = function() return PlayState() end,
          ['score'] = function() return ScoreState() end
      }
      gStateMachine:change('title')

  Level maker

  -- ---------------------------------------------------------------------------
  Ball Entity

  https://github.com/jlandron/Breakout/blob/master/BreakoutAndroid/StartGamedev-170112-win/src/Ball.lua

--]]



local Class = require 'lib.Class'
local Container = require 'lib.Container'
local Queue = require 'lib.Queue'

-- Utility (TODO: move out of file)
-- ————————————————————————————————————————————————————————————————————————————
local debounce = Class()

function debounce:new(delay)
  self.debouncePeriod = delay  * 1000 * 1000
  self.lastTime = 0
end

function debounce:run()
  self.thisTime = hs.timer.absoluteTime()
  local previous = self.lastTime
  self.lastTime = self.thisTime
  return (self.thisTime - previous) < self.debouncePeriod
end

--[[ {{{ LIBRARY INSPO ---------------------------------------------------------

  Complicated state "chart", but still good to review for more random inspo
  https://github.com/kmarkus/rFSM/tree/master/examples

  🏆️ THIS IS AWESOME 🏆️
  Probably the  best thing for me to study as of 2020-12-20
  given where I am and where I need to go with my own state machine
  https://github.com/aiyhome/lua-state-machine/tree/master

  ⭐️ petersohn/awesome-config ⭐️
  Really excellent, super clean. Biggest influence:
  https://github.com/petersohn/awesome-config/blob/master/home/.config/awesome/StateMachine.lua

  Pretty decent. thought for a moment that they had DIFFING, but not quite.
  https://github.com/qlystudio/code-corona/blob/master/ThuldanenMasestro/code/utils/StateMachine.lua
  https://github.com/mwSora/payday-2-luajit-line-number/blob/39bf0f0fc04a34217a020d53236c3e381df48993/pd2-lua/lib/utils/statemachine.lua

  Defold-adam (really tho)
  https://github.com/Insality/defold-adam/blob/main/adam/system/state_instance.lua
  https://github.com/Insality/defold-adam/blob/main/adam/system/action_instance.lua
  https://github.com/Insality/defold-adam/blob/main/adam/system/adam_instance.lua
  https://insality.github.io/defold-adam/modules/Actions.html
  NOTE: Defold is a game engine for web & mobile: https://defold.com/

  Only example I've found of a FSM that uses diffing / comparison to trigger events
  https://github.com/JackXuXin/server_logic/blob/b6bd3cf5f415ef3514c0a7cd0674a9feb065d767/logic/logic_qznn.lua#L68

  OOP version of old kyleconroy's implementation
  https://github.com/katichar/FTGEditor/blob/master/src/framework/cc/components/behavior/StateMachine.lua

  Middle-ground FSM. OOP-based, but not insanely complicated
    Machine: https://github.com/BoLaMN/VBNT-V/blob/vbnt-v_CRF979-18.1.c.0429-950-RA/usr/lib/lua/mobiled/statemachine.lua
    State: https://github.com/BoLaMN/VBNT-V/blob/vbnt-v_CRF979-18.1.c.0429-950-RA/usr/lib/lua/mobiled/state.lua

  Similar, but more robust than ↑
    Stack Machine: https://github.com/nobbyfix/IllusionConnectData/blob/main/ja-JP/script/dragon/fsm/StackStateMachine.lua
    Machine: https://github.com/nobbyfix/IllusionConnectData/blob/main/ja-JP/script/dragon/fsm/StateMachine.lua
    State: https://github.com/nobbyfix/IllusionConnectData/blob/main/ja-JP/script/dragon/fsm/State.lua

  SETUP INSPO (state machine cofig data)   --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  ---
  - https://github.com/Aristo7/GridMateLab/blob/master/dev/StarterGame/Scripts/AI/AIController.lua#L139
  - https://github.com/turanszkij/WickedEngine/blob/180ddc358643bf05e29cab4343c08e97910bafdd/scripts/fighting_game.lua#L1108

			  -- STATE EXAMPLE:
        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
			StaggerStart = {

          -- Props (will be good for Indicator)
				anim_name = "StaggerStart",
				anim = INVALID_ENTITY,
				looped = false,
				clipbox = AABB(Vector(-1), Vector(1, 5)),
				hurtbox = AABB(Vector(-1.2), Vector(1.2, 5.5)),

          -- Transitions
        transitions = StaggerStart = {
          { "StaggerAirStart", condition = function(self) return self:require_hurt() and self.position.GetY() > 0 end, },
          { "StaggerStart", condition = function(self) return self:require_hurt() end, },
          { "Stagger", condition = function(self) return self:require_animationfinish() end, },
        },
			},
        --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --

]]  -- }}}

-- State
-- ———————————————————————————————————————————————————————————————————————————
local State = Class()

function State:new(o)
  self.name = o.name

  self.transitions = Container(o.transitions)

  -- Merge in any provided handlers
  --    enter, exit, & condition have dummy fns set on class
  --    Handlers may also be registered later after creation.
  table.merge(self, o)

  return self
end

function State:enter() end
function State:exit() end
function State:condition() end

function State:register(event, handler)
  self[event] = handler
end

function State:addTransition(toState, opts)
  self.transitions[toState] = opts
end


-- Machine
-- ———————————————————————————————————————————————————————————————————————————
local Machine = Class()

-- core
function Machine:new(o)
  self.current = o.initial
  self.previous = nil
  self.transitionHistory = Queue()

  self.states = Container(o.states)

  -- helpers
  self.debounce = debounce(o.limit or 2.5)

  return self
end

function Machine:getCurr()
  return self.states[self.current]
end

function Machine:getTransitions()
  u.p(self)
  return self.states[self.current].transitions
end

function Machine:can(stateName)
   return #self:getTransitions()
           :keys()
           :filter(function(t)
              return t == stateName
            end) > 0
end

function Machine:exit()
  self.previous = self.current
  self:getCurr().exit()
  return self
end

function Machine:enter(newStateName)
  local next = self.states[newStateName]
  self.current = next.name
  next.enter()
  return self
end

function Machine:undo()
  self.transitionHistory:pop() -- burn one
  local prevTran = self.transitionHistory:pop()
  print(self.current, '<<<', prevTran)
  self:trigger(
    prevTran
  )
  -- self:trigger(self.previous)
  return self
end


function Machine:call(action, args)
  if type(action) == "table" then
    for _, a in ipairs(action) do
      a(args)
    end
  else
    action(args)
  end
end



function Machine:trigger(transition)
  if self.debounce:run() then
    print('DEBOUNCED!')
    return false
  end

  -- TODO: is there a way to match on
  --       `someTransition = { to = →newState← }`
  --       where newState == the param to trigger()?
  local t = self:getTransitions()[transition]

  if t then
    self.transitionHistory:push(transition)
    print('delayed thingie is running')

    -- Run guard. If returns `true`, abort transition
    if t.guard and not t.guard(self:getCurr()) then
      return false
    end

    -- Exit the current state
    if t.to then
    self:exit()
  end

    -- Call action(s) after leaving current state, before entering new
    if t.action then
      self:call(t.action, {})
    end

    -- Enter the new state
    if t.to then
      self:enter(t.to)
    end

  end

  return self
end



-- Return classes
-- ———————————————————————————————————————————————————————————————————————————
return {
  State = State,
  Machine = Machine,
}


-- Example
-- ———————————————————————————————————————————————————————————————————————————
--[[ {{{
  d.inspectByDefault(true)

  lib = require 'lib.fsm-aw'

  State = lib.State
  Machine = lib.Machine

  menu = State({
    name  = 'menu',
    enter = function() print('entering menu') end,
    exit = function() print('exiting menu') end,
    condition = function() print('testing if state can be entered') end,
    transitions = {
      toGame = { to = 'game' },
      toOptions = { to = 'options' }
    }
  })

  game = State({
    name  = 'game',
    enter = function() print('entering game') end,
    exit = function() print('exiting game') end,
    transitions = {
      toMenu = {
        to = 'menu',
        guard = function() print('testing if we can go from "game" state → "menu" state') return true end,
        action = {
          function() print('doing first action') end,
          function() print('doing second action') end,
        },
      },
      toOptions = {
        to = 'options'
      }
    }
  })

  options = State({
    name  = 'options',
    enter = function() print('entering game') end,
    exit = function() print('exiting game') end,
    transitions = {
      toMenu = { to = 'menu' },
      toGame = { to = 'game' }
    }
  })

  fsm = Machine({
    initial = 'menu',
    states = {
      menu = menu,
      game = game,
      options = options,
    },
  })

}}} ]]
