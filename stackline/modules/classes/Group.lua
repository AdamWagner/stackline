class = require 'lib.class'

-- See: https://refactoring.guru/design-patterns/composite

--[[ == TEST == {{{

class = require 'lib.class'

handleEvent = require 'stackline.modules.handleEvent'

Item = class('Item', handleEvent)
function Item:new(id) self.id = id end
function Item:draw(args) print('drawing ', self.id, 'with args: ', hs.inspect(args)) end
function Item:getid() return self.id end
function Item:sayBye() print('By from ', self.id) end

Group = require 'stackline.modules.group'
Group:forwardCalls('draw', 'bye', 'getid')

comp = Group:new({}, 'Top Level')

-- Generate nested Tree structure
root = comp
prefix = ''

for _,n in pairs(u.range(19)) do
  if n~=0 and n % 5 == 0 then
    tmp = Group:new({}, prefix..n)
    prefix = prefix .. 'Nested'
    root:add(tmp)
    root = tmp
  else
    root:add(Item:new(prefix .. n))
    end
end

comp.children[6].children[5].children[5].children[4]:handle{id='Nested10'}

comp.children[6].children[5].children[5].children[4]:handle{id='3'}

----------------------------------------------------

function new(self, id) self.id = id end
function draw(self, args) print('drawing ', self.id, 'with args: ', hs.inspect(args)) end
function getid(self) return self.id end
function sayBye(self) print('By from ', self.id) end

one = Chain:new({ id = 'one', draw = draw, bye = sayBye, getid = getid })
two = Chain:new({ id = 'two', draw = draw, bye = sayBye, getid = getid })
three = Chain:new({ id = 'three', draw = draw, bye = sayBye, getid = getid })
four = Chain:new({ id = 'four', draw = draw, bye = sayBye, getid = getid })

comp = Group:new({ one, two, three, four }, 'Top Level')


nested1 = Chain:new({ id = 'nested1', draw = draw, bye = sayBye, getid = getid })
nested2 = Chain:new({ id = 'nested2', draw = draw, bye = sayBye, getid = getid })

nested = Group:new({ nested1, nested2 }, 'Nested')

comp:add(nested)


-- u.pheader('drawing each member of group')
-- comp:draw('drawing', 'args')

-- ids = comp:getid()

 }}} ]]

