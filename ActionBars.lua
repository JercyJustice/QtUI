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
local UpdateXPBar
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

local function SlotForButton(button)
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

local function ButtonHasAction(button)
  if not button then return nil end
  local name = button.GetName and button:GetName()
  local id = button.GetID and button:GetID()
  if name and string.find(name, "ShapeshiftButton", 1, true) then
    if type(GetShapeshiftFormInfo) == "function" and id then
      local ok, icon = pcall(GetShapeshiftFormInfo, id)
      if ok and icon and icon ~= "" then return true end
    end
    return nil
  end
  if name and string.find(name, "PetActionButton", 1, true) then
    if type(GetPetActionInfo) == "function" and id then
      local ok, petName, _, texture = pcall(GetPetActionInfo, id)
      if ok and ((petName and petName ~= "") or (texture and texture ~= "")) then return true end
    end
    return nil
  end
  local slot = tonumber(SlotForButton(button))
  if not slot then return nil end
  if type(HasAction) == "function" then
    local ok, has = pcall(HasAction, slot)
    if ok then
      if has == true or has == 1 or has == "1" then return true end
      return nil
    end
  end
  if type(GetActionTexture) == "function" then
    local ok, tex = pcall(GetActionTexture, slot)
    if ok and tex and tex ~= "" then return true end
  end
  return nil
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

  -- Mouse clicks call UseAction on the visible button. Keybinds go through
  -- ActionButtonUp, which vanilla skips unless the button is PUSHED. Native Up
  -- also redirects to BonusActionButton while that bar reports shown — QtUI
  -- hides it, but Emberveil Hide() often still returns shown, so the key sets
  -- PUSHED on ActionButton and the original handler checks BonusActionButton.
  local function FireHotkey(button, onSelf)
    if not button then return end
    if button.SetButtonState then pcall(button.SetButtonState, button, "NORMAL") end
    local action = SlotForButton(button)
    if not action then return end
    QtUI.qtLastAction = action
    QtUI.qtLastOnSelf = onSelf
    QtUI.qtLastActionTime = GetTime()
    if type(UseAction) == "function" then UseAction(action, 0, onSelf) end
  end

  local originalActionButtonDown = ActionButtonDown
  if type(originalActionButtonDown) == "function" then
    ActionButtonDown = function(id)
      local activeButton = getglobal("ActionButton" .. tostring(id or ""))
      if not activeButton or not activeButton.QtUIPrimaryAction then
        return originalActionButtonDown(id)
      end
      if activeButton.SetButtonState then pcall(activeButton.SetButtonState, activeButton, "PUSHED") end
    end
  end

  local originalActionButtonUp = ActionButtonUp
  if type(originalActionButtonUp) == "function" then
    ActionButtonUp = function(id, onSelf)
      local activeButton = getglobal("ActionButton" .. tostring(id or ""))
      if not activeButton or not activeButton.QtUIPrimaryAction then
        return originalActionButtonUp(id, onSelf)
      end
      FireHotkey(activeButton, onSelf)
    end
  end

  if type(MultiActionButtonDown) == "function" then
    local originalMultiDown = MultiActionButtonDown
    MultiActionButtonDown = function(bar, id)
      local button = getglobal(tostring(bar or "") .. "Button" .. tostring(id or ""))
      if not button or not button.QtUIAction then
        return originalMultiDown(bar, id)
      end
      if button.SetButtonState then pcall(button.SetButtonState, button, "PUSHED") end
    end
  end

  if type(MultiActionButtonUp) == "function" then
    local originalMultiUp = MultiActionButtonUp
    MultiActionButtonUp = function(bar, id, onSelf)
      local button = getglobal(tostring(bar or "") .. "Button" .. tostring(id or ""))
      if not button or not button.QtUIAction then
        return originalMultiUp(bar, id, onSelf)
      end
      FireHotkey(button, onSelf)
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

  local function IsShapeshiftButton(button)
    local name = button and button.GetName and button:GetName()
    if name and string.find(name, "ShapeshiftButton", 1, true) then return true end
    return nil
  end

  local function PaintTint(button, icon, r, g, b)
    if button.qtTintR == r and button.qtTintG == g and button.qtTintB == b then return end
    icon:SetVertexColor(r, g, b)
    button.qtTintR, button.qtTintG, button.qtTintB = r, g, b
  end

  local function TintActionIcon(button)
    if not button then return end
    local name = button.GetName and button:GetName()
    if not name then return end
    local icon = getglobal(name .. "Icon")
    if not icon or not icon.SetVertexColor then return end
    -- Native usable/range tint on stance buttons can leave them unusable.
    if IsShapeshiftButton(button) then
      PaintTint(button, icon, 1, 1, 1)
      return
    end
    if not RangeColorOn() then return end
    local slot = ActionSlotForButton(button)
    if not slot then return end
    if type(HasAction) == "function" then
      local ok, has = pcall(HasAction, slot)
      if not ok or not (has == true or has == 1 or has == "1") then
        PaintTint(button, icon, 1, 1, 1)
        return
      end
    end
    if type(IsUsableAction) == "function" then
      local ok, usable, nomana = pcall(IsUsableAction, slot)
      if ok then
        if nomana == true or nomana == 1 or nomana == "1" then
          PaintTint(button, icon, .28, .48, 1)
          return
        end
        if not (usable == true or usable == 1 or usable == "1") then
          PaintTint(button, icon, .45, .45, .45)
          return
        end
      end
    end
    if type(IsActionInRange) == "function" then
      local ok, inRange = pcall(IsActionInRange, slot)
      if ok and inRange == 0 then
        -- Invalid or out-of-reach targets report 0 for every spell. Gray,
        -- not red, so it reads as "can't use" rather than "too far".
        PaintTint(button, icon, .45, .45, .45)
        return
      end
    end
    PaintTint(button, icon, 1, 1, 1)
  end

  local function RestyleAfterNativeUpdate()
    local button = this
    if not button then return end
    -- Only rebuild the rim if Emberveil wiped it. Calling Show/SetPoint
    -- here every ActionButton_Update tanks idle FPS on Emberveil.
    if QtUI.EnsureButtonRim and (not button.QtUIRimFrame or button.QtUIRimFrame.qtParked or button.QtUIRingOn ~= 1) then
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
  if not QtUI.rangeTintTicker then
    local ticker = CreateFrame("Frame", "QtUIRangeTint")
    ticker.elapsed = 0
    ticker:SetScript("OnUpdate", function()
      this.elapsed = this.elapsed + (arg1 or 0)
      if this.elapsed < .4 then return end
      this.elapsed = 0
      if not RangeColorOn() then return end
      local prefixes = {
        "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
        "MultiBarRightButton", "MultiBarLeftButton",
      }
      local p
      for p = 1, table.getn(prefixes) do
        local i
        for i = 1, 12 do
          local button = getglobal(prefixes[p] .. i)
          if button and button.IsShown and button:IsShown() then TintActionIcon(button) end
        end
      end
    end)
    QtUI.rangeTintTicker = ticker
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
  if type(ShapeshiftBar_Update) == "function" then
    local originalShiftUpdate = ShapeshiftBar_Update
    ShapeshiftBar_Update = function()
      originalShiftUpdate()
      local previousThis = this
      local i
      for i = 1, 10 do
        local button = getglobal("ShapeshiftButton" .. i)
        if button then
          this = button
          RestyleAfterNativeUpdate()
        end
      end
      this = previousThis
    end
  end
  if type(PetActionBar_Update) == "function" then
    local originalPetUpdate = PetActionBar_Update
    PetActionBar_Update = function()
      originalPetUpdate()
      local previousThis = this
      local i
      for i = 1, 10 do
        local button = getglobal("PetActionButton" .. i)
        if button then
          this = button
          RestyleAfterNativeUpdate()
        end
      end
      this = previousThis
    end
  end
  -- Emberveil's MultiActionBar_Update restyles MultiBarLeft/Right after
  -- our layout and wipes the rim. Only restamp when it actually stole the
  -- parent — doing PlaceInGrid on every combat update kills FPS.
  if type(MultiActionBar_Update) == "function" then
    local originalBarUpdate = MultiActionBar_Update
    local restamping
    MultiActionBar_Update = function()
      originalBarUpdate()
      if restamping then return end
      local sample = getglobal("MultiBarRightButton1")
      local parent = sample and sample.GetParent and sample:GetParent()
      if parent and QtUI.sideRightPanel and parent == QtUI.sideRightPanel then
        return
      end
      restamping = true
      if QtUI.LayoutSideBars then QtUI:LayoutSideBars() end
      if QtUI.ApplySlotBackgrounds then QtUI:ApplySlotBackgrounds() end
      if QtUI.ApplyEmptySlotVisibility then QtUI:ApplyEmptySlotVisibility() end
      restamping = nil
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
      if type(ActionButton_UpdateCooldown) == "function" then pcall(ActionButton_UpdateCooldown) end
      if QtUI.ApplyButtonCooldown then QtUI:ApplyButtonCooldown(bottomLeftButton) end
    end

    local bottomRightButton = getglobal("MultiBarBottomRightButton" .. i)
    if bottomRightButton then
      this = bottomRightButton
      if type(MultiActionButton_Update) == "function" then
        pcall(MultiActionButton_Update)
      elseif type(ActionButton_Update) == "function" then
        pcall(ActionButton_Update)
      end
      if type(ActionButton_UpdateCooldown) == "function" then pcall(ActionButton_UpdateCooldown) end
      if QtUI.ApplyButtonCooldown then QtUI:ApplyButtonCooldown(bottomRightButton) end
    end

    local rightButton = getglobal("MultiBarRightButton" .. i)
    if rightButton then
      this = rightButton
      if type(MultiActionButton_Update) == "function" then
        pcall(MultiActionButton_Update)
      elseif type(ActionButton_Update) == "function" then
        pcall(ActionButton_Update)
      end
      if type(ActionButton_UpdateCooldown) == "function" then pcall(ActionButton_UpdateCooldown) end
      if QtUI.ApplyButtonCooldown then QtUI:ApplyButtonCooldown(rightButton) end
    end

    local leftButton = getglobal("MultiBarLeftButton" .. i)
    if leftButton then
      this = leftButton
      if type(MultiActionButton_Update) == "function" then
        pcall(MultiActionButton_Update)
      elseif type(ActionButton_Update) == "function" then
        pcall(ActionButton_Update)
      end
      if type(ActionButton_UpdateCooldown) == "function" then pcall(ActionButton_UpdateCooldown) end
      if QtUI.ApplyButtonCooldown then QtUI:ApplyButtonCooldown(leftButton) end
    end

    local bonusButton = getglobal("BonusActionButton" .. i)
    if bonusButton then
      this = bonusButton
      if type(ActionButton_Update) == "function" then pcall(ActionButton_Update) end
    end
  end
  local s
  for s = 1, 10 do
    local shiftButton = getglobal("ShapeshiftButton" .. s)
    if shiftButton then
      this = shiftButton
      if QtUI.EnsureButtonRim then
        QtUI:EnsureButtonRim(shiftButton, shiftButton.GetWidth and shiftButton:GetWidth(), true)
      end
      if QtUI.ApplyButtonCooldown then QtUI:ApplyButtonCooldown(shiftButton) end
    end
    local petButton = getglobal("PetActionButton" .. s)
    if petButton then
      this = petButton
      if QtUI.EnsureButtonRim then
        QtUI:EnsureButtonRim(petButton, petButton.GetWidth and petButton:GetWidth())
      end
      if QtUI.ApplyButtonCooldown then QtUI:ApplyButtonCooldown(petButton) end
    end
  end
  this = previousThis
  SuppressPagingChrome()
  if QtUI.ApplySlotBackgrounds then QtUI:ApplySlotBackgrounds() end
  if QtUI.ApplyEmptySlotVisibility then QtUI:ApplyEmptySlotVisibility() end
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
          if button.QtUICell then
            local cell = button.QtUICell
            if cell.ClearAllPoints then
              cell:ClearAllPoints()
              cell:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -4000, 4000)
            end
            if cell.Hide then pcall(cell.Hide, cell) end
            cell.qtParked = 1
          end
          if button.QtUIRimFrame then
            local rim = button.QtUIRimFrame
            if rim.ClearAllPoints then
              rim:ClearAllPoints()
              rim:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -4000, 4000)
            end
            if rim.Hide then pcall(rim.Hide, rim) end
            rim.qtParked = 1
            button.QtUIRingOn = 0
          end
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
  pcall(events.RegisterEvent, events, "PLAYER_ENTER_COMBAT")
  pcall(events.RegisterEvent, events, "PLAYER_LEAVE_COMBAT")
  pcall(events.RegisterEvent, events, "ACTIONBAR_SLOT_CHANGED")
  pcall(events.RegisterEvent, events, "ACTIONBAR_SHOWGRID")
  pcall(events.RegisterEvent, events, "ACTIONBAR_HIDEGRID")
  pcall(events.RegisterEvent, events, "CURSOR_UPDATE")
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
    if ev == "ACTIONBAR_SHOWGRID" then
      actionGridShown = true
      if QtUI.ApplyEmptySlotVisibility then QtUI:ApplyEmptySlotVisibility() end
      return
    end
    if ev == "ACTIONBAR_HIDEGRID" then
      actionGridShown = nil
      if QtUI.ApplyEmptySlotVisibility then QtUI:ApplyEmptySlotVisibility() end
      return
    end
    if ev == "CURSOR_UPDATE" then
      if QtUI.ApplyEmptySlotVisibility then QtUI:ApplyEmptySlotVisibility() end
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

