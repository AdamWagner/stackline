local helper = require("test.helper")

local function load_conf(attributes)
    _G.hs = {
        fs = {
            attributes = function(path, attr)
                if attr == "mode" then
                    return attributes[path]
                end
            end,
        },
    }
    _G.c = nil
    return dofile("conf.lua")
end

return {
    test_conf_prefers_homebrew_arm_path = function()
        local conf = load_conf({
            ["/opt/homebrew/bin/yabai"] = "file",
        })

        helper.assert_equal(conf.paths.yabai, "/opt/homebrew/bin/yabai")
    end,

    test_conf_falls_back_to_usr_local = function()
        local conf = load_conf({
            ["/usr/local/bin/yabai"] = "file",
        })

        helper.assert_equal(conf.paths.yabai, "/usr/local/bin/yabai")
    end,
}
