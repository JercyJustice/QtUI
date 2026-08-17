local function IsTrue(value)
  return value == true or value == 1 or value == "1"
end

local function UnitIsPresent(unit)
  if UnitName(unit) then return true end
  local exists = UnitExists(unit)
  return IsTrue(exists)
end

local function HandlePartyClick()
  local unit = this.unit
  if this.potatoUsedPending then
    this.potatoUsedPending = nil
    return
  end
  if PotatoUI:UsePendingActionOnUnit(unit) then return end

  if arg1 == "LeftButton" then
    if type(TargetUnit) == "function" then TargetUnit(unit) end
    return
  end

  if arg1 ~= "RightButton" then return end

  local dropdown
  if this.partyIndex then
    dropdown = getglobal("PartyMemberFrame" .. this.partyIndex .. "DropDown")
  elseif unit == "pet" then
    dropdown = PetFrameDropDown
  end

  if dropdown and type(ToggleDropDownMenu) == "function" then
    dropdown.unit = unit
    dropdown.name = UnitName(unit)
    ToggleDropDownMenu(1, nil, dropdown, "cursor", 0, 0)
  elseif type(TargetUnit) == "function" then
    TargetUnit(unit)
  end
end

local function HandlePartyMouseUp()
  if PotatoUI:UsePendingActionOnUnit(this.unit) then
    this.potatoUsedPending = true
  end
end

local function AddClickLayer(frame, unit, partyIndex)
  local click = CreateFrame("Button", frame:GetName() .. "Click", frame)
  click:SetAllPoints(frame)
  click:SetFrameLevel(frame:GetFrameLevel() + 5)
  click.unit = unit
  click.partyIndex = partyIndex
  click:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  click:SetScript("OnMouseUp", HandlePartyMouseUp)
  click:SetScript("OnClick", HandlePartyClick)
  click:SetScript("OnEnter", function()
    if UnitIsPresent(this.unit) and GameTooltip.SetUnit then
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      GameTooltip:SetUnit(this.unit)
      GameTooltip:Show()
    end
  end)
  click:SetScript("OnLeave", function() GameTooltip:Hide() end)
  frame.click = click
end

local function CreatePartyMember(index, parent)
  local unit = "party" .. index
  local frame = PotatoUI:CreatePanel("PotatoUIParty" .. index, parent, 3)
  frame.unit = unit
  frame.partyIndex = index
  frame:SetFrameStrata("LOW")
  local layout = PotatoUI:GetLayout()
  frame:SetWidth(layout.partyWidth or 220)
  frame:SetHeight(layout.partyHeight or 44)
  local gap = (layout.partyHeight or 44) + (layout.partySpacing or 29)
  frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(index - 1) * gap)
  frame:SetBackdropColor(.015, .02, .025, .72)

  frame.health = CreateFrame("StatusBar", nil, frame)
  frame.health:SetStatusBarTexture(PotatoUI.media.statusbar)
  frame.health:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
  frame.health:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
  frame.health:SetHeight(24)

  frame.health.bg = frame.health:CreateTexture(nil, "BACKGROUND")
  frame.health.bg:SetAllPoints()
  frame.health.bg:SetTexture(PotatoUI.media.statusbar)
  frame.health.bg:SetVertexColor(.06, .065, .07, 1)

  frame.name = frame.health:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  frame.name:SetPoint("LEFT", frame.health, "LEFT", 5, 0)

  frame.healthText = frame.health:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.healthText:SetPoint("RIGHT", frame.health, "RIGHT", -5, 0)

  frame.power = CreateFrame("StatusBar", nil, frame)
  frame.power:SetStatusBarTexture(PotatoUI.media.statusbar)
  frame.power:SetPoint("TOPLEFT", frame.health, "BOTTOMLEFT", 0, -3)
  frame.power:SetPoint("TOPRIGHT", frame.health, "BOTTOMRIGHT", 0, -3)
  frame.power:SetHeight(9)

  frame.power.bg = frame.power:CreateTexture(nil, "BACKGROUND")
  frame.power.bg:SetAllPoints()
  frame.power.bg:SetTexture(PotatoUI.media.statusbar)
  frame.power.bg:SetVertexColor(.04, .045, .055, 1)

  frame.powerText = frame.power:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.powerText:SetPoint("RIGHT", frame.power, "RIGHT", -5, 0)

  if PotatoUI:IsFeatureEnabled("auras") then
    frame.debuffs = PotatoUI:CreateAuraRow(frame, unit, "DEBUFF", 6, 18)
    frame.debuffs:SetPoint("LEFT", frame, "RIGHT", 4, 10)

    frame.buffs = PotatoUI:CreateAuraRow(frame, unit, "BUFF", 6, 18)
    frame.buffs:SetPoint("LEFT", frame, "RIGHT", 4, -10)
  end

  AddClickLayer(frame, unit, index)
  return frame
