-- Simplify requiring stackline from hammerspoon init.lua

package.path = hs.configdir ..'/stackline/?.lua;' .. package.path
return require 'stackline.stackline'
