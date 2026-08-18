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

function QtUI:PaintStatusBar(bar, r, g, b)
  if not bar then return end
  r = tonumber(r) or 1
  g = tonumber(g) or 1
  b = tonumber(b) or 1

  local enabled
  if self.GetLayout then
    local layout = self:GetLayout()
    local flag = layout and layout.unitGradient
    enabled = flag == true or flag == 1 or flag == "1"
  end

  local stamp = (enabled and "1" or "0") .. ":" .. r .. ":" .. g .. ":" .. b
  if bar.QtUIPaintStamp == stamp then return end
  bar.QtUIPaintStamp = stamp

  -- Re-stamp the fill so a previous SetGradient cannot stick around.
  if bar.SetStatusBarTexture then
    bar:SetStatusBarTexture(self.media.statusbar)
  end
  bar:SetStatusBarColor(r, g, b)

  local tex = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
  if tex then
    if enabled and tex.SetGradient then
      pcall(tex.SetGradient, tex, "VERTICAL", r * .38, g * .38, b * .38, r, g, b)
    else
      if tex.SetGradient then pcall(tex.SetGradient, tex, "VERTICAL", r, g, b, r, g, b) end
      if tex.SetVertexColor then pcall(tex.SetVertexColor, tex, r, g, b, 1) end
    end
  end

  if not bar.QtUIGradient then
    local shine = bar:CreateTexture(nil, "ARTWORK")
    shine:SetAllPoints(bar)
    if shine.SetBlendMode then pcall(shine.SetBlendMode, shine, "ADD") end
    bar.QtUIGradient = shine
  end
  local shine = bar.QtUIGradient
  if shine then
    if enabled then
      shine:SetTexture("Interface\\Buttons\\WHITE8X8")
      if shine.SetGradientAlpha then
        pcall(shine.SetGradientAlpha, shine, "VERTICAL", 1, 1, 1, .28, 0, 0, 0, 0)
      elseif shine.SetGradient then
        pcall(shine.SetGradient, shine, "VERTICAL", .42, .42, .42, 0, 0, 0)
      end
      if shine.SetAlpha then pcall(shine.SetAlpha, shine, 1) end
      if shine.Show then pcall(shine.Show, shine) end
    else
      -- Hide() is ignored on Emberveil. Clear the texture and alpha instead.
      if shine.SetTexture then shine:SetTexture(nil) end
      if shine.SetAlpha then pcall(shine.SetAlpha, shine, 0) end
      if shine.Hide then pcall(shine.Hide, shine) end
    end
  end
end

local function SetPowerColor(bar, unit)
  local power = UnitPowerType(unit)
  if power == 1 then
    QtUI:PaintStatusBar(bar, .75, .12, .12)
  elseif power == 3 then
    QtUI:PaintStatusBar(bar, .92, .76, .12)
  else
    QtUI:PaintStatusBar(bar, .12, .38, .82)
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

QtUI.classColors = classColors
QtUI.ShortNumber = ShortNumber
QtUI.SetPowerColor = SetPowerColor

local TEXT_ALIGN = {
  left = { "LEFT", "LEFT", 6, 0, "LEFT", "MIDDLE" },
  right = { "RIGHT", "RIGHT", -6, 0, "RIGHT", "MIDDLE" },
  top = { "TOP", "TOP", 0, -2, "CENTER", "TOP" },
  bottom = { "BOTTOM", "BOTTOM", 0, 2, "CENTER", "BOTTOM" },
  center = { "CENTER", "CENTER", 0, 0, "CENTER", "MIDDLE" },
  topleft = { "TOPLEFT", "TOPLEFT", 6, -2, "LEFT", "TOP" },
  topright = { "TOPRIGHT", "TOPRIGHT", -6, -2, "RIGHT", "TOP" },
  bottomleft = { "BOTTOMLEFT", "BOTTOMLEFT", 6, 2, "LEFT", "BOTTOM" },
  bottomright = { "BOTTOMRIGHT", "BOTTOMRIGHT", -6, 2, "RIGHT", "BOTTOM" },
}

