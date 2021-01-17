local M = {}

function M.copyShallow(x)-- {{{
  local copy
  if u.is_table(x) then
    copy = {}
    for k,v in pairs(x) do copy[k] = v end
  else copy = x end

  return copy
end-- }}}

function M.dcopy(tbl, cache)-- {{{
  -- REVIEW: https://github.com/LPGhatguy/ld27-fast-food/blob/main/ussuri/core/utility.lua
  -- Good deepCopy implementation that does a few things I'm not doing here
  -- Also includes table_nav(), which does the string → key , value lookup thing that's currently deep in utils.
--[[ NOTES {{{
  from https://gist.github.com/tylerneylon/81333721109155b2d244 The issue here
  is that the following code will call itself indefinitely and ultimately
  cause a stack overflow:

  local my_t = {}
  my_t.a = my_t
  local t_copy = copy2(my_t)

  This happens to both copy1 and copy2, which each try to make a copy of
  my_t.a, which involves making a copy of my_t.a.a, which involves making a
  copy of my_t.a.a.a, etc. The recursive table my_t is perfectly legal, and
  it's possible to make a deep_copy function that can handle this by tracking
  which tables it has already started to copy.

  Thanks to @mnemnion for pointing out that we should not call setmetatable()
  until we're done copying values; otherwise we may accidentally trigger a
  custom __index() or __newindex()!
  ]]  -- }}}
  cache = cache or {}
  local u = require 'lib.utils'
  local dcopy = M.dcopy

  -- Simply return non-table values as-is
  if not u.is_table(tbl) then return tbl end
  -- If cache before, return cached copy
  if cache[tbl] then return cache[tbl] end

  -- New table; store in cache and copy recursively
  local res = {}
  cache[tbl] = res
  for k,v in u.iter(tbl) do

    -- both key *and* value are tables ¯\_(ツ)_/¯
    if u.all({k,v}, u.is_table) then
      res[dcopy(k,cache)] = dcopy(v,cache)

    -- only the value is a table
    elseif u.is_table(v) then
      res[k] = dcopy(v)

    -- only the value is a table
    else res[k] = dcopy(v) end

  end
  return setmetatable(res, getmetatable(tbl))
end -- }}}

