local curry =  require 'lib.utils.functions'.curry

local M = {}

function M.equal(a, b) -- {{{
  if #a ~= #b then
    return false
  end
  for i, _ in ipairs(a) do
    if b[i] ~= a[i] then
      return false
    end
  end

  return true
end -- }}}

function M.greaterThan(n) -- {{{
  return function(t)
    return #t > n
  end
end -- }}}

M.isEqual = curry(function (a, b) -- {{{
  --[[
    This function takes 2 values as input and returns true if they are equal
    and false if not. a and b can numbers, strings, booleans, tables and nil.
      --]]

  local function isEqualTable(t1, t2)
    if t1 == t2 then
      return true
    end

    for k, _ in pairs(t1) do
      if type(t1[k]) ~= type(t2[k]) then
        return false
      end
      if type(t1[k]) == "table" then
        if not isEqualTable(t1[k], t2[k]) then
          return false
        end
      else
        if t1[k] ~= t2[k] then
          return false
        end
      end
    end

    for k, _ in pairs(t2) do
      if type(t2[k]) ~= type(t1[k]) then
        return false
      end
      if type(t2[k]) == "table" then
        if not isEqualTable(t2[k], t1[k]) then
          return false
        end
      else
        if t2[k] ~= t1[k] then
          return false
        end
      end
    end
    return true
  end

  if type(a) ~= type(b) then
    return false
  end
  if type(a) == "table" then
    return isEqualTable(a, b)
  else
    return (a == b)
  end

end) -- }}}

function M.same(a, b) -- {{{
  --- Checks if two tables are the same. It compares if both tables features the
  -- same values, but not necessarily at the same keys.
  local u = require 'lib.utils'
  return u.all(a, function(v)
    return u.include(b, v)
  end) and u.all(b, function(v)
    return u.include(a, v)
  end)
end -- }}}

function M.deepEqual(a, b) -- {{{
  local u = require 'lib.utils'
  if u.isSortable(a) then
    table.sort(a)
  end
  if u.isSortable(b) then
    table.sort(b)
  end

  if type(a) ~= type(b) then
    local message = ("{1} is of type %s, but {2} is of type %s"):format(type(a), type(b))
    return false, message
  end

  if u.istable(a) and u.istable(b) and #a == #b then
    if M.same(a, b) then
      return true
    end
  end

  if type(a) == "table" then
    local visitedKeys = {}

    for key, value in pairs(a) do
      visitedKeys[key] = true

      local success, innerMessage = M.deepEqual(value, b[key])
      if not success then
        local message = innerMessage:gsub("{1}", ("{1}[%s]"):format(tostring(key))):gsub("{2}",
            ("{2}[%s]"):format(tostring(key)))

        return false, message
      end
    end

    for key, value in pairs(b) do
      if not visitedKeys[key] then
        local success, innerMessage = M.deepEqual(value, a[key])

        if not success then
          local message = innerMessage:gsub("{1}", ("{1}[%s]"):format(tostring(key))):gsub("{2}",
              ("{2}[%s]"):format(tostring(key)))

          return false, message
        end
      end
    end

    return true
  end

  if a == b then
    return true
  end

  local message = "{1} ~= {2}"
  return false, message
end -- }}}

function M.table_diff(A, B)  -- {{{
  -- FROM: https://github.com/martinfelis/luatablediff/blob/master/ltdiff.lua
  -- See alternate:
  --    /Users/adamwagner/Programming/Projects/stackline/lib/utils/table.lua:215
  --    https://github.com/Alloyed/patch.lua/blob/master/patch.lua
  --    https://github.com/lijinlong/tbdiff
  --    https://github.com/LuaDist-testing/ltdiff/blob/master/ltdiff.lua
  --    https://github.com/leegao/AMX2D/blob/9ccb32e5320e37f091d7814147b862ba14a82e47/core/table.lua#L288
  --    https://github.com/flingo64/PhotoStation-Upload-Lr-Plugin/blob/master/PhotoStation_upload.lrplugin/PSUtilities.lua#L299
  --          Supports filtering by keys first, and supplying equality func

  -- NOTE: copying the tables before comparison BREAKS the comparison!!
  -- No differences are found!
  -- A = u.copyDeep(A)
  -- B = u.copyDeep(B)

  -- for k,v in pairs(A) do
  --   if type(A[k]) == "function" or type(A[k]) == "userdata" then
  --     A[k] = nil
  --   end
  -- end
  -- for k,v in pairs(B) do
  --   if type(B[k]) == "function" or type(B[k]) == "userdata" then
  --     B[k] = nil
  --   end
  -- end

  local diff = {del = {}, mod = {}, sub = {}}

  for k, v in pairs(A) do
    if type(A[k]) == "function" or type(A[k]) == "userdata" then
      -- error("table_diff only supports diffs of tables!")
      -- do nothing (skip)

    elseif B[k] ~= nil and type(A[k]) == "table" and type(B[k]) == "table" then
      diff.sub[k] = M.table_diff(A[k], B[k])

      if next(diff.sub[k]) == nil then
        diff.sub[k] = nil
      end

    elseif B[k] == nil then
      diff.del[#(diff.del) + 1] = k

    elseif B[k] ~= v then
      print('not equal!!')
      diff.mod[k] = B[k]
    end
  end

  for k, v in pairs(B) do
    if type(B[k]) == "function" or type(B[k]) == "userdata" then
      -- error("table_diff only supports diffs of tables!")
      -- do nothing (skip)

    elseif diff.sub[k] ~= nil then
      -- do nothing (skip)

    elseif A[k] ~= nil and type(A[k]) == "table" and type(B[k]) == "table" then
      diff.sub[k] = M.table_diff(B[k], A[k])

      if next(diff.sub[k]) == nil then
        diff.sub[k] = nil
      end

    elseif B[k] ~= A[k] then
      diff.mod[k] = v
    end
  end

  if next(diff.sub) == nil then
    diff.sub = nil
  end

  if next(diff.mod) == nil then
    diff.mod = nil
  end

  if next(diff.del) == nil then
    diff.del = nil
  end

  return diff
end  -- }}}

return M
