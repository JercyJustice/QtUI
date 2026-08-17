local pagingChromeNames = {
  "MainMenuBarPageNumber", "MainMenuBarPageUpButton", "MainMenuBarPageDownButton",
  "ActionBarUpButton", "ActionBarDownButton",
  "MainMenuBar", "MainMenuBarArtFrame", "MainMenuBarMaxLevelBar",
  "MainMenuBarOverlayFrame", "BonusActionBarFrame",
  "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft",
  "ReputationWatchBar", "MainMenuExpBar", "ExhaustionTick",
  "ShapeshiftBarFrame", "PetActionBarFrame", "PossessBarFrame",
}

local function SuppressPagingChrome()
  local i
  for i = 1, table.getn(pagingChromeNames) do
    local frame = getglobal(pagingChromeNames[i])
    if frame then
      if frame.Hide then pcall(frame.Hide, frame) end
      if frame.EnableMouse then pcall(frame.EnableMouse, frame, false) end
      if frame.SetAlpha then pcall(frame.SetAlpha, frame, 0) end
      if frame.ClearAllPoints and frame.SetPoint then
        pcall(function()
          frame:ClearAllPoints()
          frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -4000, 4000)
        end)
      end
    end
  end
end

local function PassClicksThrough(panel)
  if panel and panel.EnableMouse then
    pcall(panel.EnableMouse, panel, false)
  end
end

local hiddenNames = {
  -- gryphons and action-bar artwork
  "MainMenuBarLeftEndCap", "MainMenuBarRightEndCap",
  "MainMenuBarTexture0", "MainMenuBarTexture1",
  "MainMenuBarTexture2", "MainMenuBarTexture3",
  "MainMenuBarPageNumber", "MainMenuBarPageUpButton", "MainMenuBarPageDownButton",

  -- experience, reputation and performance chrome
  "MainMenuExpBar", "ExhaustionTick", "MainMenuBarMaxLevelBar",
  "MainMenuBarOverlayFrame", "ReputationWatchBar",
  "MainMenuBarPerformanceBarFrame", "MainMenuBarPerformanceBar",

  -- micro menu shown in the first reference image
  "CharacterMicroButton", "SpellbookMicroButton", "TalentMicroButton",
  "QuestLogMicroButton", "SocialsMicroButton", "WorldMapMicroButton",
  "MainMenuMicroButton", "HelpMicroButton",

  -- original bag strip; Bagnon or keybinds can still open bags
  "MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot",
  "CharacterBag2Slot", "CharacterBag3Slot", "KeyRingButton",
}

local actionResolversInstalled
local StyleActionButton
local StyleActionButtonText
local PlaceInGrid
local SizeForGrid
local function ResolvePrimaryAction(button)
  local buttonID = button and button:GetID()
  if not buttonID then return nil end

  -- In Vanilla clients forms are stored after the six normal action pages.
  -- Emberveil does not reliably update CURRENT_ACTIONBAR_PAGE after PotatoUI
  -- reparents the buttons, so resolve the active bonus page directly.
  local bonusOffset = 0
  if type(GetBonusBarOffset) == "function" then
    bonusOffset = tonumber(GetBonusBarOffset()) or 0
  end

  -- Emberveil can leave the bonus offset stuck briefly after a rogue breaks
  -- stealth. The form state changes reliably, so do not keep routing clicks
  -- to slots 73-84 once the rogue has returned to form zero.
  local _, class
  if type(UnitClass) == "function" then _, class = UnitClass("player") end
  if class == "ROGUE" and bonusOffset > 0 and type(GetShapeshiftForm) == "function" then
    local ok, activeForm = pcall(GetShapeshiftForm)
    if ok and activeForm ~= nil and (tonumber(activeForm) or 0) == 0 then
      bonusOffset = 0
    end
  end
  if bonusOffset > 0 then
    local normalPages = tonumber(NUM_ACTIONBAR_PAGES) or 6
    return buttonID + (normalPages + bonusOffset - 1) * 12
  end

  local page = tonumber(CURRENT_ACTIONBAR_PAGE) or 1
  if page < 1 or page > (tonumber(NUM_ACTIONBAR_PAGES) or 6) then page = 1 end
  return buttonID + (page - 1) * 12
