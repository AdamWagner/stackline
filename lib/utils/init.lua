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

return utils
