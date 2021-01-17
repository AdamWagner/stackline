local curry =  require 'lib.utils.functions'.curry
local len = table.len
local format = string.format

-- local comparison helpers
local function anyNil(...) return u.any({...}, u.is_nil) end
local function allTables(...) return u.all({...}, u.is_table) end
local function eqType(a,b) return type(a)==type(b) end
local function eqLen(a,b) return len(a)==len(b) end
local function eq(a,b) return a==b end


-- presentation helpers
local function show(x)
  local u = require 'lib.utils.types'
  if u.is_table(x) then return hs.inspect(x) end
  return x
end

local M = {}

function M.checkFuzzy( n1, n2 )
  -- Deals with floats / verify false false values.
  -- This can happen because of significant figures.
  -- FROM: https://github.com/kabbend/fading/blob/main/server/yui/yaoui/UI/mlib/mlib.lua
	return ( n1 - .00001 <= n2 and n2 <= n1 + .00001 )
end


function M.equal(a, b) -- {{{
  local iter = require 'lib.utils.collections'.iter
  if eq(a,b) then return true end
  for i, _ in iter(a) do
    if b[i]~=a[i] then return false end
  end

  return true
end -- }}}

M.isEqual = curry(function (a, b) -- {{{
  --[[
    This function takes 2 values as input and returns true if they are equal
    and false if not. a and b can numbers, strings, booleans, tables and nil.
  --]]

  local function isEqualTable(t1, t2)  -- {{{
    if t1==t2 then return true end

    for k, _ in pairs(t1) do
      if type(t1[k])~=type(t2[k]) then
        return false
      end
      if u.is_table(t1[k]) then
        if not isEqualTable(t1[k], t2[k]) then
          return false
        end
      else
        if t1[k]~=t2[k] then
          return false
        end
      end
    end

    for k, _ in pairs(t2) do
      if type(t2[k])~=type(t1[k]) then
        return false
      end
      if u.is_table(t2[k]) then
        if not isEqualTable(t2[k], t1[k]) then
          return false
        end
      else
        if t2[k]~=t1[k] then
          return false
        end
      end
    end
    return true
  end  -- }}}

  if type(a)~=type(b) then
    return false
  end
  if u.is_table(a) then
    return isEqualTable(a, b)
  else
    return (a==b)
  end

end) -- }}}

function M.same(t1,t2) -- {{{
  local msgs = u.pipe( string.join, u.printWarning)

  --[[ {{{ NOTES
  INSPO: See 'module.basically_the_same()' func here:
      https://github.com/dabrady/lua-utils/blob/master/table.lua#L494

  EXAMPLE / TEST CASE
      a = { name = 'JohnDoe', age = 33 }
      b = { nom = 'JohnDoe', age = 33 }
      c = u.dcopy(b)
      u.same(a,c) -- --> false
      c.nom = nil
      c.name = 'JohnDoe'
      u.same(a,c) -- --> true

  Implementation #1
      Compare if both tables features the same values, but not necessarily at the same keys.
      return u.all(t1, function(va) return u.include(t2, va) end)
         and u.all(t2, function(vb) return u.include(t1, vb) end)
  -- }}} ]]

  -- Actually equal — short-circut
  if eq(t1, t2) then return true, '\nExactly equal' end

  -- Not even the same type or at least one `nil` — short-circuit
  if not (eqType(t1, t2) or anyNil(t1,t2)) then
    return false, msgs{'Different type or at least one Nil', hs.inspect(t1), hs.inspect(t2)}
  end

  -- Tables of different lengths are unlikely to be 'same' — short-circuit
  -- NOTE: Keep an eye on the messages for this one ↑
  if not eqLen(t1,t2) then
    return false, msgs{format('Different lengths: %s vs %s', len(t1), len(t2))}
  end

  if not allTables(t1, t2) then
    -- TODO: When needed, improve comparison for strings & numbers (lowercase, fuzzy number matching)
    return t1 == t2
  end

   -- Implementation #2 — now catches differences in *keys* as well as values
   -- If any value of t2 is not in the values of t1, they're different.
    for k1,v1 in u.iter(t1) do
      local v2 = t2[k1]
      if v2==nil or v1~=v2 then
        return false, msgs({
          format('v2 is nil or does not equal v1 for key = %s', k1),
          format('\n\t v1:%s', show(v1)),
          format('\n\t v2:%s', show(v2)),
        }, '')
      end
    end

    -- If any value of t1 is not in the values of t2, they're different.
    for k2,v2 in u.iter(t2) do
      local v1 = t1[k2]
      if v1==nil or v1~=v2 then
        return false
      end
    end

    -- if we've reached this point without returning false,
    -- the 2 tables can be considered the same
    return true
end -- }}}

