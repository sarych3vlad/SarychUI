local getmetatable, pairs = getmetatable, pairs
local CreateFrame = CreateFrame

-----------------------  patch objects metatables    -----------------------
----------------------------------------------------------------------------
-- add new methods for all objects on the hierarchy!
local short_objects_hierarchy_map = {
  -- from https://static.wikia.nocookie.net/wowpedia/images/c/ca/Widget_Hierarchy.png/revision/latest/scale-to-width-down/1000?cb=20210222032834
  -- and https://wowpedia.fandom.com/wiki/Widget_API
  Region = {
    type = 'abstract',
    methods = {
      SetShown = function(self, state)
        if state then self:Show() else self:Hide() end
      end,
    },
  },
  LayeredRegion = {
    parent = 'Region',
    type = 'abstract',
  },
  FontString = {
    parent = 'LayeredRegion',
    type = 'normal',
  },
  Frame = {
    parent = 'Region',
    type = 'normal',
  },
  Button = {
    parent = 'Frame',
    type = 'normal',
    methods = {
      SetEnabled = function(self, state)
        if state then self:Enable() else self:Disable() end
      end,
    },
  },
  CheckButton = {
    parent = 'Button',
    type = 'normal',
  },
  EditBox = {
    parent = 'Frame',
    type = 'normal',
    methods = {
      Enable = function(self)
        self:SetFontObject('GameFontWhite')
        self:EnableMouse(true)
        self:ClearFocus()
      end,
      Disable = function(self)
        self:SetFontObject('GameFontDisable')
        self:EnableMouse(false)
        self:ClearFocus()
      end,
      SetEnabled = function(self, state)
        if state then self:Enable() else self:Disable() end
      end,
    },
  },
}
local mt = {} -- table of objects metatables
local obj = {} -- table of objects

local function GetObject(obj_type)
  if obj[obj_type] then return obj[obj_type] end

  local object
  if obj_type == 'FontString' then
    object = GetObject('Frame'):CreateFontString()
  else
    object = CreateFrame(obj_type)
  end

  if object.Hide then
    object:Hide() -- NECESSARILY for EditBox! Otherwise, the keyboard in the game will not work!
  end
  obj[obj_type] = object
  return object
end

local function GetObjectMetatable(obj_type)
  if mt[obj_type] then return mt[obj_type] end
  local object = GetObject(obj_type)
  local meta = getmetatable(object)
  mt[obj_type] = meta
  return meta
end

local function HandleObject(cur_obj_type, src_obj_type)
  local obj_data = short_objects_hierarchy_map[cur_obj_type]
  if obj_data.methods then
    local obj_mt = GetObjectMetatable(src_obj_type)
    for method_name, method_func in pairs(obj_data.methods) do
      if not obj_mt[method_name] then
        obj_mt.__index[method_name] = method_func
      end
    end
  end
  if obj_data.parent then
    HandleObject(obj_data.parent, src_obj_type)
    if obj_data.parent2 then
      HandleObject(obj_data.parent2, src_obj_type)
    end
  end
end

for obj_name, obj_data in pairs(short_objects_hierarchy_map) do
  if obj_data.type == 'normal' or obj_data.type == 'unique' then
    HandleObject(obj_name, obj_name)
  end
end
----------------------------------------------------------------------------
