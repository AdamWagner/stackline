local each = require'lib.utils'.each

local scenarios = {
  'screen_state.one_S__three_W_ad24dbe2c27924edb669be1459ffaa11',
  'screen_state.two_S__five_W_b35d21aa13898de634a8f9496194b574',
}

each(scenarios, helpers.scenario.run)
