
--[[
———————————————————————————————————————————————————————————————————————————
Ramda documentation for relevant functions
———————————————————————————————————————————————————————————————————————————

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

]]




--[[
————————————————————————————————————————————————————————————————————————————
Ramda experimentation
————————————————————————————————————————————————————————————————————————————

R = require 'lib.lamda'

d.inspectByDefault(true)

ws = u.map(stackline.wf:getWindows(), function(w)
  return stackline.window:new(w)
end)

x = {1,1,1,12,2,3,3,4,5,6,6,7,8,1,1,2,2,1,1,12}

function group(tbl)
  local xs = u.dcopy(tbl)
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
  local xs = u.dcopy(tbl)
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
  local xs = u.dcopy(tbl)
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
