
local p = {
  depth   = 3,
  printer = printf,
  line    = '-------------------------------------------',
  section = '===========================================================',
  setPrinter = function (printer) p.printer = printer end,
  setLine = function (line) p.line = line end,
  setDepth = function (depth) p.depth = depth end,
}

function header(str, ...) 
  p.printer('\n')
  p.printer(p.section)
  p.printer(str, ...)
  p.printer(p.section)
  p.printer('\n')
end 

local function stringify(x)
  return type(x)=='table'
    and (hs.inspect(x, {depth=p.depth}) or '')
    or (x or '')
end

local function prettyPrint(...) 
  local items = {...}
  if #items > 1 then
    header('Printing "%s" items', #items)
  end

  for _, v in ipairs(items)  do
    p.printer(stringify(v))
    if #items > 1 then p.printer(p.line) end
  end
end 

local M = {}

M.header = header

M.p = setmetatable(p, { __call = function(_, ...) prettyPrint(...) end })

return M
