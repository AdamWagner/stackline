-- stackline-test-formatter.lua
-- Modified from: https://github.com/aperezdc/lua-matrix/blob/2946b558101a22dd0770a2548f938ada86475256/spec/detailUtfTerm.lua
--
-- OTHERS:
--  https://github.com/drmplanet/kdlenv/blob/master/koreader/base/spec/unit/verbose_print.lua

-- FROM penlight.lua -----------------------------------------------------------
local sep, other_sep, seps
local sub = string.sub
local path = {}
path.sep = '/'
path.dirsep = ':'
seps = {['/'] = true}
sep = path.sep

local function at(s, i)
  return sub(s, i, i)
end

local function splitpath(P)
  local i = #P
  local ch = at(P, i)
  while i > 0 and ch ~= sep and ch ~= other_sep do
    i = i - 1
    ch = at(P, i)
  end
  if i == 0 then
    return '', P
  else
    return sub(P, 1, i - 1), sub(P, i + 1)
  end
end
-- end penlight ----------------------------------------------------------------

local colors = require 'term.colors'

return function(options)

  local fileCount = 0
  local fileTestCount = 0
  local testCount = 0
  local successCount = 0
  local skippedCount = 0
  local failureCount = 0
  local errorCount = 0

  local width = tonumber(os.getenv('COLUMNS'))
  local busted = require 'busted'
  local handler = require 'busted.outputHandlers.utfTerminal'(options)

  local decorateTestName = function(testName)  -- {{{
    local out = {}
    for text, hashtag in testName:gmatch("([^#]*)(#?[%w_-]*)") do
      table.insert(out, colors.white(text))
      table.insert(out, colors.bright(colors.cyan(hashtag)))
    end
    return table.concat(out)
  end  -- }}}

  local function normWidth(text, padding)  -- {{{
    padding = padding or 0
    local remain = width - padding
    local len = #text

    if len > remain then
      text = text:sub(1, remain) .. " […] "
      len = #text
      return text
    end

    local filler = remain - len
    for i = 1, filler+2 do
      text = text .. ' '
    end
    return text
  end  -- }}}

  handler.fileStart = function(file)  -- {{{
    fileTestCount = 0
  end  -- }}}

  handler.fileEnd = function(element)  -- {{{
    local fname = handler.getFullName(element)

    if #fname > (width - 20) then
      _, fname = splitpath(fname)
    end

    if fileTestCount > 0 then
      local text = "\n  " .. fname
      text = normWidth(text)


      io.write(colors.bright(colors.reverse(colors.black(text)  .. "\n\n")))
        -- io.write(colors.reverse(colors.magenta(text)  .. "\n\n"))
      local rule = '┌'
      for i = 1, width - 3 do
        rule = rule .. '─'
      end
      rule = rule .. '┐'
        -- '─'
      io.write(colors.black(rule))
    end
  end  -- }}}

  handler.testStart = function(element, parent, status, debug)  -- {{{
    return nil, true
  end  -- }}}

  handler.testEnd = function(element, parent, status, debug)  -- {{{
    fileTestCount = fileTestCount + 1

    if not options.deferPrint then
    local successDot = colors.green('●')
    local failureDot = colors.red('◼')
    local errorDot   = colors.magenta('✱')
    local pendingDot = colors.magenta('◌')

    local string = successDot

    if status == 'pending' then
      string = pendingDot
    elseif status == 'failure' then
      string = failureDot
    elseif status == 'error' then
      string = errorDot
    end


    local name = handler.getFullName(element)

    local len = #name
    local space = math.floor(width - 10)

    if len > (space) then
      name = colors.dim(name:sub(1, space - 2) .. " […] ")
      len = space
      io.write("\n " .. name)
    else
      len = #name + 2
      if status == 'pending' then
        name = colors.black(name)
        io.write('\n ' .. colors.dim(name) .. " ")
      else
        io.write('\n ' .. decorateTestName(name) .. " ")
      end
    end

    for i = 1, width - len - 2 do
      io.write(colors.black('·'))
    end
    io.write(string)
    io.write(" ")
      -- io.flush()

    return nil, true
  end
end  -- }}}

  handler.suiteReset = function()  -- {{{
    fileCount = 0
    fileTestCount = 0
    testCount = 0
    successCount = 0
    skippedCount = 0
    failureCount = 0
    errorCount = 0

    return nil, true
  end  -- }}}

  handler.suiteStart = function(suite, count, total, randomseed)  -- {{{
    if total > 1 then
      io.write(repeatSuiteString:format(count, total))
    end
    if randomseed then
      io.write(randomizeString:format(randomseed))
    end
    io.write(suiteStartString)
    io.write(globalSetup)
      -- io.flush()

    return nil, true
  end  -- }}}

  busted.subscribe({'test', 'start'}, handler.testStart)
  busted.subscribe({'test', 'end'}, handler.testEnd)
  busted.subscribe({'file', 'end'}, handler.fileEnd)
  busted.subscribe({'file', 'start'}, handler.fileStart)

  return handler
end
