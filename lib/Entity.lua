local Class = require 'lib.Class'
local Container = require 'lib.Container'

--[[ DESIGN ------------------------------------------------------------------------ {{{

Behaviors:
  1. Store non-essential info on metatable -> index.
     Only *core* data is accessible via __pairs - everything else is available
     if requested, but NOT included by default.

  2.onChange handlers by default
    - Entities are built specifically to make it easy for neighbors to subscribe
     to events that fire before, on, and after any entity property is updated.

	Q - What about a hierarchy? A component should be able to be notified of
	little changes, but others may only need to know when something really big
	happens (like the Entity's state transitions). This is tricky b/c *deciding*
	that an entity's state *should* transition often requires additional info from the environment,
	so I think the manager entities will be firing most of the major state updates

	Q - How will I know that something really changed?
	    a) Protect all core data fields behind a proxy so that potential
	       changes can be evaluated (likely via u.same(...) to determine if
	       there's really any new info) in __newIndex before being saved.
	       Note this will require a DIFFERENT strategy than that used in
	       behavior #1 above, since core data *should* be available directly
	       from the entity instance via pairs, etc.

	    b) The opposite of (a): Accept any / all changes to entity fields,
	      *BUT/AND* maintain a history of past states. The current & past
	      state could then be continaully evaluated either in a loop or when
	      every new change event. A potential advantage over (a) is that
	      this approach will produce confident, 'all-at-once' state change
	      events: Being able to constantly compare the current value vs. the
	      previous value will make it easy-ish to know "NOW! Let's redraw
	      this thing!"

	    c) Even as I was writing (b) I started thinking about a third
	      approach: DON'T actually write incoming changes, just keep track of
	      them (kind of like buffering.) This approach prevents concern that
	      entities might be updated so rapidly that it would result in a
	      spastic UI or even performance issues, while *still* providing the
	      benefit of confident past/currrent comparisons.

      Typical update flow ------------------------------------------------------

      1. hs.event (e.g., window resized)
      2. Send entire new state to stackline ingestor
      3. Data is pre-processed
	  a. Discard extraneous data
	  b. Build draft stackline instances from raw data (needed to compare 1-1 with current state)
	  c. Discard data that fails shallow compare to current state
	  d. Update draft "next" state with changes
      4. Determine if the current delta between next & curr warrants an update
	  a. WHAT ARE THE ACTUAL RULES?! Will these be hard to define?
	  b. Either stay here, or proceed to #5 if state change is needed
      5. Update the instances that need to be updated, which will automatically
	 fire their onBeforeChange / onChange / onAfterChange events. These
	 events will be handled by the state machine and cascade from the bottom up.

-- }}} ]]

--[[ DESIGN - REACT.JS influence

  See 'reconcile.lua' from multiple react-clones:
    https://github.com/talldan/lua-reactor/blob/master/src/reactor/reconcile.lua
    https://github.com/Roblox/roact/blob/master/src/createReconciler.lua#L62
    https://github.com/LXSMNSYC/luact/blob/master/luact-love/reconciler.lua  <- very different. Clean.

  Far too complicated (Fiber is unnecessary for this), but interesting: https://github.com/ccheever/react-lua/tree/master/src

]]

--[[  TESTING ------------------------------------------------------------------------ {{{

e = require 'lib.EventBus':new()
e:on('update', function() print('updating test string!') end)
e:on('update', function() print('updating test string!') end)
e:on('fukcing', function() print('test string') end)
e:on('fukcing', function() print('test string more!') end)
e:on('sleeping', function() print('time to sleep now') end)
e:emit('update')

-- }}} ]]
--[[ {{{  LUACT: Very good example: This is pretty close to what we want here, I think: https://github.com/LXSMNSYC/luact/blob/master/luact/meta.lua
    local update = require "luact.fiber.update"
    local tags = require "luact.tags"
    local assign_table = require "luact.utils.assign_table"

      -- NOTE: see example reconciler here: https://github.com/LXSMNSYC/luact/blob/master/luact-love/reconciler.lua
    return function (reconciler)
      local BaseMeta = {}
      BaseMeta.__index = BaseMeta

      function BaseMeta:component_will_mount()
      end

      function BaseMeta:component_will_update()
      end

      function BaseMeta:component_will_unmount()
      end

      function BaseMeta:component_did_update()
      end

      function BaseMeta:component_did_mount()
      end

      function BaseMeta:component_did_update()
      end

      function BaseMeta:render()
      end

      function BaseMeta:set_state(action)
	if (type(action) == "function") then
	  action = action(self.state)
	end

	  -- schedule update
	self.state = assign_table(self.state, action)
	update(reconciler)
      end

      return function (setup)
	local Meta = setmetatable({}, BaseMeta)
	Meta.__index = Meta
	setup(Meta)

	function Meta.new(props)
	  return setmetatable({
	    props = props,
	  }, Meta)
	end

	return function (props)
	  return {
	    type = tags.type.META,
	    props = props,
	    constructor = Meta
	  }
	end
      end
    end
 }}} ]]

local Entity = Class(Container)

function Entity:new(o)
  o = o or {}

  for k,v in pairs(o.data or {}) do
    self[k] = v
  end

  for k,v in pairs(o.attrs or {}) do
    self:attr(k,v)
  end

  self:attr('name', o.name)
  self:attr('signal', o.signal)
end

function Entity:on(name, listener)
  self.signal:on(name, listener)
end

function Entity:emit(...)
  self.signal:emit(...)
end

return Entity
