-- Require path is longer here b/c *this* is the module that fleshes out package.path 
require 'stackline.lib.updatePackagePath'

-- Extend builtins
require 'lib.utils.string'
require 'lib.utils.table'

-- utils module
utils = {}

table.merge(utils, require 'lib.utils.math')
table.merge(utils, require 'lib.utils.types')
table.merge(utils, require 'lib.utils.collections')
table.merge(utils, require 'lib.utils.printing')
table.merge(utils, require 'lib.utils.functions')
table.merge(utils, require 'lib.utils.comparison')
table.merge(utils, require 'lib.utils.cloning')


-- ———————————————————————————————————————————————————————————————————————————
-- Stackline-specific utils
-- ———————————————————————————————————————————————————————————————————————————
function utils.isGeometryObject(v)
  local _v = utils.copyDeep(v)
  local mt = getmetatable(_v)

  -- tests
  local test_floor_method, test_table_prop, is_rect

  has_metatable = mt and mt.getarea and mt.floor

  if has_metatable then
      test_floor_method =  type(_v:floor()) == 'table'
      test_table_prop =  type(_v.table) == 'table'
      is_rect =  u.deepEqual({ "y", "x", "w", "h" }, utils.keys(_v.table))
  end

  return has_metatable
          and test_floor_method
          and test_table_prop
          and is_rect
end


return utils
