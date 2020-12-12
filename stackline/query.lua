local u = require 'stackline.lib.utils'
local async = require 'stackline.lib.async'
local c = stackline.config:get()

  --[[ {{{


  -- reduceBy
  -- —————————————————————————————————————————————————————————————————————
Groups the elements of the list according to the result of calling
the String-returning function `keyFn` on each element and reduces the elements
of each group to a single value via the reducer function `valueFn`.
This function is basically a more general [`groupBy`](#groupBy) function.

reduceToNamesBy = R.reduceBy(function(acc, student)
  return R.append(student.name, acc)
end, {})

namesByGrade = reduceToNamesBy(function(student)
  local score = student.score
  return score < 65 and 'F' or
      score < 70 and 'D' or
      score < 80 and 'C' or
      score < 90 and 'B' or 'A'
end)

students = {{name = 'Lucy', score = 92},
        {name = 'Drew', score = 85},
        {name = 'Leo', score = 90},
        {name = 'Bart', score = 62}}

namesByGrade(students)   --> {A={"Lucy", "Leo"}, B={"Drew"}, F={"Bart"}}



  -- groupBy
  -- ———————————————————————————————————————————————————————————————————————————
Splits a list into sub-lists stored in an object, based on the result of
calling a String-returning function on each element, and grouping the
results according to values returned.

byGrade = R.groupBy(function(student)
  local score = student.score
  return score < 65 and 'F' or
      score < 70 and 'D' or
      score < 80 and 'C' or
      score < 90 and 'B' or 'A'
end)
students = {{name = 'Lucy', score = 92},
      {name = 'Drew', score = 85},
      {name = 'Leo', score = 90},
      {name = 'Bart', score = 62}}
byGrade(students)
  --> {
  -- 	A={{name="Lucy", score=92}, {name="Leo", score=90}},
  -- 	B={{name="Drew", score=85}},
  -- 	F={{name="Bart", score=62}}
  -- }


  -- groupWith
  -- ———————————————————————————————————————————————————————————————————————————
Takes a list and returns a list of lists where each sublist's elements are
	all satisfied pairwise comparison according to the provided function.
	Only adjacent elements are passed to the comparison function.

R.groupWith(R.equals, {0, 1, 1, 2, 3, 5, 8, 13, 21})
  --> {{0}, {1, 1}, {2}, {3}, {5}, {8}, {13}, {21}}

R.groupWith(function(a, b) return a + 1 == b end, {0, 1, 1, 2, 3, 5, 8, 13, 21})
  --> {{0, 1}, {1, 2, 3}, {5}, {8}, {13}, {21}}

R.groupWith(function(a, b) return a % 2 == b % 2 end, {0, 1, 1, 2, 3, 5, 8, 13, 21})
  --> {{0}, {1, 1}, {2}, {3, 5}, {8}, {13, 21}}

R.groupWith(R.eqBy(R.contains(R.__, "aeiou")), 'aestiou')
  --> {'ae', 'st', 'iou'}


  -- }}} ]]

local Query = {}

R = require 'lib.lamda'

function eq(a,b)
  return a == b
end

function Query.groupByStack(windows)  -- {{{
  local groupKey = c.features.fzyFrameDetect.enabled and 'stackIdFzy' or 'stackId' -- Group by raw stackId (frame dims) or *fzy* frame dims?
  return u.filter(table.groupBy(windows, groupKey), u.greaterThan(1))                  -- stacks have > 1 window, so ignore 'groups' of 1
end  -- }}}

-- FIXME: only works if equal windows are adjacent
Query.groupByStack = R.pipe(
  R.groupWith(eq),
  R.filter(R.pipe(R.length, R.lt(1)))
)

Query.groupByStack = R.pipe(
  table.groupBy, 
  R.filter(R.pipe(R.length, R.gt(R.__, 1)))
)

Query.groupByStack = u.pipe(
  table.groupBy, 
  u.values,
  function(gs)
    return u.filter(gs, u.greaterThan(1)) 
  end
)

--[[
GOAL
Group windows that are in roughly the same position on the screen. 

HOW
Given a list of Window objects, return a list of lists in which
all windows of each inner list have frame properties that are
considered "equal" within the configured tolerance.

The journey to simplify groupByStack() was challenging:
  1. Added Window.__eq metamethod that compares window equality 
     based on win.frame. If `fzyFrameDetect` is enabled, frames are considered
     equal if the difference of each frame prop is less than the `fuzzFactor`.

  2. Wrote an ugly function that delivered the desired result:
      ```lua
      function group(tbl)
        local xs = u.copyDeep(tbl)
        local groups = {}

        for _,w in pairs(xs) do
          local curr = u.filter(xs, u.isEqual(w))
          if #curr > 0 then
            table.insert(groups, curr)
            xs = u.reject(xs, w)
          end
        end

        return groups
      end
      ```

  3. Wrote a cleaner version that I *thought* would produce the same result:

      ```lua
      function group(tbl)
        local xs = u.copyDeep(tbl)
        return u.map(u.uniq(xs), function(x)
          return u.filter(xs, u.isEqual(x))
        end)
      end
      ```
     Mapping over uniques avoids needing to remove the grouped window from
     the parent list each time. The problem with this is that traditional uniqe
     functions assign each value in the list as a key in a table (which must be unique)
     and then return the keys. 

  4. Learned that indexing in lua uses raw equality, ignoring any __eq
     metamethod that may be set. So, 'unique' looks up each new window in
     the hash table, but *never* matches an existing key, and so always returns
     *all* windows.


  5. Updated u.uniq(…) to use __eq when looking up seen values: 

      ```lua
      local function indexByEquality(self, x) 
        for k,v in pairs(self) do 
          if k == x then 
            return v 
          end 
        end 
      end


      function M.uniq(tbl)
        -- 
        local seen = setmetatable({}, { __index = indexByEquality })
        local result = {}

        for _, val in ipairs(tbl) do
          if not seen[val] then
            seen[val] = true
            result[#result + 1] = val
          end
        end
        return result
      end
      ```


      ```lua
      group = u.pipe(
        table.groupBy,              -- groups by identity if grouping fn is nil 
        u.values,                   -- we only want the values, not the keys (which are instances of Window)
        u._filter(u.greaterThan(1)) -- stacks have > 1 window, so ignore 'groups' of 1
      )
      ```


  3. Learned that a traditional groupBy function can group "by" identity. With
     primitive values, this is equivilent to the goal of grouping all equal values
     together.



]]

Query.groupByStack = u.pipe(
  table.groupBy,              -- groups by identity if grouping fn is nil 
  u.values,                   -- we only want the values, not the keys (which are instances of Window)
  u._filter(u.greaterThan(1)) -- stacks have > 1 window, so ignore 'groups' of 1
)

--[[

R = require 'lib.lamda'

d.inspectByDefault(true)

ws = u.map(stackline.wf:getWindows(), function(w)
  return stackline.window:new(w)
end)

x = {1,1,1,12,2,3,3,4,5,6,6,7,8,1,1,2,2,1,1,12}

function group(tbl)
  local xs = u.copyDeep(tbl)
  local groups = {}

  for _,w in pairs(xs) do
    local curr = u.filter(xs, u.isEqual(w))
    if #curr > 0 then
      table.insert(groups, curr)
      xs = u.reject(xs, w)
    end
  end

  return groups
end

function _group(tbl)
  local xs = u.copyDeep(tbl)
  local groups = {}


  for _,w in pairs(xs) do
    local curr = u.filter(xs, u.isEqual(w))
    if #curr > 0 then
      table.insert(groups, curr)
      xs = u.reject(xs, w)
    end
  end

  return groups
end

function group(tbl)
  local xs = u.copyDeep(tbl)
  return u.map(R.uniq(xs), function(x)
    return u.filter(xs, u.isEqual(x))
  end)
end

-- This works on a list with primitive values ({1,2,3,1,1,2,2})
-- …but will NOT work on tables via __eq metamethod.
-- indexing uses raw equality: https://stackoverflow.com/questions/23173525/in-lua-does-indexing-a-table-with-a-table-as-the-key-call-the-eq-metamethod
function groupSame(tbl)
  return table.groupBy(tbl, function(x) return x end)
end


--]]



function Query.groupByApp(byStack, windows)  -- {{{
    -- TODO: Remove when https://github.com/Hammerspoon/hammerspoon/issues/2400 closed
  if u.len(byStack) > 0 then
    local stackedWinIds = Query.getStackedWinIds(byStack)
    local stackedWins = u.filter(windows, function(w)
      return stackedWinIds[w.id]   -- true if win id is in stackedWinIds
    end)

    return table.groupBy(stackedWins, 'app')   -- app names are keys in group
  end
end -- }}}

function Query.getWinStackIdxs() -- {{{
  local r = async()
  hs.task.new(c.paths.getStackIdxs, function(code, out, err)
    r.resolve(out)
  end):start()
  return r:wait()
end -- }}}

function Query.getStackedWinIds(byStack) -- {{{
  local stackedWinIds = {}
  for _, group in pairs(byStack) do
    for _, win in pairs(group) do
      stackedWinIds[win.id] = true
    end
  end
  return stackedWinIds
end -- }}}

function Query.groupWindows(ws) -- {{{
--[[ Given windows from hs.window.filter:
       1. Create stackline window objects
       2. Group wins by `stackId` prop (aka top-left frame coords)
       3. If at least one such group, also group windows by app (to workaround hs bug unfocus event bug)
  ]]
  local windows = u.map(ws, function(w)
    return stackline.window:new(w)
  end)

  local byStack = Query.groupByStack(windows)
  local byApp = Query.groupByApp(byStack, windows)

  return byStack, byApp
end -- }}}

function Query.mergeWinStackIdxs(groups, winStackIdxs) -- {{{
  -- merge windowID <> stack-index mapping queried from yabai into window objs
  return u.map(groups, function(group)
    return u.map(group, function(w)
      w.stackIdx = winStackIdxs[tostring(w.id)]
      return w
    end)
  end)
end -- }}}

local function remap(groupedWindows)  -- {{{
  return { windows = groupedWindows }
end  -- }}}

function Query.shouldRestack(groupedWindows) -- {{{
  -- Analyze new vs. current to determine if a stack refresh is needed
  --  • change num stacks (+/-)
  --  • changes to existing stack
  --    • change position
  --    • change num windows (win added / removed)
  local curr = stackline.manager:getSummary()
  local new = stackline.manager:getSummary(u.map(groupedWindows, remap))

  if curr.numStacks ~= new.numStacks then
    return true
  elseif not u.equal(curr.topLeft, new.topLeft) then
    return true
  elseif not u.equal(curr.numWindows, new.numWindows) then
    return true
  end
end -- }}}

function Query.run(ws) -- {{{
  local byStack, byApp = Query.groupWindows(ws)

  local extantStackExists = stackline.manager:getSummary().numStacks > 0
  local shouldRefresh = (extantStackExists and Query.shouldRestack(byStack)) or true

  if shouldRefresh then
    async(function()
      local ok, winStackIndexes = pcall(hs.json.decode, Query.getWinStackIdxs())

      if ok then
        byStack = Query.mergeWinStackIdxs(byStack, winStackIndexes)
        stackline.manager:ingest(byStack, byApp, extantStackExists) -- hand over to the Stack module
      end
    end)
  end
end -- }}}

return Query
