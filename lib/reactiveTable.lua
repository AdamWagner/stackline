-- FROM: https://github.com/ZichaoNickFox/ReactiveTable

--[[
d.inspectByDefault(true)
rt = require 'lib.reactiveTable'

x = { name = 'adam', age = 33 }
react = rt.getReactiveTable(x)

rt.bindTableModify(react, "name", function(arg)
  u.p(arg)
end, true)

--]]

--[[
reactiveTable = rt.getReactiveTable({
	a = {
		b = {
			1,2,3,
			c = {

			}
		},
		[2] = 2,
		["2"] = "string2"
	},
	[2] = 8,
	["2"] = 811,
})

time1 = 0
rt.bindTableModify(reactiveTable, "a", function(arg)
	time1 = time1 + 1
	if time1 == 1 then
		-- rt.dump(arg)
		dumpResult(
			arg.modifyFields[1].newValue == 1
				and arg.modifyFields[1].oldValue == 2
				and #arg.removeFields == 0
				and #arg.insertFields == 0,
			"callback will bring modifyFields, insertFields, removeFields, table, and key"
			)
	elseif time1 == 2 then
		dumpResult(
			arg.removeFields[1].oldValue == "string2"
				and arg.removeFields[1].key == "2"
				and #arg.insertFields == 0
				and #arg.modifyFields == 0,
			"callback will bring modifyFields, insertFields, removeFields, table, and key"
			)
	elseif time1 == 3 then
		dumpResult(
			getTestIndex(),
			arg.insertFields[1].newValue == "hello world"
				and arg.insertFields[1].oldValue == nil
				and arg.insertFields[1].key == "new"
				and #arg.modifyFields == 0
				and #arg.removeFields == 0,
			"callback will bring modifyFields, insertFields, removeFields, table, and key"
			)
	end
end)
reactiveTable.a[2] = 1

--]]


local luaPrint = print
local forbidenPrint = false
function forbidPrint(forbid)
	if forbid then
		print = function()end
	else
		print = luaPrint
	end
	forbidenPrint = forbid
end

local testIdx = 0
function getTestIndex()
	testIdx = testIdx + 1
	return testIdx
end
function revertTestIndex()
	testIdx = 0 
end

local summaryOk = 0
local summaryFaild = 0
function dumpResult(result, desc)
	local i = getTestIndex()
	print = luaPrint
	if result == true then
		summaryOk = summaryOk + 1
		rt.dump(string.format("%s%s", "    " .. i .. ": OK" .. " line:" ..  debug.getinfo(2).currentline, desc and " " .. desc or ""))
	elseif result == false then
		summaryFaild = summaryFaild + 1
		rt.dump("    " .. i .. ": Faild", "line:" .. debug.getinfo(2).currentline)
	end
	forbidPrint(forbidenPrint)
end


-- public binding interface:
------------------------------------------------------------------------------------------
-- getReactiveTable([initTable])
-- bindValueChange(reactiveTable, bindingString, callback)
-- unbindValueChange(reactiveTable, bindingString, [callback])
-- bindTableModify(reactiveTable, bindingString, callback)
-- unbindTableModify(reactiveTable, bindingString, [callback])
------------------------------------------------------------------------------------------

-- public table interface:
------------------------------------------------------------------------------------------
-- dump(...)
-- pairs(reactiveTable)
-- getLuaTable(reactiveTable)
------------------------------------------------------------------------------------------

local rt = {}

-- table interface
------------------------------------------------------------------------------------------
local function isReactiveTable(t)
    return getmetatable(t) ~= nil and getmetatable(t).__realTable ~= nil
end

local function getRealTable(t)
	if isReactiveTable(t) then
		return getmetatable(t).__realTable
	else
		return t
	end
end

