local M = {}

M.identity = function(val) return val end

function M.roundToNearest(roundTo, numToRound) -- {{{
    return numToRound - numToRound % roundTo
end -- }}}

function M.length(t) -- {{{
   local len, ty = 0, type(t)
   local countable = (ty=='table' or ty=='string')
   if not countable then return 0 end

   for _ in next, t do
      len = len + 1
   end

   return len
end
M.len = M.length -- alias as M.len
-- }}}

function M.unwrap(tbl) --[=[ {{{
  Recurseively flatten 'redundant' tables
  Distinct from `M.flatten()` as it preserves non-redundant tables
  = TESTS = {{{
  M.unwrap( {1,2} )   -> { 1, 2 } · Does nothing when there's more than 1 element
  M.unwrap( {1} )     -> 1        · Returns plain-old '1'
  M.unwrap( {{1}} )   -> 1        · Same; The wrapping table is 'redundant'
  M.unwrap( {{1,2}} ) -> 1        · {1,2}; The 1st wrapping table is redundant, but the inner table is the desired value, and so not unpacked into multiple retvals.

  M.unwrap( {{name='me'}} )   -> {name='me'}
  M.unwrap( {{name='me'},2} ) -> {{name='me'},2}
  }}} ]=]

  -- Use M.len (vs #tbl) to count non-sequential keys
  -- type(...) only checks the 1st arg. E.g., type(1, {}) == 'number'
  while M.len(tbl)==1 and type(tbl)=='table' do
    tbl = tbl[1]
  end
  return tbl -- otherwise return the original tbl
end -- }}}

function M.wrap(...) --[[ {{{
   Ensure that all arguments are wrapped in a table
   If the 1st and only arg is a table itself, it will be returned as-is
   == TESTS == {{{
     a = M.wrap(1,2,3,4)                                -> { 1, 2, 3, 4 }
     b = M.wrap({1,2,3,4})                              -> { 1, 2, 3, 4 }
     c = M.wrap({name = 'johnDoe'}, {name = 'janeDoe'}) -> { { name = "johnDoe" }, { name = "janeDoe" } }
     d = M.wrap({ name = 'johnDoe' }, 1,2,3)            -> { { name = "johnDoe" }, 1, 2, 3 }
   }}} ]]
   return M.unwrap({...})
end -- }}}

function M.keys(t) -- {{{
  local rtn = {}
  for k in pairs(t or {}) do
    rtn[#rtn + 1] = k
  end
  return rtn
end -- }}}

function M.values(t) -- {{{
  local values = {}
  for _k, v in pairs(t) do
    values[#values + 1] = v
  end
  return values
end -- }}}

function M.cb(fn) -- {{{
    return function()
        return fn
    end
end -- }}}

return M