function M.deepEqual(a, b) -- {{{
  local u = require 'lib.utils'

  local function errorMsg(msg, key)
    return msg
      :gsub("{1}", ("{1}[%s]"):format(tostring(key)))
      :gsub("{2}", ("{2}[%s]"):format(tostring(key)))
  end

  -- Succeed early if actually equal
  if a==b then return true end

  -- Fail early if not the same type
  if type(a)~=type(b) then
    local message = ("{1} is of type %s, but {2} is of type %s"):format(type(a), type(b))
    return false, message
  end

  if u.isSortable(a) then table.sort(a) end
  if u.isSortable(b) then table.sort(b) end

  -- FIXME: u.same() is less strict, so it may be a bad idea to give it the
  -- power to return true here.
  if u.all({a,b}, u.is_table) and #a==#b then
    if M.same(a, b) then return true end
  end

  if u.is_table(a) then
    local visitedKeys = {}

    for k,v in pairs(a) do
      visitedKeys[k] = true
      local iseq, msg = M.deepEqual(v, b[k])
      if not iseq then return false, errorMsg(msg) end
    end

    for k,v in pairs(b) do
      if not visitedKeys[k] then
        local iseq, msg = M.deepEqual(v, a[k])
        if not iseq then return false, errorMsg(msg) end
      end
    end

    return true
  end


  local message = "{1}~={2}"
  return false, message
end -- }}}

function M.table_diff(A, B)  -- {{{
  --[[ {{{ NOTES
     FROM: https://github.com/martinfelis/luatablediff/blob/master/ltdiff.lua
  See alternate:
     /Users/adamwagner/Programming/Projects/stackline/lib/utils/table.lua:215
     https://github.com/Alloyed/patch.lua/blob/master/patch.lua
     https://github.com/lijinlong/tbdiff
     https://github.com/LuaDist-testing/ltdiff/blob/master/ltdiff.lua
     https://github.com/leegao/AMX2D/blob/9ccb32e5320e37f091d7814147b862ba14a82e47/core/table.lua#L288
     https://github.com/flingo64/PhotoStation-Upload-Lr-Plugin/blob/master/PhotoStation_upload.lrplugin/PSUtilities.lua#L299
           Supports filtering by keys first, and supplying equality func



  NOTE: copying the tables before comparison BREAKS the comparison!!
  No differences are found!
  A = u.dcopy(A)
  B = u.dcopy(B)

  for k,v in pairs(A) do
    if type(A[k])=="function" or type(A[k])=="userdata" then
      A[k] = nil
    end
  end
  for k,v in pairs(B) do
    if type(B[k])=="function" or type(B[k])=="userdata" then
      B[k] = nil
    end
  end
  }}} ]]

  local diff = {del = {}, mod = {}, sub = {}}

  for k, v in pairs(A) do
    if type(A[k])=="function" or type(A[k])=="userdata" then
      -- error("table_diff only supports diffs of tables!")
      -- do nothing (skip)

    elseif B[k]~=nil and type(A[k])=="table" and type(B[k])=="table" then
      diff[k] = M.table_diff(A[k], B[k])

      if next(diff[k])==nil then
        diff[k] = nil
      end

    elseif B[k]==nil then
      diff.del[#(diff.del) + 1] = k

    elseif B[k]~=v then
      print('old (A)', A[k])
      print('new (B)', B[k])
      diff.mod[k] = {old = A[k], new = B[k]}
    end
  end

  for k, v in pairs(B) do
    if type(B[k])=="function" or type(B[k])=="userdata" then
      -- error("table_diff only supports diffs of tables!")
      -- do nothing (skip)

    elseif diff.sub[k]~=nil then
      -- do nothing (skip)

    elseif A[k]~=nil and type(A[k])=="table" and type(B[k])=="table" then
      diff[k] = M.table_diff(A[k], B[k])

      if next(diff[k])==nil then
        diff[k] = nil
      end

    elseif B[k]~=A[k] then
      -- print('old (A)', A[k])
      -- print('new (B)', B[k])
      diff.mod[k] = {old = A[k], new = B[k]}
    end
  end

  if next(diff.sub)==nil then
    diff.sub = nil
  end

  if next(diff.mod)==nil then
    diff.mod = nil
  end

  if next(diff.del)==nil then
    diff.del = nil
  end

  return diff
end  -- }}}

function M.greaterThan(n) -- {{{
  return function(t)
    return #t > n
  end
end -- }}}

return M
