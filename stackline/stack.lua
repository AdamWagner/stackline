local _ = require 'stackline.utils.utils'
local Window = require 'stackline.stackline.window'
local tut = require 'stackline.utils.table-utils'
local under = require 'stackline.utils.underscore'

local Stack = {}

function Stack:toggleIcons() -- {{{
    self.showIcons = not self.showIcons
    Stack.update()
end -- }}}

function Stack:each_win_id(fn) -- {{{
    _.each(self.tabStacks, function(stack)
        local winIds = _.map(under.values(stack), function(w)
            return w.id
        end)

        for i = 1, #winIds do
            -- ┌────────────────────┐
            --     the main event!
            -- └────────────────────┘
            -- hs.alert.show(winIds[i])

            fn(winIds[i]) -- Call the `fn` provided with win ID
        end
    end)
end -- }}}

-- NOTE: A window must be *in* a stack to be found with this method!
function Stack:findWindow(wid) -- {{{
    for _idx, stack in pairs(self.tabStacks) do
        extantWin = stack[wid]
        if extantWin then
            return extantWin
        end
    end
end -- }}}

function Stack:cleanup() -- {{{
    for key, stack in pairs(self.tabStacks) do
        -- For each window, clear canvas element
        _.each(stack, function(w)
            w.indicator:delete()
        end)

        self.tabStacks[key] = nil
    end
end -- }}}

function Stack:newStack(stack, stackId) -- {{{
    local extantStack = self.tabStacks[stackId]
    if not extantStack then
        self.tabStacks[stackId] = {}
    end

    for k, w in pairs(stack) do
        if not extantStack then
            local win = Window:new(w)
            win:process(self.showIcons, k)
            win.indicator:show()
            win.stackId = stackId -- set stackId on win for easy lookup later
            self.tabStacks[stackId][win.id] = win

        else
            local extantWin = extantStack[w.id]
            local win = Window:new(w)

            if (type(extantWin) == 'nil') or
                not (extantWin.focused == win.focused) then
                extantWin.indicator:delete()
                win:process(self.showIcons, k)
                win.indicator:show()
                win.stackId = stackId -- set stackId on win for easy lookup later
                self.tabStacks[stackId][win.id] = win
            end
        end
    end
end -- }}}

function Stack:ingest(windowData) -- {{{
    _.each(windowData, function(winGroup)
        local stackId = table.concat(_.map(winGroup, function(w)
            return w.id
        end), '')
        Stack:newStack(winGroup, stackId)
    end)
end -- }}}

function Stack:update(shouldClean) -- {{{
    if shouldClean then
        Stack:cleanup()
    end

    local yabai_get_stacks = 'stackline/bin/yabai-get-stacks'

    hs.task.new("/bin/dash", function(_code, stdout)
        local windowData = hs.json.decode(stdout)
        Stack:ingest(windowData)
    end, {yabai_get_stacks}):start()
end -- }}}

function Stack:newStackManager(showIcons)
    self.tabStacks = {}
    self.showIcons = showIcons
    return {
        ingest = function(windowData)
            return self:ingest(windowData)
        end,
        update = self.update,
        cleanup = function()
            return self:cleanup()
        end,
        toggleIcons = function()
            return self:toggleIcons()
        end,
        findWindow = function(wid)
            return self:findWindow(wid)
        end,
        each_win = function(wid)
            return self:each_win_id(wid)
        end,
        get_win_str = function()
            return Stack.win_str
        end,
    }
end

return Stack
