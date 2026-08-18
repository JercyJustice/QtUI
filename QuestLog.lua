-- Opt-in Dragonflight quest-log parchment.
-- Emberveil ignores SetTexture on the original regions, so this draws our
-- own TGA overlays (same trick as the empty action-bar wells).

local MEDIA = "Interface\\AddOns\\QtUI\\Media\\"
local LEFT_TEX = MEDIA .. "questlog_left"
local RIGHT_TEX = MEDIA .. "questlog_right"
local CLOSE_NORMAL = MEDIA .. "close_normal"
local CLOSE_PUSHED = MEDIA .. "close_pushed"

local VANILLA_CLOSE_UP = "Interface\\Buttons\\UI-Panel-MinimizeButton-Up"
local VANILLA_CLOSE_DOWN = "Interface\\Buttons\\UI-Panel-MinimizeButton-Down"
local VANILLA_CLOSE_HIGHLIGHT = "Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight"

local hooked
local watching

local function ParkRegion(region)
  if not region then return end
  if region.SetTexture then pcall(region.SetTexture, region, nil) end
  if region.ClearAllPoints then
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -2000, 2000)
    region:SetPoint("BOTTOMRIGHT", UIParent, "TOPLEFT", -1999, 1999)
  end
  if region.SetAlpha then pcall(region.SetAlpha, region, 0) end
  if region.Hide then pcall(region.Hide, region) end
  if region.EnableMouse then pcall(region.EnableMouse, region, false) end
end

local function CollectRegions(frame)
  if not frame or type(frame.GetRegions) ~= "function" then return {} end
  local ok, packed = pcall(function()
    return { frame:GetRegions() }
  end)
  if ok and type(packed) == "table" then return packed end
  return {}
end

local function ParkVanillaArt(frame)
  local regions = CollectRegions(frame)
  local i
  for i = 1, table.getn(regions) do
    local region = regions[i]
    if region and region.GetObjectType then
      local ok, kind = pcall(region.GetObjectType, region)
      if ok and kind == "Texture" then
        local name = region.GetName and region:GetName()
        if not name or not string.find(string.lower(name), "portrait", 1, 1) then
          ParkRegion(region)
        end
      end
    end
  end
end

local function StyleCloseButton(close, frame, useDragonflight)
  if not close or not frame then return end
  if useDragonflight then
    if close.SetNormalTexture then close:SetNormalTexture(CLOSE_NORMAL) end
    if close.SetPushedTexture then close:SetPushedTexture(CLOSE_PUSHED) end
    if close.SetHighlightTexture then close:SetHighlightTexture(CLOSE_NORMAL) end
    close:ClearAllPoints()
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -28, -12)
    close:SetPoint("BOTTOMLEFT", frame, "TOPRIGHT", -45, -29)
  else
    if close.SetNormalTexture then close:SetNormalTexture(VANILLA_CLOSE_UP) end
    if close.SetPushedTexture then close:SetPushedTexture(VANILLA_CLOSE_DOWN) end
    if close.SetHighlightTexture then close:SetHighlightTexture(VANILLA_CLOSE_HIGHLIGHT) end
    close:ClearAllPoints()
    close:SetPoint("CENTER", frame, "TOPRIGHT", -44, -25)
  end
end

local function EnsureSkin(frame)
  local skin = frame.QtUIQuestSkin
  if not skin then
    skin = CreateFrame("Frame", "QtUIQuestLogSkin", frame)
    frame.QtUIQuestSkin = skin
    if skin.EnableMouse then skin:EnableMouse(false) end
    skin.left = skin:CreateTexture("QtUIQuestLogLeft", "BACKGROUND")
    skin.right = skin:CreateTexture("QtUIQuestLogRight", "BACKGROUND")
  end

  local parentLevel = 0
  if frame.GetFrameLevel then parentLevel = frame:GetFrameLevel() or 0 end
  -- One level above the frame's own BACKGROUND, still below list/buttons.
  if skin.SetFrameLevel then skin:SetFrameLevel(parentLevel + 1) end

  skin:ClearAllPoints()
  skin:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  skin:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)

  local width = 384
  if frame.GetWidth then width = frame:GetWidth() or 384 end
  if width < 200 then width = 384 end
  -- Vanilla split is 256+128. Keep that ratio so the DF tiles cover the chrome.
  local leftW = math.floor(width * 256 / 384)
  if leftW < 1 then leftW = 1 end

  skin.left:ClearAllPoints()
  skin.left:SetPoint("TOPLEFT", skin, "TOPLEFT", 0, 0)
  skin.left:SetPoint("BOTTOMRIGHT", skin, "BOTTOMLEFT", leftW, 0)
  skin.left:SetTexture(LEFT_TEX)

  skin.right:ClearAllPoints()
  skin.right:SetPoint("TOPLEFT", skin, "TOPLEFT", leftW, 0)
  skin.right:SetPoint("BOTTOMRIGHT", skin, "BOTTOMRIGHT", 0, 0)
  skin.right:SetTexture(RIGHT_TEX)

  if skin.left.Show then pcall(skin.left.Show, skin.left) end
  if skin.right.Show then pcall(skin.right.Show, skin.right) end
  if skin.Show then pcall(skin.Show, skin) end
  return skin, leftW
