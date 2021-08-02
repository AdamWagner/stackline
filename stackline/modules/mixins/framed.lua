--[[
  == Framed ==
  A mixin for classes with a `frame` property of type hs.geometry.

  When used on a class, instances compared with an equality operator will
  call the `__eq` method defined in this mixin.
]]

local Framed = {__name = 'Framed'}

function Framed:__eq(other, fuzz)
  -- Return vanilla comparison if either comparator is missing 'frame' key
  if (self == nil or other == nil) or (self.frame == nil or other.frame == nil) then
    return rawequal(self, other)
  end

  local a, b = self:frame(), other:frame()

  if not a or not b then
    self.log.d('frame is missing from one or both objects being compared')
    return rawequal(self, other)
  end

  fuzz = fuzz or stackline.config:get('features.fzyFrameDetect.fuzzFactor') or 1

  for k in pairs(a) do
    local diff = math.abs(a[k] - b[k])
    if diff > fuzz then
      return false
    end
  end

  return true -- Otherwise, the two windows *are* equal
end

Framed.frameFzyEqual = __eq

return Framed
