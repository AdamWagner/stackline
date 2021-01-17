--[[
  INSPO
  https://github.com/lodok3/assignment6/blob/master/lib/lume.lua


--]]
-- Require path is longer here b/c *this* is the module that fleshes out package.path
require 'stackline.lib.updatePackagePath'

-- Extend builtins
require 'lib.utils.string'
require 'lib.utils.table'

local M = {}

M.tmerge = table.merge
M.rawprint = print
M.print = hs.console.printStyledtext
print = M.print
M.unpack = unpack or table.unpack

-- M module
M = M.tmerge(M,
require 'lib.utils.math',
require 'lib.utils.types',
require 'lib.utils.collections',
require 'lib.utils.printing',
require 'lib.utils.functions',
require 'lib.utils.comparison',
require 'lib.utils.cloning')

-- Generic utils
-- ———————————————————————————————————————————————————————————————————————————
function M.globalKeys()
  local gkeys = u.keys(_G)
  table.sort(gkeys, function(a,b) return a < b end)
  return gkeys
end


-- reload a package
function M.reload(pkg, name)
  package.loaded[pkg] = nil
  _G.name = require(pkg)
  return pkg
end

-- Stackline-specific utils
-- ———————————————————————————————————————————————————————————————————————————
function M.isGeometryObject(v)  -- {{{
  local _v = M.dcopy(v)
  local mt = getmetatable(_v)

  -- tests
  local test_floor_method, test_table_prop, is_rect

  local has_metatable = mt and mt.getarea and mt.floor

  if has_metatable then
    test_floor_method = type(_v:floor()) == 'table'
    test_table_prop = type(_v.table) == 'table'
    is_rect = u.deepEqual({ "y", "x", "w", "h" }, M.keys(_v.table))
  end

  return has_metatable
    and test_floor_method
    and test_table_prop
    and is_rect
end  -- }}}



return M
