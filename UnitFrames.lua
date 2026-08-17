local classColors = {
  WARRIOR = { .78, .61, .43 }, MAGE = { .41, .80, .94 }, ROGUE = { 1, .96, .41 },
  DRUID = { 1, .49, .04 }, HUNTER = { .67, .83, .45 }, SHAMAN = { .14, .35, 1 },
  PRIEST = { 1, 1, 1 }, WARLOCK = { .58, .51, .79 }, PALADIN = { .96, .55, .73 },
}

local function ShortNumber(value)
  value = value or 0
  if value >= 1000000 then return string.format("%.1fm", value / 1000000) end
  if value >= 10000 then return string.format("%.1fk", value / 1000) end
  return tostring(value)
end

local function SetPowerColor(bar, unit)
  local power = UnitPowerType(unit)
  if power == 1 then
    bar:SetStatusBarColor(.75, .12, .12)
  elseif power == 3 then
    bar:SetStatusBarColor(.92, .76, .12)
  else
    bar:SetStatusBarColor(.12, .38, .82)
  end
end

local function IsLegacyTrue(value)
  return value == true or value == 1 or value == "1"
end

local function GetEnemyDifficultyBorder(targetLevel)
  targetLevel = tonumber(targetLevel) or 0
  if targetLevel == -1 then return .95, .08, .08, 1 end

  -- Emberveil exposes one of these Vanilla-era quest difficulty helpers. Use
  -- its level thresholds, but combine its yellow/orange bands into the orange
  -- requested for enemy frames.
  local difficulty = GetQuestDifficultyColor or GetDifficultyColor
  if type(difficulty) == "function" then
    local ok, color = pcall(difficulty, targetLevel)
    if ok and type(color) == "table" then
      local r = color.r or color[1] or 1
      local g = color.g or color[2] or 1
      if r >= .8 and g < .3 then return .95, .08, .08, 1 end
      if g > r then return .18, .72, .22, 1 end
      if r < .65 and g < .65 then return .42, .44, .46, 1 end
      return 1, .48, .06, 1
    end
  end

  local playerLevel = tonumber(UnitLevel("player")) or 0
  local difference = targetLevel - playerLevel
  if difference >= 5 then return .95, .08, .08, 1 end
  if difference >= -2 then return 1, .48, .06, 1 end

  local greenRange
  if playerLevel <= 5 then
    greenRange = 0
  elseif playerLevel <= 39 then
    greenRange = math.floor(playerLevel / 10) + 5
  else
    greenRange = 9
  end
  if targetLevel <= playerLevel - greenRange then return .42, .44, .46, 1 end
  return .18, .72, .22, 1
end

PotatoUI.classColors = classColors
PotatoUI.ShortNumber = ShortNumber
PotatoUI.SetPowerColor = SetPowerColor

local function HandleUnitClick()
  local unit = this.unit
  if arg1 == "LeftButton" then
    if type(TargetUnit) == "function" then TargetUnit(unit) end
    return
  end

  if arg1 ~= "RightButton" or type(ToggleDropDownMenu) ~= "function" then return end

  local dropdown
  if unit == "player" then
    dropdown = PlayerFrameDropDown
  else
    dropdown = TargetFrameDropDown
  end

  if dropdown then
    dropdown.unit = unit
    dropdown.name = UnitName(unit)
    ToggleDropDownMenu(1, nil, dropdown, "cursor", 0, 0)
  end
end

