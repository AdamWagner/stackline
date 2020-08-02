local _ = require 'stackline.utils.utils'
local Window = require 'stackline.stackline.window'
local tut = require 'stackline.utils.table-utils'
local under = require 'stackline.utils.underscore'

local Stack = {}

-- TODO: include hs.task functionality from core.lua in the Stack module directly

function Stack:toggleIcons() -- {{{
    self.showIcons = not self.showIcons
    Stack.update()
end -- }}}

function Stack:each_win_id(fn) -- {{{
    _.each(self.tabStacks, function(stack)
        -- hs.alert.show('running each win id')
        _.pheader('stack')
        -- _.p(stack)
        -- _.p(under.values(stack))
        local winIds = _.map(under.values(stack), function(w)
            return w.id
        end)
        print(hs.inspect(winIds))

        for i = 1, #winIds do
            -- ┌────────────────────┐
            --     the main event! 
            -- └────────────────────┘
            -- hs.alert.show(winIds[i])

            fn(winIds[i]) -- Call the `fn` provided with win ID

            -- hs.alert.show('inside final loop')

            -- DEBUG
            print(hs.inspect(winIds))
            -- print(winIds[i])
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
    _.p('# to be cleaned: ', _.length(self.tabStacks))
    _.p('keys be cleaned: ', _.keys(self.tabStacks))

    for key, stack in pairs(self.tabStacks) do
        -- DEBUG:
        -- _.p(stack)
        _.pheader('stack keys')
        _.p(_.map(stack, function(w)
            return _.pick(w, {'id', 'app'})
        end))

        -- For each window, clear canvas element
        _.each(stack, function(w)
            _.pheader('window indicator in cleanup')
            print(w.indicator)
            w.indicator:delete()
        end)

        self.tabStacks[key] = nil
    end
end -- }}}

function Stack:newStack(stack, stackId) -- {{{
    print('stack data #:', #stack)
    print('stack ID: ', stackId)
    local extantStack = self.tabStacks[stackId]
    if not extantStack then
        self.tabStacks[stackId] = {}
    end

    for k, w in pairs(stack) do
        if not extantStack then
            print('First run')
            local win = Window:new(w)
            win:process(self.showIcons, k)
            win.indicator:show()
            -- _.p(win)
            win.stackId = stackId -- set stackId on win for easy lookup later
            self.tabStacks[stackId][win.id] = win

        else
            local extantWin = extantStack[w.id]
            local win = Window:new(w)

            if (type(extantWin) == 'nil') or
                not (extantWin.focused == win.focused) then
                print('Needs updated:', extantWin.app)
                extantWin.indicator:delete()
                win:process(self.showIcons, k)
                win.indicator:show()
                -- _.p(win)
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
        print(stackId)
        Stack:newStack(winGroup, stackId)
    end)
end -- }}}

function Stack:update(shouldClean) -- {{{

    _.pheader('value of "shouldClean:"')
    _.p(shouldClean)
    print('\n\n')
    if shouldClean then
        _.pheader('running cleanup')
        Stack:cleanup()
    end

    local yabai_get_stacks = 'stackline/bin/yabai-get-stacks'

    hs.task.new("/usr/local/bin/dash", function(_code, stdout)
        local windowData = hs.json.decode(stdout)
        Stack:ingest(windowData)
    end, {yabai_get_stacks}):start()
end -- }}}

function Stack:newStackManager()
    self.tabStacks = {}
    self.showIcons = false
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
