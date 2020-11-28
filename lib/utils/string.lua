-- See also:
--   - https://github.com/amstel91/LuaLibs/blob/master/string/strl.lua

function string:split(p)  -- {{{
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

    return temp
end  -- }}}

function string:trim(char)  -- {{{
  char = char or '%p%c%s'
    -- select text *between* start & end pattern matching char
    -- (or punctuation & whitespace by default)
  local pattern = string.format("^[%s]*(.-)[%s]*$", char, char)
  return self:match(pattern)
end  -- }}}

function string:distance(str2)  -- {{{
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

function string:endsWith(char)  -- {{{
  local lastChar = self:sub(#self)
  return lastChar == char
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