function QtUI:PlaceUnitText(fontString, parent, align)
  if not fontString or not parent then return end
  local spec = TEXT_ALIGN[align] or TEXT_ALIGN.left
  fontString:ClearAllPoints()
  fontString:SetPoint(spec[1], parent, spec[2], spec[3], spec[4])
  if fontString.SetJustifyH then fontString:SetJustifyH(spec[5]) end
  if fontString.SetJustifyV then fontString:SetJustifyV(spec[6]) end
end

function QtUI:ApplyUnitTexts(frame, style)
  if not frame or not style then return end
  if frame.name then self:PlaceUnitText(frame.name, frame.health, style.nameAlign) end
  if frame.healthText then self:PlaceUnitText(frame.healthText, frame.health, style.healthAlign) end
  if frame.powerText and frame.power then
    self:PlaceUnitText(frame.powerText, frame.power, style.powerAlign)
  end
  if frame.classification then
    self:PlaceUnitText(frame.classification, frame.health, style.classAlign or "top")
  end
end

function QtUI:EnsurePortrait(frame)
  if not frame then return nil end
  if frame.portrait then return frame.portrait end
  local port = CreateFrame("Frame", nil, frame)
  local level = 3
  if frame.GetFrameLevel then level = (frame:GetFrameLevel() or 3) + 2 end
  if port.SetFrameLevel then port:SetFrameLevel(level) end
  if port.EnableMouse then port:EnableMouse(false) end
  -- Light well so Emberveil's dim SetPortraitTexture is not lost on dark chrome.
  port.well = port:CreateTexture(nil, "BACKGROUND")
  port.well:SetPoint("TOPLEFT", port, "TOPLEFT", 0, 0)
  port.well:SetPoint("BOTTOMRIGHT", port, "BOTTOMRIGHT", 0, 0)
  port.well:SetTexture("Interface\\Buttons\\WHITE8X8")
  if port.well.SetVertexColor then port.well:SetVertexColor(.18, .2, .22, 1) end
  port.tex = port:CreateTexture(nil, "OVERLAY")
  port.tex:SetPoint("TOPLEFT", port, "TOPLEFT", 1, -1)
  port.tex:SetPoint("BOTTOMRIGHT", port, "BOTTOMRIGHT", -1, 1)
  -- Zoom into the circular SetPortraitTexture so the face fills the square.
  if port.tex.SetTexCoord then port.tex:SetTexCoord(.18, .82, .14, .86) end
  if port.tex.SetVertexColor then port.tex:SetVertexColor(1, 1, 1, 1) end
  frame.portrait = port
  return port
end

function QtUI:UpdatePortrait(frame)
  if not frame then return end
  local port = frame.portrait
  if not frame.portraitOn then
    if port then
      if port.tex and port.tex.SetTexture then port.tex:SetTexture(nil) end
      port:ClearAllPoints()
      port:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -2000, 2000)
      port:SetPoint("BOTTOMRIGHT", UIParent, "TOPLEFT", -1960, 1960)
      if port.Hide then pcall(port.Hide, port) end
    end
    return
  end
  port = self:EnsurePortrait(frame)
  if type(SetPortraitTexture) == "function" and frame.unit and port.tex then
    pcall(SetPortraitTexture, port.tex, frame.unit)
    if port.tex.SetTexCoord then port.tex:SetTexCoord(.18, .82, .14, .86) end
    if port.tex.SetVertexColor then port.tex:SetVertexColor(1, 1, 1, 1) end
    if port.tex.SetDesaturated then pcall(port.tex.SetDesaturated, port.tex, nil) end
    if port.tex.Show then pcall(port.tex.Show, port.tex) end
  end
  if port.well and port.well.Show then pcall(port.well.Show, port.well) end
  if port.Show then pcall(port.Show, port) end
end

