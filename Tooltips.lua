-- Class line on player tooltips (ClassTooltip) and world-map cursor coords (McMapCoords).

local CLASS_RGB = {
  WARRIOR = { .78, .61, .43 }, MAGE = { .41, .80, .94 }, ROGUE = { 1, .96, .41 },
  DRUID = { 1, .49, .04 }, HUNTER = { .67, .83, .45 }, SHAMAN = { .14, .35, 1 },
  PRIEST = { 1, 1, 1 }, WARLOCK = { .58, .51, .79 }, PALADIN = { .96, .55, .73 },
}

local function LayoutFlag(key, defaultOn)
  if not QtUI.GetLayout then return defaultOn end
  local layout = QtUI:GetLayout()
  local value = layout and layout[key]
  if defaultOn then
    return value ~= false and value ~= 0 and value ~= "0"
  end
  return value == true or value == 1 or value == "1"
end

local function ClassColor(token)
  if type(RAID_CLASS_COLORS) == "table" and token and RAID_CLASS_COLORS[token] then
    local c = RAID_CLASS_COLORS[token]
    return c.r, c.g, c.b
  end
  local c = token and CLASS_RGB[token]
  if c then return c[1], c[2], c[3] end
  return 1, 1, 1
end

local function TooltipHasLine(text)
  if not GameTooltip or not GameTooltip.NumLines or not text then return nil end
  local i
  local last = GameTooltip:NumLines() or 0
  for i = 1, last do
    local line = getglobal("GameTooltipTextLeft" .. i)
    if line and line.GetText and line:GetText() == text then return true end
  end
  return nil
end

local function UnitFromFocus()
  if type(GetMouseFocus) ~= "function" then return nil end
  local ok, frame = pcall(GetMouseFocus)
  if not ok then return nil end
  local depth = 0
  while frame and depth < 12 do
    if frame.unit and type(UnitExists) == "function" then
      local exists = UnitExists(frame.unit)
      if exists == true or exists == 1 or exists == "1" then return frame.unit end
    end
    local name = frame.GetName and frame:GetName()
    if name then
      local _, _, partyPet = string.find(name, "^PartyMemberFrame([1-4])PetFrame")
      local _, _, party = string.find(name, "^PartyMemberFrame([1-4])")
      if partyPet then return "partypet" .. partyPet end
      if party then return "party" .. party end
      if string.find(name, "TargetofTarget", 1, true) or string.find(name, "TargetFrameToT", 1, true) then
        return "targettarget"
      end
      if string.find(name, "TargetFrame", 1, true) or string.find(name, "QtUITarget", 1, true) then
        if string.find(name, "targettarget", 1, true) then return "targettarget" end
        return "target"
      end
      if string.find(name, "PlayerFrame", 1, true) or string.find(name, "QtUIPlayer", 1, true) then
        return "player"
      end
      if string.find(name, "^PetFrame") then return "pet" end
    end
    frame = frame.GetParent and frame:GetParent()
    depth = depth + 1
  end
  return nil
end

local function AddPlayerClass(unit)
  if not LayoutFlag("classTooltip", true) then return end
  if not unit or not GameTooltip then return end
  if type(UnitExists) ~= "function" or type(UnitIsPlayer) ~= "function" then return end
  local okExists, exists = pcall(UnitExists, unit)
  if not okExists or not (exists == true or exists == 1 or exists == "1") then return end
  local okPlayer, isPlayer = pcall(UnitIsPlayer, unit)
  if not okPlayer or not (isPlayer == true or isPlayer == 1 or isPlayer == "1") then return end
  local className, classToken
  if type(UnitClass) == "function" then
    local ok, name, token = pcall(UnitClass, unit)
    if ok then
      className = name
      classToken = token
    end
  end
  if not className or className == "" then return end
  if TooltipHasLine(className) then return end
  local r, g, b = ClassColor(classToken)
  if GameTooltip.AddLine then GameTooltip:AddLine(className, r, g, b) end
  if GameTooltip.Show then pcall(GameTooltip.Show, GameTooltip) end
end

function QtUI:SetupClassTooltip()
  if self.classTooltipReady then return end
  self.classTooltipReady = true
  if not GameTooltip then return end
  local watch = CreateFrame("Frame", "QtUIClassTooltip", GameTooltip)
  watch.elapsed = 0
  local function TickClass()
    this.elapsed = this.elapsed + (arg1 or 0)
    if this.elapsed < .12 then return end
    this.elapsed = 0
    if not GameTooltip.IsVisible or not GameTooltip:IsVisible() then return end
    local unit = UnitFromFocus()
    if not unit and type(UnitExists) == "function" then
      local ok, exists = pcall(UnitExists, "mouseover")
      if ok and (exists == true or exists == 1 or exists == "1") then unit = "mouseover" end
    end
    AddPlayerClass(unit)
  end
  watch:SetScript("OnShow", function()
    this.elapsed = .12
    this:SetScript("OnUpdate", TickClass)
  end)
  watch:SetScript("OnHide", function()
    this:SetScript("OnUpdate", nil)
  end)
end