-- Emberveil ignores native OUTLINE. One offset copy is enough for contrast.
-- The old 8-direction outline created ~640 FontStrings and wrecked idle FPS.
local function ParkFontString(fs)
  if not fs then return end
  if fs.SetText then fs:SetText("") end
  if fs.ClearAllPoints then
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -4000, 4000)
  end
  if fs.Hide then pcall(fs.Hide, fs) end
end

local function ParkOrphanHotkeyCopies(button)
  if not button or not button.GetRegions then return end
  local keep = {}
  if button.QtUIHot then keep[button.QtUIHot] = true end
  if button.QtUICount then keep[button.QtUICount] = true end
  if button.QtUIHotShadow then keep[button.QtUIHotShadow] = true end
  local name = button.GetName and button:GetName()
  if name then
    keep[getglobal(name .. "HotKey") or false] = true
    keep[getglobal(name .. "Name") or false] = true
    keep[getglobal(name .. "Count") or false] = true
  end
  local regs = { button:GetRegions() }
  local i
  for i = 1, table.getn(regs) do
    local r = regs[i]
    if r and not keep[r] and r.GetObjectType then
      local ok, typ = pcall(r.GetObjectType, r)
      if ok and typ == "FontString" then ParkFontString(r) end
    end
  end
  local copies = button.QtUIHotOutline
  if copies then
    for i = 1, table.getn(copies) do ParkFontString(copies[i]) end
    button.QtUIHotOutline = nil
  end