local function CreateUnitFrame(name, unit, x)
  local frame = PotatoUI:CreatePanel(name, UIParent, 3)
  frame.unit = unit
  frame:SetWidth(260)
  frame:SetHeight(54)
  frame:SetPoint("BOTTOM", UIParent, "BOTTOM", x, 120)
  frame:SetFrameStrata("MEDIUM")

  frame.health = CreateFrame("StatusBar", nil, frame)
  frame.health:SetStatusBarTexture(PotatoUI.media.statusbar)
  frame.health:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
  frame.health:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
  frame.health:SetHeight(28)

  frame.health.bg = frame.health:CreateTexture(nil, "BACKGROUND")
  frame.health.bg:SetAllPoints()
  frame.health.bg:SetTexture(PotatoUI.media.statusbar)
  frame.health.bg:SetVertexColor(.08, .08, .08, 1)

  frame.name = frame.health:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  frame.name:SetPoint("LEFT", frame.health, "LEFT", 6, 0)
  frame.name:SetJustifyH("LEFT")

  frame.classification = frame.health:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.classification:SetJustifyH("RIGHT")

  frame.healthText = frame.health:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.healthText:SetPoint("RIGHT", frame.health, "RIGHT", -6, 0)
  frame.healthText:SetJustifyH("RIGHT")
  frame.classification:SetPoint("RIGHT", frame.healthText, "LEFT", -6, 0)

  frame.power = CreateFrame("StatusBar", nil, frame)
  frame.power:SetStatusBarTexture(PotatoUI.media.statusbar)
  frame.power:SetPoint("TOPLEFT", frame.health, "BOTTOMLEFT", 0, -3)
  frame.power:SetPoint("TOPRIGHT", frame.health, "BOTTOMRIGHT", 0, -3)
  frame.power:SetHeight(13)

  frame.power.bg = frame.power:CreateTexture(nil, "BACKGROUND")
  frame.power.bg:SetAllPoints()
  frame.power.bg:SetTexture(PotatoUI.media.statusbar)
  frame.power.bg:SetVertexColor(.05, .06, .08, 1)

  frame.powerText = frame.power:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.powerText:SetPoint("RIGHT", frame.power, "RIGHT", -5, 0)

  -- The visual frame is deliberately non-secure for original 1.12 clients;
  -- this transparent child restores normal player/target click behaviour.
  frame.click = CreateFrame("Button", name .. "Click", frame)
  frame.click:SetAllPoints(frame)
  frame.click:SetFrameLevel(frame:GetFrameLevel() + 5)
  frame.click.unit = unit
  frame.click:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  frame.click:SetScript("OnClick", HandleUnitClick)
  frame.click:SetScript("OnEnter", function()
    if this.unit == "target" and UnitName("target") and GameTooltip.SetUnit then
      GameTooltip:SetOwner(this, "ANCHOR_TOP")
      GameTooltip:SetUnit("target")
      GameTooltip:Show()
    end
  end)
  frame.click:SetScript("OnLeave", function() GameTooltip:Hide() end)

  if unit == "target" and PotatoUI:IsFeatureEnabled("auras") then
    frame.debuffs = PotatoUI:CreateAuraRow(frame, unit, "DEBUFF", 10, 20)
    frame.debuffs:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 2, 4)

    frame.buffs = PotatoUI:CreateAuraRow(frame, unit, "BUFF", 10, 20)
    frame.buffs:SetPoint("BOTTOMLEFT", frame.debuffs, "TOPLEFT", 0, 3)
  end

  return frame
end