end

local function InstallActionResolvers()
  if actionResolversInstalled then return end
  actionResolversInstalled = true

  -- Emberveil currently resolves MultiBarBottomLeft buttons as slots 1-12,
  -- duplicating the primary row. Honour PotatoUI's explicit slot mapping in
  -- both resolver variants used by original 1.12 FrameXML.
  local originalActionResolver = ActionButton_GetPagedID
  ActionButton_GetPagedID = function(button)
    local activeButton = button or this
    if activeButton and activeButton.PotatoUIAction then
      return activeButton.PotatoUIAction
    end
    if activeButton and activeButton.PotatoUIPrimaryAction then
      return ResolvePrimaryAction(activeButton)
    end
    if originalActionResolver then return originalActionResolver(button) end
    return activeButton and activeButton:GetID()
  end

  local originalMultiResolver = MultiActionButton_GetPagedID
  MultiActionButton_GetPagedID = function(button)
    local activeButton = button or this
    if activeButton and activeButton.PotatoUIAction then
      return activeButton.PotatoUIAction
    end
    if originalMultiResolver then return originalMultiResolver(button) end
    return activeButton and activeButton:GetID()
  end

  -- Vanilla key bindings normally divert to BonusActionButton while the
  -- native bonus controller is shown. PotatoUI keeps that controller alive
  -- for state updates but displays ActionButton instead, so dispatch bindings
  -- through the visible button and the same resolver used by mouse clicks.
  local originalActionButtonDown = ActionButtonDown
  if type(originalActionButtonDown) == "function" then
    ActionButtonDown = function(id)
      local activeButton = getglobal("ActionButton" .. tostring(id or ""))
      if not activeButton or not activeButton.PotatoUIPrimaryAction then
        return originalActionButtonDown(id)
      end
      if activeButton:GetButtonState() == "NORMAL" then
        activeButton:SetButtonState("PUSHED")
      end
    end
  end

  local originalActionButtonUp = ActionButtonUp
  if type(originalActionButtonUp) == "function" then
    ActionButtonUp = function(id, onSelf)
      local activeButton = getglobal("ActionButton" .. tostring(id or ""))
      if not activeButton or not activeButton.PotatoUIPrimaryAction then
        return originalActionButtonUp(id, onSelf)
      end
      if activeButton:GetButtonState() ~= "PUSHED" then return end
      activeButton:SetButtonState("NORMAL")
      if MacroFrame_SaveMacro then MacroFrame_SaveMacro() end
      local action = ResolvePrimaryAction(activeButton)
      if action and type(UseAction) == "function" then UseAction(action, 0, onSelf) end
      if action and type(IsCurrentAction) == "function" and IsCurrentAction(action) then
        activeButton:SetChecked(1)
      else
        activeButton:SetChecked(0)
      end
    end
  end

  if type(ActionButton_UpdateHotkeys) == "function" then
    local originalHotkeys = ActionButton_UpdateHotkeys
    ActionButton_UpdateHotkeys = function(actionButtonType)
      originalHotkeys(actionButtonType)
      if StyleActionButtonText then StyleActionButtonText(this) end
    end
  end
end

