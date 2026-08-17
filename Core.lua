PotatoUI = CreateFrame("Frame", "PotatoUIEventFrame", UIParent)
PotatoUI.version = "0.10.8"
PotatoUI.media = {
  statusbar = "Interface\\TargetingFrame\\UI-StatusBar",
}

local function Print(message)
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00PotatoUI|r: " .. message)
  end
end

function PotatoUI:Print(message)
  Print(message)
end

local function IsLegacyTrue(value)
  return value == true or value == 1 or value == "1"
end

-- Default UI: while a friendly spell is waiting for a target, click the
-- unit frame to cast it (SpellTargetUnit) instead of changing target.
function PotatoUI:UsePendingActionOnUnit(unit)
  if not unit then return nil end

  -- SpellCanTargetUnit is only true while a spell is waiting for a unit.
  -- SpellIsTargeting() alone is not trusted on Emberveil (can stay truthy).
  local pending
  if type(SpellCanTargetUnit) == "function" then
    local ok, can = pcall(SpellCanTargetUnit, unit)
    pending = ok and IsLegacyTrue(can)
  elseif type(SpellIsTargeting) == "function" then
    local ok, targeting = pcall(SpellIsTargeting)
    pending = ok and targeting == true
  end

  if pending then
    if arg1 == "RightButton" then
      if type(SpellStopTargeting) == "function" then pcall(SpellStopTargeting) end
      return true
    end
    if type(SpellTargetUnit) == "function" then
      pcall(SpellTargetUnit, unit)
    end
    return true
  end

  if type(CursorHasItem) == "function" then
    local ok, hasItem = pcall(CursorHasItem)
    if ok and hasItem == true then
      if type(DropItemOnUnit) == "function" then
        pcall(DropItemOnUnit, unit)
      end
      return true
    end
  end
  return nil
end

function PotatoUI:CreatePanel(name, parent, level)
  local panel = CreateFrame("Frame", name, parent or UIParent)
  panel:SetFrameStrata("BACKGROUND")
  panel:SetFrameLevel(level or 1)
  panel:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 8,
    edgeSize = 12,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  panel:SetBackdropColor(.025, .035, .045, .92)
  panel:SetBackdropBorderColor(.18, .24, .28, 1)
  return panel
end

function PotatoUI:HideFrame(frame)
  if not frame then return end
  frame:Hide()
  if type(frame.SetScript) == "function" then
    frame:SetScript("OnShow", function() this:Hide() end)
  end
end

local function EnsureColor(value, r, g, b, a)
  if type(value) ~= "table" then value = {} end
  value.r = tonumber(value.r) or r
  value.g = tonumber(value.g) or g
  value.b = tonumber(value.b) or b
  if a ~= nil and value.a == nil then value.a = a end
  if value.a ~= nil then value.a = tonumber(value.a) or a or 1 end
  return value
end

local function EnsureBar(bars, name, columns, size, rows)
  if not bars[name] then bars[name] = {} end
  local bar = bars[name]
  if not bar.columns then bar.columns = columns end
  if not bar.size then bar.size = size end
  if not bar.spacing then bar.spacing = 2 end
  if not bar.rows then bar.rows = rows or 12 end
  if bar.columns < 1 then bar.columns = 1 end
  if bar.columns > 24 then bar.columns = 24 end
  if bar.rows < 1 then bar.rows = 1 end
  if bar.rows > 12 then bar.rows = 12 end
  if bar.size < 20 then bar.size = 20 end
  if bar.size > 52 then bar.size = 52 end
  if bar.spacing < 0 then bar.spacing = 0 end
  if bar.spacing > 12 then bar.spacing = 12 end
  return bar
end

