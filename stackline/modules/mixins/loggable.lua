local Loggable = {__name = 'Loggable'}

function Loggable:init()
  self.__name = self.__name or 'Anonymous Class'
  self.log = hs.logger.new(self.__name, 'info')
  self.log.i(string.format('New Class: %s', self.__name))
end

function Loggable:setLogLevel(lvl)
  self.log.setLogLevel(lvl)
  self.log.i(string.format('Set log level of "%s" to "%s"', self.__name, lvl))
end

return Loggable
