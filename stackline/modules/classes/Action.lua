--[[
  == ACTION ==
  Wrap a function to be called by an event bus when an event occurs.

  == ATTRIBUTES ==
    bus             : backreference to the managing event bus
    path            : a dot-separated namespace. E.g., 'window.focused.moved' (string)
    func            : the function to be called (function)
    enabled         : determines if `func` should be called when event occurs (boolean)
    countInvocations: number of times `func` has been invoked (number)
    lastInvoked     : `os.time()` of last invocation. Used to throttle invocations (number)
    limit           : maximum number of times `func` should be invoked (number)
    interval        : the minimum number of sections that must elapse between invocations (number)

  == METHODS ==
    timeSince(): number of sections since last invocation
    guard()    : checks conditions required to invoke()
    invoke()   : calls `func` if guard() returns true
    detach()   : removes Action from message bus

  == TESTS ==
    Action = require 'stackline.modules.Action'
    handler = function() print('window focused handler #3') end
    opts = {interval = 1, limit = 3}
    action = Action:new(handler, opts)
]]

local class = require 'lib.class'

local Action = class('Action')
  :use('loggable')
  :use('hidePrivate')

Action.__tostring = nil

function Action:new(path, func, bus) -- {{{
  opts = (bus and bus.actionOpts) and bus.actionOpts or {}
  self._bus = bus

  self.path = path
  self.func = func
  self.enabled = true
  self.countInvocations = 0
  self.lastInvoked = nil

  self.limit = opts.limit or -1
  self.interval = opts.interval or 0
end -- }}}

function Action:__tostring() -- {{{
  return tostring(self.func)
end -- }}}

function Action:timeSince() -- {{{
  return os.difftime(os.time(), self.lastInvoked or 0)
end -- }}}

function Action:guard() -- {{{
  if not self.enabled then return false end

  if self.interval~=0 and (self:timeSince() < self.interval) then
    self.log.f('Action throttled: Only %ss elapsed, %ss required', self:timeSince(), self.interval)
    return false
  end

  if self.limit >= 0 and (self.countInvocations >= self.limit) then
    self.enabled = false
    self:detach()
    self.log.f('Action disabled: Invoked maximum of %ss times', self.limit)
  end

  return true
end -- }}}

function Action:invoke(...) -- {{{
  if not self:guard() then return false end

  self.func(...)
  self.countInvocations = self.countInvocations + 1
  self.lastInvoked = os.time()

  return self
end -- }}}

function Action:detach() -- {{{
  self._bus:remove(self.path, self)
end -- }}}

return Action