function QtUI:ApplyUnitBarSizes(frame, style)
  if not frame or not style then return end
  local pad = 4
  local gap = 3
  local width = style.width or 260
  local height = style.height or 54
  local portraitOn = style.portrait == true
  frame.portraitOn = portraitOn
  local portraitSize = height - 4
  if portraitSize < 20 then portraitSize = 20 end
  local leftPad = pad
  if portraitOn then
    leftPad = pad + portraitSize + 3
    if frame.SetWidth then frame:SetWidth(width + portraitSize + 3) end
  else
    if frame.SetWidth then frame:SetWidth(width) end
  end
  frame:SetHeight(height)

  if portraitOn then
    local port = self:EnsurePortrait(frame)
    port:ClearAllPoints()
    port:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
    port:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 2, 2)
    port:SetPoint("TOPRIGHT", frame, "TOPLEFT", 2 + portraitSize, -2)
    if port.Show then pcall(port.Show, port) end
    self:UpdatePortrait(frame)
  else
    self:UpdatePortrait(frame)
  end

  if not frame.health then return end
  if frame.power and style.powerHeight then
    local powerH = style.powerHeight or 13
    local healthH = height - pad * 2 - powerH - gap
    if healthH < 14 then healthH = 14 end
    frame.health:ClearAllPoints()
    frame.health:SetPoint("TOPLEFT", frame, "TOPLEFT", leftPad, -pad)
    frame.health:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -pad, -pad)
    frame.health:SetHeight(healthH)
    frame.power:ClearAllPoints()
    frame.power:SetPoint("TOPLEFT", frame.health, "BOTTOMLEFT", 0, -gap)
    frame.power:SetPoint("TOPRIGHT", frame.health, "BOTTOMRIGHT", 0, -gap)
    frame.power:SetHeight(powerH)
  else
    frame.health:ClearAllPoints()
    frame.health:SetPoint("TOPLEFT", frame, "TOPLEFT", leftPad, -pad)
    frame.health:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -pad, pad)
  end
end

local function HandleUnitClick()
  local unit = this.unit
  if this.qtUsedPending then
    this.qtUsedPending = nil
    return
  end
  if QtUI:UsePendingActionOnUnit(unit) then return end

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

local RAID_ICON_TEX = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"

local function RaidIconCoords(index)
  index = (tonumber(index) or 1) - 1
  if index < 0 then index = 0 end
  if index > 7 then index = 7 end
  local col = math.mod(index, 4)
  local row = math.floor(index / 4)
  return col * .25, (col + 1) * .25, row * .25, (row + 1) * .25
end

function QtUI:UpdateRaidIcon(frame)
  if not frame then return end
  local holder = frame.raidIconHolder
  if not holder then
    local parent = frame.click or frame
    holder = CreateFrame("Frame", nil, parent)
    if holder.EnableMouse then holder:EnableMouse(false) end
    local level = 6
    if parent.GetFrameLevel then level = (parent:GetFrameLevel() or 5) + 1 end
    if holder.SetFrameLevel then holder:SetFrameLevel(level) end
    holder.icon = holder:CreateTexture(nil, "OVERLAY")
    holder.icon:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
    holder.icon:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 0, 0)
    frame.raidIconHolder = holder
  end

  local index
  if frame.unit and type(GetRaidTargetIndex) == "function" then
    local ok, value = pcall(GetRaidTargetIndex, frame.unit)
    if ok then index = tonumber(value) end
  end

  if index and index >= 1 and index <= 8 then
    holder:ClearAllPoints()
    holder:SetPoint("TOPLEFT", frame, "TOPRIGHT", -20, 10)
    holder:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 4, -14)
    local icon = holder.icon
    if icon.SetTexture then icon:SetTexture(RAID_ICON_TEX) end
    if type(SetRaidTargetIconTexture) == "function" then
      pcall(SetRaidTargetIconTexture, icon, index)
    else
      icon:SetTexCoord(RaidIconCoords(index))
    end
    if icon.SetAlpha then icon:SetAlpha(1) end
    if icon.Show then pcall(icon.Show, icon) end
    if holder.Show then pcall(holder.Show, holder) end
  else
    local icon = holder.icon
    if icon and icon.SetTexture then icon:SetTexture(nil) end
    if icon and icon.SetAlpha then icon:SetAlpha(0) end
    if icon and icon.Hide then pcall(icon.Hide, icon) end
    holder:ClearAllPoints()
    holder:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -2000, 2000)
    holder:SetPoint("BOTTOMRIGHT", UIParent, "TOPLEFT", -1976, 1976)
    if holder.Hide then pcall(holder.Hide, holder) end
  end
