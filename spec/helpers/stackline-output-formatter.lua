-- stackline-test-formatter.lua
-- Modified from: https://github.com/aperezdc/lua-matrix/blob/2946b558101a22dd0770a2548f938ada86475256/spec/detailUtfTerm.lua
--
-- OTHERS:
--  https://github.com/drmplanet/kdlenv/blob/master/koreader/base/spec/unit/verbose_print.lua

local s = require 'say'
-- FROM penlight.lua  {{{
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
-- END penlight.lua }}}

-- colors & glyphs {{{
local colors = require 'term.colors'
local glyph = {
  success = colors.green('●'),
  failure= colors.red('◼'),
  error= colors.magenta('✱'),
  pending= colors.magenta('◌'),
}
-- }}}

return function(options)
    -- opts {{{
  local fileCount = 0
  local fileTestCount = 0
  local testCount = 0
  local successCount = 0
  local skippedCount = 0
  local failureCount = 0
  local errorCount = 0
  -- }}}

  local width = tonumber(os.getenv('COLUMNS'))
  local busted = require 'busted'
  local handler = require 'busted.outputHandlers.base'(options)
  -- inherits from: /usr/local/Cellar/luarocks/3.4.0/share/lua/5.3/busted/outputHandlers/base.lua

  -- local handler = require 'busted.outputHandlers.utfTerminal'(options)
  -- inherits from: /usr/local/Cellar/luarocks/3.4.0/share/lua/5.3/busted/outputHandlers/utfTerminal.lua

  local failureMessage = function(failure)  -- {{{
    local string = failure.randomseed and ('Random seed: ' .. failure.randomseed .. '\n') or ''
    if type(failure.message) == 'string' then
      string = string .. failure.message
    elseif failure.message == nil then
      string = string .. 'Nil error'
    else
      string = string .. io.write(failure.message)
    end

    return string
  end  -- }}}

  local failureDescription = function(failure, isError)  -- {{{
    local string = colors.red(s('output.failure')) .. ' → '
    if isError then
      string = colors.magenta(s('output.error')) .. ' → '
    end

    if not failure.element.trace or not failure.element.trace.short_src then
      string = string ..
        colors.cyan(failureMessage(failure)) .. '\n' ..
        colors.bright(failure.name)
    else
      string = string ..
        colors.cyan(failure.element.trace.short_src) .. ' @ ' ..
        colors.cyan(failure.element.trace.currentline) .. '\n' ..
        colors.bright(failure.name) .. '\n' ..
        failureMessage(failure)
    end

    if options.verbose and failure.trace and failure.trace.traceback then
      string = string .. '\n' .. failure.trace.traceback
    end

    return string
  end  -- }}}

  local pendingDescription = function(pending)  -- {{{
    local name = pending.name

    local string = colors.yellow(s('output.pending')) .. ' → ' ..
      colors.cyan(pending.trace.short_src) .. ' @ ' ..
      colors.cyan(pending.trace.currentline)  ..
      '\n' .. colors.bright(name)

    if type(pending.message) == 'string' then
      string = string .. '\n' .. pending.message
    elseif pending.message ~= nil then
      string = string .. '\n' .. io.write(pending.message)
    end

    return string
  end  -- }}}

  local statusString = function()  -- {{{
    local successString = s('output.success_plural')
    local failureString = s('output.failure_plural')
    local pendingString = s('output.pending_plural')
    local errorString = s('output.error_plural')

    local sec = handler.getDuration()
    local successes = handler.successesCount
    local pendings = handler.pendingsCount
    local failures = handler.failuresCount
    local errors = handler.errorsCount

    if successes == 0 then
      successString = s('output.success_zero')
    elseif successes == 1 then
      successString = s('output.success_single')
    end

    if failures == 0 then
      failureString = s('output.failure_zero')
    elseif failures == 1 then
      failureString = s('output.failure_single')
    end

    if pendings == 0 then
      pendingString = s('output.pending_zero')
    elseif pendings == 1 then
      pendingString = s('output.pending_single')
    end

    if errors == 0 then
      errorString = s('output.error_zero')
    elseif errors == 1 then
      errorString = s('output.error_single')
    end

    local formattedTime = ('%.6f'):format(sec):gsub('([0-9])0+$', '%1')

    return colors.green(successes) .. ' ' .. successString .. ' / ' ..
      colors.red(failures) .. ' ' .. failureString .. ' / ' ..
      colors.magenta(errors) .. ' ' .. errorString .. ' / ' ..
      colors.yellow(pendings) .. ' ' .. pendingString .. ' : ' ..
      colors.bright(formattedTime) .. ' ' .. s('output.seconds')
  end  -- }}}

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
    for i = 1, filler+3 do
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

    if status == 'success' then
      insertTable = handler.successes
      handler.successesCount = handler.successesCount + 1
    elseif status == 'pending' then
      insertTable = handler.pendings
      handler.pendingsCount = handler.pendingsCount + 1
    elseif status == 'failure' then
      handler.failuresCount = handler.failuresCount + 1
      return nil, true
    elseif status == 'error' then
      insertTable = handler.errors
      return nil, true
    end

    if not options.deferPrint then
      local string = glyph[status]
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
    io.flush()

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
    -- if total > 1 then
    --   io.write(repeatSuiteString:format(count, total))
    -- end
    -- if randomseed then
    --   io.write(randomizeString:format(randomseed))
    -- end
    -- io.write(suiteStartString)
    -- io.write(globalSetup)
      -- io.flush()

    return nil, true
  end  -- }}}

  handler.suiteEnd = function(suite, count, total)  -- {{{
    print('')
    print(statusString())

    for i, pending in pairs(handler.pendings) do
      print('')
      print(pendingDescription(pending))
    end

    for i, err in pairs(handler.failures) do
      print('')
      print(failureDescription(err))
    end

    for i, err in pairs(handler.errors) do
      print('')
      print(failureDescription(err, true))
    end

    return nil, true
  end  -- }}}

  busted.subscribe({'file', 'end'}, handler.fileEnd)
  busted.subscribe({'file', 'start'}, handler.fileStart)
  busted.subscribe({'test', 'start'}, handler.testStart)
  busted.subscribe({'test', 'end'}, handler.testEnd)
  busted.subscribe({'suite', 'end'}, handler.suiteEnd)
  busted.subscribe({'suite', 'reset'}, handler.suiteReset)
  return handler
end
