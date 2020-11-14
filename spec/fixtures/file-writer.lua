--[[
Lua file writer.

This module means to present a way of easily generating Lua *importable* files with the information found in an existing Lua table variable.
For convenience, it also contains a small wrapper that allows passing the path to a JSON file to be reconstructed as an importable Lua file.

This original verison supports Strings, Numbers and Boolean values (as well as tables, of course). That is unlikely to change and quite
frankly there's not much else you would really want imo.

JSON functionality requires luajson 1.3.4 (may be compatible with other versions).

Author: Samuel Waugh
Date: December 17th 2018
Version 1.0.0
]]--
local converter = {}

--These are language constants anyway, but imo easier to read this way
local NUMBER = "number"
local STRING = "string"
local BOOLEAN = "boolean"
local FUNCTION = "function"
local TABLE = "table"

--Default name of the table variable in the generated file.
local STDNAME = "entity"

--Actually the JSON table if one was read from file.
local jsonstr
--Lua code to write to file
local luastr

--Used for recursion purposes
local processed_keystrs = {}

function read(filepath)
	--[[
	Pulls a JSON file into memory as a table using luajson

	:param string filepath: path to file to convert
	]]--
	local json = require('json')
	local file = io.open(filepath)
	if not file then
		error("This file does not exist: "..filepath)
	end
	local todecode = file:read "*a"
	file:close()
	jsonstr = json.decode(todecode)
end

function write(filepath)
	--[[
	Write result to an output file.

	:param string filepath: path to output file
	]]--
	local file = io.open(filepath, 'w')
	if not file then
		error("Can't write to "..filepath)
	end
	file:write(luastr)
	file:close()
end

local function fileprep()
	--[[
	Set output string to header. Defines the module table.
	]]--
	luastr = "local "..STDNAME.." = {}\n"
end

local function filefinish()
	--[[
	Append the Lua return of the module table.
	]]--
	luastr = luastr.."return "..STDNAME.."\n"
end

local function ty(key)
	--[[
	Writing a stringified version of a value is annoying. If the stringified
	thing is itself a string, we need to add quotes around it for proper output syntax.

	:param <unknown> key: the key we are tyring to write

	:returns: the contextualized stringified version of the table call to that key
	:rtype: string
	]]--
	if type(key) == STRING then
		return "[\""..key.."\"]" end
	return "["..key.."]"
end

local function convert(tab, keystr)
	--[[
	Converts each key-value pair of the table into it's single value assignment form.
	Recursively handles nested tables.

	:param table tab: table to process
	:param string keystr: the full nested path to the current key-value pair
	]]--
	if not keystr then keystr = STDNAME end
	if not processed_keystrs[keystr] then
		luastr = luastr..keystr.." = {}\n"
		processed_keystrs[keystr] = true
	end
	for key, value in pairs(tab or jsonstr) do
		if type(value) == TABLE then
			convert(value, keystr..ty(key))
		elseif type(value) == FUNCTION then
			--Functions are not supported. Leave a commented line in the output file.
			luastr = luastr.."--a function: "..key.."\n"
		elseif type(value) == STRING then
			luastr = luastr..keystr..ty(key).." = [["..value.."]]\n"
		elseif type(value) == NUMBER then
			luastr = luastr..keystr..ty(key).." = "..value.."\n"
		elseif type(value) == BOOLEAN then
			--Can't concatenate boolean values REEEEEEEEEEEEE
			if value then insert="true" else insert="false" end
			luastr = luastr..keystr..ty(key).." = "..insert.."\n"
		else
			--All other formats not currenlty supported. Leave a commented line in the output file.
			luastr = luastr.."--unsupported type for:   "..value.."\n"
		end
	end
end

function converter.convertFile(inpath, outpath)
	--[[
	Fully process the conversion of a JSON file into a Lua module.

	:param string inpath: path to JSON file
	:param string outpath: path to desired output file
	]]--
	read(inpath)
	fileprep()
	convert()
	filefinish()
	write(outpath)
	processed_keystrs = {}
end

function converter.convertTable(table, outpath)
	--[[
	Write out a Lua table into it's own file as a Lua module

	:param table table: table to convert
	:param string outpath: path to the desired output file
	]]--
	fileprep()
	convert(table)
	filefinish()
	write(outpath)
	processed_keystrs = {}
end

return converter
