-- STACKLINE REFERENCES:
--    hs.image.imageFromAppBundle
-- -----------------------------------------------------------------------------

local Image = {}

function Image:iconForFileType()
    return nil
end

function Image:imageFromAppBundle()
  return 'userdata'
end

return Image