local function getDumpStr(t)
    if type(t) ~= "table" then
        if type(t) == "string" then
            return "\"" .. t .. "\""
        else
            return tostring(t)
        end
    end
    local function getIndentString(level)
        local ret = ""
        for i = 1, level do
            ret = ret .. "    "
        end
        return ret
    end
    local ret = ""
    local function printTable(t, indent)
        if indent == 0 then
            ret = ret .. "{\n"
        end
        for k,v in rt.pairs(t) do
            k = type(k) == "string" and "\"" .. k .. "\"" or k
            v = type(v) == "string" and "\"" .. v .. "\"" or v
            if type(v) == "table" then
                ret = ret .. getIndentString(indent + 1) .. tostring(k) .. " = {\n"
                printTable(v, indent + 1)
            else
                ret = ret .. getIndentString(indent + 1) .. tostring(k) .. " = " .. tostring(v) .. "\n"
            end
        end
        ret = ret .. getIndentString(indent) .. "}\n"
    end
    printTable(t, 0)
    return ret
end

local function revertStringNumber(k)
    if type(k) == "string" and string.sub(k, 1, 1) == '\"' and string.sub(k, string.len(k), string.len(k)) == "\"" then
        k = string.sub(k, 2, string.len(k) - 1)
    end
    return k
end

local function revertNumber(k)
    if type(k) == "string" and tonumber(k) ~= nil then
        k = tonumber(k)
    end
    return k
end

local function tableLength(t)
    local len = 0
    for k,v in rt.pairs(t) do
        len = len + 1
    end
    return len
end

function rt.getLuaTable(reactiveTable)
    local target = {}
    for k, v in rt.pairs(reactiveTable) do
        if type(v) == "table" then
            target[k] = rt.getLuaTable(v)
        else
            target[k] = v
        end
    end
    return target
end

-- print all the tables or values,
-- nil example:
-- input: dump(nil,nil,1) -- output: nil nil 1
-- input: dump(1, nil, nil) -- output: 1
-- return targetString for test
function rt.dump(...)
    arg = {...}
	if arg and table.maxn(arg) == 0 then
		print("all_are_nil")
		return
	end
    local targetString = ""
    for i = 1, table.maxn(arg) do
        if type(arg[i]) == nil then
            targetString = targetString .. "nil" .. "\t"
        else
            targetString = targetString .. getDumpStr(arg[i]) .. "\t"
        end
    end
    print(targetString)
    return targetString
end

