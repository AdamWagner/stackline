local FilteredPairs = {__name = 'FilteredPairs'}

FilteredPairs.omitPrivate = function(v, k)
  -- require `v` to be non-nil to hide dynamically inserted nil values caused by Stack:__len() metamethod to get #Stack.windows
  if u.is.str(k) then
    return k:sub(1,1)~='_' and k~='log' and v~=nil
  end
  return v~=nil
end

FilteredPairs.omitMeta = u.negate(u.is.metamethod)

function FilteredPairs:init()
    self._pairsFilter = omitPrivate
end

function FilteredPairs:setFilter(fnOrKey)
    self._pairsFilter = u.iscallable(fnOrKey) and fn or self[fnOrKey]
end

function FilteredPairs:rawpairs()
    return u.rawpairs(self)
end

function FilteredPairs:raw()
    local c = {}
    for k,v in self:rawpairs() do c[k] = v end
    return c
end

function FilteredPairs:__pairs()
   return u.rawpairs(
        u.filterKeys(self, self.omitPrivate)
    )
end

return FilteredPairs
