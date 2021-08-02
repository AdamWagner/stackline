--[[
  == hidePrivate ==
  A mixin to exclude "private" keys from the `pairs` iterator
]]
local hidePrivate = { __name = 'HidePrivate'}

function hidePrivate:__pairs() -- {{{ omit keys that start with underscore when iterating
  if self.printPrivate then return u.rawpairs(self) end

  return u.rawpairs(
    u.filterKeys(self, function(v,k)
      if v==nil then return false end
      if u.is.num(k) then return true end
      if u.is.str(k) then
        return k:sub(1,1)~='_' and k~='log'
      end
    end)
  )
end  -- }}}


function hidePrivate:allPairs()
  return pairs(self)
end

return hidePrivate
