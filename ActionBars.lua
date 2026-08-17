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
local ParkActionButton
local SetPanelShown
local BarEnabled
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

  local function RestyleAfterNativeUpdate()
    local button = this
    if not button then return end
    if PotatoUI.EnsureButtonRim then
      PotatoUI:EnsureButtonRim(button, button.GetWidth and button:GetWidth())
    end
    if StyleActionButtonText then StyleActionButtonText(button) end
  end
  if type(ActionButton_Update) == "function" then
    local originalUpdate = ActionButton_Update
    ActionButton_Update = function()
      originalUpdate()
      RestyleAfterNativeUpdate()
    end
  end
  if type(MultiActionButton_Update) == "function" then
    local originalMultiUpdate = MultiActionButton_Update
    MultiActionButton_Update = function()
      originalMultiUpdate()
      RestyleAfterNativeUpdate()
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
  if not BarEnabled(aux) then
    local i
    for i = 1, 10 do
      ParkActionButton(getglobal("ShapeshiftButton" .. i))
      ParkActionButton(getglobal("PetActionButton" .. i))
    end
    SetPanelShown(panel, false)
    return
  end
  SetPanelShown(panel, true)

  local size = aux.size or 34
  local spacing = aux.spacing or 2
  local columns = aux.columns or 10
  local pad = 8

  local formCount = 0
  if type(GetNumShapeshiftForms) == "function" then
    formCount = tonumber(GetNumShapeshiftForms()) or 0
  end
  -- Emberveil can report the full 10-slot strip. Count forms that actually
  -- have an icon or name so warriors do not get seven empty stance wells.
  if type(GetShapeshiftFormInfo) == "function" then
    local filled = 0
    local i
    for i = 1, 10 do
      local ok, icon, name = pcall(GetShapeshiftFormInfo, i)
      if ok and ((icon and icon ~= "") or (name and name ~= "")) then
        filled = filled + 1
      end
    end
    if filled > 0 then formCount = filled end
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

  local total = 0
  if formCount > 0 then total = total + formCount end
  if hasPet then total = total + 10 end
  -- Do not stretch the panel to the unused grid columns (12x1 with one
  -- stance would otherwise stay twelve slots wide).
  if total > 0 and total < columns then columns = total end
  if columns < 1 then columns = 1 end

  local function PlaceAuxiliaryButtons(prefix, visibleCount, startIndex)
    local i
    for i = 1, 10 do
      local button = getglobal(prefix .. i)
      if button then
        if i <= visibleCount then
          PlaceInGrid(button, panel, startIndex + i - 1, columns, size, spacing, pad)
          if button.EnableMouse then pcall(button.EnableMouse, button, true) end
        else
          if button.Hide then pcall(button.Hide, button) end
          if button.EnableMouse then pcall(button.EnableMouse, button, false) end
          if button.PotatoUICell then button.PotatoUICell:Hide() end
          if button.ClearAllPoints and button.SetPoint then
            pcall(function()
              button:ClearAllPoints()
              button:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -4000, 4000)
            end)
          end
        end
      end
    end
  end

  if ShapeshiftBarFrame then
    -- Keep Blizzard's controller alive for state updates, but remove its
    -- large classic artwork and empty-slot strip.
    ShapeshiftBarFrame:SetAlpha(0)
    ShapeshiftBarFrame:EnableMouse(false)
    PlaceAuxiliaryButtons("ShapeshiftButton", formCount, 1)
  end
  if PetActionBarFrame then
    PetActionBarFrame:SetAlpha(0)
    PetActionBarFrame:EnableMouse(false)
    PlaceAuxiliaryButtons("PetActionButton", hasPet and 10 or 0, formCount > 0 and (formCount + 1) or 1)
  end
  if total < 1 then
    panel:SetWidth(size + pad * 2)
    panel:SetHeight(size + pad * 2)
  else
    local width, height = SizeForGrid(total, columns, size, spacing, pad)
    panel:SetWidth(width)
    panel:SetHeight(height)
  end
  if PotatoUI.ApplySlotBackgrounds then PotatoUI:ApplySlotBackgrounds() end
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
  if PotatoUI.EnsureButtonRim then
    PotatoUI:EnsureButtonRim(button, size)
  end
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

