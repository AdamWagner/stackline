--[[ {{{
  == Utils ==

  Inspiration / Reference:

    -- Clean --
    github.com/darmyn/Knit/blob/main/src/Util/TableUtil.lua

    -- Kitchen Sync --
    github.com/stevedonovan/Microlight
    github.com/luapower/glue/blob/master/glue.lua

    -- Functional --
    github.com/CodeKingdomsTeam/rodash
    github.com/danielmgmi/lodash.lua
    github.com/rxi/lume/blob/master/lume.lua
    github.com/moriyalb/lamda/blob/master/dist/lamda.lua
    github.com/chunpu/shim/blob/master/lib/shim.lua
    github.com/Yonaba/Moses/blob/master/moses.lua                   (https://github.com/Yonaba/Moses/blob/master/doc/tutorial.md)
    github.com/JesterXL/luafp                                       (includes interesting "reactive" module w/ fp-style events)
    github.com/rwaaren/lodash-functions
    github.com/mirven/underscore.lua/blob/master/lib/underscore.lua (old)
    github.com/foeb/cranberry.lua/blob/master/cranberry.lua

    github.com/starwing/luaiter
    github.com/luafun/luafun (older, inspo for `luaiter`)

    github.com/aiq/luazdf
    github.com/pocomane/luasnip (strongly inspired by luazdf)

    github.com/gordonbrander/iter/blob/master/iter.lua
    github.com/aperezdc/lua-itertools
    github.com/tlrobrn/itertools_lua/blob/master/src/itertools.lua

    github.com/italomaia/lua_table/blob/master/src/lua_table.lua
    github.com/aillieo/tableext/blob/master/tableext.lua
    github.com/kitsunies/list.lua/blob/master/list.lua

    -- Time --
    github.com/rxi/tick
    github.com/kikito/cron.lua/blob/master/cron.lua

 }}} ]]
require 'stackline.lib.utils.globals'

local modulePath = "stackline.lib.utils.%s"

local function get(module)
  return require(modulePath:format(module))
end

local u = get('core')

for _, mod in ipairs{'types', 'compare',  'array', 'collections', 'functional', 'path', 'metatable', 'debug', 'extra' } do
  for k,v in pairs(get(mod)) do
    u[k] = v
  end
end


local function unchain(self) return self.chained end

local function inplace(self) 
  u.assign(self, self.chained) 
  self.chained = nil 
  return self 
end

local Chain = {
  new = function(self, t, o)
    o = o or {}
    o.chained = t
    setmetatable(o, {__index = self, __call = unchain})
    return o
  end,
  tap = function(self, f)
    f(self.chained)
    return self
  end,
  inspect = function(self) return self:tap(u.p) end,
  value = unchain,
  inplace = inplace
}

u.each(u, function(fn, k)
  Chain[k] = function(self, ...)
    self.chained = fn(self.chained, ...)
    return self
  end
end)

function u.chain(t) return Chain:new(t) end

return setmetatable(u, {__call = function(u, t) return u.chain(t) end})
