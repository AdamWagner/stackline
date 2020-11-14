local json = require 'lib.json'


-- ———————————————————————————————————————————————————————————————————————————
-- hs.json mock
-- ———————————————————————————————————————————————————————————————————————————
return {
    encode = function(v) return json:encode(v) end,
    decode = function(v) return json:decode(v) end,
}
