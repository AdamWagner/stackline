--[[ INSPO: {{{
  mode:       https://github.com/arrowresearch/mode/blob/master/lua/mode/util.lua#L9
  nvim-utils: https://github.com/hrsh7th/nvim-tuil/blob/master/lua/oop/class.lua
  modern:     https://github.com/skrolikowski/Modern
  http://tst2005.github.io/lua-users.org/wiki/YetAnotherClassImplementation.html
  https://github.com/Nezuo/class
  LOOP: Way too much, but some really neat stuff. https://github.com/DarrenGZY/script/tree/master/ide/ObjectOriented
  https://github.com/hrsh7th/nvim-tuil/blob/master/lua/oop/class.lua ← TO REVIEW
    TAB = setmetatable({}, { __index = function (self, n)
    self[n] = stringRep('    ', n)
    return self[n]


   - Cache module: https://github.com/daolie/kong_plugin/blob/master/kong/cache.lua
   - Container pattern (hide data): https://github.com/lua-stdlib/prototype/blob/master/lib/std/prototype/container.lua


  Neat Metamethod helper fns
  https://github.com/bhou/Bo-LuaOOP/tree/master/bhou/oo

  Minimal Libs -----------------------------------------------------------------
    8 Lines: https://github.com/sevanspowell/DraygonTensor/blob/develop/project/steps/share/scripts/class.lua
      .. and yet does most of what I want.
      Same project also has a very tiny FSM: https://github.com/sevanspowell/DraygonTensor/blob/develop/project/steps/share/scripts/fsm.lua
        + separate state class: https://github.com/sevanspowell/DraygonTensor/blob/develop/project/steps/share/scripts/state.lua
        ----------------------------------------
        function class(members)
          members = members or {}
          local mt = { __index     = members; }
          local function new(_, init)
            return setmetatable(init or {}, mt)
          end
          members.new  = members.new  or new
          return mt
        end
        ----------------------------------------


    Strange Finds
      https://github.com/kwiksher/kwik4tmplt/blob/master/components/store/storeFSM.lua
      This does NOT look clean. But it DOES look *real*. Might be a lesson here.
          Download Manager: https://github.com/kwiksher/kwik4tmplt/blob/master/components/store/downloadManagerV2.lua
          UI: https://github.com/kwiksher/kwik4tmplt/blob/master/components/store/UI.lua
              ↑ this is neat b/c it's a rare example of seeing an FSM in a clearly realistic scenario



  Major Libs -------------------------------------------------------------------

    =========LASH=============
      https://github.com/Taroven/lash

    =============LOOP =========
    - https://github.com/ImagicTheCat/Luaoop -- very informative

    “Private” instance properties can be achieved using a local table in the
    class definition with weak keys for the instances.
        local privates = setmetatable({}, {__mode = "k"})

        function Object:__construct()
          privates[self] = { a = 1, b = 2 }
          -- [AW NOTE]: ↑ private props can be stored *outside* the instance, but still be
          -- referenced for as long as the instance is alive. This was a bit of
          -- a light-bulb moment for me, and it could prove quite useful when
          -- redesigning the stackline datastructure in general.
              -- e.g., --> instead of storing references to parents on instances
              -- (which makes copying & inspecting harder), add a class method to
              -- *look up* the parent using instance properties such as `id`, etc.
              -- Note that I *had* planned to address this by 'hiding' this kind
              -- of data in the metatable index table, but this idea might be
              -- even cleaner (avoids needing to even think about dealing with
              -- the side-effects when inheriting - filtering out private data
              -- or somehow earmarking it with a naming convention.. )
        end

        function Object:method()
          local p = privates[self]
          p.a = p.a*p.b
        end

      https://github.com/okahyphen/base
      Very well-written README. Good refresher on OOP

  Happy Accidents --------------------------------------------------------------
  Group-oriented programming
    https://github.com/bvssvni/luagroups/blob/master/groups.lua

    Group Oriented Programming is a paradigm where computations are done with "groups".

    First we need some data to calculate with.
    Notice that Clark has no hair member.
        local people = {{name="John", hair=true}, {name="Clark"}}

    We can extract the groups we need on the fly.
        local name = groups_HasKey(people, "name")
        local hair = groups_HasKey(people, "hair")

        local name_and_hair = name * hair

    Loop through each index in group, starting at offset 1 to match Lua index.
        local person
        for i in group(name_and_hair, 1) do
            person = people[i]
            print(person.name)
        end


    A group generator is a function that iterates through an array and creates a
    group. The easiest way of doing this is by using the 'ByFunction' function,
    like this:

        function groups_LessThan(data, prop, value, region)
            return groups_ByFunction(data, function (data, i)
                local item = data[i]
                if item[prop] < value then return true
                else return false end
            end, region)
        end

    A group generator can also take a region group as argument to limit the
    scope of iterations. Using a region group is faster.

        -- A bit slower.
        local US = groups_HasKey(people, "US")
        local name = groups_HasKey(people, "name")
        local name_and_in_US = US * name

        -- A bit faster.
        local US = groups_HasKey(people, "US")
        local name_and_in_US = groups_HasKey(people, "name", US)

    It is the group generator that makes the difference. The performance of the
    algebra is not depending on the size of data, but how fragmented the
    information in the group is. This is completely determined by the data. When
    it comes to speed, it is the generators that matters.

  OOP Toolbox ------------------------------------------------------------------
    AMAZING! Super well-commented metatable utils & good examples of how
    metatamethods can be deployed to achieve specific OOP effects
      https://github.com/bhou/Bo-LuaOOP/tree/master/bhou/oo

    Pretty good. Found string indexing via brackets trick here:
      https://github.com/Paradigm-MP/oof/blob/master/shared/lua-additions/lua-additions.lua
    Also has well-commented base class file:
      https://github.com/Paradigm-MP/oof/blob/master/shared/object-oriented/class.lua
    And getter-setter mixins:
      https://github.com/Paradigm-MP/oof/blob/master/shared/object-oriented/shGetterSetter.lua

    OOPlib, ClassLib, and Async: https://github.com/sbx320/lua_utils

  One-off dude's Class libs:
    https://github.com/jonstoler/class.lua
end})
-- }}} ]]

