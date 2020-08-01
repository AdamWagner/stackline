--[[

  Copyright (C) 2018 Masatoshi Teruya

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
  THE SOFTWARE.

  flatten.lua
  lua-table-flatten
  Created by Masatoshi Teruya on 18/05/21.

--]] --- file-scope variables
local type = type
local next = next
local tostring = tostring
--- constants
local INF_POS = math.huge
local INF_NEG = -INF_POS

--- isFinite
-- @param n
-- @return ok
local function isFinite(n)
    return type(n) == 'number' and (n < INF_POS and n > INF_NEG)
end

--- encode
-- @param key
-- @param val
-- @return key
-- @return val
local function encode(key, val)
    -- default do-nothing
    return key, val
end

--- setAsTable
-- @param tbl
-- @param key
-- @param val
local function setAsTable(tbl, key, val) tbl[key] = val end

--- _flatten
-- @param tbl
-- @param maxdepth
-- @param encoder
-- @param depth
-- @param prefix
-- @param circular
-- @param setter
-- @param res
-- @return res
-- @return err
local function _flatten(tbl, maxdepth, encoder, depth, prefix, res, circular,
                        setter)
    local k, v = next(tbl)

    while k do
        if type(v) ~= 'table' then
            setter(res, encoder(prefix .. k, v))
        else
            local ref = tostring(v)

            -- set value except circular referenced value
            if not circular[ref] then
                if maxdepth > 0 and depth >= maxdepth then
                    setter(res, prefix .. k, v)
                else
                    circular[ref] = true
                    _flatten(v, maxdepth, encoder, depth + 1,
                             prefix .. k .. '.', res, circular, setter)
                    circular[ref] = nil
                end
            end
        end

        k, v = next(tbl, k)
    end

    return res
end

--- flatten
-- @param tbl
-- @param maxdepth
-- @param encoder
-- @param setter
-- @return res
local function flatten(tbl, maxdepth, encoder, setter)
    -- veirfy arguments
    if type(tbl) ~= 'table' then error('tbl must be table') end

    if maxdepth == nil then
        maxdepth = 0
    elseif not isFinite(maxdepth) then
        error('maxdepth must be finite number')
    end

    -- use default encode function
    if encoder == nil then
        encoder = encode
    elseif type(encoder) ~= 'function' then
        error('encoder must be function')
    end

    -- use default setter
    if setter == nil then
        setter = setAsTable
    elseif type(setter) ~= 'function' then
        error('setter must be function')
    end

    return _flatten(tbl, maxdepth, encoder, 1, '', {}, {[tostring(tbl)] = true},
                    setter)
end

return flatten