end

-- DF left tile punches a circular hole at the top-left. Emberveil also
-- leaves that socket empty, so the world shows through (the circled gap).
local function PlacePortrait(frame, leftW, height)
  local holder = frame.QtUIQuestPortraitHolder
  if not holder then
    holder = CreateFrame("Frame", "QtUIQuestLogPortraitHolder", frame)
    frame.QtUIQuestPortraitHolder = holder
    if holder.EnableMouse then holder:EnableMouse(false) end
    holder.art = holder:CreateTexture("QtUIQuestLogPortrait", "BACKGROUND")
    holder.art:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
    holder.art:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 0, 0)
  end

  local parentLevel = 0
  if frame.GetFrameLevel then parentLevel = frame:GetFrameLevel() or 0 end
  if holder.SetFrameLevel then holder:SetFrameLevel(parentLevel) end

  leftW = leftW or 256
  height = height or 512
  -- Hole in the 512² left tile is ~41,39 r36. Map that onto the stretched overlay.
  local cx = leftW * 41 / 512
  local cy = height * 39 / 512
  local radius = leftW * 48 / 512
  if radius < 36 then radius = 36 end

  holder:ClearAllPoints()
  holder:SetPoint("TOPLEFT", frame, "TOPLEFT", cx - radius, -(cy - radius))
  holder:SetPoint("BOTTOMRIGHT", frame, "TOPLEFT", cx + radius, -(cy + radius))

  if type(SetPortraitTexture) == "function" then
    pcall(SetPortraitTexture, holder.art, "player")
  end
  if holder.art.Show then pcall(holder.art.Show, holder.art) end
  if holder.Show then pcall(holder.Show, holder) end

  local native = getglobal("QuestLogFramePortrait")
  if native then
    native:ClearAllPoints()
    native:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
    native:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 0, 0)
    if type(SetPortraitTexture) == "function" then
      pcall(SetPortraitTexture, native, "player")
    end
    if native.Show then pcall(native.Show, native) end
  end
end

local function HideSkin(frame)
  local skin = frame and frame.QtUIQuestSkin
  if not skin then return end
  ParkRegion(skin.left)
  ParkRegion(skin.right)
  ParkRegion(skin)
  if frame.QtUIQuestPortraitHolder then
    ParkRegion(frame.QtUIQuestPortraitHolder.art)
    ParkRegion(frame.QtUIQuestPortraitHolder)
  end
end

function QtUI:RestoreQuestLogArt()
  local frame = getglobal("QuestLogFrame")
  if not frame then return end
  HideSkin(frame)
  StyleCloseButton(getglobal("QuestLogFrameCloseButton"), frame, nil)
end

function QtUI:ApplyQuestLogArt()
  local frame = getglobal("QuestLogFrame")
  if not frame then return end

  if not self:IsFeatureEnabled("questLog") then
    self:RestoreQuestLogArt()
    return
  end

  ParkVanillaArt(frame)
  local _, leftW = EnsureSkin(frame)
  local height = 512
  if frame.GetHeight then height = frame:GetHeight() or 512 end
  PlacePortrait(frame, leftW, height)
  StyleCloseButton(getglobal("QuestLogFrameCloseButton"), frame, true)
end

local function WatchForFrame()
  if watching then return end
  watching = true
  local watcher = CreateFrame("Frame", "QtUIQuestLogWatch")
  watcher.elapsed = 0
  watcher:SetScript("OnUpdate", function()
    this.elapsed = this.elapsed + (arg1 or 0)
    if getglobal("QuestLogFrame") then
      this:SetScript("OnUpdate", nil)
      if QtUI.SetupQuestLog then QtUI:SetupQuestLog() end
    elseif this.elapsed > 20 then
      this:SetScript("OnUpdate", nil)
    end
  end)
end

function QtUI:SetupQuestLog()
  local frame = getglobal("QuestLogFrame")
  if not frame then
    WatchForFrame()
    return
  end

  self:ApplyQuestLogArt()

  if hooked then return end
  hooked = true

  local prev
  if type(frame.GetScript) == "function" then
    prev = frame:GetScript("OnShow")
  end
  frame:SetScript("OnShow", function()
    if prev then pcall(prev) end
    if QtUI.ApplyQuestLogArt then QtUI:ApplyQuestLogArt() end
  end)

  if type(ToggleQuestLog) == "function" then
    local prevToggle = ToggleQuestLog
    ToggleQuestLog = function()
      prevToggle()
      if QtUI.ApplyQuestLogArt then QtUI:ApplyQuestLogArt() end
    end
  end

  local portraits = CreateFrame("Frame", "QtUIQuestLogPortraitEvents")
  portraits:RegisterEvent("UNIT_PORTRAIT_UPDATE")
  portraits:RegisterEvent("PLAYER_ENTERING_WORLD")
  portraits:SetScript("OnEvent", function()
    if arg1 and arg1 ~= "player" then return end
    if QtUI.ApplyQuestLogArt and QtUI:IsFeatureEnabled("questLog") then
      QtUI:ApplyQuestLogArt()
    end
  end)
end