end

local function PaintHotkeyOutline(button, text)
  local fs = button and button.QtUIHotShadow
  if not fs then return end
  if not button.QtUIHotOutlineOn or not text or text == "" then
    fs:SetText("")
    return
  end
  fs:SetText("|cff010101" .. text)
end

local function ParkNativeHotkey(button)
  local name = button and button.GetName and button:GetName()
  if not name then return nil end
  local native = getglobal(name .. "HotKey")
  if not native then return nil end
  native:ClearAllPoints()
  native:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -4000, 4000)
  return native
end

local function EnsureHotkeyOutline(button, thickness, hotSize, align, size)
  if not button then return end
  thickness = tonumber(thickness) or 0
  if thickness < 1 then
    button.QtUIHotOutlineOn = nil
    ParkFontString(button.QtUIHotShadow)
    return
  end
  button.QtUIHotOutlineOn = true
  local fs = button.QtUIHotShadow
  if not fs then
    fs = button:CreateFontString(nil, "ARTWORK")
    button.QtUIHotShadow = fs
  end
  if fs.SetDrawLayer then fs:SetDrawLayer("ARTWORK") end
  if QtUI.PlaceAlignedText then
    QtUI:PlaceAlignedText(fs, button, align, 1, size, size, 1, -1)
  end
  if QtUI.ApplyFont then QtUI:ApplyFont(fs, hotSize) end
  if fs.SetNonSpaceWrap then fs:SetNonSpaceWrap(false) end
  if fs.SetShadowOffset then fs:SetShadowOffset(0, 0) end
  if fs.Show then pcall(fs.Show, fs) end
