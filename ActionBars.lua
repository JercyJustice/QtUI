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
  -- Emberveil does not reliably update CURRENT_ACTIONBAR_PAGE after QtUI
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
  -- duplicating the primary row. Honour QtUI's explicit slot mapping in
  -- both resolver variants used by original 1.12 FrameXML.
  local originalActionResolver = ActionButton_GetPagedID
  ActionButton_GetPagedID = function(button)
    local activeButton = button or this
    if activeButton and activeButton.QtUIAction then
      return activeButton.QtUIAction
    end
    if activeButton and activeButton.QtUIPrimaryAction then
      return ResolvePrimaryAction(activeButton)
    end
    if originalActionResolver then return originalActionResolver(button) end
    return activeButton and activeButton:GetID()
  end

  local originalMultiResolver = MultiActionButton_GetPagedID
  MultiActionButton_GetPagedID = function(button)
    local activeButton = button or this
    if activeButton and activeButton.QtUIAction then
      return activeButton.QtUIAction
    end
    if originalMultiResolver then return originalMultiResolver(button) end
    return activeButton and activeButton:GetID()
  end

  -- Vanilla key bindings normally divert to BonusActionButton while the
  -- native bonus controller is shown. QtUI keeps that controller alive
  -- for state updates but displays ActionButton instead, so dispatch bindings
  -- through the visible button and the same resolver used by mouse clicks.
  local originalActionButtonDown = ActionButtonDown
  if type(originalActionButtonDown) == "function" then
    ActionButtonDown = function(id)
      local activeButton = getglobal("ActionButton" .. tostring(id or ""))
      if not activeButton or not activeButton.QtUIPrimaryAction then
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
      if not activeButton or not activeButton.QtUIPrimaryAction then
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

  local function RangeColorOn()
    if not QtUI.GetLayout then return true end
    local layout = QtUI:GetLayout()
    local value = layout and layout.barRangeColor
    return value ~= false and value ~= 0 and value ~= "0"
  end

  local function ActionSlotForButton(button)
    if not button then return nil end
    if button.QtUIAction then return button.QtUIAction end
    if button.QtUIPrimaryAction then return ResolvePrimaryAction(button) end
    if button.action then return button.action end
    if type(ActionButton_GetPagedID) == "function" then
      local ok, slot = pcall(ActionButton_GetPagedID, button)
      if ok then return slot end
    end
    if button.GetID then return button:GetID() end
    return nil
  end

  local function TintActionIcon(button)
    if not button or not RangeColorOn() then return end
    local name = button.GetName and button:GetName()
    if not name then return end
    local icon = getglobal(name .. "Icon")
    if not icon or not icon.SetVertexColor then return end
    local slot = ActionSlotForButton(button)
    if not slot then return end
    if type(HasAction) == "function" then
      local ok, has = pcall(HasAction, slot)
      if not ok or not (has == true or has == 1 or has == "1") then
        icon:SetVertexColor(1, 1, 1)
        return
      end
    end
    if type(IsActionInRange) == "function" then
      local ok, inRange = pcall(IsActionInRange, slot)
      if ok and inRange == 0 then
        icon:SetVertexColor(1, .16, .16)
        return
      end
    end
    if type(IsUsableAction) == "function" then
      local ok, usable, nomana = pcall(IsUsableAction, slot)
      if ok then
        if nomana == true or nomana == 1 or nomana == "1" then
          icon:SetVertexColor(.28, .48, 1)
          return
        end
        if not (usable == true or usable == 1 or usable == "1") then
          icon:SetVertexColor(.4, .4, .4)
          return
        end
      end
    end
    icon:SetVertexColor(1, 1, 1)
  end

  local function RestyleAfterNativeUpdate()
    local button = this
    if not button then return end
    -- Only restore the rim if Emberveil wiped it. Hotkey layout is handled
    -- by ActionButton_UpdateHotkeys and by bar layout, not every slot tick.
    if QtUI.EnsureButtonRim then
      QtUI:EnsureButtonRim(button, button.GetWidth and button:GetWidth())
    end
    TintActionIcon(button)
  end

  if type(ActionButton_UpdateUsable) == "function" then
    local originalUsable = ActionButton_UpdateUsable
    ActionButton_UpdateUsable = function()
      originalUsable()
      TintActionIcon(this)
    end
  end
  if type(ActionButton_OnUpdate) == "function" then
    local originalOnUpdate = ActionButton_OnUpdate
    ActionButton_OnUpdate = function(elapsed)
      originalOnUpdate(elapsed)
      this.qtRangeElapsed = (this.qtRangeElapsed or 0) + (elapsed or arg1 or 0)
      if this.qtRangeElapsed >= .15 then
        this.qtRangeElapsed = 0
        TintActionIcon(this)
      end
    end
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
  if QtUI.ApplySlotBackgrounds then QtUI:ApplySlotBackgrounds() end
