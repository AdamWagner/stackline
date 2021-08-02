require 'spec.helpers'

describe('FrameSet', function()

  before_each(function()
    FrameSet = require 'classes.FrameSet'
    ws = hs.window.filter()
    fs = FrameSet:new(table.slice(ws,1,5))
  end)

  -- after_each(function()
  --   -- TODO: consider adding something like this as a __tostring method on `FrameSet`
  --   for k,v in u.spairs(fs.groups) do
  --     print('\n'..tostring(k:floor()) ..' · length = '..#v)
  --     for _,j in pairs(v) do
  --       print('   ',j.app .. ' - '..j.id .. ' - rect:',tostring(j:frame():floor()))
  --     end
  --   end
  -- end)

  it('Auto-groups new windows added after initialization', function()
    fs:add(ws[6])
    fs:add(ws[7])
    -- TODO: write assert
  end)

  -- it('works with simple values', function() 
  --       autog = require 'stackline.modules.AutoGroupable'
  --       x = autog.setup()
  --       x[{'a'}] = 'five'
  --       x[{'a'}] = 'five'
  --       print('---------------------')
  --       u.p(x)
  --       print('---------------------')
  --   end)
end)