local function RefreshActionButtons()
  local previousThis = this
  local i
  for i = 1, 12 do
    local button = getglobal("ActionButton" .. i)
    if button then
      -- Emberveil's input bridge may read this cached field directly instead
      -- of calling ActionButton_GetPagedID. Keep it synchronized on every
      -- page/form refresh so leaving stealth restores slots 1-12.
      button.action = ResolvePrimaryAction(button)
      this = button
      if type(ActionButton_Update) == "function" then pcall(ActionButton_Update) end
      if type(ActionButton_UpdateUsable) == "function" then pcall(ActionButton_UpdateUsable) end
      if type(ActionButton_UpdateCooldown) == "function" then pcall(ActionButton_UpdateCooldown) end
    end

    local bottomLeftButton = getglobal("MultiBarBottomLeftButton" .. i)
    if bottomLeftButton then
      this = bottomLeftButton
      if type(MultiActionButton_Update) == "function" then
        pcall(MultiActionButton_Update)
      elseif type(ActionButton_Update) == "function" then
        pcall(ActionButton_Update)
      end
    end

    local bottomRightButton = getglobal("MultiBarBottomRightButton" .. i)
    if bottomRightButton then
      this = bottomRightButton
      if type(MultiActionButton_Update) == "function" then
        pcall(MultiActionButton_Update)
      elseif type(ActionButton_Update) == "function" then
        pcall(ActionButton_Update)
      end
    end

    local rightButton = getglobal("MultiBarRightButton" .. i)
    if rightButton then
      this = rightButton
      if type(MultiActionButton_Update) == "function" then
        pcall(MultiActionButton_Update)
      elseif type(ActionButton_Update) == "function" then
        pcall(ActionButton_Update)
      end
    end

    local leftButton = getglobal("MultiBarLeftButton" .. i)
    if leftButton then
      this = leftButton
      if type(MultiActionButton_Update) == "function" then
        pcall(MultiActionButton_Update)
      elseif type(ActionButton_Update) == "function" then
        pcall(ActionButton_Update)
      end
    end
  end
  this = previousThis
  SuppressPagingChrome()
  if PotatoUI.ApplySlotBackgrounds then PotatoUI:ApplySlotBackgrounds() end
  local labels = {
    "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
    "MultiBarRightButton", "MultiBarLeftButton",
  }
  local n
  for n = 1, table.getn(labels) do
    local i
    for i = 1, 12 do
      local button = getglobal(labels[n] .. i)
      if button then StyleActionButtonText(button) end
    end
  end
end

function PotatoUI:PositionAuxiliaryBars()
  if not self.auxiliaryPanel then
    local panel = CreateFrame("Frame", "PotatoUIAuxiliaryPanel", UIParent)
    panel:SetWidth(362)
    panel:SetHeight(38)
    panel:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 18, 18)
    panel:SetFrameStrata("MEDIUM")
    panel:SetFrameLevel(4)
    self.auxiliaryPanel = panel
  end
  local panel = self.auxiliaryPanel

  local aux = self:GetBarConfig("aux")
  local size = aux.size or 34
  local spacing = aux.spacing or 2
  local columns = aux.columns or 10
  local pad = 8

  local function PlaceAuxiliaryButtons(prefix, visibleCount, startIndex)
    local i
    for i = 1, 10 do
      local button = getglobal(prefix .. i)
      if button then
        PlaceInGrid(button, panel, startIndex + i - 1, columns, size, spacing, pad)
        if prefix == "ShapeshiftButton" or i <= visibleCount then
          button:Show()
        else
          button:Hide()
          if button.PotatoUICell then button.PotatoUICell:Hide() end
        end
      end
    end
  end

  local formCount = 0
  if type(GetNumShapeshiftForms) == "function" then
    formCount = tonumber(GetNumShapeshiftForms()) or 0
  end
  if ShapeshiftBarFrame then
    -- Keep Blizzard's controller alive for state updates, but remove its
    -- large classic artwork and empty-slot strip.
    ShapeshiftBarFrame:SetAlpha(0)
    ShapeshiftBarFrame:EnableMouse(false)
    PlaceAuxiliaryButtons("ShapeshiftButton", formCount, 1)
  end

  local hasPet
  if type(HasPetUI) == "function" then
    local petUI = HasPetUI()
    hasPet = petUI == true or petUI == 1 or petUI == "1"
  end
  if not hasPet and type(UnitExists) == "function" then
    local petExists = UnitExists("pet")
    hasPet = petExists == true or petExists == 1 or petExists == "1"
  end
  if PetActionBarFrame then
    PetActionBarFrame:SetAlpha(0)
    PetActionBarFrame:EnableMouse(false)
    PlaceAuxiliaryButtons("PetActionButton", hasPet and 10 or 0, formCount > 0 and (formCount + 1) or 1)
  end
  local total = 0
  if formCount > 0 then total = total + formCount end
  if hasPet then total = total + 10 end
  if total < 1 then total = 1 end
  local width, height = SizeForGrid(total, columns, size, spacing, pad)
  panel:SetWidth(width)
  panel:SetHeight(height)