end

function QtUI:PositionAuxiliaryBars()
  if not self.auxiliaryPanel then
    local panel = CreateFrame("Frame", "QtUIAuxiliaryPanel", UIParent)
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
          if button.QtUICell then button.QtUICell:Hide() end
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
  if QtUI.ApplySlotBackgrounds then QtUI:ApplySlotBackgrounds() end
end

local function SetupActionPageEvents()
  if QtUI.actionPageEvents then return end
  local events = CreateFrame("Frame", "QtUIActionPageEvents")
  -- Some Emberveil builds expose a slightly different subset of the old
  -- FrameXML events. Register each defensively so one absent alias cannot
  -- prevent QtUI from loading.
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

  local function CurrentBonusOffset()
    if type(GetBonusBarOffset) ~= "function" then return 0 end
    return tonumber(GetBonusBarOffset()) or 0
  end

  local function RefreshAfterClientUpdate()
    this.cooldown = (this.cooldown or 0) - (arg1 or 0)
    this.refreshRemaining = (this.refreshRemaining or 0) - (arg1 or 0)
    if this.watchBonus then
      this.watchBonus = this.watchBonus - (arg1 or 0)
      local offset = CurrentBonusOffset()
      if offset ~= this.lastBonusOffset then
        this.lastBonusOffset = offset
        this.pending = true
        this.refreshRemaining = .4
      end
      if this.watchBonus <= 0 then this.watchBonus = nil end
    end

    if this.pending and this.cooldown <= 0 then
      this.pending = nil
      this.cooldown = .15
      RefreshActionButtons()
      if this.pendingAux then
        this.pendingAux = nil
        QtUI:PositionAuxiliaryBars()
      end
    elseif this.refreshRemaining > 0 and this.cooldown <= 0 then
      this.pending = true
    end

    if not this.pending and this.refreshRemaining <= 0 and not this.watchBonus then
      this:SetScript("OnUpdate", nil)
    end
  end
  events.lastBonusOffset = CurrentBonusOffset()
  events:SetScript("OnEvent", function()
    local ev = event
    -- Aura ticks must not rebuild every bar. Watch the bonus offset briefly
    -- so stealth/form still swaps pages when Emberveil publishes the aura first.
    if ev == "PLAYER_AURAS_CHANGED" then
      if not this.watchBonus or this.watchBonus <= 0 then
        this.watchBonus = .4
      end
      this:SetScript("OnUpdate", RefreshAfterClientUpdate)
      return
    end

    if ev == "UPDATE_BONUS_ACTIONBAR" or ev == "ACTIONBAR_PAGE_CHANGED"
        or ev == "UPDATE_SHAPESHIFT_FORM" or ev == "UPDATE_SHAPESHIFT_FORMS" then
      this.lastBonusOffset = CurrentBonusOffset()
      -- Emberveil can publish form, bonus offset and action IDs on different
      -- frames when stealth ends through an attack.
      this.refreshRemaining = .6
    end

    this.pending = true
    if ev == "UPDATE_SHAPESHIFT_FORM" or ev == "UPDATE_SHAPESHIFT_FORMS"
        or ev == "PET_BAR_UPDATE" or ev == "UNIT_PET" then
      this.pendingAux = true
    end
    this:SetScript("OnUpdate", RefreshAfterClientUpdate)
  end)
  QtUI.actionPageEvents = events
end

