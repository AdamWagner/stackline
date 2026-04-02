local helper = require("test.helper")

local function make_frame(x, y, w, h)
    local frame = {x = x, y = y, w = w, h = h}
    function frame:floor()
        return self
    end
    return frame
end

local function make_app(opts)
    return {
        name = function()
            return opts.name
        end,
        bundleID = function()
            return opts.bundle_id
        end,
        path = function()
            return opts.path
        end,
    }
end

local function make_window(app)
    return {
        title = function()
            return "Example"
        end,
        application = function()
            return app
        end,
        id = function()
            return 99
        end,
        frame = function()
            return make_frame(0, 0, 400, 300)
        end,
        screen = function()
            return {
                id = function()
                    return 1
                end,
            }
        end,
    }
end

local function load_window_module(opts)
    local bundle_calls = 0
    local file_calls = 0
    local app_lookup_calls = 0

    _G.u = helper.basic_u()
    _G.stackline = {
        config = {
            get = function(_, path)
                if path == "features.fzyFrameDetect.fuzzFactor" then
                    return 30
                end
            end,
        },
    }
    _G.hs = {
        logger = {
            new = function()
                return helper.logger()
            end,
        },
        image = {
            imageFromAppBundle = function(bundle_id)
                bundle_calls = bundle_calls + 1
                if opts.bundle_images then
                    return opts.bundle_images[bundle_id]
                end
            end,
            iconForFile = function(path)
                file_calls = file_calls + 1
                if opts.file_images then
                    return opts.file_images[path]
                end
            end,
        },
        application = {
            get = function(name)
                app_lookup_calls = app_lookup_calls + 1
                return opts.named_apps and opts.named_apps[name]
            end,
        },
    }

    helper.reset_modules("stackline.window")
    local Window = require("stackline.window")

    return {
        Window = Window,
        bundle_calls = function()
            return bundle_calls
        end,
        file_calls = function()
            return file_calls
        end,
        app_lookup_calls = function()
            return app_lookup_calls
        end,
    }
end

return {
    test_icon_lookup_uses_live_app_bundle_and_caches_result = function()
        local env = load_window_module({
            bundle_images = {
                ["com.example.Test"] = "bundle-image",
            },
        })
        local app = make_app({
            name = "TestApp",
            bundle_id = "com.example.Test",
            path = "/Applications/Test.app",
        })

        local window = env.Window:new(make_window(app))
        helper.assert_equal(window:iconFromAppName(), "bundle-image")
        helper.assert_equal(window:iconFromAppName(), "bundle-image")
        helper.assert_equal(env.bundle_calls(), 1)
        helper.assert_equal(env.app_lookup_calls(), 0)
    end,

    test_icon_lookup_falls_back_to_named_application_lookup = function()
        local env = load_window_module({
            bundle_images = {
                ["com.apple.Safari"] = "safari-image",
            },
            named_apps = {
                Safari = make_app({
                    name = "Safari",
                    bundle_id = "com.apple.Safari",
                }),
            },
        })
        local app = make_app({
            name = "Safari",
        })

        local window = env.Window:new(make_window(app))
        helper.assert_equal(window:iconFromAppName(), "safari-image")
        helper.assert_equal(env.app_lookup_calls(), 1)
    end,
}
