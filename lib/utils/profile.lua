-- FROM: https://github.com/Ruin0x11/OpenNefia/blob/develop/src/thirdparty/profile.lua
local clock = os.clock

local profile = {}

local labeled = {}  -- function labels
local defined = {}  -- function definitions
local tcalled = {}  -- time of last call
local telapsed = {} -- total execution time
local ncalls = {}   -- number of calls
local internal = {} -- list of internal profiler functions

function profile.hooker(event, line, info)-- {{{
  info = info or debug.getinfo(2, 'fnS')
  f = info.func
  if internal[f] or info.what ~= "Lua" then  -- ignore the profiler itself
    return
  end
               
  if info.name then -- get the function name if available
    labeled[f] = info.name
  end
                                                                              
  if not defined[f] then    -- find the line definition
    defined[f] = info.short_src..":"..info.linedefined
    ncalls[f] = 0
    telapsed[f] = 0
  end
  if tcalled[f] then
    dt = clock() - tcalled[f]
    telapsed[f] = telapsed[f] + dt
    tcalled[f] = nil
  end
  if event == "tail call" then
    prev = debug.getinfo(3, 'fnS')
    profile.hooker("return", line, prev)
    profile.hooker("call", line, info)
  elseif event == 'call' then
    tcalled[f] = clock()
    ncalls[f] = ncalls[f] + 1
  end
end-- }}}

function profile.setclock(f)-- {{{
  --- Sets a clock function to be used by the profiler.
  -- @param f Clock function that returns a number
  assert(type(f) == "function", "clock must be a function")
  clock = f
end-- }}}

function profile.start()-- {{{
  debug.sethook(profile.hooker, "cr")
end-- }}}

function profile.stop()-- {{{
  debug.sethook()
  for f in pairs(tcalled) do
    dt = clock() - tcalled[f]
    telapsed[f] = telapsed[f] + dt
    tcalled[f] = nil
  end

  -- merge closures
  lookup = {}
  for f, d in pairs(defined) do
    id = (labeled[f] or '?')..d
    f2 = lookup[id]
    if f2 then
      ncalls[f2] = ncalls[f2] + (ncalls[f] or 0)
      telapsed[f2] = telapsed[f2] + (telapsed[f] or 0)
      defined[f], labeled[f] = nil, nil
      ncalls[f], telapsed[f] = nil, nil
    else
      lookup[id] = f
    end
  end
  collectgarbage('collect')
end-- }}}

function profile.reset()-- {{{
  for f in pairs(ncalls) do
    ncalls[f] = 0
  end
  for f in pairs(telapsed) do
    telapsed[f] = 0
  end
  for f in pairs(tcalled) do
    tcalled[f] = nil
  end
  collectgarbage('collect')
end-- }}}

function profile.comp(a, b)-- {{{
  dt = telapsed[b] - telapsed[a]
  if dt == 0 then
    return ncalls[b] < ncalls[a]
  end
  return dt < 0
end-- }}}

--- Iterates all functions that have been called since the profile was started.
-- @param n Number of results (optional)
function profile.query(limit)-- {{{
  t = {}
  for f, n in pairs(ncalls) do
    if n > 0 then
      t[#t + 1] = f
    end
  end
  table.sort(t, profile.comp)
  if limit then
    while #t > limit do
      table.remove(t)
    end
  end
  for i, f in ipairs(t) do
    dt = 0
    if tcalled[f] then
      dt = clock() - tcalled[f]
    end
    t[i] = { i, labeled[f] or '?', ncalls[f], math.round(telapsed[f] + dt, 5), defined[f] }
  end
  return t
end-- }}}
cols = { 3, 29, 11, 24, 32 }

function profile.report(n) -- {{{

  d.inspectByDefault(false) -- Added by AW for printing to hammerspoon console 2021-07-18

  out = {}
  report = profile.query(n)

  for i, row in ipairs(report) do
    for j = 1, 5 do
      s = row[j]
      l2 = cols[j]
      s = tostring(s)
      l1 = s:len()
      if l1 < l2 then
        s = s..(' '):rep(l2-l1)
      elseif l1 > l2 then
        s = s:sub(l1 - l2 + 1, l1)
      end
      row[j] = s
    end
    out[i] = table.concat(row, ' | ')
  end
  row = " +-----+-------------------------------+-------------+--------------------------+-------------------------------- -- + \n"
  col = " | #   | Function                      | Calls       | Time                     | Code                             | \n"
  sz = row..col..row

  if #out > 0 then
    sz = sz..' | '..table.concat(out, ' | \n | ')..' | \n'
  end

  print('\n'..sz..row)

  d.inspectByDefault(true) -- Added by AW for printing to hammerspoon console 2021-07-18

end -- }}}

-- store all internal profiler functions
for k, v in pairs(profile) do
  if type(v) == "function" then
    internal[v] = true
  end
end

return profile