end

local function HandleUnitMouseUp()
  if QtUI:UsePendingActionOnUnit(this.unit) then
    this.qtUsedPending = true
  end
end

local function CreateUnitFrame(name, unit, x, opts)
  local frame = QtUI:CreatePanel(name, UIParent, 3)
  frame.unit = unit
  local layout = QtUI:GetLayout()
  frame:SetWidth(layout.unitWidth or 260)
  frame:SetHeight(layout.unitHeight or 54)
  frame:SetPoint("BOTTOM", UIParent, "BOTTOM", x, 120)
  frame:SetFrameStrata("MEDIUM")

  frame.health = CreateFrame("StatusBar", nil, frame)
  frame.health:SetStatusBarTexture(QtUI.media.statusbar)
  frame.health:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
  frame.health:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
  frame.health:SetHeight(28)

  frame.health.bg = frame.health:CreateTexture(nil, "BACKGROUND")
  frame.health.bg:SetAllPoints()
  frame.health.bg:SetTexture(QtUI.media.statusbar)
  frame.health.bg:SetVertexColor(.08, .08, .08, 1)

  frame.name = frame.health:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  frame.name:SetPoint("LEFT", frame.health, "LEFT", 6, 0)
  frame.name:SetJustifyH("LEFT")

  frame.classification = frame.health:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.classification:SetJustifyH("RIGHT")

  frame.healthText = frame.health:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.healthText:SetPoint("RIGHT", frame.health, "RIGHT", -6, 0)
  frame.healthText:SetJustifyH("RIGHT")
  frame.classification:SetPoint("TOP", frame.health, "TOP", 0, -2)

  frame.power = CreateFrame("StatusBar", nil, frame)
  frame.power:SetStatusBarTexture(QtUI.media.statusbar)
  frame.power:SetPoint("TOPLEFT", frame.health, "BOTTOMLEFT", 0, -3)
  frame.power:SetPoint("TOPRIGHT", frame.health, "BOTTOMRIGHT", 0, -3)
  frame.power:SetHeight(13)

  frame.power.bg = frame.power:CreateTexture(nil, "BACKGROUND")
  frame.power.bg:SetAllPoints()
  frame.power.bg:SetTexture(QtUI.media.statusbar)
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
  frame.click:SetScript("OnMouseUp", HandleUnitMouseUp)
  frame.click:SetScript("OnClick", HandleUnitClick)
  frame.click:SetScript("OnEnter", function()
    if this.unit == "target" and UnitName("target") and GameTooltip.SetUnit then
      GameTooltip:SetOwner(this, "ANCHOR_TOP")
      GameTooltip:SetUnit("target")
      GameTooltip:Show()
    end
  end)
  frame.click:SetScript("OnLeave", function() GameTooltip:Hide() end)

  if (not opts or not opts.noAuras) and QtUI:IsFeatureEnabled("auras") then
    local auraCount = 10
    if unit == "player" then auraCount = 16 end
    frame.debuffs = QtUI:CreateAuraRow(frame, unit, "DEBUFF", auraCount, 20)
    frame.debuffs:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 2, 4)

    frame.buffs = QtUI:CreateAuraRow(frame, unit, "BUFF", auraCount, 20)
    frame.buffs:SetPoint("BOTTOMLEFT", frame.debuffs, "TOPLEFT", 0, 3)
  end

  return frame
end

