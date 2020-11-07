local MockBase = require 'stackline.tests.mockHammerspoon.utils.mockbase'

-- Stackline uses:
-- hs.image.imageFromAppBundle

-- local Image = MockBase({})
local Image = {}

function Image:iconForFileType()
    return nil
end

function Image:imageFromAppBundle()
  return 'userdata'
end

return Image