local function UpdateUnitFrame(frame)
  local unit = frame.unit
  if unit == "target" and not UnitName("target") then
    frame:Hide()
    return
  end
  frame:Show()

  local health = UnitHealth(unit) or 0
  local healthMax = UnitHealthMax(unit) or 1
  local power = UnitMana(unit) or 0
  local powerMax = UnitManaMax(unit) or 1
  if healthMax < 1 then healthMax = 1 end
  if powerMax < 1 then powerMax = 1 end

  frame.health:SetMinMaxValues(0, healthMax)
  frame.health:SetValue(health)
  frame.power:SetMinMaxValues(0, powerMax)
  frame.power:SetValue(power)
  SetPowerColor(frame.power, unit)

  local name = UnitName(unit) or "Unknown"
  local level = UnitLevel(unit) or 0
  frame.name:SetText((level > 0 and level .. " " or "") .. name)
  frame.healthText:SetText(ShortNumber(health) .. " / " .. ShortNumber(healthMax))
  frame.powerText:SetText(ShortNumber(power) .. " / " .. ShortNumber(powerMax))

  if unit == "target" and type(UnitClassification) == "function" then
    local classification = UnitClassification(unit)
    if classification == "worldboss" then
      frame.classification:SetText("|cffff4040BOSS|r")
    elseif classification == "rareelite" then
      frame.classification:SetText("|cffff66ffRARE ELITE|r")
    elseif classification == "elite" then
      frame.classification:SetText("|cffffcc00ELITE|r")
    elseif classification == "rare" then
      frame.classification:SetText("|cff66ccffRARE|r")
    else
      frame.classification:SetText("")
    end
  else
    frame.classification:SetText("")
  end

  local isEnemy = IsLegacyTrue(UnitIsEnemy("player", unit))
  local isFriend = IsLegacyTrue(UnitIsFriend("player", unit))

  if unit == "player" then
    local _, class = UnitClass(unit)
    local color = classColors[class] or { .2, .75, .25 }
    frame.health:SetStatusBarColor(color[1], color[2], color[3])
  elseif isEnemy then
    frame.health:SetStatusBarColor(.78, .12, .12)
  elseif isFriend then
    frame.health:SetStatusBarColor(.15, .72, .22)
  else
    frame.health:SetStatusBarColor(.82, .68, .16)
  end

  if unit == "target" then
    local attackable = isEnemy
    if not attackable and type(UnitCanAttack) == "function" then
      local ok, value = pcall(UnitCanAttack, "player", unit)
      attackable = ok and IsLegacyTrue(value)
    end
    if attackable then
      frame:SetBackdropBorderColor(GetEnemyDifficultyBorder(level))
    else
      frame:SetBackdropBorderColor(.18, .24, .28, 1)
    end
  end

  if unit == "target" and frame.debuffs then
    PotatoUI:UpdateAuraRow(frame.debuffs)
    PotatoUI:UpdateAuraRow(frame.buffs)
  end
end

local function SetPlayerCombatOutline(inCombat)
  local frame = PotatoUI.playerFrame
  if not frame then return end
  if inCombat then
    frame:SetBackdropBorderColor(.95, .08, .08, 1)
  else
    frame:SetBackdropBorderColor(.18, .24, .28, 1)
  end
end

local function PlayerIsInCombat()
  if type(UnitAffectingCombat) ~= "function" then return nil end
  local ok, value = pcall(UnitAffectingCombat, "player")
  if not ok then return nil end
  return value == true or value == 1 or value == "1"
end

local function UpdateComboPoints()
  local frame = PotatoUI.comboFrame
  if not frame then return end

  local _, class = UnitClass("player")
  local isRogue = class == "ROGUE"
  local isCatDruid = class == "DRUID" and UnitPowerType("player") == 3
  if not isRogue and not isCatDruid then
    frame:Hide()
    return
  end

  local count = 0
  if type(GetComboPoints) == "function" then
    local ok, value = pcall(GetComboPoints)
    if not ok then ok, value = pcall(GetComboPoints, "player", "target") end
    if ok then count = tonumber(value) or 0 end
  end
  local i
  for i = 1, 5 do
    if i <= count then
      frame.points[i]:SetVertexColor(1, .42, .08, 1)
    else
      frame.points[i]:SetVertexColor(.08, .09, .1, .92)
    end
  end
  frame:Show()
end

