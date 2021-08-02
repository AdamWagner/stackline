--[[
   == PATH UTILS ==
   ADAPTED FROM: https://github.com/darthzen/sierra-sdk/blob/master/SampleApps/AirVantageAgent/avagent_r8m/luafwk/utils/path.lua

   Detailed explanation of the design concepts used in the "Treemanager" module of which path.lua is a part can be found here:
   https://github.com/nim65s/mihini-repo/blob/master/agent/agent/treemgr/init.lua

   In this module, "path" is *not equal to Lua path* (meaning the way Lua provide table indexing)
   In particular, 'table[ ]' notation is not supported
   Element separator is  '.' (dot)

   Provided path is always cleaned before being processed:
   if the path starts and/or ends with one or several dots, there are automatically removed.
      e.g.: `'...toto.tutu....'` means `'toto.tutu'`
   internal repetitions of successives dots are replaced by a single dot.
      e.g.: `'toto...tutu.tata..foo.bar'` means `'toto.tutu.tata.foo.bar'`

   If a path element can be *converted to a number*, then it is returned as a number,
   otherwise all elements or paths are returned as strings.
      e.g.: `split('a.2', 1)` -> `('a', 2)`   (where 2 is returned as a number)
      e.g.: `split('a.b.2e3.c', 1)` -> `('a', 'b.2000.c')`

  Relevant posts:
    https://www.reddit.com/r/lua/comments/kl27nb/how_to_check_if_some_element_such_as_tableab/
    https://stackoverflow.com/questions/23779151/accessing-deeply-nested-table-without-error

  Seems interesting, but doesn't work as expected
    https://github.com/wolfoops/safeget/blob/main/safeget.lua

  luasnip repo composes this functionality together from reusable chunks like `get(tbl, key1, key2)`
    SEE: https://github.com/pocomane/luasnip/blob/master/src/get.lua
        function get_rec(count, parent, child, ...)
          return count < 2 
            and parent 
            or get_rec(count-1, parent[child], ...)
        end

        function get(...) -- get
          local ok, data = pcall(function(...)
            return get_rec(select('#', ...), ...)
          end, ...)
          local result = ok and data or nil
          return result, not ok and data or nil
        end
]]

local Path = {}

function Path.segments(path) --[[ {{{
  Splits a string path on '.' into segments i na table.
  @param path string containing the path to split.
  @return list of split path elements.
  ]]
  assert(type(path)=='string', 'u.path.segments(path) requires `path` to be a string. Got '..type(path))
  -- Simpler version from: https://luazdf.aiq.dk/fn/splitpath.html
  local res = {}
  for segment in string.gmatch( path, "[^%.]+" ) do
    if #segment > 0 then
      table.insert(res, segment)
    end
  end
  return res

  --[[ TODO: Delete once the simpler impl. above is tested
  local t = {}
  local index, newindex, elt = 1
  repeat
    newindex = path:find('.', index, true) or #path + 1 -- last round
    elt = path:sub(index, newindex - 1)
    elt = tonumber(elt) or elt
    if elt and elt~='' then
      table.insert(t, elt)
    end
    index = newindex + 1
  until newindex == #path + 1
  return t ]]
end -- }}}

function Path.checkPath(path) --[[ {{{
  If the given path is a string, call path.segments() to get a table of segments
  Otherwise, assume the given path is already a table of segments ]]
  return type(path)=='table'
    and path
    or Path.segments(path)
end -- }}}

function Path.concat(...) -- Concatenate a sequence of path strings together {{{
  return table.concat({ ... }, '.')
end -- }}}

function Path.clean(path) -- Given path string like 'one.two.three',  remove trailing/preceding/doubling '.'. {{{
  return Path.concat(
    unpack(
      Path.segments(path)
    )
  )
end -- }}}

function Path.up(path) --[[ {{{
  u.path.up('window.focused.moved.special') -->  'window.focused.moved'
  u.path.up('window.focused.moved') -->  'window.focused'
  u.path.up('window.focused') -->  'window'
  u.path.up('window.') -->  'window'
  u.path.up('window') -->  'window'
  u.path.up('win') -->  'win'
  ]]
  local p = Path.segments(path)
  if #p > 1 then table.remove(p, #p) end -- Do not go 'up' if we're already at the root
  return Path.concat(unpack(p))
end -- }}}

