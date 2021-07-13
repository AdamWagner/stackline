local M = {}

function M.equal(a, b) --[[
    Adapted from: https://github.com/Yonaba/Moses/blob/master/moses.lua#L2786
    REVIEW: explore Interesting alternative from RBXunderscore: https://github.com/dennis96411/RBXunderscore/blob/master/RBXunderscore.lua#L1489
    == TESTS == {{{
    a = {name = 'john'}
    b = {name = 'john'}

    a1 = { {name = 'john'}, {name = 'cindy'} }
    b1 = { {name = 'john'}, {name = 'cindy'} }

    a3 = { {name = 'john'}, {name = 'cindy'}, 4, 5, 6 }
    b3 = { {name = 'john'}, {name = 'cindy'}, 4, 5, 6 }

    a4 = { {name = 'john'}, {name = 'cindy'}, 4, 5, 6 }
    b4 = { {name = 'john'}, {name = 'cindy'}, 4, 5, 7 }

    u.equal(a, b) -- -> true
    u.equal(a1, b1) -- -> true
    u.equal(a2, b2) -- -> true
    u.equal(a3, b3) -- -> true
    u.equal(a4, b4) -- -> false

    }}} ]]

    local typeA, typeB = type(a), type(b)

    -- Equal if direct compare is `true`. Note this will use mt.__eq if present and equal on both args.
    if a==b then return true end

    -- Not equal if either arg is nil
    if a==nil or b==nil then return false end

    -- Not equal if not of same type
    if typeA~=typeB then return false end

    -- If either arg is not a table, return direct comparison
    if not u.all({a,b}, u.istable) then return (a==b) end

    -- == NOTE: At this point, we know *both args ARE tables*

    -- Not equal if args do not have same length
    if u.len(a)~=u.len(b) then return false end

    -- == NOTE: Now we have no choice but to compare each k,v in the table

    -- Before doing so, do a safe sort (sorts if array only) first
    -- FIXME: causes error: bad argument #2 to 'sort' (function expected, got number)
    -- u.each({a,b}, u.sort)

    -- Deep compare elements of `a` and `b`
    for k in pairs(a) do if not u.equal(b[k], a[k]) then return false end end

    -- Finally, make sure that `b` doesn't have keys that are missing in `a`
    for k in pairs(b) do if a[k]==nil then return false end end

    return true
end 

function M.allEqual(t, comp) --[[
    Compare the 1st element in `t` to the other elements
    Return true if all equal ]]
    comp = comp or u.equal
    local _, first = next(t)
    for k, v in pairs(t) do
        if not comp(first, v) then return false end
    end
    return true
end 

function M.greaterThan(n) 
    return function(t)
        return #t > n
    end
end 

return M