local function RestoreRoundSlot(button, size)
  if not button then return end
  if button.QtUIBorder then button.QtUIBorder:Hide() end
  if QtUI.EnsureButtonRim then
    QtUI:EnsureButtonRim(button, size)
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
  if not name or not QtUI.GetBarConfig then return QtUI:GetBarConfig("main") end
  if string.find(name, "MultiBarBottomLeft", 1, true) then return QtUI:GetBarConfig("extra") end
  if string.find(name, "MultiBarBottomRight", 1, true) then return QtUI:GetBarConfig("utility") end
  if string.find(name, "MultiBarRight", 1, true) then return QtUI:GetBarConfig("sideRight") end
  if string.find(name, "MultiBarLeft", 1, true) then return QtUI:GetBarConfig("sideLeft") end
  if string.find(name, "Shapeshift", 1, true) then return QtUI:GetBarConfig("aux") end
  if string.find(name, "PetAction", 1, true) then return QtUI:GetBarConfig("aux") end
  return QtUI:GetBarConfig("main")
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
  local stamp = tostring(size) .. ":" .. hotSize .. ":" .. shadow .. ":" .. align
  local hotkey = getglobal(name .. "HotKey")
  if button.QtUITextStamp == stamp then
    if hotkey and hotkey.GetText and hotkey.SetText then
      hotkey:SetText(AbbreviateHotkey(hotkey:GetText()))
    end
    return
  end
  button.QtUITextStamp = stamp
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
  if button.QtUISlotBg then
    button.QtUISlotBg:Hide()
    if button.QtUISlotBg.SetTexture then button.QtUISlotBg:SetTexture(nil) end
  end
  RestoreRoundSlot(button, size)
  StyleActionButtonText(button, size)
  button.QtUIStyled = true
end

ParkActionButton = function(button)
  if not button then return end
  if button.Hide then pcall(button.Hide, button) end
  if button.EnableMouse then pcall(button.EnableMouse, button, false) end
  if button.QtUICell then button.QtUICell:Hide() end
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
  if QtUI.EnsureSlotCell then QtUI:EnsureSlotCell(button, panel) end
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

function QtUI:LayoutActionBars()
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
    local saved = QtUIDB.positions and QtUIDB.positions.experience
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

function QtUI:LayoutSideBars()
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
        button.QtUIAction = actionBase + i
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
  local bar = QtUI.xpBar
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

function QtUI:SetupXPBar()
  if self.xpBar then return end

  local parent = self.actionPanel or UIParent
  local bar = CreateFrame("StatusBar", "QtUIXPBar", parent)
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

  local events = CreateFrame("Frame", "QtUIXPEvents")
  events:RegisterEvent("PLAYER_XP_UPDATE")
  events:RegisterEvent("UPDATE_EXHAUSTION")
  events:RegisterEvent("PLAYER_LEVEL_UP")
  events:RegisterEvent("PLAYER_ENTERING_WORLD")
  pcall(events.RegisterEvent, events, "PLAYER_UPDATE_RESTING")
  events:SetScript("OnEvent", UpdateXPBar)

  self.xpBar = bar
  UpdateXPBar()
end