end

local function SetupActionPageEvents()
  if PotatoUI.actionPageEvents then return end
  local events = CreateFrame("Frame", "PotatoUIActionPageEvents")
  -- Some Emberveil builds expose a slightly different subset of the old
  -- FrameXML events. Register each defensively so one absent alias cannot
  -- prevent PotatoUI from loading.
  pcall(events.RegisterEvent, events, "UPDATE_BONUS_ACTIONBAR")
  pcall(events.RegisterEvent, events, "ACTIONBAR_PAGE_CHANGED")
  pcall(events.RegisterEvent, events, "UPDATE_SHAPESHIFT_FORM")
  pcall(events.RegisterEvent, events, "UPDATE_SHAPESHIFT_FORMS")
  pcall(events.RegisterEvent, events, "PLAYER_AURAS_CHANGED")
  pcall(events.RegisterEvent, events, "PLAYER_ENTER_COMBAT")
  pcall(events.RegisterEvent, events, "PLAYER_LEAVE_COMBAT")
  pcall(events.RegisterEvent, events, "ACTIONBAR_SLOT_CHANGED")
  pcall(events.RegisterEvent, events, "PET_BAR_UPDATE")
  pcall(events.RegisterEvent, events, "UNIT_PET")

  local function RefreshAfterClientUpdate()
    this.refreshElapsed = (this.refreshElapsed or 0) + (arg1 or 0)
    this.refreshRemaining = (this.refreshRemaining or 0) - (arg1 or 0)
    if this.refreshElapsed >= .05 or this.refreshRemaining <= 0 then
      this.refreshElapsed = 0
      RefreshActionButtons()
      PotatoUI:PositionAuxiliaryBars()
    end
    if this.refreshRemaining <= 0 then this:SetScript("OnUpdate", nil) end
  end
  events:SetScript("OnEvent", function()
    -- Refresh throughout the short native bonus-bar transition. Emberveil can
    -- publish the aura/form, bonus offset and cached action ID on different
    -- frames when stealth ends through an attack.
    RefreshActionButtons()
    PotatoUI:PositionAuxiliaryBars()
    this.refreshElapsed = 0
    this.refreshRemaining = .75
    this:SetScript("OnUpdate", RefreshAfterClientUpdate)
  end)
  PotatoUI.actionPageEvents = events
end

local function RestoreRoundSlot(button, size)
  if not button then return end
  if button.PotatoUIBorder then button.PotatoUIBorder:Hide() end
  if button.SetNormalTexture then
    button:SetNormalTexture("Interface\\Buttons\\UI-Quickslot2")
  end
  local normal = button.GetNormalTexture and button:GetNormalTexture()
  if not normal then return end
  normal:SetAlpha(1)
  local pad = math.floor((size or 34) * 0.38)
  if pad < 10 then pad = 10 end
  normal:ClearAllPoints()
  normal:SetPoint("TOPLEFT", button, "TOPLEFT", -pad, pad)
  normal:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", pad, -pad)
end

local function AbbreviateHotkey(text)
  if not text or text == "" or text == RANGE_INDICATOR then return text end
  text = string.gsub(text, "SHIFT%-", "s")
  text = string.gsub(text, "CTRL%-", "c")
  text = string.gsub(text, "ALT%-", "a")
  text = string.gsub(text, "Middle Mouse", "M3")
  text = string.gsub(text, "Mouse Button 4", "M4")
  text = string.gsub(text, "Mouse Button 5", "M5")
  text = string.gsub(text, "Mouse Wheel Up", "WU")
  text = string.gsub(text, "Mouse Wheel Down", "WD")
  text = string.gsub(text, "Num Pad", "N")
  text = string.gsub(text, "Mouse Button ", "M")
  return text