local function UpdateUnitFrame(frame, skipAuras)
  local unit = frame.unit
  if (unit == "target" or unit == "targettarget") and not UnitName(unit) then
    frame:Hide()
    if QtUI.UpdateRaidIcon then QtUI:UpdateRaidIcon(frame) end
    if QtUI.UpdatePortrait then QtUI:UpdatePortrait(frame) end
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

  local layout = QtUI:GetLayout()
  if unit == "player" then
    if layout.playerClassColor then
      local _, class = UnitClass(unit)
      local color = classColors[class] or { .2, .75, .25 }
      QtUI:PaintStatusBar(frame.health, color[1], color[2], color[3])
    else
      local c = layout.playerHealth
      QtUI:PaintStatusBar(frame.health, c.r, c.g, c.b)
    end
  elseif isEnemy then
    local c = layout.enemyHealth
    QtUI:PaintStatusBar(frame.health, c.r, c.g, c.b)
  elseif isFriend then
    local c = layout.friendHealth
    QtUI:PaintStatusBar(frame.health, c.r, c.g, c.b)
  else
    local c = layout.neutralHealth
    QtUI:PaintStatusBar(frame.health, c.r, c.g, c.b)
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

  if not skipAuras and frame.debuffs then
    QtUI:UpdateAuraRow(frame.debuffs)
    QtUI:UpdateAuraRow(frame.buffs)
  end
  if QtUI.UpdateRaidIcon then QtUI:UpdateRaidIcon(frame) end
  if QtUI.UpdatePortrait then QtUI:UpdatePortrait(frame) end
end

local function SetPlayerCombatOutline(inCombat)
  local frame = QtUI.playerFrame
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

local function ComboSettings()
  local layout = QtUI:GetLayout()
  local size = tonumber(layout.comboPointSize) or 15
  if size < 8 then size = 8 end
  if size > 28 then size = 28 end
  local spacing = tonumber(layout.comboSpacing)
  if spacing == nil then spacing = 2 end
  if spacing < 0 then spacing = 0 end
  if spacing > 12 then spacing = 12 end
  local color = layout.comboColor or { r = 1, g = .42, b = .08 }
  local showBg = layout.comboShowBackground
  if showBg == false or showBg == 0 or showBg == "0" then
    showBg = nil
  else
    showBg = true
  end
  return size, spacing, color, showBg
end

local function UpdateComboPoints()
  local frame = QtUI.comboFrame
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
  local _, _, color = ComboSettings()
  local r = color.r or 1
  local g = color.g or .42
  local b = color.b or .08
  local i
  for i = 1, 5 do
    if i <= count then
      frame.points[i]:SetVertexColor(r, g, b, 1)
    else
      frame.points[i]:SetVertexColor(.08, .09, .1, .92)
    end
  end
  frame:Show()
end

function QtUI:ApplyComboLayout()
  local frame = self.comboFrame
  if not frame then return end
  local size, spacing, _, showBg = ComboSettings()
  local pad = 4
  local width = pad * 2 + size * 5 + spacing * 4
  local height = pad * 2 + size
  if frame.SetWidth then frame:SetWidth(width) end
  if frame.SetHeight then frame:SetHeight(height) end

  local i
  for i = 1, 5 do
    local slot = frame.slots and frame.slots[i]
    if slot then
      local x = pad + (i - 1) * (size + spacing)
      slot:ClearAllPoints()
      slot:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -pad)
      slot:SetPoint("BOTTOMRIGHT", frame, "TOPLEFT", x + size, -pad - size)
    end
  end

  if showBg then
    frame:SetBackdropColor(.015, .02, .025, .76)
    frame:SetBackdropBorderColor(.18, .24, .28, 1)
  else
    frame:SetBackdropColor(0, 0, 0, 0)
    frame:SetBackdropBorderColor(0, 0, 0, 0)
  end
  UpdateComboPoints()
end

