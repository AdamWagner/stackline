local M = {}

function M.p(data, _depth)
    -- local logger = hs.logger.new('inspect', 'debug')
    local depth = _depth or 3
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

function M.pheader(str)  -- {{{
    print('\n\n\n')
    print("========================================")
    print(string.upper(str), '==========')
    print("========================================")
    print('\n\n')
end  -- }}}

function M.printBox(x, _depth)
  local opts = {depth = _depth or 1}
  print('\n\nSTART--------------------')
  print(hs.inspect(x, opts))
  print('END--------------------\n\n')
end

function M.printWarning(msg)
  local divider = '⚠️-------------------------------------⚠️'
  local gap = '\n\n\n'
  local space = '\n\n'
  local header = gap .. divider .. space
  local footer = space .. divider .. gap
  print(header .. "WARNING: " .. msg .. footer)
end


return M
