-- Required at the top of every test file

require 'lib.packagepath'

hs = require 'stackline.spec.hammerMocks'

_G.u = require 'lib.utils'

-- Execute a shell command and capture the output
function exec(cmd)
  local handle = io.popen(cmd)
  local result = handle:read("*a")
  handle:close()
  return result
end

function printf(...) return ...  end

-- A convoluted way to get data out of hammerspoon via the `hc` cli
function hsExec(cmd)
  return hs.json.decode(exec(
    string.format([[
      hs -c 'hs.json.encode(
        u.prepareJsonEncode(%s)
      )'
    ]], cmd)
  ))
end
