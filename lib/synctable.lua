-- FROM: https://github.com/simonxlg/syncobj/blob/master/synctable.lua

--[[ EXAMPLE -------------------------------------------------------------------
synctable = require "lib.synctable"

x = {name = 'adam', age = 33}

-- Create a copy of 'x' that can later be diffed with 'x'
tab = synctable.create(x)

-- Modify the copy
tab.sex = 'male'

-- Output the diff
diff = synctable.diff(tab)
→ { {
  →    ["root.sex"] = "male"
  →  } }


  -- update 'x' to track changes made to 'tab'
  synctable.patch(x, synctable.diff(tab))

  --]] ---------------------------------------------------------------------------


  local pairs = pairs
  local setmetatable = setmetatable
  local synctable = {}
  local new
  local make

  new = function(root,tab,tag)
    local _tab = {}
    local _root = root
    local ret = make(_root,_tab,tag)
    if not _root then
      _root = ret
    end
    for k,v in pairs(tab) do
      if type(v) == "table"  then
	_tab[k] = new(_root,v,tag.."."..k)
      else
	_tab[k] = v
      end
    end
    return ret
  end

  make = function(root,tab,tag)
    local proxy = {
      __data = tab,
      __tag = tag,
      __root = root,
    }
    if not root then
      proxy.__root = proxy
      proxy.__pair ={}
    end
    setmetatable(proxy,{
      __newindex = function(s, k, v)
	local root = s.__root
	local tag = s.__tag
	local data = s.__data

	local old = data[k]

	if not data[k] and type(v) == "table"  then
	  data[k] = new(root,v,tag.."."..k)
	else
	  data[k] = v
	end

	local new = data[k]

	print('new', hs.inspect(new), 'old', hs.inspect(old))

	table.insert(root.__pair,{[s.__tag.."."..k] = v or "nil"})
      end,
      __index = function (s, k)
	return s.__data[k]
      end,
      __pairs = function(tab)
	return next, tab.__data ,nil
      end,
      __len = function (tab)
	return #tab.__data
      end
    })
    return proxy
  end

  function synctable.create(tab)
    local _tag = "root"
    return new(nil,tab,_tag)
  end

  function synctable.diff(tab)
    local diff = tab.__pair
    tab.__pair = {}
    return diff
  end

  function synctable.patch(obj,diff)
    for i = 1 ,#diff do
      for k,v in pairs(diff[i]) do
	local arr = {}
	for w in k:gmatch("([^.]+)") do table.insert(arr,w) end
	local curr = obj
	local len = #arr
	for i=2,len-1 do
	  curr = curr[tonumber(arr[i]) or (arr[i])]
	  assert(curr,string.format("key err=%s",arr[i]))
	end
	curr[tonumber(arr[len]) or (arr[len])] = v
      end
    end
    return obj
  end

  return synctable