function Path.find(t, path, autovivicate) --[[ {{{
  Retrieves the element in a sub-table corresponding to the path.
  @param t is the table to look into.
  @param path can be either a string (see @{segments}) or an array where `path[1]` is the root and `path[n]` is the leaf.
  @param autovivicate parameter allows to create intermediate tables as specified by the path, if necessary.  May be true, false, or 'noowr' (no overwrite). Default false.
  @return returned values depend on autovivicate value:

  * if autovivicate is false (or nil), find returns the table if it finds one, or it returns nil followed by the last
    non-nil value (which will always be a table)

  * if autovivicate is true, find overwrites or create tables as necessary so it always returns a table.

  * if autovivicate is 'noowr', find creates tables as necessary but does not overwrite non-table values. So as with
    `autovivicate=false`, it only returns a table if possible, otherwise nil if the path points to a neither-table-nor-nil
    value plus a second retval to the last non-nil table value.

  @usage 
    config = {toto={titi={tutu = 5}}}
    Path.find(config, "toto.titi")   -- will return the table titi
    Path.find(config, "toto.titi.bobo.bust")   -- will return the table titi
  ]]

  if t==nil then return nil end

  local p = Path.checkPath(path)

  for i, n in ipairs(p) do
    local v = t[n]

    if type(v)~='table' then -- Only return the penultimate *table*, not the final leaf value

      if not autovivicate or (autovivicate=='noowr' and v~=nil) then
        local valPath = Path.concat(
          unpack(table.slice(p, 1, i))
        )
        local lastNonNil = t
        return nil, lastNonNil, valPath
      else -- autovivicate (create table) if leaf value is *nil* 
        v = {}
        t[n] = v
      end
    end
    t = v -- update "t" to the latest value found
  end

  return t
end -- }}}

function Path.get(t, path, safe) --[[ {{{
  Gets the value of a table field. The field can be in a sub table.
  The field to get is indicated by a path relative to the table.
  @param t table where to get the value.
  @param path can be either a string (see @{split}) or an array where path[1] is the root and path[n] is the leaf.
  @param safe will not return nil (unless `t` is nil). It will return the last non-nil value in the path instead.
  @return value if the field is found, nil otherwise
  ]]
  local p = Path.checkPath(path)
  if p==nil then return end

  -- If the root of the path is a global, the caller likely included the root in "path", 
  -- so set 't' to the global table to handle this common case. E.g., Path.get('stackline.manager') 
  if _G[p[1]] then t = _G end

  local k = table.remove(p)  -- Pop the last path element off `p` — it's the key we care about
  if not k then return t end -- Also, if we can't find this last path element, just return input

  -- Get the penultimate element, which will be a *table*
  -- If it's non-nil, then return the value at key 'k' that we defined above
  t, lastNonNil, valPath  = Path.find(t, p)

  if lastNonNil and safe then 
    return lastNonNil, valPath
  end

  return t and t[k]
end -- }}}


function Path.accessor(tab, mkpath, ... ) --[[ {{{
  FROM: https://luazdf.aiq.dk/fn/accessor.html

  = TEST =
  obj = {
     name = { first_name = "Dave", last_name = "Yarwood" },
     age = 28,
     hobbies = { "music", "languages", "programming" }
  }
  age = u.path.accessor(obj, false, "age" )

  age:get()

  }}} ]]
   local path = { ... }

   local acsr = { parent=nil, value=tab, key=nil }

   for i, k in ipairs( path ) do
      if not acsr.value[ k ] and i ~= #path then
         if mkpath then acsr.value[ k ] = {} else return nil end
      end
      acsr.parent = acsr.value
      acsr.value = acsr.value[ k ]
      acsr.key = k
   end

   acsr.get = function( self )
      return self.value
   end
   acsr.set = function( self, v )
      self.value = v
      self.parent[ self.key ] = self.value
   end

   return acsr
end




function Path.set(t, path, value) --[[ {{{
  Sets a value in a tree-like table structure.
  The value to set is indicated by the path relative to the table.
  This function creates the table structure to store the value, unless the value to set is nil.
  If the value to set is nil and the table structure already exists then the value is set to nil.
  If the value is not nil, then the table structure is always created/overwritten and the value set.
  @param t table where to set the value.
  @param path can be either a string (see @{#(utils.path).split}) or an array where path[1] is the root and path[n] is the leaf.
  @param value the value to set.
  ]]
  local p = Path.checkPath(path)
  local k = table.remove(p) -- Pop the last path element off `p` — it's the key we care about

  -- If the root of the path is a global, then the caller very likely included the root in "path", 
  -- so set 't' to the global table to handle this common case.
  if _G[p[1]] then t = _G end

  t = Path.find(t, p, value~=nil) -- NOTE: 'autovivicate' when value is not nil

  if t then
    t[k] = value
  end
end -- }}}

return { path = Path }