--[[ === RESEARCH: HOW TO STRUCTURE UI ELEMENTS === {{{

Areas to explore:
1. Composite pattern
  - Forward method calls to children. Eg, "obj:draw()" can be called on a group of many components or a single component in the same way

2.Event-driven design
  -  Propagation
    - Up from children?
    - Down from parent?
    - Both?! How to provide the right level of flexibility without making things too complex / abstract?

3.Change detection
  - Is it worth it to write a great Proxy class? 
  - Or, is it better to use explicit setter fns and track need to redraw explicitly (e.g., `obj:dirty()`)


== REFERENCE EXAMPLES ==


ltui - excellent simple terminal UI library. Pretty relevant, and admirably simplie. Manages own event loop, tho
.. it's actually the same as https://github.com/xmake-io/xmake/tree/master/xmake/core/ui tho?!
  https://github.com/tboox/ltui/blob/master/src/ltui/window.lua
  https://github.com/tboox/ltui/blob/master/src/ltui/panel.lua
  https://github.com/tboox/ltui/blob/master/src/ltui/view.lua
  https://github.com/tboox/ltui/blob/master/src/ltui/program.lua
  https://github.com/tboox/ltui/blob/master/tests/window.lua
  https://github.com/tboox/ltui/blob/master/tests/events.lua
  https://github.com/tboox/ltui/blob/master/tests/desktop.lua

Lua-Console-User-Interface
  Weird... this is much older, but seems to be related to ltui?!?
  https://github.com/gitmesam/Lua-Console-User-Interface/blob/master/lua_cui/lua/cui/group.lua
  https://github.com/gitmesam/Lua-Console-User-Interface/blob/master/lua_cui/lua/cui/window.lua
  https://github.com/gitmesam/Lua-Console-User-Interface/blob/master/lua_cui/lua/cui/view.lua
  https://github.com/gitmesam/Lua-Console-User-Interface/blob/master/lua_cui/lua/cui/program.lua

Fav examples from these URLs:
    https://github.com/elemel/heart-2/blob/master/heart/game/Entity.lua
    https://github.com/serlo/mfnf-lua-scripts/blob/master/src/Node.lua
    https://github.com/McSimp/Borderlands2SDK/blob/nogwen/lua/includes/modules/gwen/controls/Base.lua
    https://github.com/marmalade/OpenQuick/blob/master/samples/HelloWorld/quicklua/QNode.lua
    https://github.com/ebernerd/Flare/blob/master/lib/UIElement.lua#L290
    https://github.com/ebernerd/Flare/blob/master/lib/class.lua
    https://github.com/1bardesign/hallucinet/blob/master/src/ui.lua
    https://github.com/henkboom/beamer/blob/master/gui/Widget.lua
    https://github.com/AIValkyries/Unity_luaECS/blob/main/Assets/ToLua/Examples/02_ScriptsFromFile/Lua/Component.lua
    https://github.com/woshihuo12/UnityHello/blob/master/UnityHello/Assets/Lua/ai/bt/composite_node.lua
    https://github.com/szymonkaliski/hhtwm/blob/master/hhtwm/init.lua
    https://github.com/tavuntu/gooi/tree/master/gooi
    https://github.com/tavuntu/urutora/blob/master/urutora/panel.lua

    -- Handle events sent to this node. If there are any children, we work down the hierarchy.
    -- FROM: https://github.com/marmalade/OpenQuick/blob/master/samples/HelloWorld/quicklua/QNode.lua
    function QNode:handleEvent(event)
        local result = false
        result = handleEventWithListeners(event, self.eventListeners) -- Handle the event (just a "Bus" type fn. Src here: https://github.com/marmalade/OpenQuick/blob/master/samples/HelloWorld/quicklua/QEvent.lua#L127)

        -- Propagate the event to our children
        if result == false and not event.nopropagation then
            for i = 1,#self.children do
                result = self.children[i]:handleEvent(event)
                if result == true then
                    break
                end
            end
        end

        return result -- true if event handled
    end


    --mark a node's tree dirty
    -- FROM: https://github.com/1bardesign/hallucinet/blob/master/src/ui.lua
    function ui_base:dirty()
        if not self.is_dirty then
            self.is_dirty = true
            --todo: figure out which way this should actually propagate :)
            if self.parent then
                self.parent:dirty()
            end
            for i,v in ipairs(self.children) do
                v:dirty()
            end
        end
        return self
    end

    -- FROM: https://github.com/ebernerd/Flare/blob/master/lib/UIElement.lua#L290
    function UIElement:setChanged( changed )
        self.changed = changed
        if changed and self.parent then self.parent.changed = true end
    end


    function UIElement:update( dt )
        self:onUpdate( dt )
        for i = 1, #self.children do
            self.children[i]:update( dt )
        end
    end



    -- FROM: https://github.com/McSimp/Borderlands2SDK/blob/nogwen/lua/includes/modules/gwen/controls/Base.lua#L374
    function BaseControl:OnBoundsChanged(oldBounds)
        if self:GetParent() then
            self:GetParent():OnChildBoundsChanged(oldBounds, self)
        end

        if self.bounds.w ~= oldBounds.w or self.bounds.h ~= oldBounds.h then
            self:Invalidate()
        end

        self:Redraw()
        self:UpdateRenderBounds()
    end

 }}} ]]

Group = class('Group')
    :use('handleEvent')
    :use('hidePrivate')

Group.__printPrivate = true

function Group:new(children, id)
  self.id = id

  children = children or {}
  assert(u.is.array(children), 'Group expects instance to have array-like self.children. Got ' .. type(children))

  local parent = self
  self.children = u.map(children, function(c) 
    function c:parent() return parent end
    return c
  end)
end

function Group:resolve(evt)
  printf('Trying to resolve in "Group". Will execute if evt.id "%s" == self.id "%s"', evt.id, self.id)
  local match = self.id==evt.id

  if not match then
    printf('\n No match at parent, looking *↓ downward ↓* to child with id = "%s"', evt.id, self.id, next.id)

    -- FIXME: ...agner/.hammerspoon/stackline/stackline/modules/group.lua:95: attempt to index a function value (global 'next')
    match = u.unwrap(u.filter(self.children, {id = evt.id}))
    if match then
      match:handle(evt)
    end

  end
end

function Group:forwardCalls(...)
  for _, k in ipairs({...}) do
    self[k] = function(self, ...)  
      return u.invoke(self.children, k, ...) 
    end
  end
end

function Group:add(child)
  local parent = self
  function child:parent() return parent end
  table.insert(self.children, child)
  return self
end

return Group

