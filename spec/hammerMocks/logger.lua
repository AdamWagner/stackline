--[[ 
  == hs.logger mock ==

  Stackline references to `hs.logger`:
    hs.logger.new(level)
    log.setLogLevel('info')
    log.i(msg), etc
]]
return {
  new = function()
    return {
      i = function(...) table.insert(logfile, {...}) end,
      f = function(...) table.insert(logfile, {...}) end,
      wf = function(...) table.insert(logfile, {...}) end,
    }
  end,
  historySize = function() end,
}