local autoUnshiftInstalled
local function InstallAutoUnshift()
  if autoUnshiftInstalled then return end
  autoUnshiftInstalled = true

  -- Same approach as pfUI/modules/autoshift.lua: wait for the client error,
  -- then CancelPlayerBuff on the 0-31 buff slot whose icon is a form.
  local formIcons = {
    "ability_racial_bearform",
    "ability_druid_catform",
    "ability_druid_travelform",
    "ability_druid_aquaticform",
    "ability_druid_direbearform",
    "ability_druid_treeoflife",
    "ability_druid_stagform",
    "spell_nature_forceofnature",
    "spell_nature_spiritwolf",
    "spell_shadow_shadowform",
  }

  local errorGlobals = {
    "SPELL_FAILED_NOT_SHAPESHIFT",
    "SPELL_FAILED_NO_ITEMS_WHILE_SHAPESHIFTED",
    "SPELL_NOT_SHAPESHIFTED",
    "SPELL_NOT_SHAPESHIFTED_NOSPACE",
    "ERR_CANT_INTERACT_SHAPESHIFTED",
    "ERR_NOT_WHILE_SHAPESHIFTED",
    "ERR_NO_ITEMS_WHILE_SHAPESHIFTED",
    "ERR_TAXIPLAYERSHAPESHIFTED",
    "ERR_MOUNT_SHAPESHIFTED",
    "ERR_EMBLEMERROR_NOTABARDGEOSET",
    "SPELL_FAILED_NOT_MOUNTED",
    "ERR_ATTACK_MOUNTED",
    "ERR_TAXIPLAYERALREADYMOUNTED",
  }

  local originalUseAction = UseAction
  local passing
  local lastSlot, lastCheckCursor, lastOnSelf
  local lastSpell
  local pending = CreateFrame("Frame", "QtUIAutoUnshift")
  pending:Hide()

  local function FeatureOn()
    if QtUI.GetLayout then
      local layout = QtUI:GetLayout()
      if layout and (layout.unshiftToCast == false or layout.unshiftToCast == 0 or layout.unshiftToCast == "0") then
        return nil
      end
    end
    return true
  end

  local function IsFormTexture(texture)
    if not texture or texture == "" then return nil end
    local lower = string.lower(texture)
    local i
    for i = 1, table.getn(formIcons) do
      if string.find(lower, formIcons[i], 1, true) then return true end
    end
    return nil
  end

  local function StillInForm()
    if type(GetPlayerBuffTexture) ~= "function" then return nil end
    local i
    for i = 0, 31 do
      local ok, tex = pcall(GetPlayerBuffTexture, i)
      if ok and IsFormTexture(tex) then return true end
    end
    return nil
  end

  local function LeaveShapeshift()
    if type(CancelPlayerBuff) ~= "function" then return nil end
    local i
    for i = 0, 31 do
      local tex
      local cancelId = i
      if type(GetPlayerBuffTexture) == "function" then
        local ok, value = pcall(GetPlayerBuffTexture, i)
        if ok then tex = value end
      end
      if (not tex or tex == "") and type(GetPlayerBuff) == "function" then
        local ok, buffIndex = pcall(GetPlayerBuff, i, "HELPFUL|PASSIVE")
        if not ok then ok, buffIndex = pcall(GetPlayerBuff, i, "HELPFUL") end
        if not ok then ok, buffIndex = pcall(GetPlayerBuff, i - 1, "HELPFUL") end
        buffIndex = ok and tonumber(buffIndex) or nil
        if buffIndex and buffIndex ~= 0 and buffIndex ~= -1 then
          local texOk, value = pcall(GetPlayerBuffTexture, buffIndex)
          if texOk then tex = value end
          cancelId = buffIndex
        end
      end
      if IsFormTexture(tex) then
        pcall(CancelPlayerBuff, cancelId)
        if cancelId ~= i then pcall(CancelPlayerBuff, i) end
        return true
      end
    end
    return nil
  end

  local function IsShapeshiftError(text)
    if not text or text == "" then return nil end
    local i
    for i = 1, table.getn(errorGlobals) do
      local value = getglobal(errorGlobals[i])
      if value and text == value then return true end
    end
    local lower = string.lower(text)
    if string.find(lower, "shapeshift", 1, true) then return true end
    if string.find(lower, "verwandelt", 1, true) then return true end
    if string.find(lower, "gestalt", 1, true) then return true end
    if string.find(lower, "this form", 1, true) then return true end
    if string.find(lower, "dieser form", 1, true) then return true end
    if string.find(lower, "while shapeshifted", 1, true) then return true end
    return nil
  end

  local function StopPending()
    pending:Hide()
    pending:SetScript("OnUpdate", nil)
  end

  local function FlushPending()
    local slot = pending.slot
    local spell = pending.spell
    StopPending()
    passing = true
    if slot and originalUseAction then
      pcall(originalUseAction, slot, pending.checkCursor, pending.onSelf)
    elseif spell and type(CastSpellByName) == "function" then
      pcall(CastSpellByName, spell)
    end
    passing = nil
  end

  local function PendingOnUpdate()
    this.elapsed = (this.elapsed or 0) + (arg1 or 0)
    this.retry = (this.retry or 0) + (arg1 or 0)
    if not StillInForm() then
      FlushPending()
      return
    end
    if this.retry >= .1 then
      this.retry = 0
      LeaveShapeshift()
    end
    if this.elapsed >= 1.2 then
      FlushPending()
    end
  end

  local function QueueRecast()
    pending.slot = lastSlot
    pending.checkCursor = lastCheckCursor
    pending.onSelf = lastOnSelf
    pending.spell = lastSpell
    pending.elapsed = 0
    pending.retry = 0
    pending:SetScript("OnUpdate", PendingOnUpdate)
    pending:Show()
  end

  local function HandleError(text)
    if not FeatureOn() or not IsShapeshiftError(text) then return nil end
    if getglobal("ERR_CANT_INTERACT_SHAPESHIFTED") and text == ERR_CANT_INTERACT_SHAPESHIFTED then
      if type(UnitAffectingCombat) == "function" then
        local ok, combat = pcall(UnitAffectingCombat, "player")
        if ok and (combat == true or combat == 1 or combat == "1") then return nil end
      end
    end
    LeaveShapeshift()
    if lastSlot or lastSpell then QueueRecast() end
    return true
  end

  local events = CreateFrame("Frame", "QtUIAutoUnshiftEvents")
  pcall(events.RegisterEvent, events, "UI_ERROR_MESSAGE")
  pcall(events.RegisterEvent, events, "SYSMSG")
  events:SetScript("OnEvent", function()
    HandleError(arg1)
  end)

  if type(UIErrorsFrame_OnEvent) == "function" then
    local originalError = UIErrorsFrame_OnEvent
    UIErrorsFrame_OnEvent = function(eventName, message)
      HandleError(message or arg1)
      return originalError(eventName, message)
    end
  end

  if UIErrorsFrame and UIErrorsFrame.AddMessage then
    local originalAdd = UIErrorsFrame.AddMessage
    UIErrorsFrame.AddMessage = function(frame, text, a, b, c, d, e)
      HandleError(text)
      return originalAdd(frame, text, a, b, c, d, e)
    end
  end

  if type(originalUseAction) == "function" then
    UseAction = function(slot, checkCursor, onSelf)
      if not passing and slot then
        lastSlot = slot
        lastCheckCursor = checkCursor
        lastOnSelf = onSelf
        lastSpell = nil
      end
      return originalUseAction(slot, checkCursor, onSelf)
    end
  end

  if type(CastSpellByName) == "function" then
    local originalCast = CastSpellByName
    CastSpellByName = function(name, onSelf)
      if not passing and name then
        lastSpell = name
        lastSlot = nil
      end
      return originalCast(name, onSelf)
    end
  end
