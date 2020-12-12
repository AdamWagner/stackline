

return setmetatable({data = {}, cb = {}}, {
  __call = function(self, data)
    if data == "touch" then
      for k, v in pairs(self.data) do
        local cb = self.cb[k] or {}
        for i = 1, #cb do cb[i](v) end
      end
      return
    end
    self.data = data or {}
    return self
  end,
  __index = function(self, name)
    local cb = self.cb[name] or {}
    local v = self.data[name]
    return setmetatable({}, {
      __call = function(_, def)
        return v == nil and def or v
      end,

      __newindex = function(_, index, v)
        if index == "event" then
          if not self.cb[name] then self.cb[name] = {} end
          table.insert(self.cb[name], v)
        end
      end,

      __index = {
        dec = function(inc, min, reset)
          if not v then v = 0 end
          if type(v) == "number" then
            if not inc then inc = 1 end
            if min ~= nil and v - inc < min then
              v = reset ~= nil and reset or max
            else
              v = v - inc
            end
            self.data[name] = v
            for i = 1, #cb do cb[i](v) end
          end
          return v == nil and def or v
        end,

        inc = function (inc, max, reset)
          if not v then v = 0 end
          if type(v) == "number" then
            if not inc then inc = 1 end
            if max ~= nil and v + inc > max then
              v = reset ~= nil and reset or max
            else
              v = v + inc
            end
            self.data[name] = v
            for i=1, #cb do cb[i](v) end
          end
          return v == nil and def or v
        end,

        touch = function()
          for i=1, #cb do cb[i](v) end
          return v == nil and def or v
        end
      },
    })
  end,
  __newindex = function(self, name, v)
    self.data[name] = v
    local cb = self.cb[name] or {}
    for i=1, #cb do cb[i](v) end
    return self
  end,
})
