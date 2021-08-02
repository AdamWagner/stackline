--[[ FROM: https://github.com/asmagill/hammerspoon-config-take2/blob/master/_scratch/yabaisocket.lua
      This person has built quite a bit on top of it: https://github.com/haberdashPI/preferences/blob/main/yabai.luau
         https://github.com/haberdashPI/preferences/blob/main/hs.init.lua
]]

local socket = require("hs.socket")

local module = {}

module.sockFile = string.format("/tmp/yabai_%s.socket", os.getenv("USER"))

module.sockTimeout = 5

module.send = function(fn, ...)
    assert(u.is.callable(fn), "callback must be a function or object with __call metamethod")

    local args = table.pack(...)
    local message = ""
    for i = 1, args.n, 1 do
        message = message .. tostring(args[i]) .. string.char(0)
    end
    message = message .. string.char(0)

    local mySocket = socket.new()
    local results = ""
    mySocket:setTimeout(module.sockTimeout or -1):connect(module.sockFile, function()
        mySocket:write(message, function(_)
            mySocket:setCallback(function(data, _)
                results = results .. data
                if mySocket:connected() then
                    mySocket:read("\n")
                else
                    fn(results)
                end
            end)
            mySocket:read("\n")
        end)
    end)
end

return module
