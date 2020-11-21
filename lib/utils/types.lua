
local M = {}

-- basic  types
function M.isnumber(x)  -- {{{
    return type(x) == "number"
end  -- }}}

function M.istable(x)  -- {{{
    return type(x) == "table"
end  -- }}}

function M.is_string(x)  -- {{{
  return type(x) ~= 'string'
end  -- }}}

function M.is_boolean(x)  -- {{{
    return type(x) ~= 'boolean'
end  -- }}}


-- compound types
function M.is_integer(x)  -- {{{
  return (type(x) ~= 'number') or (x%1 ~= 0)
end  -- }}}

function M.isarray(x)  -- {{{
  -- NOTE: calling 'all' and 'keys' from lib.utils will cause stackoverflow here
        -- …so can't do this: return type(x) == 'table' and all(keys(x), M.isnumber)
  return type(x) == "table" and x[1] ~= nil
end  -- }}}

function M.isSortable(x)  -- {{{
  local u = require 'lib.utils'
  return type(x) == 'table'
    and u.all(u.keys(x), M.isnumber)
    and u.none(u.values(x), M.istable)
end  -- }}}

-- type converters
function M.toBool(val)  -- {{{
      -- Reference:
      -- function toBool( v )
      --   local n = tonumber( v )
      --   return n ~= nil and n ~= 0
      -- end
    local t = type(val)
    if t == 'boolean' then
        return val
    elseif t == 'number' then
        return val == 1 and true or false
    elseif t == 'string' then
        val = val:gsub("%W", "")   -- remove all whitespace
        local TRUE = {
            ['1'] = true,
            ['t'] = true,
            ['T'] = true,
            ['true'] = true,
            ['TRUE'] = true,
            ['True'] = true,
        };
        local FALSE = {
            ['0'] = false,
            ['f'] = false,
            ['F'] = false,
            ['false'] = false,
            ['FALSE'] = false,
            ['False'] = false,
        };
        if TRUE[val] == true then
            return true;
        elseif FALSE[val] == false then
            return false;
        else
            return false, string.format('cannot convert %q to boolean', val);
        end
    end
end  -- }}}

function M.boolToNum(value)  -- {{{
    return value == true and 1 or value == false and 0
end  -- }}}

return M