end

local function ApplyHotkeyVisibility(button)
  if not button then return end
  local native = ParkNativeHotkey(button)
  local text = ""
  if ButtonHasAction(button) and native and native.GetText then
    text = AbbreviateHotkey(native:GetText()) or ""
    if text == RANGE_INDICATOR then text = "" end
  end
  local hotkey = button.QtUIHot
  if hotkey and hotkey.SetText then hotkey:SetText(text) end
  PaintHotkeyOutline(button, text)
end

local function PlaceCountText(button, size, hotSize)
  if not button or not button.GetName then return end
  size = size or button.QtUISize or (button.GetWidth and button:GetWidth()) or 34
  hotSize = tonumber(hotSize) or 10

  -- Native Count is Hide()'d on empty slots; Emberveil often never Show()s it
  -- again after a move. Park it and draw the stack size ourselves.
  local native = getglobal(button:GetName() .. "Count")
  if native and not native.qtParked then
    native:ClearAllPoints()
    native:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -4000, 4000)
    if native.SetText then native:SetText("") end
    native.qtParked = 1
  end

  local count = button.QtUICount
  if not count then
    count = button:CreateFontString(nil, "OVERLAY")
    button.QtUICount = count
  end
  -- Tight corner box. PlaceAlignedText's 58%x50% well sits the number inward.
  local boxW = hotSize + 10
  local boxH = hotSize + 2
  if boxW < 16 then boxW = 16 end
  if boxH < 10 then boxH = 10 end
  count:ClearAllPoints()
  count:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", size - boxW + 4, -3)
  count:SetPoint("TOPRIGHT", button, "BOTTOMLEFT", size + 3, boxH - 3)
  if count.SetWidth then
    count:SetWidth(boxW + 1)
    count:SetWidth(boxW)
  end
  if count.SetHeight then
    count:SetHeight(boxH + 1)
    count:SetHeight(boxH)
  end
  if count.SetJustifyH then count:SetJustifyH("RIGHT") end
  if count.SetJustifyV then count:SetJustifyV("BOTTOM") end
  if count.SetDrawLayer then count:SetDrawLayer("OVERLAY") end
  if QtUI.ApplyFont then QtUI:ApplyFont(count, hotSize) end
  if count.SetTextColor then count:SetTextColor(1, 1, 1) end

  local text = ""
  local slot = tonumber(SlotForButton(button))
  if slot then
    local n = 0
    local consumable
    if type(GetActionCount) == "function" then
      local ok, value = pcall(GetActionCount, slot)
      if ok then n = tonumber(value) or 0 end
    end
    if type(IsConsumableAction) == "function" then
      local ok, value = pcall(IsConsumableAction, slot)
      if ok and (value == true or value == 1 or value == "1") then consumable = true end
    end
    if consumable or n > 0 then text = tostring(n) end
  end
  if count.SetText then count:SetText(text) end
  if count.Show then pcall(count.Show, count) end
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
  local stamp = tostring(size) .. ":" .. hotSize .. ":" .. shadow .. ":" .. align .. ":own"
  if button.QtUITextStamp ~= stamp or button.QtUIHotClean ~= 2 then
    button.QtUITextStamp = stamp
    button.QtUIHotClean = 2
    ParkOrphanHotkeyCopies(button)
    ParkNativeHotkey(button)
    local hotkey = button.QtUIHot
    if not hotkey then
      hotkey = button:CreateFontString(nil, "OVERLAY")
      button.QtUIHot = hotkey
    end
    if QtUI.PlaceAlignedText then
      QtUI:PlaceAlignedText(hotkey, button, align, 1, size, size)
    end
    if QtUI.ApplyFont then QtUI:ApplyFont(hotkey, hotSize) elseif hotkey.SetFont then hotkey:SetFont(font, hotSize) end
    if hotkey.SetTextColor then hotkey:SetTextColor(1, 1, 1) end
    if hotkey.SetShadowOffset then hotkey:SetShadowOffset(0, 0) end
    if hotkey.SetNonSpaceWrap then hotkey:SetNonSpaceWrap(false) end
    if hotkey.SetDrawLayer then hotkey:SetDrawLayer("OVERLAY") end
    if hotkey.Show then pcall(hotkey.Show, hotkey) end
    EnsureHotkeyOutline(button, shadow, hotSize, align, size)

    local macro = getglobal(name .. "Name")
    if macro then
      macro:ClearAllPoints()
      macro:SetPoint("BOTTOM", button, "BOTTOM", 0, 2)
      macro:SetWidth(size - 4)
      if macro.SetJustifyH then macro:SetJustifyH("CENTER") end
      if QtUI.ApplyFont then QtUI:ApplyFont(macro, nameSize) elseif macro.SetFont then macro:SetFont(font, nameSize) end
    end
  end
  ApplyHotkeyVisibility(button)
  PlaceCountText(button, size, hotSize)