function PotatoUI:EnsureLayoutDefaults()
  if not PotatoUIDB.layout then PotatoUIDB.layout = {} end
  local layout = PotatoUIDB.layout
  if not layout.scale then layout.scale = 1 end
  layout.scale = tonumber(layout.scale) or 1
  if layout.scale < 0.6 then layout.scale = 0.6 end
  if layout.scale > 1.6 then layout.scale = 1.6 end
  if not layout.unitWidth then layout.unitWidth = 260 end
  if not layout.unitHeight then layout.unitHeight = 54 end
  if layout.unitWidth < 160 then layout.unitWidth = 160 end
  if layout.unitWidth > 420 then layout.unitWidth = 420 end
  if layout.unitHeight < 40 then layout.unitHeight = 40 end
  if layout.unitHeight > 80 then layout.unitHeight = 80 end
  if layout.playerClassColor == nil then layout.playerClassColor = true end
  layout.playerHealth = EnsureColor(layout.playerHealth, .2, .75, .25)
  layout.enemyHealth = EnsureColor(layout.enemyHealth, .78, .12, .12)
  layout.friendHealth = EnsureColor(layout.friendHealth, .15, .72, .22)
  layout.neutralHealth = EnsureColor(layout.neutralHealth, .82, .68, .16)
  if not layout.partyWidth then layout.partyWidth = 220 end
  if not layout.partyHeight then layout.partyHeight = 44 end
  if not layout.partySpacing then layout.partySpacing = 29 end
  if not layout.petWidth then layout.petWidth = 180 end
  if layout.partyWidth < 140 then layout.partyWidth = 140 end
  if layout.partyWidth > 360 then layout.partyWidth = 360 end
  if layout.partyHeight < 32 then layout.partyHeight = 32 end
  if layout.partyHeight > 70 then layout.partyHeight = 70 end
  if layout.partySpacing < 4 then layout.partySpacing = 4 end
  if layout.partySpacing > 40 then layout.partySpacing = 40 end
  if layout.petWidth < 100 then layout.petWidth = 100 end
  if layout.petWidth > 280 then layout.petWidth = 280 end
  if layout.partyClassColor == nil then layout.partyClassColor = true end
  layout.partyHealth = EnsureColor(layout.partyHealth, .2, .72, .28)
  if layout.barShowBackground == nil then layout.barShowBackground = false end
  layout.barBackground = EnsureColor(layout.barBackground, .025, .035, .045, .85)
  layout.barBorder = EnsureColor(layout.barBorder, .18, .24, .28, 1)
  if layout.slotShowBackground == nil then layout.slotShowBackground = true end
  layout.slotBackground = EnsureColor(layout.slotBackground, .02, .025, .03, .96)
  layout.slotBorder = EnsureColor(layout.slotBorder, .14, .18, .2, 1)
  if not layout.bars then layout.bars = {} end
  EnsureBar(layout.bars, "main", 12, 34, 2)
  EnsureBar(layout.bars, "utility", 12, 34, 1)
  EnsureBar(layout.bars, "aux", 10, 34, 1)
  EnsureBar(layout.bars, "sideRight", 3, 34, 4)
  EnsureBar(layout.bars, "sideLeft", 3, 34, 4)
  if not layout.sideGridUpgraded then
    local function UpgradeSideDefault(bar)
      if bar and bar.columns == 1 and bar.rows == 12 then
        bar.columns = 3
        bar.rows = 4
      end
    end
    UpgradeSideDefault(layout.bars.sideRight)
    UpgradeSideDefault(layout.bars.sideLeft)
    layout.sideGridUpgraded = true
  end
  return layout
end

function PotatoUI:GetLayout()
  return self:EnsureLayoutDefaults()
end

function PotatoUI:GetBarConfig(name)
  local layout = self:GetLayout()
  return layout.bars[name] or layout.bars.main
end

function PotatoUI:ApplyScale()
  local scale = self:GetLayout().scale or 1
  -- Only PotatoUI-created top-level frames. Children inherit.
  local frames = {
    self.playerFrame, self.targetFrame, self.comboFrame,
    self.partyAnchor, self.playerPetFrame,
    self.actionPanel, self.utilityActionPanel, self.auxiliaryPanel,
    self.sideRightPanel, self.sideLeftPanel,
    self.dataBar, self.bagFrame,
  }
  local i
  for i = 1, table.getn(frames) do
    local frame = frames[i]
    if frame and frame.SetScale then pcall(frame.SetScale, frame, scale) end
  end
end

function PotatoUI:ApplyActionBarBackground()
  local layout = self:GetLayout()
  local function Paint(panel)
    if not panel or not panel.SetBackdropColor then return end
    if not panel.GetBackdrop or not panel:GetBackdrop() then
      panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
      })
    end
    if layout.barShowBackground then
      local c = layout.barBackground
      local b = layout.barBorder
      panel:SetBackdropColor(c.r, c.g, c.b, c.a or .85)
      panel:SetBackdropBorderColor(b.r, b.g, b.b, b.a or 1)
    else
      panel:SetBackdropColor(0, 0, 0, 0)
      panel:SetBackdropBorderColor(0, 0, 0, 0)
    end
  end
  Paint(self.actionPanel)
  Paint(self.utilityActionPanel)
  Paint(self.auxiliaryPanel)
  Paint(self.sideRightPanel)
  Paint(self.sideLeftPanel)
  -- Backdrop makes frames eat clicks. Only the buttons should be clickable.
  local panels = {
    self.actionPanel, self.utilityActionPanel, self.auxiliaryPanel,
    self.sideRightPanel, self.sideLeftPanel,
  }
  local i
  for i = 1, table.getn(panels) do
    if panels[i] and panels[i].EnableMouse then
      pcall(panels[i].EnableMouse, panels[i], false)
    end
  end