function rt.ipairs(t)
    local realTable = getRealTable(t)
    local keys = {}
    local values = {}
    for k, v in ipairs(realTable) do
        if isReactiveTable(t) then
            k = revertNumber(k)
            k = revertStringNumber(k)
        end
        keys[#keys + 1] = k
        values[#values + 1] = v
    end
    local i = 0
    local n = #keys
    return function()
        i = i + 1
        if i <= n then
            return keys[i], values[i]
        end
    end
end

function rt.pairs(t)
    local realTable = getRealTable(t)
    local keys = {}
    local values = {}
    for k, v in pairs(realTable) do
        if isReactiveTable(t) then
            k = revertNumber(k)
            k = revertStringNumber(k)
        end
        keys[#keys + 1] = k
        values[#values + 1] = v
    end
    local i = 0
    local n = #keys
    return function()
        i = i + 1
        if i <= n then
            return keys[i], values[i]
        end
    end
end

-- function rt.insert(t, pos, v)
-- 	local rt = reactive.getRealTable(t)
-- 	-- three params
-- 	if v then
-- 		table.insert(rt, pos, v)
-- 	else	-- two params
-- 		v = pos
-- 		table.insert(rt, v)
-- 	end
-- end

-- binding interface
------------------------------------------------------------------------------------------
-- iterator
local function cutBindingString(bindingString)
	for i = 1, string.len(bindingString) do
        c = string.sub(bindingString, i, i)
        if c == '.' then
            return string.sub(bindingString, i + 1, string.len(bindingString))
        end
        if i == string.len(bindingString) then
        	return ""
        end
    end
end

local function getNextBindingKey(bindingString)
	for i = 1, string.len(bindingString) do
        c = string.sub(bindingString, i, i)
        if c == '.' then
            return string.sub(bindingString, 1, i - 1)
        end
        if i == string.len(bindingString) then
        	return ""
        end
    end
end

-- is the bindingString don't have '.',
-- e.g.
-- "model.hero.attack" return false
-- "hero.attack" return false
-- "attack" return true
local function isBindingEnd(bindingString)
	for i = 1, string.len(bindingString) do
        c = string.sub(bindingString, i, i)
        if c == '.' then
            return false
        end
        if i == string.len(bindingString) then
        	return true
        end
    end
end

-- reactiveMetaTable.__valueChangeBindingTable must be coordinate with bindingString
local function IterToEnd(reactiveMetaTable, bindingString, func)
	-- maybe bind future table, so reactiveMetaTable may be nil
	if reactiveMetaTable == nil then
		return
	end

	-- callback
	func(reactiveMetaTable, bindingString)
	-- travel to next reactiveMetaTable along with bindingString
	local realTable = reactiveMetaTable.__realTable
	local nextBindingKey = getNextBindingKey(bindingString)
	local bindingString = cutBindingString(bindingString)
	if bindingString ~= "" then
		IterToEnd(getmetatable(realTable[nextBindingKey]), bindingString, func)
	end
end

--@return
-- arrivable,
-- parentTable,
-- keyInParent,
-- value
local function getBindingEnd(reactiveMetaTable, bindingString)
	if reactiveMetaTable == nil or isBindingEnd(bindingString) then
		local arrivable = reactiveMetaTable ~= nil and isBindingEnd(bindingString)
		local bindingValue = reactiveMetaTable ~= nil and reactiveMetaTable.__realTable[bindingString] or nil
		return {
			arrivable = arrivable,
			reactiveMetaTable = reactiveMetaTable,
			bindingKey = bindingString,
			bindingValue = bindingValue
		}
	else
		local key = getNextBindingKey(bindingString)
		local realTable = reactiveMetaTable.__realTable
		local subTable = realTable[key]
		if subTable == nil then
			return getBindingEnd(nil, bindingString)
		else
			reactiveMetaTable = getmetatable(subTable)
			return getBindingEnd(reactiveMetaTable, cutBindingString(bindingString))
		end
	end
end

local function getParentBindingString(bindingString, keyInParent)
	if bindingString == "" then
		return keyInParent
	else
		return keyInParent .. "." .. bindingString
	end
end

-- @return rootMetaTable, bindingString
local function getBindingRoot(reactiveMetaTable, bindingString)
	local keyInParentTable = reactiveMetaTable.__keyInParentTable

	-- find root table
	while(keyInParentTable ~= nil) do
		bindingString = getParentBindingString(bindingString, keyInParentTable)
		reactiveMetaTable = reactiveMetaTable.__parentMetaTable
		keyInParentTable = reactiveMetaTable.__keyInParentTable
	end

	return reactiveMetaTable, bindingString
end

-- insert new binding string from any level of a table tree
local function insertValueChangeBinding(reactiveMetaTable, bindingString, callback, callbackOnceWhenBinding)
    local rootReactiveMetaTable, rootUnbindingString = getBindingRoot(reactiveMetaTable, bindingString)

	IterToEnd(
		rootReactiveMetaTable,
		rootUnbindingString,
		function(reactiveMetaTable, bindingString)
			-- add to valueChangeBindingTable, ingore whether there is a key, because the key may have in future
			local valueChangeBindingTable = reactiveMetaTable.__valueChangeBindingTable
            if not valueChangeBindingTable[bindingString] then
                valueChangeBindingTable[bindingString] = {}
            end
			valueChangeBindingTable[bindingString][callback] = true
            if callbackOnceWhenBinding and isBindingEnd(bindingString) then
                callback{
                    newValue = reactiveMetaTable.__realTable[bindingString],
                    oldValue = nil,
                    key = bindingString
                }
            end
		end
		)
end

local function InsertFieldsModifyBinding(reactiveMetaTable, bindingString, callback, callbackOnceWhenBinding)
    local rootReactiveMetaTable, rootBindingString = getBindingRoot(reactiveMetaTable, bindingString)

    IterToEnd(
        rootReactiveMetaTable,
        rootBindingString,
        function(reactiveMetaTable, bindingString)
            -- add to tableModifyBindingTable, ingore whether there is a key, because the key may have in future
            local tableModifyBindingTable = reactiveMetaTable.__tableModifyBindingTable
            if not tableModifyBindingTable[bindingString] then
                tableModifyBindingTable[bindingString] = {}
            end
            tableModifyBindingTable[bindingString][callback] = true
            if callbackOnceWhenBinding and isBindingEnd(bindingString) then
                -- rt.dump(reactiveMetaTable)
                -- os.exit()
                -- here may be lead stack too deep exception
                local t = reactiveMetaTable.__realTable[bindingString]
                callback{
                    table = t ~= nil and rt.getLuaTable(t) or nil
                }
            end
        end
        )
end

local function deleteValueChangeBinding(reactiveMetaTable, unbindingString, callback)
	local rootReactiveMetaTable, rootUnbindingString = getBindingRoot(reactiveMetaTable, unbindingString)
    IterToEnd(
        rootReactiveMetaTable,
        rootUnbindingString,
        function(reactiveMetaTable, unbindingString)
            local valueChangeBindingTable = reactiveMetaTable.__valueChangeBindingTable
            for k, v in pairs(valueChangeBindingTable) do
                if k == unbindingString then
                    if callback then
                        local testFound = false
                        for m, n in pairs(v) do
                            if m == callback then
                                testFound = true
                                v[m] = nil
                            end
                        end
                        if testFound == false then
                            rt.dump(debug.traceback())
                            rt.dump("deleteValueChangeBinding Error : cannot find unbindingString, you may not bind " .. unbindingString .. " to this reactive table")
                        end
                    end
                    if tableLength(v) == 0 or not callback then
                        valueChangeBindingTable[k] = nil
                    end
                end
            end
        end
        )
end

local function deleteTableModifyBinding(reactiveMetaTable, unbindingString, callback)
    local rootReactiveMetaTable, rootUnbindingString = getBindingRoot(reactiveMetaTable, unbindingString)
    IterToEnd(
        rootReactiveMetaTable,
        rootUnbindingString,
        function(reactiveMetaTable, unbindingString)
            local tableModifyBindingTable = reactiveMetaTable.__tableModifyBindingTable
            for k, v in pairs(tableModifyBindingTable) do
                if k == unbindingString then
                    if callback then
                        local testFound = false
                        for m, n in pairs(v) do
                            if m == callback then
                                testFound = true
                                v[m] = nil
                            end
                        end
                        if testFound == false then
                            rt.dump(debug.traceback())
                            rt.dump("deleteTableModifyBinding Error : cannot find unbindingString, you may not bind " .. unbindingString .. " to this reactive table")
                        end
                    end
                    if tableLength(v) == 0 or not callback then
                        tableModifyBindingTable[k] = nil
                    end
                end
            end
        end
        )
end

local function transStringNumber(k)
    if type(k) == "string" and tonumber(k) ~= nil then
        k = "\"" .. k .. "\""
    end
    return k
end

local function transNumber(k)
    if type(k) == "number" then
        k = tostring(k)
    end
    return k
end

-- public interface implementation
------------------------------------------------------------------------------------------
-- @ return a pseudo table(always empty) for users
-- some code only do once in outermost layer recursive function
local stackLevel = 0
function rt.getReactiveTable(initTable)
    -- we use this table to store real data
    -- the table this function returns is a pseudo table which always be nil
    local realTable = {}

    -- this table is used to record user visible table
    local reactiveTable = {}

    -- this table is used to store observable changing strings
    local valueChangeBindingTable = {}

    -- this table is used to store table modify changing strings
    local tableModifyBindingTable = {}

    -- record old bindingValue
    local oldBindingValue = {}

    -- there are 5 tables:
    -- realTable: store real data
    -- reactiveTable: give user, always empty, __newindex = function(t,k,v), the "t" is reactiveTable
    -- valueChangeBindingTable : store bindingStrings.
    -- parentTable : parent reactiveMetaTable
    -- keyInParentTable : parent key toward this table
    -- reactiveMetaTable : store all message, use getmetatable(reactiveTable) get
    setmetatable(reactiveTable, {
        __realTable = realTable,
        __reactiveTable = reactiveTable,
        __valueChangeBindingTable = valueChangeBindingTable,
        __tableModifyBindingTable = tableModifyBindingTable,
        __keyInParentTable = nil,
        __parentMetaTable = nil,
        __index = function(t, k)
    		-- if the key likes "2" then replace the key to "__2__" for binding
    		k = transStringNumber(k)
    		k = transNumber(k)

            return rawget(getmetatable(t).__realTable, k)
        end,
        -- t is __reactiveTable
        __newindex = function(t, k, v)
        	local function storeOldValueChangeBindingValue(reactiveTable)
        		-- store all old binding value
            	local reactiveMetaTable = getmetatable(reactiveTable)
            	local valueChangeBindingTable = reactiveMetaTable.__valueChangeBindingTable
            	for k,v in pairs(valueChangeBindingTable) do
            		local bindingEnd = getBindingEnd(reactiveMetaTable, k)
            		local arrivable, endReactiveMetaTable, bindingKey, bindingValue = bindingEnd.arrivable, bindingEnd.reactiveMetaTable, bindingEnd.bindingKey, bindingEnd.bindingValue
					oldBindingValue[k] = {
						arrivable,
						endReactiveMetaTable,
						bindingKey,
						bindingValue
					}
            	end
        	end

            local function storeOldTableModifyBindingValue(reactiveTable)
                local function copyTable(t)
                    local target = {}
                    for k, v in rt.pairs(t) do
                        target[k] = v
                    end
                    return target
                end
                -- store all old binding value
                local reactiveMetaTable = getmetatable(reactiveTable)
                local parentMetaTabel = reactiveMetaTable.__parentMetaTable
                if parentMetaTabel then
                    local tableModifyBindingTable = parentMetaTabel.__tableModifyBindingTable
                    for k,v in pairs(tableModifyBindingTable) do
                        local bindingEnd = getBindingEnd(parentMetaTabel, k)
                        local arrivable, endReactiveMetaTable, bindingKey, bindingValue = bindingEnd.arrivable, bindingEnd.reactiveMetaTable, bindingEnd.bindingKey, bindingEnd.bindingValue
                        oldBindingValue[k] = {
                            arrivable,
                            endReactiveMetaTable,
                            bindingKey,
                            copyTable(bindingValue)
                        }
                    end
                end
            end

        	local function rebuildSubBindingTable(reactiveTable)
        		local reactiveMetaTable = getmetatable(reactiveTable)

                for k,v in pairs(reactiveMetaTable.__valueChangeBindingTable) do
                    local callbacks = reactiveMetaTable.__valueChangeBindingTable[k]

                    IterToEnd(
                        reactiveMetaTable,
                        k,
                        function(iterReactiveMetaTable, iterKey)
                            for k, v in pairs(callbacks) do
                                if not iterReactiveMetaTable.__valueChangeBindingTable[iterKey] then
                                    iterReactiveMetaTable.__valueChangeBindingTable[iterKey] = {}
                                end
                                iterReactiveMetaTable.__valueChangeBindingTable[iterKey][k] = v
                            end
                        end
                        )
                end

                for k,v in pairs(reactiveMetaTable.__tableModifyBindingTable) do
                    local callbacks = reactiveMetaTable.__tableModifyBindingTable[k]

                    IterToEnd(
                        reactiveMetaTable,
                        k,
                        function(iterReactiveMetaTable, iterKey)
                            for k, v in pairs(callbacks) do
                                if not iterReactiveMetaTable.__tableModifyBindingTable[iterKey] then
                                    iterReactiveMetaTable.__tableModifyBindingTable[iterKey] = {}
                                end
                                iterReactiveMetaTable.__tableModifyBindingTable[iterKey][k] = v
                            end
                        end
                        )
                end
        	end

        	local function compareOldValueChangeBindingValueWithNew(reactiveTable)
            	-- compare if the old binding value is same as new one
            	local reactiveMetaTable = getmetatable(reactiveTable)
            	local valueChangeBindingTable = getmetatable(reactiveTable).__valueChangeBindingTable

            	for k,v in pairs(valueChangeBindingTable) do
            		local bindingEnd = getBindingEnd(reactiveMetaTable, k)
            		local newArrivable, newEndReactiveMetaTable, newEndBindingString, newEndValue = bindingEnd.arrivable, bindingEnd.reactiveMetaTable, bindingEnd.bindingKey, bindingEnd.bindingValue
            		local oldArrivable, oldEndReactiveMetaTable, oldEndBindingString, oldEndValue = oldBindingValue[k][1], oldBindingValue[k][2], oldBindingValue[k][3], oldBindingValue[k][4]
            		oldBindingValue[k] = nil

            		if (newArrivable ~= oldArrivable) or (newEndValue ~= oldEndValue) then
            			local callbacks = nil
            			local oldReactiveTable = nil
            			local newReactiveTable = nil
            			local key = nil
            			if newEndReactiveMetaTable then
            				callbacks = newEndReactiveMetaTable.__valueChangeBindingTable[newEndBindingString]
            				newReactiveTable = newEndReactiveMetaTable.__reactiveTable
            				key = newEndBindingString
        				elseif oldEndReactiveMetaTable then
        					callbacks = oldEndReactiveMetaTable.__valueChangeBindingTable[oldEndBindingString]
        					oldReactiveTable = oldEndReactiveMetaTable.__reactiveTable
        					key = oldEndBindingString
        				end
        				if callbacks then
                            for m, n in pairs(callbacks) do
            					arg = {}
            					arg.oldValue = type(oldEndValue) == "table" and rt.getLuaTable(oldEndValue) or oldEndValue
            					arg.newValue = type(newEndValue) == "table" and rt.getLuaTable(newEndValue) or newEndValue
            					-- arg.oldReactiveTable = oldReactiveTable
            					-- arg.newReactiveTable = newReactiveTable
            					arg.key = key
            					m(arg)
                            end
        				end
            		end
            	end
        	end

            local function compareOldTableModifyBindingValueWithNew(reactiveTable)
                local function compareDifference(oldEndValue, newEndValue)
                    local isDifferent = false
                    local removeFields = {}
                    local insertFields = {}
                    local modifyFields = {}
                    for k, v in rt.pairs(newEndValue) do
                        if newEndValue[k] ~= oldEndValue[k] then
                            isDifferent = true
                            if oldEndValue[k] == nil then
                                insertFields[#insertFields + 1] = {
                                    newValue = newEndValue[k],
                                    key = k
                                }
                            elseif oldEndValue[k] ~= nil then
                                modifyFields[#modifyFields + 1] = {
                                    oldValue = oldEndValue[k],
                                    newValue = newEndValue[k],
                                    key = k
                                }
                            end
                        end
                        oldEndValue[k] = nil
                    end
                    for k, v in rt.pairs(oldEndValue) do
                        isDifferent = true
                        removeFields[#removeFields + 1] = {
                            oldValue = oldEndValue[k],
                            key = k
                        }
                    end
                    return {
                        isDifferent = isDifferent,
                        removeFields = removeFields,
                        insertFields = insertFields,
                        modifyFields = modifyFields
                    }
                end
                -- compare if the old binding value is same as new one
                local reactiveMetaTable = getmetatable(reactiveTable)
                local parentMetaTabel = reactiveMetaTable.__parentMetaTable
                if parentMetaTabel then
                    local tableModifyBindingTable = parentMetaTabel.__tableModifyBindingTable
                    -- rt.dump(tableModifyBindingTable)
                    for k,v in pairs(tableModifyBindingTable) do
                        local bindingEnd = getBindingEnd(parentMetaTabel, k)
                        local newArrivable, newEndReactiveMetaTable, newEndBindingString, newEndValue = bindingEnd.arrivable, bindingEnd.reactiveMetaTable, bindingEnd.bindingKey, bindingEnd.bindingValue
                        local oldArrivable, oldEndReactiveMetaTable, oldEndBindingString, oldEndValue = oldBindingValue[k][1], oldBindingValue[k][2], oldBindingValue[k][3], oldBindingValue[k][4]
                        oldBindingValue[k] = nil

                        local compareResult = compareDifference(oldEndValue, newEndValue)
                        if (newArrivable ~= oldArrivable) or compareResult.isDifferent then
                            local callbacks = nil
                            local oldReactiveTable = nil
                            local newReactiveTable = nil
                            local key = nil
                            if newEndReactiveMetaTable then
                                callbacks = newEndReactiveMetaTable.__tableModifyBindingTable[newEndBindingString]
                                newReactiveTable = newEndReactiveMetaTable.__reactiveTable
                                key = newEndBindingString
                            elseif oldEndReactiveMetaTable then
                                callbacks = oldEndReactiveMetaTable.__tableModifyBindingTable[oldEndBindingString]
                                oldReactiveTable = oldEndReactiveMetaTable.__reactiveTable
                                key = oldEndBindingString
                            end
                            if callbacks then
                                for m, n in pairs(callbacks) do
                                    arg = {}
                                    arg.removeFields = compareResult.removeFields
                                    arg.insertFields = compareResult.insertFields
                                    arg.modifyFields = compareResult.modifyFields
                                    -- arg.oldValue = oldEndValue
                                    -- arg.newValue = newEndValue
                                    -- arg.oldReactiveTable = oldReactiveTable
                                    -- arg.newReactiveTable = newReactiveTable
                                    arg.table = type(newEndValue) == "table" and rt.getLuaTable(newEndValue) or newEndValue
                                    arg.key = key
                                    m(arg)
                                end
                            end
                        end
                    end
                end
            end

        	local function insertOrUpdateValue(k, v)
        		local oldValue = realTable[k]
	            local newValue = v
	            if type(v) == "table" then
	            	newValue = rt.getReactiveTable()
	            	getmetatable(newValue).__keyInParentTable = k
	            	getmetatable(newValue).__parentMetaTable = getmetatable(reactiveTable)
	           		realTable[k] = newValue

	            	for m, n in pairs(v) do
		            	realTable[k][m] = n
		            end
		        else
		        	realTable[k] = v
	            end
        	end

        	-- if the key likes "2" then replace the key to "__2__" for binding
	        k = transStringNumber(k)
	        k = transNumber(k)

        	-- stackLevel is 1 when the fist level
        	if realTable[k] ~= v then
	        	stackLevel = stackLevel + 1
	        	if stackLevel == 1 then
		        	storeOldValueChangeBindingValue(reactiveTable)
                    storeOldTableModifyBindingValue(reactiveTable)
		        end

		        insertOrUpdateValue(k, v)

	            if stackLevel == 1 then
                    if type(v) == "table" then
	            	    rebuildSubBindingTable(reactiveTable)
                    end

	            	compareOldValueChangeBindingValueWithNew(reactiveTable)
                    compareOldTableModifyBindingValueWithNew(reactiveTable)
                end

	            stackLevel = stackLevel - 1
	        end
        end
        })

    -- initTable
    if initTable then
    	for k,v in pairs(initTable) do
    		reactiveTable[k] = v
    	end
    end

    return reactiveTable
end

-- @return
-- 		newValue,
-- 		oldValue,
--		key
function rt.bindValueChange(reactiveTable, bindingString, callback, callbackOnceWhenBinding)
    insertValueChangeBinding(getmetatable(reactiveTable), bindingString, callback, callbackOnceWhenBinding or false)
end

-- if no callback then remove all observer of one binding
function rt.unbindValueChange(reactiveTable, bindingString, callback)
    deleteValueChangeBinding(getmetatable(reactiveTable), bindingString, callback)
end

function rt.bindTableModify(reactiveTable, bindingString, callback, callbackOnceWhenBinding)
    InsertFieldsModifyBinding(getmetatable(reactiveTable), bindingString, callback, callbackOnceWhenBinding or false)
end

function rt.unbindTableModify(reactiveTable, bindingString, callback)
    deleteTableModifyBinding(getmetatable(reactiveTable), bindingString, callback)
end

return rt