end

local function CreatePetFrame(name, unit, parent, point, relativePoint, x, y, width)
  local frame = PotatoUI:CreatePanel(name, parent, 3)
  frame.unit = unit
  frame:SetFrameStrata("LOW")
  frame:SetWidth(width)
  frame:SetHeight(27)
  frame:SetPoint(point, parent, relativePoint, x, y)
  frame:SetBackdropColor(.03, .045, .035, .72)
  frame:SetBackdropBorderColor(.18, .42, .24, .95)

  frame.health = CreateFrame("StatusBar", nil, frame)
  frame.health:SetStatusBarTexture(PotatoUI.media.statusbar)
  frame.health:SetPoint("TOPLEFT", frame, "TOPLEFT", 3, -3)
  frame.health:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -3, 3)
  frame.health:SetStatusBarColor(.18, .68, .28)

  frame.health.bg = frame.health:CreateTexture(nil, "BACKGROUND")
  frame.health.bg:SetAllPoints()
  frame.health.bg:SetTexture(PotatoUI.media.statusbar)
  frame.health.bg:SetVertexColor(.045, .06, .05, 1)

  frame.name = frame.health:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  frame.name:SetPoint("LEFT", frame.health, "LEFT", 5, 0)

  frame.healthText = frame.health:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.healthText:SetPoint("RIGHT", frame.health, "RIGHT", -5, 0)

  AddClickLayer(frame, unit, nil)
  return frame
end

local function UpdatePartyMember(frame)
  local unit = frame.unit
  if not UnitIsPresent(unit) then
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
  PotatoUI.SetPowerColor(frame.power, unit)
  if frame.powerText then
    frame.powerText:SetText(PotatoUI.ShortNumber(power) .. " / " .. PotatoUI.ShortNumber(powerMax))
  end

  local layout = PotatoUI:GetLayout()
  if layout.partyClassColor then
    local _, class = UnitClass(unit)
    local color = PotatoUI.classColors[class] or { .2, .72, .28 }
    PotatoUI:PaintStatusBar(frame.health, color[1], color[2], color[3])
  else
    local c = layout.partyHealth
    PotatoUI:PaintStatusBar(frame.health, c.r, c.g, c.b)
  end

  local prefix = ""
  if type(UnitIsPartyLeader) == "function" and IsTrue(UnitIsPartyLeader(unit)) then
    prefix = "|cffffcc00L|r "
  end
  local level = UnitLevel(unit) or 0
  local levelText = level > 0 and (level .. " ") or ""
  frame.name:SetText(prefix .. levelText .. (UnitName(unit) or "Unknown"))

  if type(UnitIsDeadOrGhost) == "function" and IsTrue(UnitIsDeadOrGhost(unit)) then
    frame.healthText:SetText("|cffff5555DEAD|r")
  elseif type(UnitIsConnected) == "function" and not IsTrue(UnitIsConnected(unit)) then
    frame.healthText:SetText("|cff999999OFFLINE|r")
  else
    frame.healthText:SetText(PotatoUI.ShortNumber(health) .. " / " .. PotatoUI.ShortNumber(healthMax))
  end

  if frame.debuffs then
    PotatoUI:UpdateAuraRow(frame.debuffs)
    PotatoUI:UpdateAuraRow(frame.buffs)
  end
end