end

function QtUI:SetupActionBars()
  InstallActionResolvers()
  InstallAutoUnshift()

  for _, name in ipairs(hiddenNames) do
    self:HideFrame(getglobal(name))
  end

  local panel = self:CreatePanel("QtUIActionPanel", UIParent, 1)
  panel:SetWidth(442)
  panel:SetHeight(82)
  panel:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 18)
  panel:SetBackdropColor(0, 0, 0, 0)
  panel:SetBackdropBorderColor(0, 0, 0, 0)
  PassClicksThrough(panel)
  self.actionPanel = panel

  -- MultiBarBottomLeft used to share the main panel. It is its own bar so
  -- each 12-button strip can use 1x12 / 3x4 / 12x1 independently.
  local extraPanel = self:CreatePanel("QtUIExtraActionPanel", UIParent, 1)
  extraPanel:SetWidth(442)
  extraPanel:SetHeight(44)
  extraPanel:SetPoint("BOTTOM", panel, "TOP", 0, 4)
  extraPanel:SetBackdropColor(0, 0, 0, 0)
  extraPanel:SetBackdropBorderColor(0, 0, 0, 0)
  PassClicksThrough(extraPanel)
  self.extraActionPanel = extraPanel

  -- Emberveil leaves the second multi-action row partially off-screen when
  -- its original bar geometry is active. Give slots 49-60 a compact QtUI
  -- panel of their own at bottom-right instead.
  local utilityPanel = self:CreatePanel("QtUIUtilityActionPanel", UIParent, 1)
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
    if primaryButton then primaryButton.QtUIPrimaryAction = true end
    local upperButton = getglobal("MultiBarBottomLeftButton" .. i)
    if upperButton then
      upperButton.QtUIAction = 60 + i
      upperButton.action = 60 + i
    end
    local utilityButton = getglobal("MultiBarBottomRightButton" .. i)
    if utilityButton then
      utilityButton.QtUIAction = 48 + i
      utilityButton.action = 48 + i
    end
    local rightButton = getglobal("MultiBarRightButton" .. i)
    if rightButton then
      rightButton.QtUIAction = 24 + i
      rightButton.action = 24 + i
    end
    local leftButton = getglobal("MultiBarLeftButton" .. i)
    if leftButton then
      leftButton.QtUIAction = 36 + i
      leftButton.action = 36 + i
    end
  end

  local sideRight = self:CreatePanel("QtUISideRightPanel", UIParent, 1)
  sideRight:SetPoint("RIGHT", UIParent, "RIGHT", -14, 40)
  sideRight:SetBackdropColor(0, 0, 0, 0)
  sideRight:SetBackdropBorderColor(0, 0, 0, 0)
  PassClicksThrough(sideRight)
  self.sideRightPanel = sideRight

  local sideLeft = self:CreatePanel("QtUISideLeftPanel", UIParent, 1)
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

  -- The buttons now belong directly to QtUI. Hide their old containers
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