end

StyleActionButton = function(button, size)
  if not button then return end
  size = size or 34
  if size < 8 then size = 34 end
  button.QtUISize = size
  button:SetWidth(size)
  button:SetHeight(size)
  if button.QtUISlotBg then
    button.QtUISlotBg:Hide()
    if button.QtUISlotBg.SetTexture then button.QtUISlotBg:SetTexture(nil) end
  end
  RestoreRoundSlot(button, size)
  StyleActionButtonText(button, size)
  if QtUI.LayerActionCooldown then QtUI:LayerActionCooldown(button) end
  button.QtUIStyled = true
end

local actionGridShown
local EMPTY_SLOT_PREFIXES = {
  "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
  "MultiBarRightButton", "MultiBarLeftButton",
  "PetActionButton",
}

local function HideEmptySlotsOn()
  if not QtUI.GetLayout then return true end
  local layout = QtUI:GetLayout()
  if not layout then return true end
  local value = layout.hideEmptySlots
  return value == true or value == 1 or value == "1"
end

local function CursorIsHolding()
  local names = { "CursorHasItem", "CursorHasSpell", "CursorHasMacro" }
  local i
  for i = 1, table.getn(names) do
    local fn = getglobal(names[i])
    if type(fn) == "function" then
      local ok, has = pcall(fn)
      if ok and (has == true or has == 1 or has == "1") then return true end
    end
  end
  return nil
end

local function ShowEmptySlotsNow()
  if QtUI.moveMode then return true end
  if actionGridShown then return true end
  if CursorIsHolding() then return true end
  return nil
end

local function ConcealEmptyButton(button)
  if not button then return end
  -- Stay on the bar as an invisible drop target. Hide() + EnableMouse(false)
  -- made empty slots impossible to fill.
  if button.Show then pcall(button.Show, button) end
  if button.EnableMouse then pcall(button.EnableMouse, button, true) end
  if button.QtUICell then
    local cell = button.QtUICell
    if cell.ClearAllPoints then
      cell:ClearAllPoints()
      cell:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -4000, 4000)
    end
    if cell.Hide then pcall(cell.Hide, cell) end
    cell.qtParked = 1
  end
  if button.QtUIRimFrame then
    local rim = button.QtUIRimFrame
    if rim.ClearAllPoints then
      rim:ClearAllPoints()
      rim:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -4000, 4000)
    end
    if rim.Hide then pcall(rim.Hide, rim) end
    rim.qtParked = 1
    button.QtUIRingOn = 0
  end
  button.qtEmptyHidden = 1
end

local function RevealEmptyButton(button)
  if not button then return end
  button.qtEmptyHidden = nil
  if button.EnableMouse then pcall(button.EnableMouse, button, true) end
  if button.Show then pcall(button.Show, button) end
end

function QtUI:ApplyEmptySlotVisibility()
  local hide = HideEmptySlotsOn()
  local showEmpty = not hide or ShowEmptySlotsNow()
  local n
  for n = 1, table.getn(EMPTY_SLOT_PREFIXES) do
    local prefix = EMPTY_SLOT_PREFIXES[n]
    local last = 12
    if prefix == "PetActionButton" then last = 10 end
    local i
    for i = 1, last do
      local button = getglobal(prefix .. i)
      if button and button.QtUIStyled then
        if showEmpty or ButtonHasAction(button) then
          if button.qtEmptyHidden then RevealEmptyButton(button) end
        else
          ConcealEmptyButton(button)
        end
      end
    end
  end
  if QtUI.ApplySlotBackgrounds then QtUI:ApplySlotBackgrounds() end
