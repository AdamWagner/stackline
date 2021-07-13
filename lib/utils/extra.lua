local M = {}

function M.inject(t, mt_index) --[[ {{{
  ADAPTED FROM: https://github.com/peete-q/assets/blob/master/lua-modules/lib/metatable.lua
  SEE ALSO: https://github.com/MyMindWorld/Starbound_mods/blob/master/unpacked/interface/games/util.lua#L2
  = TEST = {{{
    x = { name = 'adam', age = 33 }
    setmetatable(x, {__call = function() print('called "x"') end})
    u.inject(x, {job = 'farmer'})
    u.inject(x, {color = 'red'})
    u.inject(x, {type = 'Person'})
  }}} ]]

  assert(u.is.tbl(mt_index), "u.inject(t, mtidx): invalid metatable: " .. tostring(mt_index))

  -- This works b/c the metatable is being mutated below
  -- It's not necessary to setmetatable(t, mt) again afterward.
  local mt = getmetatable(t) or {}
  setmetatable(t, mt)

  if type(oldindex) == "table" then
    function mt.__index(t, k)
      return mt_index[k] or oldindex[k]
    end

  else
    function mt.__index(t, k)
      return mt_index[k] or oldindex(t, k)
    end
  end
end -- }}}

function M.flattenPath(tbl) -- {{{
  local function flatten(input, mdepth, depth, prefix, res, circ) -- {{{
    local k, v = next(input)
    while k do
      local pk = prefix .. k
      if not u.is.tbl(v) then
        res[pk] = v
      else
        local ref = tostring(v)
        if not circ[ref] then
          if mdepth > 0 and depth >= mdepth then
            res[pk] = v
          else   -- set value except circular referenced value
            circ[ref] = true
            local nextPrefix = pk .. '.'
            flatten(v, mdepth, depth + 1, nextPrefix, res, circ)
            circ[ref] = nil
          end
        end
      end
      k, v = next(input, k)
    end
    return res
  end -- }}}

  local maxdepth = 0
  local prefix = ''
  local result = {}
  local circularRef = {[tostring(tbl)] = true}

  return flatten(tbl, maxdepth, 1, prefix, result, circularRef)
end -- }}}

function M.aliasTableKeys(aliasLookup, keyFn, selfFn, tbl) -- {{{
  keyFn = keyFn or M.identity   -- unconditionally transform the key (e.g., remove 's' from string)
  selfFn = selfFn or M.identity -- transform self before doing lookup (e.g., try looking in a child table)

  local __args = {aliasLookup, keyFn, selfFn, tbl}

  if type(tbl)~='table' then return tbl end

  setmetatable(tbl, {
    __index = function(self, key)
      xform_key = keyFn(key)
      local k = aliasLookup[key] or aliasLookup[xform_key] or xform_key
      return rawget(selfFn(self), k) 
    end
  })

  return tbl -- Not necessary to return anything, since setmetatable(t) mutates 't', but we do anyway
end -- }}}

function M.makeTypeMetatable(builtin)  --[[ {{{
  Invert the key,val pairs of builtin to get a reverse-lookup
  If a table modded with this fn can't find a key on its own, it will use
  this lookup table to map the given key to an alternative key ]]
  local aliasLookup = u.invert(builtin)

  -- Transform lookup string before indexing `u.is` and even the root `u` module
  -- Strip trailing "s" (to ignore pluralization) & leading "is"
  local key_fn = function(key)
    key = key:gsub('s$',''):gsub('^is','')
    return key
  end

  -- Transform self to try to find key within child 'is' table
  local self_fn = function(self)
    return rawget(self, 'is') or self
  end

  -- Partially apply the key lookup table + key/self xformation fns
  -- The last remaining arg to u.aliasTableKeys() will be the *tbl*
  local addTypecheckAliases = u.curry(u.aliasTableKeys)(aliasLookup, key_fn, self_fn)

  return addTypecheckAliases
end  -- }}}

function M.groupByInnerKeys(tbl) 
  -- From: https://github.com/CVandML/torchnet-master/blob/master/transform.lua#L242
  local res = {}
  for i, x in pairs(tbl) do
    for k, v in pairs(x) do
      if not res[k] then res[k] = {} end
      res[k][i] = v
      u.p(res)
    end
  end
  return res
end 

function M.task_cb(fn) -- wrap callback given to hs.task {{{
  return function(...)
    local out = {...}

    local is_hstask = function(x) -- {{{
      return #x==3
        and tonumber(x[1])
        and u.is.str(x[2])
    end -- }}}

    if is_hstask(out) then
      local stdout = out[2]

      if u.is.json(stdout) then
        -- NOTE: hs.json.decode cannot parse "inf" values
        -- yabai response may have "inf" values: e.g., frame":{"x":inf,"y":inf,"w":0.0000,"h":0.0000}
        -- So, we must replace ":inf," with ":0,"
        local clean = stdout:gsub(':inf,',':0,')
        stdout = hs.json.decode(clean)
      end

      return fn(stdout)
    end

    -- fallback if 'out' is not from hs.task
    return fn(out)
  end
end -- }}}

return M