end

StyleActionButtonText = function(button, size)
  if not button or not button.GetName then return end
  local name = button:GetName()
  if not name then return end
  size = size or (button.GetWidth and button:GetWidth()) or 34
  local font = (STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF")
  local hotSize = math.floor(size * 0.26)
  if hotSize < 8 then hotSize = 8 end
  if hotSize > 11 then hotSize = 11 end
  local nameSize = hotSize - 1
  if nameSize < 7 then nameSize = 7 end

  local hotkey = getglobal(name .. "HotKey")
  if hotkey then
    hotkey:ClearAllPoints()
    hotkey:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    hotkey:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    if hotkey.SetJustifyH then hotkey:SetJustifyH("CENTER") end
    if hotkey.SetJustifyV then hotkey:SetJustifyV("MIDDLE") end
    if hotkey.SetFont then hotkey:SetFont(font, hotSize, "OUTLINE") end
    if hotkey.SetNonSpaceWrap then hotkey:SetNonSpaceWrap(false) end
    if hotkey.GetText and hotkey.SetText then
      hotkey:SetText(AbbreviateHotkey(hotkey:GetText()))
    end
  end

  local macro = getglobal(name .. "Name")
  if macro then
    macro:ClearAllPoints()
    macro:SetPoint("BOTTOM", button, "BOTTOM", 0, 2)
    macro:SetWidth(size - 4)
    if macro.SetJustifyH then macro:SetJustifyH("CENTER") end
    if macro.SetFont then macro:SetFont(font, nameSize, "OUTLINE") end
  end

  local count = getglobal(name .. "Count")
  if count then
    count:ClearAllPoints()
    count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    if count.SetFont then count:SetFont(font, hotSize, "OUTLINE") end
    if count.SetJustifyH then count:SetJustifyH("RIGHT") end
  end
end

StyleActionButton = function(button, size)
  if not button then return end
  size = size or 34
  button:SetWidth(size)
  button:SetHeight(size)
  if button.PotatoUISlotBg then
    button.PotatoUISlotBg:Hide()
    if button.PotatoUISlotBg.SetTexture then button.PotatoUISlotBg:SetTexture(nil) end
  end
  RestoreRoundSlot(button, size)
  StyleActionButtonText(button, size)
  button.PotatoUIStyled = true
end

PlaceInGrid = function(button, panel, index, columns, size, spacing, pad)
  if not button or not panel then return end
  if columns < 1 then columns = 1 end
  local col = math.mod(index - 1, columns)
  local row = math.floor((index - 1) / columns)
  button:SetParent(panel)
  button:ClearAllPoints()
  button:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT",
    pad + col * (size + spacing), pad + row * (size + spacing))
  StyleActionButton(button, size)
  if PotatoUI.EnsureSlotCell then PotatoUI:EnsureSlotCell(button, panel) end
  button:Show()
end

SizeForGrid = function(count, columns, size, spacing, pad)
  if columns < 1 then columns = 1 end
  if count < 1 then count = 1 end
  local rows = math.floor((count - 1) / columns) + 1
  local width = pad * 2 + columns * size + (columns - 1) * spacing
  local height = pad * 2 + rows * size + (rows - 1) * spacing
  return width, height
end