local function UpdatePetFrame(frame)
  local unit = frame.unit
  if not UnitIsPresent(unit) then
    frame:Hide()
    return
  end
  frame:Show()

  local health = UnitHealth(unit) or 0
  local healthMax = UnitHealthMax(unit) or 1
  if healthMax < 1 then healthMax = 1 end
  frame.health:SetMinMaxValues(0, healthMax)
  frame.health:SetValue(health)
  PotatoUI:PaintStatusBar(frame.health, .18, .68, .28)
  frame.name:SetText(UnitName(unit) or "Pet")
  frame.healthText:SetText(PotatoUI.ShortNumber(health) .. " / " .. PotatoUI.ShortNumber(healthMax))
end

function PotatoUI:ApplyPartyFrameLayout()
  local layout = self:GetLayout()
  local party = self:GetUnitStyle("party") or {}
  local pet = self:GetUnitStyle("pet") or {}
  local width = party.width or layout.partyWidth or 220
  local height = party.height or layout.partyHeight or 44
  local spacing = party.spacing or layout.partySpacing or 29
  local gap = height + spacing
  if self.partyFrames then
    local i
    for i = 1, 4 do
      local frame = self.partyFrames[i]
      if frame then
        self:ApplyUnitBarSizes(frame, party)
        self:ApplyUnitTexts(frame, party)
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", self.partyAnchor or UIParent, "TOPLEFT", 0, -(i - 1) * gap)
      end
    end
  end
  if self.partyAnchor then
    self.partyAnchor:SetWidth(width + 120)
    self.partyAnchor:SetHeight(4 * gap)
  end
  if self.playerPetFrame then
    self:ApplyUnitBarSizes(self.playerPetFrame, pet)
    self:ApplyUnitTexts(self.playerPetFrame, pet)
  end
  if self.partyPetFrames then
    local i
    for i = 1, 4 do
      if self.partyPetFrames[i] then self:ApplyUnitTexts(self.partyPetFrames[i], pet) end
    end
  end
end

function PotatoUI:UpdatePartyFrames()
  local i
  for i = 1, 4 do
    UpdatePartyMember(self.partyFrames[i])
    UpdatePetFrame(self.partyPetFrames[i])
  end
  UpdatePetFrame(self.playerPetFrame)
end

function PotatoUI:SetupPartyFrames()
  self.partyFrames = {}
  self.partyPetFrames = {}

  local anchor = CreateFrame("Frame", "PotatoUIPartyAnchor", UIParent)
  anchor:SetWidth(330)
  anchor:SetHeight(263)
  anchor:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 18, -105)
  anchor:SetFrameStrata("LOW")
  self.partyAnchor = anchor

  self:HideFrame(PetFrame)
  local i
  for i = 1, 4 do
    self:HideFrame(getglobal("PartyMemberFrame" .. i))
    self:HideFrame(getglobal("PartyMemberFrame" .. i .. "PetFrame"))

    local member = CreatePartyMember(i, anchor)
    local pet = CreatePetFrame("PotatoUIPartyPet" .. i, "partypet" .. i,
      member, "TOPLEFT", "BOTTOMLEFT", 12, -2, 165)
    self.partyFrames[i] = member
    self.partyPetFrames[i] = pet
  end

  self.playerPetFrame = CreatePetFrame("PotatoUIPlayerPet", "pet",
    UIParent, "BOTTOM", "BOTTOM", -133, 170, PotatoUI:GetLayout().petWidth or 180)
  if self.ApplyPartyFrameLayout then self:ApplyPartyFrameLayout() end

  local events = CreateFrame("Frame", "PotatoUIPartyEvents")
  events:RegisterEvent("PARTY_MEMBERS_CHANGED")
  events:RegisterEvent("PARTY_LEADER_CHANGED")
  events:RegisterEvent("PLAYER_ENTERING_WORLD")
  events:RegisterEvent("UNIT_HEALTH")
  events:RegisterEvent("UNIT_MAXHEALTH")
  events:RegisterEvent("UNIT_MANA")
  events:RegisterEvent("UNIT_MAXMANA")
  events:RegisterEvent("UNIT_DISPLAYPOWER")
  events:RegisterEvent("UNIT_AURA")
  events:RegisterEvent("UNIT_LEVEL")
  events:RegisterEvent("UNIT_NAME_UPDATE")
  events:RegisterEvent("UNIT_PET")
  events:RegisterEvent("PET_UI_UPDATE")
  events:SetScript("OnEvent", function() PotatoUI:UpdatePartyFrames() end)

  self:UpdatePartyFrames()
end