function PotatoUI:SetupComboPoints()
  self:HideFrame(ComboFrame)

  local frame = self:CreatePanel("PotatoUIComboPoints", UIParent,
    self.playerFrame:GetFrameLevel() + 2)
  frame:SetFrameStrata("MEDIUM")
  frame:SetWidth(96)
  frame:SetHeight(22)
  frame:SetPoint("RIGHT", self.playerFrame, "LEFT", -8, 0)
  frame:SetBackdropColor(.015, .02, .025, .76)
  frame.points = {}

  local i
  for i = 1, 5 do
    local slot = CreateFrame("Frame", nil, frame)
    slot:SetWidth(15)
    slot:SetHeight(14)
    slot:SetPoint("LEFT", frame, "LEFT", 6 + (i - 1) * 17, 0)
    slot.fill = slot:CreateTexture(nil, "ARTWORK")
    slot.fill:SetAllPoints(slot)
    slot.fill:SetTexture("Interface\\Buttons\\WHITE8X8")
    frame.points[i] = slot.fill
  end

  local events = CreateFrame("Frame", "PotatoUIComboEvents")
  events:RegisterEvent("PLAYER_COMBO_POINTS")
  events:RegisterEvent("PLAYER_TARGET_CHANGED")
  events:RegisterEvent("UNIT_DISPLAYPOWER")
  events:RegisterEvent("PLAYER_ENTERING_WORLD")
  events:SetScript("OnEvent", UpdateComboPoints)

  self.comboFrame = frame
  self.comboEvents = events
  UpdateComboPoints()
end

function PotatoUI:UpdateUnitFrames()
  if self.playerFrame then UpdateUnitFrame(self.playerFrame) end
  if self.targetFrame then UpdateUnitFrame(self.targetFrame) end
end

function PotatoUI:SetupUnitFrames()
  self:HideFrame(PlayerFrame)
  self:HideFrame(TargetFrame)

  self.playerFrame = CreateUnitFrame("PotatoUIPlayerFrame", "player", -133)
  self.targetFrame = CreateUnitFrame("PotatoUITargetFrame", "target", 133)
  self:SetupComboPoints()
  if self.PositionAuxiliaryBars then self:PositionAuxiliaryBars() end

  local events = CreateFrame("Frame", "PotatoUIUnitEvents")
  events:RegisterEvent("PLAYER_TARGET_CHANGED")
  events:RegisterEvent("UNIT_HEALTH")
  events:RegisterEvent("UNIT_MAXHEALTH")
  events:RegisterEvent("UNIT_MANA")
  events:RegisterEvent("UNIT_MAXMANA")
  events:RegisterEvent("UNIT_DISPLAYPOWER")
  events:RegisterEvent("UNIT_AURA")
  events:RegisterEvent("UNIT_LEVEL")
  events:RegisterEvent("UNIT_NAME_UPDATE")
  events:RegisterEvent("PLAYER_ENTERING_WORLD")
  pcall(events.RegisterEvent, events, "PLAYER_ENTER_COMBAT")
  pcall(events.RegisterEvent, events, "PLAYER_LEAVE_COMBAT")
  pcall(events.RegisterEvent, events, "PLAYER_REGEN_DISABLED")
  pcall(events.RegisterEvent, events, "PLAYER_REGEN_ENABLED")
  events:SetScript("OnEvent", function()
    if event == "PLAYER_REGEN_DISABLED" then
      this.combatLocked = true
      SetPlayerCombatOutline(true)
    elseif event == "PLAYER_REGEN_ENABLED" then
      this.combatLocked = nil
      SetPlayerCombatOutline(false)
    elseif event == "PLAYER_ENTER_COMBAT" then
      SetPlayerCombatOutline(true)
    elseif event == "PLAYER_LEAVE_COMBAT" then
      -- PLAYER_LEAVE_COMBAT can mean only that auto-attack stopped. Keep the
      -- outline while the actual combat-lockdown state remains active.
      SetPlayerCombatOutline(this.combatLocked or PlayerIsInCombat())
    elseif event == "PLAYER_ENTERING_WORLD" then
      SetPlayerCombatOutline(PlayerIsInCombat())
    end
    if event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_ENTERING_WORLD" or arg1 == "player" or arg1 == "target" then
      PotatoUI:UpdateUnitFrames()
    end
  end)

  SetPlayerCombatOutline(PlayerIsInCombat())
  self:UpdateUnitFrames()
end