end

function PotatoUI:EnsureSlotCell(button, panel)
  if not button then return end
  if button.PotatoUISlotBg then
    button.PotatoUISlotBg:Hide()
    if button.PotatoUISlotBg.SetTexture then button.PotatoUISlotBg:SetTexture(nil) end
  end
  if button.PotatoUIBorder then
    button.PotatoUIBorder:Hide()
  end
  panel = panel or button:GetParent()
  if not panel then return end

  local cell = button.PotatoUICell
  if not cell then
    cell = CreateFrame("Frame", nil, panel)
    cell:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 8, edgeSize = 10,
      insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    button.PotatoUICell = cell
  else
    cell:SetParent(panel)
  end

  local panelLevel = 1
  if panel.GetFrameLevel then panelLevel = panel:GetFrameLevel() or 1 end
  cell:SetFrameLevel(math.max(0, panelLevel))
  if button.SetFrameLevel then button:SetFrameLevel(panelLevel + 4) end
  cell:ClearAllPoints()
  -- Fill more of the Quickslot2 well without covering the round rim.
  cell:SetPoint("TOPLEFT", button, "TOPLEFT", -5, 5)
  cell:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 5, -5)
  return cell
end

local function SlotHasSpell(button, prefix, index)
  if prefix == "PetActionButton" and type(GetPetActionInfo) == "function" then
    local name = GetPetActionInfo(index)
    return name and name ~= ""
  end
  if prefix == "ShapeshiftButton" and type(GetShapeshiftFormInfo) == "function" then
    local icon = GetShapeshiftFormInfo(index)
    return icon and icon ~= ""
  end
  local action = button.PotatoUIAction or button.action
  if not action and button.GetID then action = button:GetID() end
  if action and type(HasAction) == "function" then
    local ok, has = pcall(HasAction, action)
    if ok and (has == true or has == 1 or has == "1") then return true end
  end
  return nil
end

function PotatoUI:ApplySlotBackgrounds()
  local layout = self:GetLayout()
  local names = {
    "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
    "MultiBarRightButton", "MultiBarLeftButton",
    "ShapeshiftButton", "PetActionButton",
  }
  local maxCount = { 12, 12, 12, 12, 12, 10, 10 }
  local n
  for n = 1, table.getn(names) do
    local i
    local last = maxCount[n]
    for i = 1, last do
      local button = getglobal(names[n] .. i)
      if button then
        local shown = button.IsShown and button:IsShown()
        local cell = self:EnsureSlotCell(button, button:GetParent())
        if cell then
          if shown and layout.slotShowBackground and not SlotHasSpell(button, names[n], i) then
            local c = layout.slotBackground
            cell:SetBackdropColor(c.r, c.g, c.b, c.a or .96)
            cell:SetBackdropBorderColor(c.r, c.g, c.b, 0)
            cell:Show()
          else
            cell:Hide()
          end
        end
        if shown then
          local filled = SlotHasSpell(button, names[n], i)
          -- Shapeshift stores the form icon on NormalTexture. Only stamp
          -- Quickslot2 onto empty stance slots so the icon stays visible.
          if button.SetNormalTexture and (names[n] ~= "ShapeshiftButton" or not filled) then
            button:SetNormalTexture("Interface\\Buttons\\UI-Quickslot2")
          end
          local ring = button.GetNormalTexture and button:GetNormalTexture()
          if names[n] == "ShapeshiftButton" and filled then
            if not button.PotatoUIRing then
              button.PotatoUIRing = button:CreateTexture(nil, "OVERLAY")
              button.PotatoUIRing:SetTexture("Interface\\Buttons\\UI-Quickslot2")
            end
            ring = button.PotatoUIRing
            ring:Show()
          elseif button.PotatoUIRing then
            button.PotatoUIRing:Hide()
          end
          if ring then
            local size = button.GetWidth and button:GetWidth() or 34
            local pad = math.floor(size * 0.38)
            if pad < 10 then pad = 10 end
            ring:ClearAllPoints()
            ring:SetPoint("TOPLEFT", button, "TOPLEFT", -pad, pad)
            ring:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", pad, -pad)
            ring:SetAlpha(1)
          end
        end
      end
    end
  end
end