function QtUI:SetupComboPoints()
  self:HideFrame(ComboFrame)

  local frame = self:CreatePanel("QtUIComboPoints", UIParent,
    self.playerFrame:GetFrameLevel() + 2)
  frame:SetFrameStrata("MEDIUM")
  frame:SetPoint("RIGHT", self.playerFrame, "LEFT", -8, 0)
  frame.points = {}
  frame.slots = {}

  local i
  for i = 1, 5 do
    local slot = CreateFrame("Frame", nil, frame)
    slot.fill = slot:CreateTexture(nil, "ARTWORK")
    slot.fill:SetPoint("TOPLEFT", slot, "TOPLEFT", 0, 0)
    slot.fill:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", 0, 0)
    slot.fill:SetTexture("Interface\\Buttons\\WHITE8X8")
    frame.slots[i] = slot
    frame.points[i] = slot.fill
  end

  local events = CreateFrame("Frame", "QtUIComboEvents")
  events:RegisterEvent("PLAYER_COMBO_POINTS")
  events:RegisterEvent("PLAYER_TARGET_CHANGED")
  events:RegisterEvent("UNIT_DISPLAYPOWER")
  events:RegisterEvent("PLAYER_ENTERING_WORLD")
  events:SetScript("OnEvent", UpdateComboPoints)

  self.comboFrame = frame
  self.comboEvents = events
  self:ApplyComboLayout()
end

function QtUI:ApplyUnitFrameLayout()
  local player = self:GetUnitStyle("player")
  local target = self:GetUnitStyle("target")
  local tot = self:GetUnitStyle("targettarget")
  if self.playerFrame then
    self:ApplyUnitBarSizes(self.playerFrame, player)
    self:ApplyUnitTexts(self.playerFrame, player)
  end
  if self.targetFrame then
    self:ApplyUnitBarSizes(self.targetFrame, target)
    self:ApplyUnitTexts(self.targetFrame, target)
  end
  if self.targetTargetFrame then
    local layout = self:GetLayout()
    local show = layout.showTargetTarget ~= false and layout.showTargetTarget ~= 0 and layout.showTargetTarget ~= "0"
    self:ApplyUnitBarSizes(self.targetTargetFrame, tot or { width = 180, height = 36, powerHeight = 8 })
    self:ApplyUnitTexts(self.targetTargetFrame, tot or { nameAlign = "left", healthAlign = "right", powerAlign = "right" })
    if not show then
      self.targetTargetFrame:Hide()
    end
  end
  if self.castBar and player then
    self.castBar:SetWidth(player.width or 260)
    if self.PlaceCastBar then self:PlaceCastBar() end
  end
  if self.RefreshEnergyTick then self:RefreshEnergyTick() end
  if self.ApplyComboLayout then self:ApplyComboLayout() end
end

function QtUI:UpdateUnitFrames(skipAuras)
  if self.playerFrame then UpdateUnitFrame(self.playerFrame, skipAuras) end
  if self.targetFrame then UpdateUnitFrame(self.targetFrame, skipAuras) end
  if self.targetTargetFrame then
    local layout = self:GetLayout()
    local show = layout.showTargetTarget ~= false and layout.showTargetTarget ~= 0 and layout.showTargetTarget ~= "0"
    if show then
      UpdateUnitFrame(self.targetTargetFrame, true)
    else
      self.targetTargetFrame:Hide()
    end
  end
end

local function EnergyTickWidth()
  local layout = QtUI:GetLayout()
  local width = tonumber(layout and layout.energyTickWidth) or 1
  if width < 1 then width = 1 end
  if width > 8 then width = 8 end
  return width
end

local function EnergyTickAlpha()
  local layout = QtUI:GetLayout()
  local alpha = tonumber(layout and layout.energyTickAlpha)
  if not alpha then alpha = .95 end
  if alpha < .1 then alpha = .1 end
  if alpha > 1 then alpha = 1 end
  return alpha
end

local function PaintEnergyTick(tick, alpha)
  local line = tick.line
  if not line then return end
  if not alpha then alpha = 0 end
  -- Emberveil ignores texture SetAlpha / SetVertexColor-alpha. Backdrop
  -- color is the same path as bar background opacity, which does work.
  if line.SetBackdropColor then
    line:SetBackdropColor(1, 1, 1, alpha)
  end
end

