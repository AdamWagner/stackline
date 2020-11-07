local function methodSpy(obj, methodName, args)
  local spy = spy.on(obj, methodName)
  local result = obj[methodName](obj, table.unpack(args))
  assert.spy(spy).was_called()
  assert.spy(spy).was_called_with(match.is_ref(obj), table.unpack(args))
  return result
end

return methodSpy