function PotatoUI:LayoutActionBars()
  if not self.actionPanel then return end
  local pad = 5
  local main = self:GetBarConfig("main")
  local extra = self:GetBarConfig("extra")
  local utility = self:GetBarConfig("utility")

  local i
  for i = 1, 12 do
    PlaceInGrid(getglobal("ActionButton" .. i), self.actionPanel, i, main.columns, main.size, main.spacing, pad)
    local extraButton = getglobal("MultiBarBottomLeftButton" .. i)
    if extraButton and self.extraActionPanel then
      PlaceInGrid(extraButton, self.extraActionPanel, i, extra.columns, extra.size, extra.spacing, pad)
    elseif extraButton then
      PlaceInGrid(extraButton, self.actionPanel, 12 + i, main.columns, main.size, main.spacing, pad)
    end
    if self.utilityActionPanel then
      PlaceInGrid(getglobal("MultiBarBottomRightButton" .. i), self.utilityActionPanel, i, utility.columns, utility.size, utility.spacing, pad)
    end
  end

  local mainW, mainH = SizeForGrid(12, main.columns, main.size, main.spacing, pad)
  self.actionPanel:SetWidth(mainW)
  self.actionPanel:SetHeight(mainH)
  if self.extraActionPanel then
    local extraW, extraH = SizeForGrid(12, extra.columns, extra.size, extra.spacing, pad)
    self.extraActionPanel:SetWidth(extraW)
    self.extraActionPanel:SetHeight(extraH)
  end
  if self.utilityActionPanel then
    local utilW, utilH = SizeForGrid(12, utility.columns, utility.size, utility.spacing, pad)
    self.utilityActionPanel:SetWidth(utilW)
    self.utilityActionPanel:SetHeight(utilH)
  end
  if self.xpBar and self.actionPanel then
    self.xpBar:SetWidth(mainW)
  end
  self:LayoutSideBars()
  self:PositionAuxiliaryBars()
  SuppressPagingChrome()
  if self.ApplyActionBarBackground then self:ApplyActionBarBackground() end
  PassClicksThrough(self.actionPanel)
  PassClicksThrough(self.extraActionPanel)
  PassClicksThrough(self.utilityActionPanel)
  PassClicksThrough(self.sideRightPanel)
  PassClicksThrough(self.sideLeftPanel)
  PassClicksThrough(self.auxiliaryPanel)
end

function PotatoUI:LayoutSideBars()
  local pad = 5
  local function LayoutSide(panel, prefix, cfg, actionBase)
    if not panel then return end
    local columns = cfg.columns or 3
    local size = cfg.size or 34
    local spacing = cfg.spacing or 2
    if columns < 1 then columns = 1 end
    local i
    for i = 1, 12 do
      local button = getglobal(prefix .. i)
      if button then
        button.PotatoUIAction = actionBase + i
        button.action = actionBase + i
        PlaceInGrid(button, panel, i, columns, size, spacing, pad)
        button:Show()
      end
    end
    local width, height = SizeForGrid(12, columns, size, spacing, pad)
    panel:SetWidth(width)
    panel:SetHeight(height)
  end

  LayoutSide(self.sideRightPanel, "MultiBarRightButton", self:GetBarConfig("sideRight"), 24)
  LayoutSide(self.sideLeftPanel, "MultiBarLeftButton", self:GetBarConfig("sideLeft"), 36)
end

local function UpdateXPBar()
  local bar = PotatoUI.xpBar
  if not bar then return end

  local current = UnitXP("player") or 0
  local maximum = UnitXPMax("player") or 0
  local level = UnitLevel("player") or 0
  local rested = 0
  if type(GetXPExhaustion) == "function" then rested = GetXPExhaustion() or 0 end
  local resting
  if type(IsResting) == "function" then
    local ok, value = pcall(IsResting)
    resting = ok and (value == true or value == 1 or value == "1")
  end

  if resting then
    bar:SetStatusBarColor(.18, .48, .92)
    bar:SetBackdropBorderColor(.35, .62, 1, 1)
  else
    bar:SetStatusBarColor(.38, .28, .78)
    bar:SetBackdropBorderColor(.18, .22, .28, 1)
  end

  if maximum > 0 then
    local percent = math.floor(current / maximum * 100)
    bar:SetMinMaxValues(0, maximum)
    bar:SetValue(current)
    if resting and rested > 0 then
      bar.text:SetText("Level " .. level .. "  -  " .. percent .. "%  |cff66aaffResting  -  Rested " .. rested .. "|r")
    elseif resting then
      bar.text:SetText("Level " .. level .. "  -  " .. percent .. "%  |cff66aaffResting|r")
    elseif rested > 0 then
      bar.text:SetText("Level " .. level .. "  -  " .. percent .. "%  |cff66aaffRested " .. rested .. "|r")
    else
      bar.text:SetText("Level " .. level .. "  -  " .. percent .. "%")
    end
  else
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    if resting then
      bar.text:SetText("Level " .. level .. "  -  Maximum Level  |cff66aaffResting|r")
    else
      bar.text:SetText("Level " .. level .. "  -  Maximum Level")
    end
  end

  bar.current = current
  bar.maximum = maximum
  bar.rested = rested
  bar.resting = resting