local function PlaceEnergyTick(tick, pos)
  local line = tick.line
  if not line then return end
  -- Emberveil ignores SetWidth(1) and keeps WHITE8X8 at 8x8. Stretch the
  -- column with corner anchors, same as the move-mode grid.
  local width = tick.lineWidth or EnergyTickWidth()
  line:ClearAllPoints()
  line:SetPoint("TOPLEFT", tick, "TOPLEFT", pos, 0)
  line:SetPoint("BOTTOMRIGHT", tick, "BOTTOMLEFT", pos + width, 0)
end

function QtUI:SetupEnergyTick()
  if self.energyTick or not self.playerFrame or not self.playerFrame.power then return end
  local bar = self.playerFrame.power
  local tick = CreateFrame("Frame", "QtUIEnergyTick", bar)
  tick:SetAllPoints(bar)
  local barLevel = 1
  if bar.GetFrameLevel then barLevel = bar:GetFrameLevel() or 1 end
  tick:SetFrameLevel(barLevel)
  if tick.EnableMouse then tick:EnableMouse(false) end

  local line = CreateFrame("Frame", nil, tick)
  if line.EnableMouse then line:EnableMouse(false) end
  if line.SetBackdrop then
    line:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
  end
  tick.line = line
  tick.lineWidth = EnergyTickWidth()
  PaintEnergyTick(tick, EnergyTickAlpha())
  PlaceEnergyTick(tick, 0)

  tick:RegisterEvent("PLAYER_ENTERING_WORLD")
  tick:RegisterEvent("UNIT_DISPLAYPOWER")
  tick:RegisterEvent("UNIT_ENERGY")
  tick:RegisterEvent("UNIT_MANA")
  tick:SetScript("OnEvent", function()
    QtUI:RefreshEnergyTick()
    if event == "PLAYER_ENTERING_WORLD" then
      this.lastPower = UnitMana("player")
    end
    if (event == "UNIT_MANA" or event == "UNIT_ENERGY") and arg1 == "player" then
      local current = UnitMana("player") or 0
      local diff = 0
      if this.lastPower then diff = current - this.lastPower end
      if this.mode == "MANA" and diff < 0 then
        this.target = 5
      elseif this.mode == "MANA" and diff > 0 then
        if this.max ~= 5 and diff > ((this.badtick and this.badtick * 1.2) or 5) then
          this.target = 2
        else
          this.badtick = diff
        end
      elseif this.mode == "ENERGY" and diff > 0 then
        this.target = 2
      end
      this.lastPower = current
    end
  end)
  tick:SetScript("OnUpdate", function()
    if not this.mode then return end
    if this.target then
      this.start = GetTime()
      this.max = this.target
      this.target = nil
    end
    if not this.start or not this.max or this.max <= 0 then return end
    local current = GetTime() - this.start
    if current > this.max then
      this.start = GetTime()
      this.max = 2
      current = 0
    end
    local width = this:GetWidth() or 0
    if width < 1 then return end
    this.lastPos = width * (current / this.max)
    PlaceEnergyTick(this, this.lastPos)
  end)

  self.energyTick = tick
  self:RefreshEnergyTick()
end

function QtUI:RefreshEnergyTick()
  local tick = self.energyTick
  if not tick then return end
  local layout = self:GetLayout()
  local enabled = layout.energyTick ~= false and layout.energyTick ~= 0 and layout.energyTick ~= "0"
  local powerType = 0
  if type(UnitPowerType) == "function" then
    powerType = tonumber(UnitPowerType("player")) or 0
  end
  if enabled and powerType == 0 then
    tick.mode = "MANA"
  elseif enabled and powerType == 3 then
    tick.mode = "ENERGY"
  else
    tick.mode = nil
  end
  tick.lineWidth = EnergyTickWidth()
  PlaceEnergyTick(tick, tick.lastPos or 0)
  if tick.mode then
    if tick.Show then pcall(tick.Show, tick) end
    if tick.line and tick.line.Show then pcall(tick.line.Show, tick.line) end
    PaintEnergyTick(tick, EnergyTickAlpha())
  else
    PaintEnergyTick(tick, 0)
  end
end