local function BarConfigForButton(button)
  local name = button and button.GetName and button:GetName()
  if not name or not PotatoUI.GetBarConfig then return PotatoUI:GetBarConfig("main") end
  if string.find(name, "MultiBarBottomLeft", 1, true) then return PotatoUI:GetBarConfig("extra") end
  if string.find(name, "MultiBarBottomRight", 1, true) then return PotatoUI:GetBarConfig("utility") end
  if string.find(name, "MultiBarRight", 1, true) then return PotatoUI:GetBarConfig("sideRight") end
  if string.find(name, "MultiBarLeft", 1, true) then return PotatoUI:GetBarConfig("sideLeft") end
  if string.find(name, "Shapeshift", 1, true) then return PotatoUI:GetBarConfig("aux") end
  if string.find(name, "PetAction", 1, true) then return PotatoUI:GetBarConfig("aux") end
  return PotatoUI:GetBarConfig("main")
end

local HOTKEY_ALIGN = {
  left = { "LEFT", "LEFT", 2, 0, "LEFT", "MIDDLE" },
  right = { "RIGHT", "RIGHT", -2, 0, "RIGHT", "MIDDLE" },
  top = { "TOP", "TOP", 0, -1, "CENTER", "TOP" },
  bottom = { "BOTTOM", "BOTTOM", 0, 1, "CENTER", "BOTTOM" },
  center = { "CENTER", "CENTER", 0, 0, "CENTER", "MIDDLE" },
  topleft = { "TOPLEFT", "TOPLEFT", 2, -1, "LEFT", "TOP" },
  topright = { "TOPRIGHT", "TOPRIGHT", -2, -1, "RIGHT", "TOP" },
  bottomleft = { "BOTTOMLEFT", "BOTTOMLEFT", 2, 1, "LEFT", "BOTTOM" },
  bottomright = { "BOTTOMRIGHT", "BOTTOMRIGHT", -2, 1, "RIGHT", "BOTTOM" },
}

StyleActionButtonText = function(button, size)
  if not button or not button.GetName then return end
  local name = button:GetName()
  if not name then return end
  size = size or (button.GetWidth and button:GetWidth()) or 34
  local cfg = BarConfigForButton(button)
  local font = (STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF")
  local hotSize = (cfg and cfg.hotkeySize) or 10
  if hotSize < 7 then hotSize = 7 end
  if hotSize > 16 then hotSize = 16 end
  local nameSize = hotSize - 1
  if nameSize < 7 then nameSize = 7 end
  local shadow = 1
  if cfg and cfg.hotkeyShadow ~= nil then shadow = cfg.hotkeyShadow end
  local align = (cfg and cfg.hotkeyAlign) or "center"
  local spec = HOTKEY_ALIGN[align] or HOTKEY_ALIGN.center

  local hotkey = getglobal(name .. "HotKey")
  if hotkey then
    hotkey:ClearAllPoints()
    hotkey:SetPoint(spec[1], button, spec[2], spec[3], spec[4])
    if hotkey.SetJustifyH then hotkey:SetJustifyH(spec[5]) end
    if hotkey.SetJustifyV then hotkey:SetJustifyV(spec[6]) end
    if hotkey.SetFont then hotkey:SetFont(font, hotSize, "OUTLINE") end
    if hotkey.SetShadowColor then hotkey:SetShadowColor(0, 0, 0, shadow > 0 and 1 or 0) end
    if hotkey.SetShadowOffset then hotkey:SetShadowOffset(shadow, -shadow) end
    if hotkey.SetNonSpaceWrap then hotkey:SetNonSpaceWrap(false) end
    if hotkey.Show then pcall(hotkey.Show, hotkey) end
    if hotkey.SetAlpha then pcall(hotkey.SetAlpha, hotkey, 1) end
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

ParkActionButton = function(button)
  if not button then return end
  if button.Hide then pcall(button.Hide, button) end
  if button.EnableMouse then pcall(button.EnableMouse, button, false) end
  if button.PotatoUICell then button.PotatoUICell:Hide() end
  if button.ClearAllPoints and button.SetPoint then
    pcall(function()
      button:ClearAllPoints()
      button:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -4000, 4000)
    end)
  end
