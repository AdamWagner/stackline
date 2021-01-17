-- See also:
--   - https://github.com/amstel91/LuaLibs/blob/master/string/strl.lua
--   - https://github.com/Yonaba/Allen/blob/master/allen.lua
--   - https://github.com/lunarmodules/Penlight/blob/master/lua/pl/stringx.lua
--   - https://github.com/skrolikowski/Lua-Lander/blob/master/mods/string.lua

--[[ STRING INDEXING!
  http://lua-users.org/wiki/StringIndexing

  Discovered via: https://github.com/Paradigm-MP/oof/blob/master/shared/lua-additions/lua-additions.lua
  -- DEMO ----------------------------------------------------------------------
      a='abcdef'
      return a[4]       --> d
      return a(3,5)     --> cde
      return a{1,-4,5}  --> ace

  So there you have it:
    - one-byte substrings with square brackets
    - to-from substrings with round,
    - selected bytes with curly
--]]


getmetatable('').__index = function(str,i)
  if type(i) == 'number' then
    return string.sub(str,i,i)
  else
    return string[i]
  end
end

-- Extending the builtin `string` lib
-- ———————————————————————————————————————————————————————————————————————————
function string:split(p)  -- {{{
  local Container = require 'lib.Container'

  -- Splits the string [s] into substrings wherever pattern [p] occurs.
  -- Returns: a table of substrings or, a table with the string as the only element
  p = p or '%s' -- split on space by default
  local temp = {}
  local index = 0
  local last_index = self:len()

  while true do
    local i, e = self:find(p, index)

    if i and e then
      local next_index = e + 1
      local word_bound = i - 1
      table.insert(temp, self:sub(index, word_bound))
      index = next_index
    else
      if index > 0 and index <= last_index then
        table.insert(temp, self:sub(index, last_index))
      elseif index == 0 then
        temp = {self}
      end
      break
    end
  end

  return Container(temp)
end  -- }}}

function string:trim(char)  -- {{{
  char = char or '%p%c%s'
  -- select text *between* start & end pattern matching char
  -- (or punctuation & whitespace by default)
  local pattern = string.format("^[%s]*(.-)[%s]*$", char, char)
  return self:match(pattern)
end  -- }}}

function string:trim(char, trimPunctuation)  -- {{{
  -- use given char or check opts
  local defaultChar = trimPunctuation and '%p%c%s' or '%s'
  char = char or defaultChar

  -- local whitespace = string.format('^%s*(.-)%s*$', char) -- s:gsub(pat, '%1')

  local pattern = string.format("^[%s]*(.-)[%s]*$", char, char)

  return self:gsub(pattern, '%1')
  -- return self:match(pattern, '%1')
end  -- }}}

function string:distance(str2)  -- {{{
  -- Alternatives:
  --    https://github.com/Phrogz/Liqr
  local this, other = self:lower(), str2:lower()
  local len1, len2 = #this, #other

  local char1, char2, distance = {}, {}, {}

  this:gsub('.', function(c)
    table.insert(char1, c)
  end)

  other:gsub('.', function(c)
    table.insert(char2, c)
  end)

  for i = 0, len1 do distance[i] = {} end
  for i = 0, len1 do distance[i][0] = i end
  for i = 0, len2 do distance[0][i] = i end

  for i = 1, len1 do
    for j = 1, len2 do
      local a = distance[i - 1][j] + 1
      local b = distance[i][j - 1] + 1
      local c = distance[i - 1][j - 1] + (char1[i] == char2[j] and 0 or 1)
      distance[i][j] = math.min(a,b,c)
    end
  end
  return distance[len1][len2] / #other
end  -- }}}

function string:endsWith(str)  -- {{{
  local lastChar = self:sub(#self - (#str - 1))
  return lastChar == str
end  -- }}}

function string:startsWith(str)  -- {{{
  local firstChar = self:sub(1, #str)
  return firstChar == str
end  -- }}}

function string:ensureEndsWith(char)  -- {{{
  -- ensure string ends with given char
  if not self:endsWith(char) then
    self = self .. char
  end
end  -- }}}

function string:truncate(maxlen)  -- {{{
  local txtlen = self:len()
  if txtlen > maxlen then
    self = self:sub(1, maxlen - 3) .. "..."
  end
  return self
end  -- }}}

function string:capitalize()  -- {{{
    return self:gsub("^%l", string.upper)
end  -- }}}

function string.join(tbl, sep)
  sep = sep or '\n'
  return table.concat(tbl, sep)
end

-- -- Non-primative helpers
-- -- ———————————————————————————————————————————————————————————————————————————
-- local M = {}
--
-- function M.joinStr(tbl)
--   return table.concat(tbl, '\n')
-- end
--
-- return M
