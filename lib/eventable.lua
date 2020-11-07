---Eventable
-- A series of tubes for tables
-- @version 0.1.2
-- @author C. Byerley
-- @copyright 2015-17 develephant.com
-- @license MIT
-- @classmod
local Eventable = {}
Eventable._members = {}

--== Metatable ==--
function _eventer()
  local et = {}

  et._events = {}
  et._muted = false
  et._isOnce = false

  et.on = function( self, event_name, callback )
    self._events[ event_name ] = callback
  end

  et.once = function( self, event_name, callback )
    self._isOnce = true
    self._events[ event_name ] = callback
  end

  et.off = function( self, event_name )
    if self._events[ event_name ] then
      self._events[ event_name ] = nil
    end
  end

  et.allOff = function( self )
    self._events = {}
    self._muted = false
  end

  et.mute = function( self, new_state )
    self._muted = new_state
  end

  et.isMuted = function( self )
    return self._muted
  end

  et.emit = function( self, event_name, ... )
    local evt =
    {
      name = event_name,
      caller = self,
      isOnce = self._isOnce
    }
    Eventable._broadcast( evt, ... )
    self._isOnce = false
  end

  et._onEvent = function( self, event, ... )

    if self._events[ event.name ] then
      self._events[ event.name ]( event, ... )
      if event.isOnce then
        self:off( event.name )
      end
    end

  end
  return et
end

--== Eventable ==--
function Eventable:new( o )
  local o = o or {}
  o.et = _eventer()
  o.et.__index = o.et
  setmetatable(o, o.et)
  Eventable._members[ o ] = o
  return o
end

Eventable._broadcast = function( event, ... )
  for _, member in pairs (Eventable._members) do
    if member and not member._muted then
      member:_onEvent( event, ... )
    end
  end
end

--== Utils

---Current listener count
Eventable.count = function()
  local cnt = 0
  for _, member in pairs( Eventable._members ) do
    if member then
      cnt = cnt + 1
    end
  end
  return cnt
end

---List all events registered
-- may include duplicates.
-- TODO: Make it work.
Eventable.list = function()
  for _, member in pairs( Eventable._members ) do
    Eventable.p( member._events )
  end
end

---Release a member from the broadcast loop
-- you can rewrap the tbl to add the member
-- back to the messaging loop.
Eventable.release = function( member )
  if Eventable._members[ member ] then
    Eventable._members[ member ] = nil
  end
end

-- Table printer
local _toString = function( t, indent )
-- print contents of a table, with keys sorted. second parameter is optional, used for indenting subtables
  local names = {}
  if not indent then indent = "" end
  for n,g in pairs(t) do
      table.insert(names,n)
  end
  table.sort(names)
  for i,n in pairs(names) do
      local v = t[n]
      if type(v) == "table" then
          if(v==t) then -- prevent endless loop if table contains reference to itself
              log.d(indent..tostring(n)..": <-")
          else
              log.d(indent..tostring(n)..":")
              Eventable.p(v,indent.."   ")
          end
      else
          if type(v) == "function" then
              log.d(indent..tostring(n).."()")
          else
              log.d(indent..tostring(n)..": "..tostring(v))
          end
      end
  end
end
Eventable.p = _toString

return Eventable