end

ParkActionButton = function(button)
  if not button then return end
  button.qtEmptyHidden = nil
  if button.Hide then pcall(button.Hide, button) end
  if button.EnableMouse then pcall(button.EnableMouse, button, false) end
  if button.QtUICell then
    local cell = button.QtUICell
    if cell.art and cell.art.SetTexture then cell.art:SetTexture(nil) end
    if cell.ClearAllPoints then
      cell:ClearAllPoints()
      cell:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -4000, 4000)
    end
    if cell.Hide then pcall(cell.Hide, cell) end
    cell.qtParked = 1
  end
  if button.QtUIRimFrame then
    local rim = button.QtUIRimFrame
    if rim.art and rim.art.SetTexture then rim.art:SetTexture(nil) end
    if rim.ClearAllPoints then
      rim:ClearAllPoints()
      rim:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -4000, 4000)
    end
    if rim.Hide then pcall(rim.Hide, rim) end
    rim.qtParked = 1
    button.QtUIRingOn = 0
  end
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
  if not size or size < 8 then size = 34 end
  local col = math.mod(index - 1, columns)
  local row = math.floor((index - 1) / columns)
  local x = pad + col * (size + spacing)
  local y = pad + row * (size + spacing)
  button:SetParent(panel)
  button.QtUIGridX = x
  button.QtUIGridY = y
  button.QtUISize = size
  button:ClearAllPoints()
  button:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", x, y)
  -- Emberveil drops SetWidth on MultiBarLeft/Right. A second corner is
  -- what actually gives the button a box for the rim to wrap.
  button:SetPoint("TOPRIGHT", panel, "BOTTOMLEFT", x + size, y + size)
  if button.SetWidth then
    button:SetWidth(size + 1)
    if button.SetHeight then button:SetHeight(size + 1) end
    button:SetWidth(size)
    if button.SetHeight then button:SetHeight(size) end
  end
  StyleActionButton(button, size)
  if QtUI.EnsureSlotCell then QtUI:EnsureSlotCell(button, panel) end
  if QtUI.ApplyButtonCooldown then QtUI:ApplyButtonCooldown(button) end
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
    local width = 442
    local barH = 20
    if self.GetLayout then
      local layout = self:GetLayout()
      if layout then
        width = tonumber(layout.xpBarWidth) or width
        barH = tonumber(layout.xpBarHeight) or barH
      end
    end
    if width < 80 then width = 80 end
    if width > 800 then width = 800 end
    if barH < 12 then barH = 12 end
    if barH > 32 then barH = 32 end
    self.xpBar:ClearAllPoints()
    if saved then
      saved.w = width
      saved.h = barH
    end
    if saved and saved.x and saved.y then
      local left, bottom = saved.x, saved.y
      self.xpBar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
      self.xpBar:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", left + width, bottom + barH)
    elseif BarEnabled(main) and self.actionPanel then
      self.xpBar:SetPoint("TOPLEFT", self.actionPanel, "BOTTOMLEFT", 0, -4)
      self.xpBar:SetPoint("BOTTOMRIGHT", self.actionPanel, "BOTTOMLEFT", width, -(4 + barH))
    else
      self.xpBar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 18, 6)
      self.xpBar:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", 18 + width, 6 + barH)
    end
    if self.xpBar.SetWidth then
      self.xpBar:SetWidth(width + 1)
      self.xpBar:SetWidth(width)
    end
    if self.xpBar.SetHeight then
      self.xpBar:SetHeight(barH + 1)
      self.xpBar:SetHeight(barH)
    end
    UpdateXPBar()
  end
  self:LayoutSideBars()
  self:PositionAuxiliaryBars()
  SuppressPagingChrome()
  if self.ApplyActionBarBackground then self:ApplyActionBarBackground() end
  if self.ApplySlotBackgrounds then self:ApplySlotBackgrounds() end
  PassClicksThrough(self.actionPanel)
  PassClicksThrough(self.extraActionPanel)
  PassClicksThrough(self.utilityActionPanel)
  PassClicksThrough(self.sideRightPanel)
  PassClicksThrough(self.sideLeftPanel)
  PassClicksThrough(self.auxiliaryPanel)
  if self.ApplyEmptySlotVisibility then self:ApplyEmptySlotVisibility() end
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
    if panel.SetWidth then
      panel:SetWidth(width + 1)
      if panel.SetHeight then panel:SetHeight(height + 1) end
      panel:SetWidth(width)
      if panel.SetHeight then panel:SetHeight(height) end
    end
  end

  LayoutSide(self.sideRightPanel, "MultiBarRightButton", self:GetBarConfig("sideRight"), 24)
  LayoutSide(self.sideLeftPanel, "MultiBarLeftButton", self:GetBarConfig("sideLeft"), 36)
end