local u = require 'lib.utils'

-- BaseClass
-- ———————————————————————————————————————————————————————————————————————————
local BaseClass = {}

-- Make it easy to create instances
--  e.g., local Human = Class()
function BaseClass:__call(...)
  return self:new(...)
end

-- Auto-wraps subclass:new( … ) to create a properly independent instance
function BaseClass:construct(newFn)
  -- NOTE: Auto-wraps subclass:new( … ) to create a properly independent instance {{{
  -- that inherits from the parent class. E.g.,
  --    Klass = require 'lib.Class2'
  --    Human = Klass()                -- or Klass:extend()
  --    function Human:new(name, age)
  --      self.name = name
  --      self.age = age
  --      return self
  --    end
  --    JohnDoe = Human('JohnDoe', 33)   -- or Human:new('JohnDoe', 33)
  -- }}}
  return function(_, ...)
    local obj = setmetatable({}, { __index = self })
    newFn(obj, ...)
    return obj
  end
end

-- If ":new()" is being set, wrap in constructor above
function BaseClass:__newindex(k,v)
  if k=='new' and type(v)=='function' then
   rawset(self, k, self:construct(v))
  else
   rawset(self, k, v)
  end
end

-- Extend the base class with optional mixins
function BaseClass:extend(...)
  local mt = {}
  mt.__index = table.merge(self, ...)  -- merge the props from all mixins provided
  mt.__newindex = BaseClass.__newindex -- intercept the :new() method for wrapping
  mt.__call = BaseClass.__call         -- make callable so instances can be created easily with :new()
  return setmetatable({}, mt)
end

-- Return a function to get a new BaseClass
-- Examples:
--     local Person = Class()
--     local Person = Class(kung_foo) -- use mixins to share behavior with the class
--     local Elder = Person:extend()  -- use :extend() to make subclasses that inherit from parent
return function(o)
  -- must clone optional base tbl, otherwise original class
  -- will *also* get methods defined on subclass
  local obj = u.dcopy(o or {})
  return BaseClass:extend(obj)
end
