-- Simplify requiring stackline from ~/hammerspoon/init.lua

package.path = os.getenv'HOME' ..'/.hammerspoon/stackline/?.lua;' .. package.path
package.path = os.getenv'HOME' ..'/.hammerspoon/stackline/lib/utils/?.lua;' .. package.path
return require 'stackline.stackline'
