-- INSPO
--    https://github.com/lunarmodules/Penlight/blob/master/lua/pl/types.lua

local M = {}

local primatives = {
  'number',
  'table',
  'string',
  'boolean',
  'function',
  'userdata',
  'thread',
  'nil',
}

--- generate fns for all primative types
for _, v in ipairs(primatives) do
  M['is' .. v] = function(val) return type(val)==(v) end
  M['is_' .. v] = M['is' .. v]
end

-- compound types --------------------------------------------------------------
function M.isinteger(x)    -- {{{
  return M.is_number(x) or (x%1 ~= 0)
end  
M.is_integer = M.isinteger  -- }}}

function M.isarray(obj)  -- {{{
    --- Checks if the given argument is an array. 
    -- Assumes `obj` is an array if is a table with consecutive integer keys starting at 1.
    -- Thanks @Wojak and @Enrique García Cota for suggesting this
    -- See : http://love2d.org/forums/viewtopic.php?f=3&t=77255&start=40#p163624
  if not M.istable(obj) then return false end
  local i = 0
  for k in pairs(obj) do
    i = i + 1
    if obj[i] == nil then return false end
  end
  return true
end
M.is_array = M.isarray  -- }}}

function M.isSortable(x)  -- {{{
  local u = require 'lib.utils'
  return M.is_array(x)
    and u.none(u.values(x), M.is_table)
end  
M.issortable = M.isSortable
M.is_sortable = M.issortable -- }}}

function M.iscallable(x)  -- {{{
  if type(x)=='function' then return true end
  local mt = getmetatable(x)
  return mt and mt.__call ~= nil
end  
M.is_callable = M.iscallable -- }}}

-- type converters -------------------------------------------------------------
function M.toBool(val)  -- {{{
      -- Reference:
      -- function toBool( v )
      --   local n = tonumber( v )
      --   return n ~= nil and n ~= 0
      -- end
    local t = type(val)
    if M.is_boolean(val) then
        return val
    elseif M.is_number(val) then
        return val == 1 and true or false
    elseif M.is_string(val) then
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
    return (value == true) and 1 or (value == false) and 0
end  -- }}}

return M