function M.clone(obj, shallow)-- {{{
    local lookup_table = {}

    local function _copy (object)
      if type (object) ~= "table" then
	return object
      elseif lookup_table [object] then
	return lookup_table [object]
      end  -- if

      local new_table = {}
      lookup_table [object] = new_table

      for index, value in pairs (object) do
	new_table [_copy (index)] = _copy (value)
      end  -- for

      return setmetatable (new_table, getmetatable (object))
    end  -- function _copy

    return _copy (obj)
  end-- }}}

  -- ———————————————————————————————————————————————————————————————————————————
  -- aryajur/tableUtils
  -- https://github.com/aryajur/tableUtils/blob/master/src/tableUtils.lua
  -- ———————————————————————————————————————————————————————————————————————————

  -- Copy table t1 to t2 overwriting any common keys
  -- If full is true then copy is recursively going down into nested tables
  -- returns t2 and mapping of source to destination and destination to source tables
  local WEAKK = {__mode="k"}
  local WEAKV = {__mode="v"}
  function M.copyTable(t1,t2,full,map,tabDone)  -- {{{
    map = map or {
      s2d=setmetatable({},WEAKK),
      d2s=setmetatable({},WEAKV)
    }
    map.s2d[t1] = t2		  -- s2d contains mapping of source table tables to destination tables
    map.d2s[t2] = t1		  -- d2s contains mapping of destination table tables to source tables
    tabDone = tabDone or {[t1]=t2}	  -- To keep track of recursive tables
    for k,v in pairs(t1) do
      if type(v) == "number" or type(v) == "string" or type(v) == "boolean" or type(v) == "function" or type(v) == "thread" or type(v) == "userdata" then
	if type(k) == "table" then
	  if full then
	    local kp
	    if not tabDone[k] then
	      kp = {}
	      tabDone[k] = kp
	      M.copyTable(k,kp,true,map,tabDone)
	      map.d2s[kp] = k
	      map.s2d[k] = kp
	    else
	      kp = tabDone[k]
	    end
	    t2[kp] = v
	  else
	    t2[k] = v
	  end
	else
	  t2[k] = v
	end
      else
	-- type(v) = ="table"
	if full then
	  if type(k) == "table" then
	    local kp
	    if not tabDone[k] then
	      kp = {}
	      tabDone[k] = kp
	      M.copyTable(k,kp,true,map,tabDone)
	      map.d2s[kp] = k
	      map.s2d[k] = kp
	    else
	      kp = tabDone[k]
	    end
	    t2[kp] = {}
	    if not tabDone[v] then
	      tabDone[v] = t2[kp]
	      M.copyTable(v,t2[kp],true,map,tabDone)
	      map.d2s[t2[kp]] = v
	      map.s2d[v] = t2[kp]
	    else
	      t2[kp] = tabDone[v]
	    end
	  else
	    t2[k] = {}
	    if not tabDone[v] then
	      tabDone[v] = t2[k]
	      M.copyTable(v,t2[k],true,map,tabDone)
	      map.d2s[t2[k]] = v
	      map.s2d[v] = t2[k]
	    else
	      t2[k] = tabDone[v]
	    end
	  end
	else
	  t2[k] = v
	end
      end
    end
    return t2,map
  end  -- }}}



  -- Function to compare 2 tables. Returns nil if they are not equal in value or do not have the same recursive link structure
  -- Recursive tables are allowed
  function M.compareTables(t1,t2,traversing)  -- {{{
    if not t2 then
      return false
    end
    traversing = traversing or {}
    traversing[t1] = t2	  -- t1 is being traversed to match it to t2
    local donet2 = {}	  -- To mark which keys are taken
    for k,v in pairs(t1) do
      --print(k,v)
      if type(v) == "number" or type(v) == "string" or type(v) == "boolean" or type(v) == "function" or type(v) == "thread" or type(v) == "userdata" then
	if type(k) == "table" then
	  -- Find a matching key
	  local found
	  for k2,v2 in pairs(t2) do
	    if not donet2[k2] and type(k2) == "table" then
	      -- Check if k2 is already traversed or is being traversed
	      local traversal
	      for k3,v3 in pairs(traversing) do
		if v3 == k2 then
		  traversal = k3
		  break
		end
	      end
	      if not traversal then
		if M.compareTables(k,k2,traversing) and v2 == v then
		  found = k2
		  break
		end
	      elseif traversal==k and v2 == v then
		found = k2
		break
	      end
	    end
	  end
	  if not found then
	    return false
	  end
	  donet2[found] = true
	else
	  if v ~= t2[k] then
	    return false
	  end
	  donet2[k] = true
	end
      else
	-- type(v) = ="table"
	--print("  --  --  --  -->Going In "..tostring(v))
	if type(k) == "table" then
	  -- Find a matching key
	  local found
	  for k2,v2 in pairs(t2) do
	    if not donet2[k2] and type(k2) == "table" then
	      -- Check if k2 is already traversed or is being traversed
	      local traversal
	      for k3,v3 in pairs(traversing) do
		if v3 == k2 then
		  traversal = k3
		  break
		end
	      end
	      if not traversal then
		if M.compareTables(k,k2,traversing) and v2 == v then
		  found = k2
		  break
		end
	      elseif traversal==k and v2 == v then
		found = k2
		break
	      end
	    end
	  end
	  if not found then
	    return false
	  end
	  donet2[found] = true
	else
	  -- k is not a table
	  if not traversing[v] then
	    if not M.compareTables(v,t2[k],traversing) then
	      return false
	    end
	  else
	    -- This is a recursive table so it should match
	    if traversing[v] ~= t2[k] then
	      return false
	    end
	  end
	  donet2[k] = true
	end
      end
    end
    -- Check if any keys left in t2
    for k,_ in pairs(t2) do
      if not donet2[k] then
	return false	  -- extra stuff in t2
      end
    end
    traversing[t1] = nil
    return true
  end  -- }}}


  local setnil = {}	-- Marker table for diff to set nil

  -- Function to return the diff patch of t2-t1. The patch when applied to t1 will make it equal in value to t2 such that compareTables will return true
  -- Use the patch function the apply the patch
  -- map is the table that can provide mapping of any table in t2 to a table in t1 i.e. they can be considered the referring to the same table i.e. that table in t2 after the patch operation would be the same in value as the table in t1 that the map defines but its address will still be the address it was in t2. If there is no mapping for the table found then the same table is looked up at that level to match. But if there is a same table then the diff for that table is obviously 0

  -- NOTE: a diff object is temporary and cannot be saved for a later session(This is because of setnil being unique to a session). To save it is better to serialize and save t1 and t2 using t2s functions
  function M.diffTable(t1,t2,map,tabDone,diff)  -- {{{
    map = map or {
      [t2]=t1
    }
    tabDone = tabDone or {[t2]=true}	  -- To keep track of recursive tables
    diff = diff or {}
    local diffDirty
    diff[t1] = diff[t1] or {}
    local keyTabs = {}
    -- To convert t1 to t2 let us iterate over all elements of t2 first
    for k,v in pairs(t2) do
      -- There are 8 types in Lua (except nil and table we check everything here
      if type(v) ~= "table" then			  --
	if type(k) == "table" then
	  -- Check if there is a mapping else the mapping in t1 is k
	  local kt1 = k
	  if map[k] then
	    kt1 = map[k]
	    -- Get diff of kt1 and k
	    if not tabDone[k] then
	      tabDone[k]= true
	      M.diffTable(kt1,k,map,tabDone,diff)
	      diffDirty = diffDirty or diff[kt1]
	    end
	  end
	  keyTabs[kt1] = k
	  if t1[kt1] == nil or t1[kt1] ~= v then
	    diff[t1][kt1] = v
	    diffDirty = true
	  end
	else	  -- if type(k) == "table" then else
	  -- Neither v is a table not k is a table
	  if t1[k] ~= v then
	    diff[t1][k] = v
	    diffDirty = true
	  end
	end		  -- if type(k) == "table" then ends
      else	  --if type(v) ~= "table" then
	-- v == "table"
	if type(k) == "table" then
	  -- Both v and k are tables
	  local kt1 = k
	  if map[k] then
	    kt1 = map[k]
	    if not tabDone[k] then
	      tabDone[k] = true
	      M.diffTable(kt1,k,map,tabDone,diff)
	      diffDirty = diffDirty or diff[kt1]
	    end
	  end
	  keyTabs[kt1] = k
	  local vt1 = v
	  if map[v] then
	    vt1 = map[v]
	    if not tabDone[v] then
	      tabDone[v] = true
	      M.diffTable(vt1,v,map,tabDone,diff)
	      diffDirty = diffDirty or diff[vt1]
	    end
	  end
	  if t1[kt1] == nil or t1[kt1] ~= vt1 then
	    diff[t1][kt1] = vt1
	    diffDirty = true
	  end
	else
	  local vt1 = v
	  if map[v] then
	    vt1 = map[v]
	    -- Get the diff of vt1 and v
	    if not tabDone[v] then
	      tabDone[v] = true
	      M.diffTable(vt1,v,map,tabDone,diff)
	      diffDirty = diffDirty or diff[vt1]
	    end
	  end
	  if t1[k] == nil or t1[k] ~= vt1 then
	    diff[t1][k] = vt1
	    diffDirty = true
	  end
	end
      end	  --if type(v) ~= "table" then ends
    end	  -- for k,v in pairs(t2) do ends
    -- Now to find extra stuff in t1 which should be removed
    for k,_ in pairs(t1) do
      if type(k) ~= "table" then
	if t2[k] == nil then
	  diff[t1][k] = setnil
	  diffDirty = true
	end
      else
	-- k is a table
	-- get the t2 counterpart if it was found
	if not keyTabs[k] then
	  diff[t1][k] = setnil
	  diffDirty = true
	end
      end
    end
    if not diffDirty then diff[t1] = nil end
    return diffDirty and diff
  end  -- }}}

  return M