end

function PotatoUI:SetupXPBar()
  if self.xpBar then return end

  local parent = self.actionPanel or UIParent
  local bar = CreateFrame("StatusBar", "PotatoUIXPBar", parent)
  bar:SetWidth(442)
  bar:SetHeight(12)
  if self.actionPanel then
    bar:SetPoint("TOP", self.actionPanel, "BOTTOM", 0, -4)
  else
    bar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 18)
  end
  bar:SetStatusBarTexture(self.media.statusbar)
  bar:SetStatusBarColor(.38, .28, .78)
  bar:SetFrameLevel((parent:GetFrameLevel() or 1) + 3)
  bar:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 8,
    edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  bar:SetBackdropColor(.025, .03, .04, .8)
  bar:SetBackdropBorderColor(.18, .22, .28, 1)

  bar.background = bar:CreateTexture(nil, "BACKGROUND")
  bar.background:SetAllPoints()
  bar.background:SetTexture(self.media.statusbar)
  bar.background:SetVertexColor(.035, .04, .055, .9)

  bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  bar.text:SetPoint("CENTER", bar, "CENTER", 0, 0)

  bar:EnableMouse(true)
  bar:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_TOP")
    GameTooltip:SetText("Experience")
    if this.maximum and this.maximum > 0 then
      GameTooltip:AddLine(this.current .. " / " .. this.maximum, 1, 1, 1)
      if this.rested and this.rested > 0 then
        GameTooltip:AddLine("Rested: " .. this.rested, .4, .65, 1)
      end
    else
      GameTooltip:AddLine("Maximum level", 1, .82, .2)
    end
    if this.resting then GameTooltip:AddLine("Currently resting", .4, .65, 1) end
    GameTooltip:Show()
  end)
  bar:SetScript("OnLeave", function() GameTooltip:Hide() end)

  local events = CreateFrame("Frame", "PotatoUIXPEvents")
  events:RegisterEvent("PLAYER_XP_UPDATE")
  events:RegisterEvent("UPDATE_EXHAUSTION")
  events:RegisterEvent("PLAYER_LEVEL_UP")
  events:RegisterEvent("PLAYER_ENTERING_WORLD")
  pcall(events.RegisterEvent, events, "PLAYER_UPDATE_RESTING")
  events:SetScript("OnEvent", UpdateXPBar)

  self.xpBar = bar
  UpdateXPBar()
end

