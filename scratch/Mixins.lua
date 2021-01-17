
local M = {}

function M:__newindex(k,v)
  if k=='new' and type(v)=='function' then
    return rawset(self, '_new', v)
  end
  rawset(self, k, v)
end
