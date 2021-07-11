local class = require 'lib.class'

local UiElement = class('UiElement')

function UiElement:init(...)
    name = self.__name
    self.log = hs.logger.new(name, 'info')
    self.log.i(string.format('New Class: %s', name))
end

function UiElement:__eq(other, fuzz)-- {{{
    if (self==nil or other==nil)
        or (self.frame==nil or other.frame==nil) then 
        return 
    end
    local a,b = self:frame(), other:frame()

     -- Return vanilla comparison if either comparator is missing 'frame' key
   if not a or not b then
      self.log.d('Frame is missing from one or otheroth windows othereing compared')
      return rawequal(self, other)
   end

   local fuzzFactor = fuzz or stackline.config:get('features.fzyFrameDetect.fuzzFactor') or 1

   for k,v in pairs(a) do
      local diff = math.abs(a[k] - b[k])
      if diff > fuzzFactor then
         return false
      end
   end

   return true   -- Otherwise, the two windows *are* equal
end -- }}}

UiElement.frameFzyEqual = __eq

function UiElement:rawpairs() -- {{{
    return u.rawpairs(self)
end -- }}}

function UiElement:raw() -- {{{
    local c = {}
    for k,v in self:rawpairs() do c[k] = v end
    return c
end -- }}}

-- function UiElement:__pairs(self) -- {{{ omit keys that start with underscore when iterating
--    return u.rawpairs(u.filterKeys(self, function(_, k) 
--         return k:sub(1,1)~='_' 
--     end))
-- end  -- }}}

function UiElement:call(m)   -- {{{
    return u.partial(self[m], self)
end   -- }}}

function UiElement:listen(events, handlerName) -- {{{
   -- Convert an event name to a handler method name
   -- E.g., 'windowCreated' -> 'onWindowCreated'
   handlerName = type(handlerName)=='string' 
      and 'on'..handlerName:capitalize()

   self.log.i(('Listening for events:  %s  |  Custom handler fn: <%s>')
         :format(hs.inspect(events), handlerName or 'None'))

   local handler = handlerName 
      and self:call(handlerName) -- Call the specific handler name if present.
      or self:call('handleEvent') -- Otherwise call `handleEvent` to dispatch the desired handler

   -- TODO: The var names of hs.window.filter (`wf`) varies among the consumers of this base class :/
   -- This is very messy and needs to be cleaned up.
   local wf = self._wf or self.wf

   wf:subscribe(events, handler)
end -- }}}

function UiElement:unlisten() -- {{{
    self._wf:unsubscribeAll()
end -- }}}

function UiElement:handleEvent(...) -- {{{
    local handlerName = 'on'..group:capitalize()
    self[handlerName](self, ...)

    if hswin:id() == self.id then
        self['on'..evt:capitalize()](self)
    end
end -- }}}

function UiElement:setLogLevel(lvl) -- {{{
    self.log.setLogLevel(lvl)
    self.log.i( ('stackline.indow log level set to %s'):format(lvl) )
end -- }}}

--[[ 
   2 retvals: module, metatable 

   Build an instance of the UiElement base module for use enriching higher-level classes.
   The consuming class typically extends itself with `UiElement`, and either
   sets the UiElement's metatable outright, or extends its `self` with the
   UiElement metatable before assigning to __index.outright, or extends its
   `self` with the UiElement metatable before assigning to __index.

   Example 1:
         local UiElement, mt = require'stackline.modules.ui-element'('Window')
         local Window = u.extend({}, mt)
         Window.__index = u.extend(Window, UiElement)

   Example 2:
         local Stackmanager = u.extend({}, mt)
         setmetatable(Stackmanager, {
            __index = UiElement,
            __len = function(s) return #s.stacks end
         })

]]

return UiElement
-- return function(name)
--     UiElement.__name = name
--     UiElement.log = hs.logger.new(UiElement.__name, 'info')
--     UiElement.log.i('Loading module', name)

--     local metatable = {__eq=__eq, __pairs=__pairs}

--     return UiElement, metatable
--     return UiElement, metatable
-- end
