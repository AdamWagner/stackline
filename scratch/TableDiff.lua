local Class = 'lib.Class'
local async = 'lib.async'

local TableDiff = Class()

function TableDiff:new()
  self.LastState = {}
  self.CurrentState = {}
  self.ExcludeKeys = {}
  self.PauseAfterSteps = 10000
  self.Count = 0
  return self
end

function TableDiff:Step()
  self.Count = self.Count + 1
end

function TableDiff:Build(NewStateRoot, LastStateRoot, Path, LookForRemoval) -- {{{
  if ((NewStateRoot == nil) and LastStateRoot) then
    self.Removal(Path, LastStateRoot)
    return
  end

  if LookForRemoval then
    return
  end

  if (NewStateRoot and (LastStateRoot == nil)) then
    self.Addition(Path, NewStateRoot)
    return
  end

  if (type(NewStateRoot) == "table" and type(LastStateRoot) == "table") then
    local ExcludeKeys = self.ExcludeKeys

    for Key, Value in pairs(NewStateRoot) do
      -- if (ExcludeKeys[Key]) then
      --     -- continue
      -- end

      self:Step()

      local NewPath = Path .. "@" .. Key
      self:Build(Value, LastStateRoot[Key], NewPath, false)
    end

    for Key, Value in pairs(LastStateRoot) do
      -- if (ExcludeKeys[Key]) then
      --     -- continue
      -- end

      self:Step()

      local NewPath = Path .. "@" .. Key

      -- Only look for removals from old to new (final argument in this call)
      self:Build(NewStateRoot[Key], Value, NewPath, true)
    end

    return
  end

  if (NewStateRoot == LastStateRoot) then
    -- self.Same(Path, NewStateRoot)
    return
  end

  self.Change(Path, LastStateRoot, NewStateRoot)
end -- }}}

function TableDiff:Update() -- {{{
  --[[
  Copy should be taken before any traversal so we have
  an unmodifiable table. Since 'CurrentState' can
  be changed during the delay time, this can cause
  bugs. Snapshotting beforehand solves any issues.
  ]]

  local tmp = u.dcopy(self.CurrentState)
  self:Build(tmp, self.LastState, "", false)

  self.LastState = tmp

  -- print("Updated Replication")
end -- }}}

-- Handlers to be overwritten
-- function TableDiff.Same(Path, Value) end
function TableDiff.Change(Path, Old, New)
end
function TableDiff.Addition(Path, New)
end
function TableDiff.Removal(Path, Old)
end

return TableDiff
