local prop = require 'hammerMocks.utils.prop'
local sleep = require 'lib.utils'.sleep


local json = require 'hammerMocks.json'

-- STACKLINE REFERENCES:
-- hs.task.new

local task = {}

task.__defaults = {}
task.__defaults.launchPath = '/bin/sh'
task.__defaults.callbackFn = function(code, stdOut, stdErr)
  print('code', code)
  print('stdOut', stdOut)
  print('stdErr', stdErr)
end

task.__defaults.launchPath =
    "/Users/adamwagner/.hammerspoon/stackline/bin/yabai-get-stack-idx"

function task:__setDefaults(o)
  self.__defaults = table.merge(self.defaults, o)
end

function task:__getDefaults(o)
  self.__defaults = table.merge(self.defaults, o)
end

-- Function: hs.task.new(launchPath, callbackFn[, streamCallbackFn][, arguments])
--    callbackFn args:
--        * exitCode - An integer containing the exit code of the process
--        * stdOut - A string containing the standard output of the process
--        * stdErr - A string containing the standard error output of the process
function task.new(launchPath, callbackFn, args)
  local o = {}
  setmetatable(o, task)
  task.__index = task

  o.cmd = launchPath or task.__defaults.launchPath
  o.cb = callbackFn or task.__defaults.callbackFn
  return o
end

-- iternal method for setting result
function task:set(result)
  self.__exitCode = 0
  self.__stdout = result
  self.__stderr = nil
end

function task:start()

  -- TODO: Should be non-blocking like the real hs.task (coroutines?)
  sleep(math.random(50, 200) / 100) -- simulate async b/n 0.5s and 2s

  if self.__stdout then -- if response provided use this instead of calling script
    return type(self.__stdout) == 'table' -- if type table, encode json
    and self.cb(self.__exitCode, json.encode(self.__stdout)) or
               self.cb(self.__exitCode, self.__stdout)
  else
    local res = io.popen(self.cmd, 'r')
    local out = res:read('*a')
    return self.cb(self.__exitCode, self.__stdout)
  end

end

return task
