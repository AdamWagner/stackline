local HS_EXTENSION_PATH = '/Applications/Hammerspoon.app/Contents/Resources/extensions/'

local suffixes = { '?.lua', '?/init.lua', }

local function appendPath(path)
  for _, suffix in pairs(suffixes) do
    local p = path .. suffix .. ';'
    package.path = p .. package.path
  end
end

local packagePaths = {
  os.getenv'HOME' .. '/.hammerspoon/',
  os.getenv'HOME' .. '/.hammerspoon/stackline/',
  os.getenv'HOME' .. '/.hammerspoon/stackline/lib/',
  os.getenv'HOME' .. '/.hammerspoon/stackline/spec/',
  os.getenv'HOME' .. '/.hammerspoon/stackline/stackline/',
  os.getenv'HOME' .. '/.hammerspoon/stackline/stackline/modules/',
  HS_EXTENSION_PATH,
}

for _, path in pairs(packagePaths) do
  appendPath(path)
end