function PotatoUI:SetupActionBars()
  InstallActionResolvers()

  for _, name in ipairs(hiddenNames) do
    self:HideFrame(getglobal(name))
  end

  local panel = self:CreatePanel("PotatoUIActionPanel", UIParent, 1)
  panel:SetWidth(442)
  panel:SetHeight(82)
  panel:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 18)
  panel:SetBackdropColor(0, 0, 0, 0)
  panel:SetBackdropBorderColor(0, 0, 0, 0)
  PassClicksThrough(panel)
  self.actionPanel = panel

  -- MultiBarBottomLeft used to share the main panel. It is its own bar so
  -- each 12-button strip can use 1x12 / 3x4 / 12x1 independently.
  local extraPanel = self:CreatePanel("PotatoUIExtraActionPanel", UIParent, 1)
  extraPanel:SetWidth(442)
  extraPanel:SetHeight(44)
  extraPanel:SetPoint("BOTTOM", panel, "TOP", 0, 4)
  extraPanel:SetBackdropColor(0, 0, 0, 0)
  extraPanel:SetBackdropBorderColor(0, 0, 0, 0)
  PassClicksThrough(extraPanel)
  self.extraActionPanel = extraPanel

  -- Emberveil leaves the second multi-action row partially off-screen when
  -- its original bar geometry is active. Give slots 49-60 a compact PotatoUI
  -- panel of their own at bottom-right instead.
  local utilityPanel = self:CreatePanel("PotatoUIUtilityActionPanel", UIParent, 1)
  utilityPanel:SetWidth(442)
  utilityPanel:SetHeight(44)
  utilityPanel:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -14, 14)
  utilityPanel:SetBackdropColor(0, 0, 0, 0)
  utilityPanel:SetBackdropBorderColor(0, 0, 0, 0)
  PassClicksThrough(utilityPanel)
  self.utilityActionPanel = utilityPanel

  local i
  for i = 1, 12 do
    local primaryButton = getglobal("ActionButton" .. i)
    if primaryButton then primaryButton.PotatoUIPrimaryAction = true end
    local upperButton = getglobal("MultiBarBottomLeftButton" .. i)
    if upperButton then
      upperButton.PotatoUIAction = 60 + i
      upperButton.action = 60 + i
    end
    local utilityButton = getglobal("MultiBarBottomRightButton" .. i)
    if utilityButton then
      utilityButton.PotatoUIAction = 48 + i
      utilityButton.action = 48 + i
    end
    local rightButton = getglobal("MultiBarRightButton" .. i)
    if rightButton then
      rightButton.PotatoUIAction = 24 + i
      rightButton.action = 24 + i
    end
    local leftButton = getglobal("MultiBarLeftButton" .. i)
    if leftButton then
      leftButton.PotatoUIAction = 36 + i
      leftButton.action = 36 + i
    end
  end

  local sideRight = self:CreatePanel("PotatoUISideRightPanel", UIParent, 1)
  sideRight:SetPoint("RIGHT", UIParent, "RIGHT", -14, 40)
  sideRight:SetBackdropColor(0, 0, 0, 0)
  sideRight:SetBackdropBorderColor(0, 0, 0, 0)
  PassClicksThrough(sideRight)
  self.sideRightPanel = sideRight

  local sideLeft = self:CreatePanel("PotatoUISideLeftPanel", UIParent, 1)
  sideLeft:SetPoint("RIGHT", sideRight, "LEFT", -8, 0)
  sideLeft:SetBackdropColor(0, 0, 0, 0)
  sideLeft:SetBackdropBorderColor(0, 0, 0, 0)
  PassClicksThrough(sideLeft)
  self.sideLeftPanel = sideLeft

  if SHOW_MULTI_ACTIONBAR_3 ~= nil then SHOW_MULTI_ACTIONBAR_3 = 1 end
  if SHOW_MULTI_ACTIONBAR_4 ~= nil then SHOW_MULTI_ACTIONBAR_4 = 1 end
  if type(MultiActionBar_Update) == "function" then pcall(MultiActionBar_Update) end

  self:LayoutActionBars()
  SetupActionPageEvents()
  RefreshActionButtons()

  -- The buttons now belong directly to PotatoUI. Hide their old containers
  -- so Emberveil cannot draw a second native copy at the bottom of the screen.
  self:HideFrame(MainMenuBarArtFrame)
  self:HideFrame(MainMenuBar)
  if MultiBarBottomLeft then
    self:HideFrame(MultiBarBottomLeft)
  end
  if MultiBarBottomRight then
    self:HideFrame(MultiBarBottomRight)
  end
  if MultiBarRight then
    self:HideFrame(MultiBarRight)
  end
  if MultiBarLeft then
    self:HideFrame(MultiBarLeft)
  end

  -- Keep only the useful stance/form and pet buttons at bottom-left; the
  -- original controller frames remain invisible so their update code works.
  self:PositionAuxiliaryBars()

end
