-- array.lua: utils for array-like tables

local M = {}

function M.flatten(tbl, maxDepth) --[[ {{{
  Flattens *one* level by default. Pass higher `maxDepth` to go deeper.
  TEST -- {{{
    w = u.flatten(ws)

    ff = { 9,9, {1,2,3, {1,2,3} } ,{1,2,3, {1,2,3, {1,2,3} } } }
      > for k,v in u.iter(ff) do print(k,hs.inspect(v)) end
          1	9
          2	9
          3	{ 1, 2, 3, { 1, 2, 3 } }
          4	{ 1, 2, 3, { 1, 2, 3, { 1, 2, 3 } } }

    flatter = u.flatten(ff)
      > for k,v in u.iter(flatter) do print(k,hs.inspect(v)) end
          1	9
          2	9
          3	1
          4	2
          5	3
          6	{ 1, 2, 3 }
          7	1
          8	2
          9	3
          10	{ 1, 2, 3, { 1, 2, 3 } }


    flattest = u.flatten(ff, math.huge)
      > for k,v in u.iter(flatest) do print(k,hs.inspect(v)) end
          1	9
          2	9
          3	1
          4	2
          5	3
          6	1
          7	2
          8	3
          9	1
          10	2
          11	3
          12	1
          13	2
          14	3
          15	1
          16	2
          17	3
  }}} ]]
  local result = {}
  maxDepth = maxDepth or 1 -- TIP: pass math.huge for max maxDepth

  local function flatten(t, depth)
    depth = (depth or 0) + 1
    for k, v in pairs(t) do
      if u.is.tbl(v) and (depth <= maxDepth) then
        flatten(v, depth)
      elseif u.is.num(k) then
        table.insert(result,k,v) -- NOTE: val is appended sequentially if "k" is nil
      elseif u.is.str(k) then
        result[#result+1] = v
      end
    end
  end

  flatten(tbl)
  return result
end -- }}}


return M
