require("hs.ipc")

local Stack = require 'stackline.stackline.stack'
local tut = require 'stackline.utils.table-utils'
local utils = require 'stackline.utils.utils'

print(hs.settings.bundleID)

local showIcons = utils.settingsGetOrSet("show_icons", false)
wsi = Stack:newStackManager(showIcons)

local shouldRestack = tut.Set{
    "application_terminated",
    "application_launched",
    "window_created",
    "window_destroyed",
    "window_resized",
    "window_moved",
    "show_icons",
    "indicator_colors",
}

local shouldClean = tut.Set{
    "application_hidden",
    "application_visible",
    "window_deminimized",
    "window_minimized",
}

function configHandler(_, msgID, msg)
    if msgID == 900 then
        return "version:2.0a"
    end

    if msgID == 500 then
        key, value = msg:match(".+:([%a_-]+):([%a%d_-]+)")
        hs.settings.set(key, utils.boolean(string.lower(value)))

        if shouldRestack[key] then
            wsi.cleanup()
            wsi = Stack:newStackManager(hs.settings.get("show_icons"))
        end
        wsi.update(shouldClean[key])
    end
    return "ok"
end

function yabaiSignalHandler(_, msgID, msg)
    if msgID == 900 then
        return "version:2.0a"
    end

    if msgID == 500 then
        event = msg:match(".+:([%a_]+)")

        if shouldRestack[event] then
            wsi.cleanup()
            wsi = Stack:newStackManager(showIcons)
        end
        wsi.update(shouldClean[event])
    end
    return "ok"
end


ipcEventsPort = hs.ipc.localPort("stackline-events", yabaiSignalHandler)
ipcConfigPort = hs.ipc.localPort("stackline-config", configHandler)