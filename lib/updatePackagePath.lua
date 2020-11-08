function string:ensureEndsWith(char)
  local lastChar = self:sub(#self)
  if lastChar ~= char then
    self = self .. char
  end
  return self
end

local function appendPath(path, opts)
  opts = opts or {}
  if opts.home then path = os.getenv('HOME') .. path end -- prepend user's home dir if opts.home == true
  path = path:ensureEndsWith('/')

  local suffixes = { '?.lua', '?/init.lua', }
  for _,suffix in pairs(suffixes) do
    print('suffix:', suffix)
    p = path .. suffix
    print('path:', p)
    p = p:ensureEndsWith(';')
    print('path after end check:', p)
    package.path = p .. package.path
  end
end

appendPath('/Applications/Hammerspoon.app/Contents/Resources/extensions/')

local packagePaths = {
  '/.hammerspoon/',
  '/.hammerspoon/stackline/',
  '/.hammerspoon/stackline/lib/',
  '/.hammerspoon/stackline/spec/',
}

for _, path in pairs(packagePaths) do
  appendPath(path, {home = true})
end