local function ApplyXPBarFont(wrap)
  if not wrap or not wrap.label then return end
  local layout = QtUI.GetLayout and QtUI:GetLayout() or {}
  local fontSize = tonumber(layout.xpBarFontSize) or 12
  if fontSize < 8 then fontSize = 8 end
  if fontSize > 18 then fontSize = 18 end
  wrap.label:ClearAllPoints()
  wrap.label:SetPoint("CENTER", wrap, "CENTER", 0, 0)
  wrap.label:SetPoint("TOPLEFT", wrap, "CENTER", -2, 2)
  wrap.label:SetPoint("BOTTOMRIGHT", wrap, "CENTER", 2, -2)
  if wrap.label.SetScale then wrap.label:SetScale(1) end
  if not wrap.text then
    wrap.text = wrap.label:CreateFontString(nil, "OVERLAY")
    wrap.text:SetPoint("CENTER", wrap.label, "CENTER", 0, 0)
    wrap.text:SetJustifyH("CENTER")
  end
  if QtUI.ApplyFont then
    QtUI:ApplyFont(wrap.text, fontSize)
  elseif wrap.text.SetFont then
    wrap.text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", fontSize)
  end
  wrap.text:SetTextColor(1, 1, 1)
end

function UpdateXPBar()
  local wrap = QtUI.xpBar
  local bar = wrap and wrap.status
  if not wrap or not bar then return end
  ApplyXPBarFont(wrap)

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
    if wrap.SetBackdropBorderColor then wrap:SetBackdropBorderColor(.35, .62, 1, 1) end
  else
    bar:SetStatusBarColor(.38, .28, .78)
    if wrap.SetBackdropBorderColor then wrap:SetBackdropBorderColor(.18, .22, .28, 1) end
  end

  local layout = QtUI.GetLayout and QtUI:GetLayout() or {}
  local showText = layout.xpBarText ~= false
  if maximum > 0 then
    local percent = math.floor(current / maximum * 100)
    bar:SetMinMaxValues(0, maximum)
    bar:SetValue(current)
    if wrap.text then
      if showText then
        wrap.text:SetText(level .. "   " .. current .. " / " .. maximum .. "   " .. percent .. "%")
      else
        wrap.text:SetText("")
      end
    end
  else
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    if wrap.text then
      if showText then
        wrap.text:SetText(level .. "   max")
      else
        wrap.text:SetText("")
      end
    end
  end

  wrap.current = current
  wrap.maximum = maximum
  wrap.rested = rested
  wrap.resting = resting
end

