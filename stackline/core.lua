require("hs.ipc")

local Stack = require 'stackline.stackline.stack'
local tut = require 'stackline.utils.table-utils'

print(hs.settings.bundleID)

function getOrSet(key, val)
    local existingVal = hs.settings.get(key)
    if existingVal == nil then
        hs.settings.set(key, val)
        return val
    end
    return existingVal
end

local showIcons = getOrSet("showIcons", false)
wsi = Stack:newStackManager(showIcons)

local shouldRestack = tut.Set{
    "application_terminated",
    "application_launched",
    "space_changed",
    "window_created",
    "window_destroyed",
    "window_resized",
    "window_moved",
    "toggle_icons",
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
        if key == "toggle_icons" then
            showIcons = not showIcons
            hs.settings.set("showIcons", showIcons)
        end

        if shouldRestack[key] then
            wsi.cleanup()
            wsi = Stack:newStackManager(showIcons)
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
            print(string.format("Recreating the stack because of yabai event: %s", event))

            wsi.cleanup()
            wsi = Stack:newStackManager(showIcons)
        end
        wsi.update(shouldClean[event])
    end
    return "ok"
end


ipcEventsPort = hs.ipc.localPort("stackline-events", yabaiSignalHandler)
ipcConfigPort = hs.ipc.localPort("stackline-config", configHandler)