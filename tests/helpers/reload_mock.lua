
local function reloadMock() 
  hs = nil
  _G.hs = nil
  for k, v in pairs(package.loaded) do
    local hsmock = k:match('mockHammerspoon')
    if hsmock then
      package.loaded[k] = nil
    end
  end
  _G['u'] = require 'stackline.lib.utils'
  return require 'tests.mockHammerspoon'
end 

return reloadMock