function QtUI:SetupXPBar()
  if self.xpBar then return end

  local parent = self.actionPanel or UIParent
  local wrap = CreateFrame("Frame", "QtUIXPBar", UIParent)
  local width = 442
  local barH = 20
  if self.GetLayout then
    local layout = self:GetLayout()
    if layout then
      width = tonumber(layout.xpBarWidth) or width
      barH = tonumber(layout.xpBarHeight) or barH
    end
  end
  if width < 80 then width = 80 end
  if barH < 12 then barH = 12 end
  wrap:SetWidth(width)
  wrap:SetHeight(barH)
  if self.actionPanel then
    wrap:SetPoint("TOPLEFT", self.actionPanel, "BOTTOMLEFT", 0, -4)
    wrap:SetPoint("BOTTOMRIGHT", self.actionPanel, "BOTTOMLEFT", width, -(4 + barH))
  else
    wrap:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 18, 6)
    wrap:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", 18 + width, 6 + barH)
  end
  wrap:SetFrameLevel((parent:GetFrameLevel() or 1) + 3)
  -- Thin bar: large tooltip edgeSize eats the fill and the text.
  wrap:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 8,
    edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  wrap:SetBackdropColor(.025, .03, .04, .92)
  wrap:SetBackdropBorderColor(.18, .22, .28, 1)

  local bar = CreateFrame("StatusBar", "QtUIXPBarStatus", wrap)
  bar:SetPoint("TOPLEFT", wrap, "TOPLEFT", 2, -2)
  bar:SetPoint("BOTTOMRIGHT", wrap, "BOTTOMRIGHT", -2, 2)
  bar:SetStatusBarTexture(self.media.statusbar)
  bar:SetStatusBarColor(.38, .28, .78)
  wrap.status = bar

  bar.background = bar:CreateTexture(nil, "BACKGROUND")
  bar.background:SetAllPoints()
  bar.background:SetTexture(self.media.statusbar)
  bar.background:SetVertexColor(.035, .04, .055, .9)

  wrap.label = CreateFrame("Frame", nil, wrap)
  wrap.label:SetPoint("TOPLEFT", wrap, "TOPLEFT", 0, 0)
  wrap.label:SetPoint("BOTTOMRIGHT", wrap, "BOTTOMRIGHT", 0, 0)
  if wrap.label.SetFrameLevel then
    wrap.label:SetFrameLevel((wrap:GetFrameLevel() or 5) + 8)
  end
  if wrap.label.EnableMouse then wrap.label:EnableMouse(false) end
  ApplyXPBarFont(wrap)

  wrap:EnableMouse(true)
  wrap:SetScript("OnEnter", function()
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
  wrap:SetScript("OnLeave", function() GameTooltip:Hide() end)

  local events = CreateFrame("Frame", "QtUIXPEvents")
  events:RegisterEvent("PLAYER_XP_UPDATE")
  events:RegisterEvent("UPDATE_EXHAUSTION")
  events:RegisterEvent("PLAYER_LEVEL_UP")
  events:RegisterEvent("PLAYER_ENTERING_WORLD")
  pcall(events.RegisterEvent, events, "PLAYER_UPDATE_RESTING")
  events:SetScript("OnEvent", UpdateXPBar)

  self.xpBar = wrap
  UpdateXPBar()
end

local autoUnshiftInstalled
local function InstallAutoUnshift()
  if autoUnshiftInstalled then return end
  autoUnshiftInstalled = true

  -- Leave form via the shapeshift bar, not GetPlayerBuff*. Scanning player
  -- buff slots in the same frame as Tiger's Fury crashes Emberveil (0x338).
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

  local function ActiveFormIndex()
    if type(GetNumShapeshiftForms) ~= "function" or type(GetShapeshiftFormInfo) ~= "function" then
      return nil
    end
    local n = tonumber(GetNumShapeshiftForms()) or 0
    local i
    for i = 1, n do
      local _, _, active = GetShapeshiftFormInfo(i)
      if active == true or active == 1 or active == "1" then return i end
    end
    return nil
  end

  local function StillInForm()
    return ActiveFormIndex() and true or nil
  end

  local function LeaveShapeshift()
    local index = ActiveFormIndex()
    if not index then return nil end
    if type(CastShapeshiftForm) == "function" then
      pcall(CastShapeshiftForm, index)
      return true
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
    local onSelf = pending.onSelf
    StopPending()
    if slot and type(UseAction) == "function" then
      pcall(UseAction, slot, 0, onSelf)
    end
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
    pending.slot = QtUI.qtLastAction
    pending.onSelf = QtUI.qtLastOnSelf
    pending.elapsed = 0
    pending.retry = 0
    pending:SetScript("OnUpdate", PendingOnUpdate)
    pending:Show()
  end

  local function HandleError(text)
    if not FeatureOn() or not IsShapeshiftError(text) then return nil end
    -- Right-clicking a friendly (inspect, trade, follow) is interact, not a cast.
    if getglobal("ERR_CANT_INTERACT_SHAPESHIFTED") and text == ERR_CANT_INTERACT_SHAPESHIFTED then
      return nil
    end
    local now = GetTime()
    if not QtUI.qtLastAction or not QtUI.qtLastActionTime or (now - QtUI.qtLastActionTime) > .5 then
      return nil
    end
    LeaveShapeshift()
    QueueRecast()
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
  if panel.SetBackdrop then pcall(panel.SetBackdrop, panel, nil) end
  PassClicksThrough(panel)
  self.actionPanel = panel

  -- MultiBarBottomLeft used to share the main panel. It is its own bar so
  -- each 12-button strip can use 1x12 / 3x4 / 12x1 independently.
  local extraPanel = self:CreatePanel("QtUIExtraActionPanel", UIParent, 1)
  extraPanel:SetWidth(442)
  extraPanel:SetHeight(44)
  extraPanel:SetPoint("BOTTOM", panel, "TOP", 0, 4)
  if extraPanel.SetBackdrop then pcall(extraPanel.SetBackdrop, extraPanel, nil) end
  PassClicksThrough(extraPanel)
  self.extraActionPanel = extraPanel

  -- Emberveil leaves the second multi-action row partially off-screen when
  -- its original bar geometry is active. Give slots 49-60 a compact QtUI
  -- panel of their own at bottom-right instead.
  local utilityPanel = self:CreatePanel("QtUIUtilityActionPanel", UIParent, 1)
  utilityPanel:SetWidth(442)
  utilityPanel:SetHeight(44)
  utilityPanel:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -14, 14)
  if utilityPanel.SetBackdrop then pcall(utilityPanel.SetBackdrop, utilityPanel, nil) end
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
  if sideRight.SetBackdrop then pcall(sideRight.SetBackdrop, sideRight, nil) end
  PassClicksThrough(sideRight)
  self.sideRightPanel = sideRight

  local sideLeft = self:CreatePanel("QtUISideLeftPanel", UIParent, 1)
  sideLeft:SetPoint("RIGHT", sideRight, "LEFT", -8, 0)
  if sideLeft.SetBackdrop then pcall(sideLeft.SetBackdrop, sideLeft, nil) end
  PassClicksThrough(sideLeft)
  self.sideLeftPanel = sideLeft

  if SHOW_MULTI_ACTIONBAR_3 ~= nil then SHOW_MULTI_ACTIONBAR_3 = 1 end
  if SHOW_MULTI_ACTIONBAR_4 ~= nil then SHOW_MULTI_ACTIONBAR_4 = 1 end
  if type(MultiActionBar_Update) == "function" then pcall(MultiActionBar_Update) end

  self.RefreshAllActionButtons = RefreshActionButtons
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
