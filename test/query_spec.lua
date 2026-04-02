local helper = require("test.helper")

local function make_hs_window(id, stack_id, app_name)
    return {
        id = function()
            return id
        end,
        stackId = stack_id,
        stackIdFzy = stack_id,
        appName = app_name or ("App" .. tostring(id)),
    }
end

local function install_query_env(opts)
    local task_invocations = {}
    local notifications = {}
    local ingest_calls = {}
    local hs_window_by_id = opts.hs_window_by_id or {}

    _G.u = helper.basic_u()
    _G.c = {
        features = {
            fzyFrameDetect = {
                enabled = false,
            },
        },
    }

    _G.hs = {
        logger = {
            new = function()
                return helper.logger()
            end,
        },
        fs = {
            attributes = function(path, attr)
                if attr == "mode" then
                    return (opts.path_modes or {})[path]
                end
            end,
        },
        notify = {
            new = function(_, attrs)
                table.insert(notifications, attrs)
                return {
                    send = helper.noop,
                }
            end,
        },
        spaces = {
            activeSpaces = function()
                return opts.active_spaces or {}
            end,
        },
        window = {
            get = function(id)
                return hs_window_by_id[id]
            end,
        },
        task = {
            new = function(path, callback, args)
                local invocation = {
                    path = path,
                    args = args,
                }
                table.insert(task_invocations, invocation)
                return {
                    start = function()
                        callback(opts.yabai_response)
                        return true
                    end,
                }
            end,
        },
    }

    _G.stackline = {
        config = {
            get = function(_, path)
                if path == "paths.yabai" then
                    return opts.configured_yabai_path
                end
            end,
        },
        wf = {
            getWindows = function()
                return opts.filter_windows or {}
            end,
        },
        manager = {
            getSummary = function(_, external)
                if external then
                    return {
                        numStacks = helper.count_entries(external),
                    }
                end

                return {
                    numStacks = opts.current_num_stacks or 0,
                }
            end,
            ingest = function(_, stacks, by_app, should_clean)
                table.insert(ingest_calls, {
                    stacks = stacks,
                    by_app = by_app,
                    should_clean = should_clean,
                })
            end,
        },
        window = {
            new = function(_, hs_win)
                local id = hs_win:id()
                local stack_id = hs_win.stackId or hs_win.stackIdFzy or "stack"
                return {
                    id = id,
                    app = hs_win.appName or ("App" .. tostring(id)),
                    stackId = stack_id,
                    stackIdFzy = hs_win.stackIdFzy or stack_id,
                }
            end,
        },
    }

    helper.reset_modules("stackline.query")
    local query = require("stackline.query")

    return {
        query = query,
        task_invocations = task_invocations,
        notifications = notifications,
        ingest_calls = ingest_calls,
    }
end

return {
    test_query_resolves_directory_yabai_path = function()
        local env = install_query_env({
            configured_yabai_path = "/opt/homebrew/opt/yabai",
            path_modes = {
                ["/opt/homebrew/opt/yabai"] = "directory",
                ["/opt/homebrew/opt/yabai/bin/yabai"] = "file",
            },
            filter_windows = {
                make_hs_window(1, "stack-a", "Alpha"),
                make_hs_window(2, "stack-a", "Beta"),
            },
            yabai_response = {
                {
                    id = 1,
                    ["stack-index"] = 1,
                    ["is-minimized"] = false,
                    ["is-hidden"] = false,
                    ["is-native-fullscreen"] = false,
                    subrole = "AXStandardWindow",
                },
                {
                    id = 2,
                    ["stack-index"] = 2,
                    ["is-minimized"] = false,
                    ["is-hidden"] = false,
                    ["is-native-fullscreen"] = false,
                    subrole = "AXStandardWindow",
                },
            },
        })

        env.query.run({forceRedraw = true})

        helper.assert_equal(env.task_invocations[1].path, "/opt/homebrew/opt/yabai/bin/yabai")
        helper.assert_equal(helper.count_entries(env.ingest_calls[1].stacks), 1)
        helper.assert_equal(env.ingest_calls[1].should_clean, false)
    end,

    test_query_rebuilds_stack_from_yabai_ids_when_filter_misses_windows = function()
        local env = install_query_env({
            configured_yabai_path = "/opt/homebrew/bin/yabai",
            path_modes = {
                ["/opt/homebrew/bin/yabai"] = "file",
            },
            filter_windows = {},
            active_spaces = {
                display1 = 7,
            },
            hs_window_by_id = {
                [11] = make_hs_window(11, "stack-z", "Safari"),
                [12] = make_hs_window(12, "stack-z", "Firefox"),
            },
            yabai_response = {
                {
                    id = 11,
                    space = 7,
                    ["stack-index"] = 1,
                    ["is-minimized"] = false,
                    ["is-hidden"] = false,
                    ["is-native-fullscreen"] = false,
                    subrole = "AXStandardWindow",
                },
                {
                    id = 12,
                    space = 7,
                    ["stack-index"] = 2,
                    ["is-minimized"] = false,
                    ["is-hidden"] = false,
                    ["is-native-fullscreen"] = false,
                    subrole = "AXStandardWindow",
                },
            },
        })

        env.query.run({forceRedraw = true})

        helper.assert_equal(helper.count_entries(env.ingest_calls[1].stacks), 1)
        local stack = env.ingest_calls[1].stacks["stack-z"]
        helper.assert_true(stack ~= nil, "expected fallback stack to be rebuilt from yabai window ids")
        helper.assert_equal(#stack, 2)
        helper.assert_true(env.ingest_calls[1].by_app.Safari ~= nil, "expected app grouping to be rebuilt too")
    end,
}