end

SetPanelShown = function(panel, shown)
  if not panel then return end
  if shown then
    if panel.Show then pcall(panel.Show, panel) end
    if panel.SetAlpha then pcall(panel.SetAlpha, panel, 1) end
  else
    if panel.Hide then pcall(panel.Hide, panel) end
    if panel.SetAlpha then pcall(panel.SetAlpha, panel, 0) end
    if panel.EnableMouse then pcall(panel.EnableMouse, panel, false) end
  end
end

BarEnabled = function(cfg)
  return not cfg or cfg.enabled ~= false
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
  if button.EnableMouse then pcall(button.EnableMouse, button, true) end
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

  local function LayoutTwelve(panel, prefix, cfg)
    local i
    if not BarEnabled(cfg) then
      for i = 1, 12 do ParkActionButton(getglobal(prefix .. i)) end
      SetPanelShown(panel, false)
      return
    end
    SetPanelShown(panel, true)
    for i = 1, 12 do
      local button = getglobal(prefix .. i)
      if button and panel then
        PlaceInGrid(button, panel, i, cfg.columns, cfg.size, cfg.spacing, pad)
      end
    end
    local width, height = SizeForGrid(12, cfg.columns, cfg.size, cfg.spacing, pad)
    if panel then
      panel:SetWidth(width)
      panel:SetHeight(height)
    end
  end

  LayoutTwelve(self.actionPanel, "ActionButton", main)
  if self.extraActionPanel then
    LayoutTwelve(self.extraActionPanel, "MultiBarBottomLeftButton", extra)
  else
    local i
    for i = 1, 12 do
      local extraButton = getglobal("MultiBarBottomLeftButton" .. i)
      if extraButton then
        if BarEnabled(extra) then
          PlaceInGrid(extraButton, self.actionPanel, 12 + i, main.columns, main.size, main.spacing, pad)
        else
          ParkActionButton(extraButton)
        end
      end
    end
  end
  LayoutTwelve(self.utilityActionPanel, "MultiBarBottomRightButton", utility)

  if self.xpBar then
    self.xpBar:SetParent(UIParent)
    local saved = PotatoUIDB.positions and PotatoUIDB.positions.experience
    if not saved then
      self.xpBar:ClearAllPoints()
      if BarEnabled(main) and self.actionPanel then
        self.xpBar:SetPoint("TOP", self.actionPanel, "BOTTOM", 0, -4)
      else
        self.xpBar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 6)
      end
    end
    if BarEnabled(main) then
      self.xpBar:SetWidth(self.actionPanel:GetWidth())
    end
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
    local i
    if not BarEnabled(cfg) then
      for i = 1, 12 do ParkActionButton(getglobal(prefix .. i)) end
      SetPanelShown(panel, false)
      return
    end
    SetPanelShown(panel, true)
    local columns = cfg.columns or 3
    local size = cfg.size or 34
    local spacing = cfg.spacing or 2
    if columns < 1 then columns = 1 end
    for i = 1, 12 do
      local button = getglobal(prefix .. i)
      if button then
        button.PotatoUIAction = actionBase + i
        button.action = actionBase + i
        PlaceInGrid(button, panel, i, columns, size, spacing, pad)
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
  if self.RefreshBarChrome then self:RefreshBarChrome() end
  if self.ScheduleBarChromeRefresh then self:ScheduleBarChromeRefresh() end
end