function PotatoUI:ApplyLayout()
  self:EnsureLayoutDefaults()
  if self.LayoutActionBars then self:LayoutActionBars() end
  if self.ApplyActionBarBackground then self:ApplyActionBarBackground() end
  if self.ApplySlotBackgrounds then self:ApplySlotBackgrounds() end
  if self.ApplyUnitFrameLayout then self:ApplyUnitFrameLayout() end
  if self.ApplyPartyFrameLayout then self:ApplyPartyFrameLayout() end
  if self.ApplyScale then self:ApplyScale() end
  if self.UpdateUnitFrames then self:UpdateUnitFrames() end
  if self.UpdatePartyFrames then self:UpdatePartyFrames() end
end

function PotatoUI:EnsureDB()
  if not PotatoUIDB then PotatoUIDB = {} end
  PotatoUIDB.scale = nil
  if self.EnsureFeatureDefaults then self:EnsureFeatureDefaults() end
  if self.EnsureLayoutDefaults then self:EnsureLayoutDefaults() end
end

function PotatoUI:Initialize()
  if self.initialized then return end
  self.initialized = true
  self:EnsureDB()

  local function SafeSetup(label, fn)
    if not fn then return end
    local ok, err = pcall(fn, self)
    if not ok then
      Print("Error in " .. label .. ": " .. tostring(err))
    end
  end

  if self:IsFeatureEnabled("actionBars") then SafeSetup("actionBars", self.SetupActionBars) end
  if self:IsFeatureEnabled("experienceBar") then SafeSetup("experienceBar", self.SetupXPBar) end
  if self:IsFeatureEnabled("unitFrames") then SafeSetup("unitFrames", self.SetupUnitFrames) end
  if self:IsFeatureEnabled("castBar") then SafeSetup("castBar", self.SetupCastBar) end
  if self:IsFeatureEnabled("partyFrames") then SafeSetup("partyFrames", self.SetupPartyFrames) end
  if self:IsFeatureEnabled("bags") then SafeSetup("bags", self.SetupBags) end
  if self:IsFeatureEnabled("minimap") then SafeSetup("minimap", self.SetupMinimap) end
  if self:IsFeatureEnabled("mapReveal") then SafeSetup("mapReveal", self.SetupWorldMap) end
  if self:IsFeatureEnabled("autoLoot") then SafeSetup("autoLoot", self.SetupAutoLoot) end
  if self:IsFeatureEnabled("autoSell") then SafeSetup("autoSell", self.SetupAutoSell) end
  if self:IsFeatureEnabled("dataText") then SafeSetup("dataText", self.SetupDataText) end
  SafeSetup("settingsButton", self.SetupSettingsButton)
  SafeSetup("moveMode", self.SetupMoveMode)
  SafeSetup("applyLayout", self.ApplyLayout)

  Print("Loaded. Type /pui for commands.")
end

SLASH_POTATOUI1 = "/potatoui"
SLASH_POTATOUI2 = "/pui"
SlashCmdList["POTATOUI"] = function(message)
  local command = string.lower(message or "")
  command = string.gsub(command, "^%s+", "")
  command = string.gsub(command, "%s+$", "")
  if command == "reset" then
    PotatoUIDB = { positions = {} }
    if type(ReloadUI) == "function" then
      ReloadUI()
    elseif type(ConsoleExec) == "function" then
      ConsoleExec("reloadui")
    else
      Print("Settings reset. Restart Emberveil to apply the default layout.")
    end
  elseif command == "reload" then
    if type(ReloadUI) == "function" then
      ReloadUI()
    elseif type(ConsoleExec) == "function" then
      ConsoleExec("reloadui")
    else
      Print("This Emberveil build does not expose a UI reload function; restart the client instead.")
    end
  elseif command == "bags" then
    if PotatoUI.ToggleBags then PotatoUI:ToggleBags() end
  elseif command == "move" then
    if PotatoUI.ToggleMoveMode then PotatoUI:ToggleMoveMode() end
  elseif command == "settings" or command == "config" then
    if PotatoUI.ToggleSettings then PotatoUI:ToggleSettings() end
  else
    Print("Loaded v" .. PotatoUI.version .. ". Commands: /pui settings, /pui move, /pui bags, /pui reload, /pui reset")
  end
end

PotatoUI:SetScript("OnEvent", function()
  if event == "ADDON_LOADED" and arg1 == "PotatoUI" then
    PotatoUI:EnsureDB()
  elseif event == "PLAYER_ENTERING_WORLD" then
    PotatoUI:Initialize()
  end
end)
PotatoUI:RegisterEvent("ADDON_LOADED")
PotatoUI:RegisterEvent("PLAYER_ENTERING_WORLD")
