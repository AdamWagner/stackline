local Class = require 'stackline.lib.class'

local Queue = Class()

-- Creates and returns a new stack
function Queue:new()
  self.stack = {}
  self._size = 0
end

-- Copies and returns a new stack.
function Queue:copy()
  local stack = {}
  for k,v in pairs(self) do
    stack[k] = v
  end
  return setmetatable(stack, Queue)
end

function Queue:toTable()
    return {table.unpack(self.stack)}
end

-- Clears the stack of all values.
function Queue:clear()
  for k,v in pairs(self) do
    self[k] = nil
  end
  self._size = 0
end

-- Returns the number of values in the stack
function Queue:size()
  return self._size
end

-- Inserts a new value on top of the stack.
function Queue:push(...)
  for k, val in pairs({...}) do
    self._size = self._size + 1
    self[self._size] = val
  end
end

-- Removes the top value in the stack and returns it. Returns nil if the stack is empty
function Queue:pop()
  if self._size <= 0 then return nil end
  local val = self[self._size]
  self[self._size] = nil
  self._size = self._size - 1
  return val
end

-- Returns the top value of the stack without removing it.
function Queue:peek()
  return self[self._size]
end

function Queue:peek2()
  return self[self._size], self[self._size - 1]
end

-- Iterate over all values starting from the top. Set retain to true to keep the values from being removed.
function Queue:iterate(retain)
  local i = self:size()
  local count = 0
  return function()
    if i > 0 then
      i = i - 1
      count = count + 1
      return count, not retain and self:pop() or self[i+1]
    end
  end
end

return Queue
