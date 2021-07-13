
local filter = require 'stackline.utils.iterators'.filter
local extend = require 'stackline.utils.collections'.extend


local M = {}

function M.methods(obj, ignoreMt) --[[ {{{
  = TEST =
    w = stackline.manager:get()[1].windows[1]
    methods = u.methods(w)
  ]]
  obj = obj or M
  local res = filter(obj, u.is.func)

  if ignoreMt then return res end

  local mt = getmetatable(obj)
  if mt and mt.__index then
    extend(res, M.methods(mt.__index))
  end
  return res
end -- }}}

function M.weakKeys(input) -- {{{
  local t = input or {}
  local mt = getmetatable(t)
  mt.__mode = 'k'
  return setmetatable(t, mt)
end -- }}}

function M.copyMetaMethods(from, to) --[[ {{{
  Copy metamethods from super to cls
  `from` is typically the super, and `to` is the subclass.
  This ensures metamethods defined on the class will be inherited by instances
  (normal methods can be looked up via instance's mt.__index, but
  metamethods cannot be inherited this way) ]]
  for _, k in ipairs(allowed_metamethods) do
    to[k] = from[k]
  end
end -- }}}

function M.getmetamethod(t, f) -- {{{
  local mt = getmetatable(t)
  return mt and rawget(mt,f)
end -- }}}

function M.setmetatablekey(t,k,v) -- {{{
  local mt = getmetatable(t) or {}
  rawset(mt, k, v)
  return setmetatable(t, mt)
end -- }}}

function M.filterMt(tbl) -- {{{
  if not M.istable(tbl) then return tbl end

  local mt = {}
  local not_mt = {}
  for k,v in pairs(tbl) do
    if ismetamethod(k) then
      mt[k] = v
    else
      not_mt[k] = v
    end
  end
  local original_mt = getmetatable(tbl)
  return setmetatable(mt, original_mt),  setmetatable(not_mt, original_mt)
end -- }}}

function M.rejectMt(tbl) -- {{{
  local is_mt, not_mt = M.filterMt(tbl)
  return not_mt
end -- }}}

function M.setIndexByEquality(tbl) --[[ {{{
  When looking up a table key, return value at any key that is *equal* to the given key.
  __eq() metamethod will drive equality comparison if set on keys that are tables.
  ]]
  local function indexByEquality(tbl, keyToFind)
    for extantKey, v in pairs(tbl) do
      if M.equal(extantKey, keyToFind) then
        return v
      end
    end
  end

  local mt = getmetatable(tbl) or {}
  mt.__index = indexByEquality

  return setmetatable(tbl, mt)
end -- }}}

function M.extend_mt(tbl, additional_mt) -- {{{
  local orig_mt = getmetatable(tbl)
  for k,v in pairs(additional_mt) do
    if k ~= '__index' then -- only want to copy class metamethods OTHER than index
      rawset(getmetatable(tbl), k, v)
    end
  end

  return tbl
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

return M
