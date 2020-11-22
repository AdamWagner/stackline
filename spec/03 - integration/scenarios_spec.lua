local u = require 'lib.utils'

-- TODO: remove hardcoded scenarios
-- hardcoded scenarios to run
-- local scenarios = {
--   'screen_state.one_S__three_W_ad24dbe2c27924edb669be1459ffaa11',
--   'screen_state.two_S__five_W_b35d21aa13898de634a8f9496194b574',
-- }

u.each(
  helpers.scenario.getFixturePaths(),
  helpers.scenario.run
)
