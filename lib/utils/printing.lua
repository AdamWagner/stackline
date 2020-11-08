local M = {}

function M.p(data, howDeep)
    -- local logger = hs.logger.new('inspect', 'debug')
    local depth = howDeep or 3
    if type(data) == 'table' then
        print(hs.inspect(data, {depth = depth}))
        -- logger.df(hs.inspect(data, {depth = depth}))
    else
        print(hs.inspect(data, {depth = depth}))
        -- logger.df(hs.inspect(data, {depth = depth}))
    end
end

function M.look(obj)
    print(hs.inspect(obj, {depth = 2, metatables = true}))
end

function M.pdivider(str) -- {{{
    str = string.upper(str) or ""
    print("=========", str, "==========")
end -- }}}

function M.pheader(str)
    print('\n\n\n')
    print("========================================")
    print(string.upper(str), '==========')
    print("========================================")
end

return M
