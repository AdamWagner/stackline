local function valAtKeyBy(t, wanted, by)
  -- get `v` at `k` if `by(k, wanted)` is true
  -- `by` can be prototyped as either `by(k)` or `by(k1,k2)`
  by = by or u.equal
  for k,v in pairs(t) do
    if by(k, wanted) then
      return v
    end
  end
end

local function lookup(t, k, by)
  return rawget(t, k) or valAtKeyBy(t, k, by)
end

local function appendNewindex(t, k, v)
  local mbGroup = t[k]
  if type(mbGroup)=='table' then
    table.insert(mbGroup, v)
  else
    rawset(t, k, {v})
  end
end

local function autogroup(matcher)
  matcher = matcher or u.equal
  return setmetatable({}, {
    __index = u.bindTail2(lookup, matcher),
    __newindex = appendNewindex,
  })
end

-- == AutoGroupable mixin ==
local AutoGroupable = {__name = 'AutoGroupable'}

-- Can be called as a regular function `AutoGroupable.autogroup()` 
-- Or, if used as a mixin on a class, as a method `instance:new():autogroup()`
function AutoGroupable:autogroup(opts)
  self = (self==nil) and {} or self
  opts = opts or {}
  self.matcher = self.matcher or opts.matcher

  return autogroup(self.matcher)
end

return AutoGroupable