function QtUI:SetupTargetTarget()
  if self.targetTargetFrame then return end
  local frame = CreateUnitFrame("QtUITargetTargetFrame", "targettarget", 0, { noAuras = true })
  frame:ClearAllPoints()
  if self.targetFrame then
    frame:SetPoint("LEFT", self.targetFrame, "RIGHT", 8, 0)
  else
    frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 280, 120)
  end
  self.targetTargetFrame = frame
  local tot = self:GetUnitStyle("targettarget")
  if tot and self.ApplyUnitBarSizes then
    self:ApplyUnitBarSizes(frame, tot)
    if self.ApplyUnitTexts then self:ApplyUnitTexts(frame, tot) end
  else
    frame:SetWidth(180)
    frame:SetHeight(36)
    if frame.power then frame.power:SetHeight(8) end
  end
  if TargetofTargetFrame then self:HideFrame(TargetofTargetFrame) end

  if not self.targetTargetWatch then
    local watch = CreateFrame("Frame", "QtUITargetTargetWatch")
    watch.elapsed = 0
    watch:SetScript("OnUpdate", function()
      if not QtUI.targetTargetFrame then return end
      local layout = QtUI:GetLayout()
      if layout.showTargetTarget == false or layout.showTargetTarget == 0 or layout.showTargetTarget == "0" then
        QtUI.targetTargetFrame:Hide()
        return
      end
      this.elapsed = this.elapsed + (arg1 or 0)
      if not UnitName("target") then
        QtUI.targetTargetFrame:Hide()
        this.hadTarget = nil
        return
      end
      this.hadTarget = true
      if this.elapsed >= .2 then
        this.elapsed = 0
        UpdateUnitFrame(QtUI.targetTargetFrame, true)
      end
    end)
    self.targetTargetWatch = watch
  end
end

function QtUI:SetupUnitFrames()
  self.playerFrame = CreateUnitFrame("QtUIPlayerFrame", "player", -133)
  self.targetFrame = CreateUnitFrame("QtUITargetFrame", "target", 133)
  self:SetupComboPoints()
  self:SetupTargetTarget()
  self:SetupEnergyTick()
  if self.playerFrame then self:HideFrame(PlayerFrame) end
  if self.targetFrame then self:HideFrame(TargetFrame) end
  if self:IsFeatureEnabled("auras") then
    local buffFrame = BuffFrame
    if buffFrame then
      if buffFrame.EnableMouse then pcall(buffFrame.EnableMouse, buffFrame, false) end
      if buffFrame.SetAlpha then pcall(buffFrame.SetAlpha, buffFrame, 0) end
      if buffFrame.ClearAllPoints and buffFrame.SetPoint then
        pcall(function()
          buffFrame:ClearAllPoints()
          buffFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -4000, 4000)
        end)
      end
    end
  end
  if self.PositionAuxiliaryBars then self:PositionAuxiliaryBars() end
  self:ApplyUnitFrameLayout()

  local events = CreateFrame("Frame", "QtUIUnitEvents")
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
  pcall(events.RegisterEvent, events, "UNIT_PORTRAIT_UPDATE")
  pcall(events.RegisterEvent, events, "RAID_TARGET_UPDATE")
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
    if event == "RAID_TARGET_UPDATE" then
      QtUI:UpdateUnitFrames(true)
      if QtUI.UpdatePartyFrames then QtUI:UpdatePartyFrames(true) end
    elseif event == "UNIT_PORTRAIT_UPDATE" then
      if arg1 == "player" or arg1 == "target" or arg1 == "targettarget" or not arg1 then
        QtUI:UpdateUnitFrames(true)
      end
      if arg1 and string.find(arg1, "party", 1, true) and QtUI.UpdatePartyFrames then
        QtUI:UpdatePartyFrames(true)
      end
    elseif event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_ENTERING_WORLD" or arg1 == "player" or arg1 == "target" then
      local refreshAuras = event == "UNIT_AURA" or event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_ENTERING_WORLD"
      QtUI:UpdateUnitFrames(not refreshAuras)
    end
  end)

  SetPlayerCombatOutline(PlayerIsInCombat())
  self:UpdateUnitFrames()
end
