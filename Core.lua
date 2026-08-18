QtUI = CreateFrame("Frame", "QtUIEventFrame", UIParent)
QtUI.version = "0.10.8"
QtUI.media = {
  statusbar = "Interface\\TargetingFrame\\UI-StatusBar",
}

local function Print(message)
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00QtUI|r: " .. message)
  end
end

function QtUI:Print(message)
  Print(message)
end

local function IsLegacyTrue(value)
  return value == true or value == 1 or value == "1"
end

-- Default UI: while a friendly spell is waiting for a target, click the
-- unit frame to cast it (SpellTargetUnit) instead of changing target.
function QtUI:UsePendingActionOnUnit(unit)
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

function QtUI:CreatePanel(name, parent, level)
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

function QtUI:HideFrame(frame)
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
  if bar.columns > 12 then bar.columns = 12 end
  if bar.rows < 1 then bar.rows = 1 end
  if bar.rows > 12 then bar.rows = 12 end
  if bar.size < 20 then bar.size = 20 end
  if bar.size > 52 then bar.size = 52 end
  if bar.spacing < 0 then bar.spacing = 0 end
  if bar.spacing > 12 then bar.spacing = 12 end
  if bar.enabled == nil then bar.enabled = true end
  if not bar.hotkeyAlign then bar.hotkeyAlign = "center" end
  if bar.hotkeyAlign ~= "left" and bar.hotkeyAlign ~= "right" and bar.hotkeyAlign ~= "top"
      and bar.hotkeyAlign ~= "bottom" and bar.hotkeyAlign ~= "center"
      and bar.hotkeyAlign ~= "topleft" and bar.hotkeyAlign ~= "topright"
      and bar.hotkeyAlign ~= "bottomleft" and bar.hotkeyAlign ~= "bottomright" then
    bar.hotkeyAlign = "center"
  end
  if not bar.hotkeySize then bar.hotkeySize = 10 end
  bar.hotkeySize = tonumber(bar.hotkeySize) or 10
  if bar.hotkeySize < 7 then bar.hotkeySize = 7 end
  if bar.hotkeySize > 16 then bar.hotkeySize = 16 end
  if bar.hotkeyShadow == nil then bar.hotkeyShadow = 1 end
  bar.hotkeyShadow = tonumber(bar.hotkeyShadow) or 1
  if bar.hotkeyShadow < 0 then bar.hotkeyShadow = 0 end
  if bar.hotkeyShadow > 4 then bar.hotkeyShadow = 4 end
  return bar
end

function QtUI:EnsureLayoutDefaults()
  if not QtUIDB.layout then QtUIDB.layout = {} end
  local layout = QtUIDB.layout
  layout.scale = nil
  if not layout.unitWidth then layout.unitWidth = 260 end
  if not layout.unitHeight then layout.unitHeight = 54 end
  if layout.unitWidth < 160 then layout.unitWidth = 160 end
  if layout.unitWidth > 420 then layout.unitWidth = 420 end
  if layout.unitHeight < 40 then layout.unitHeight = 40 end
  if layout.unitHeight > 80 then layout.unitHeight = 80 end
  if layout.playerClassColor == nil then layout.playerClassColor = true end
  if layout.unitGradient == nil then layout.unitGradient = true end
  if not layout.unitPowerHeight then layout.unitPowerHeight = 13 end
  layout.unitPowerHeight = tonumber(layout.unitPowerHeight) or 13
  if layout.unitPowerHeight < 6 then layout.unitPowerHeight = 6 end
  if layout.unitPowerHeight > 28 then layout.unitPowerHeight = 28 end
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
  if not layout.unitStyle then layout.unitStyle = {} end
  local function EnsureAlign(value, fallback)
    if value == "left" or value == "right" or value == "top" or value == "bottom"
        or value == "center" or value == "topleft" or value == "topright"
        or value == "bottomleft" or value == "bottomright" then
      return value
    end
    return fallback
  end
  local function EnsureUnitStyle(name, defaults)
    if not layout.unitStyle[name] then layout.unitStyle[name] = {} end
    local style = layout.unitStyle[name]
    if not style.width then style.width = defaults.width end
    if not style.height then style.height = defaults.height end
    if not style.powerHeight then style.powerHeight = defaults.powerHeight end
    if not style.spacing then style.spacing = defaults.spacing end
    style.width = tonumber(style.width) or defaults.width
    style.height = tonumber(style.height) or defaults.height
    if style.powerHeight then style.powerHeight = tonumber(style.powerHeight) or defaults.powerHeight end
    if style.spacing then style.spacing = tonumber(style.spacing) or defaults.spacing end
    local minWidth = defaults.minWidth or 100
    if style.width < minWidth then style.width = minWidth end
    if style.width > 420 then style.width = 420 end
    if style.height and style.height < 24 then style.height = 24 end
    if style.height and style.height > 100 then style.height = 100 end
    if style.powerHeight and style.powerHeight < 6 then style.powerHeight = 6 end
    if style.powerHeight and style.powerHeight > 28 then style.powerHeight = 28 end
    style.nameAlign = EnsureAlign(style.nameAlign, defaults.nameAlign)
    style.healthAlign = EnsureAlign(style.healthAlign, defaults.healthAlign)
    style.powerAlign = EnsureAlign(style.powerAlign, defaults.powerAlign)
    style.classAlign = EnsureAlign(style.classAlign, defaults.classAlign)
    return style
  end
  EnsureUnitStyle("player", {
    width = layout.unitWidth or 260, height = layout.unitHeight or 54,
    powerHeight = layout.unitPowerHeight or 13,
    nameAlign = "left", healthAlign = "right", powerAlign = "right",
  })
  EnsureUnitStyle("target", {
    width = layout.unitWidth or 260, height = layout.unitHeight or 54,
    powerHeight = layout.unitPowerHeight or 13,
    nameAlign = "left", healthAlign = "right", powerAlign = "right", classAlign = "top",
  })
  EnsureUnitStyle("party", {
    width = layout.partyWidth or 220, height = layout.partyHeight or 44,
    powerHeight = 9, spacing = layout.partySpacing or 29,
    nameAlign = "left", healthAlign = "right", powerAlign = "right",
  })
  EnsureUnitStyle("pet", {
    width = layout.petWidth or 180, height = 27,
    nameAlign = "left", healthAlign = "right",
  })
  EnsureUnitStyle("targettarget", {
    width = 180, height = 36, powerHeight = 8, minWidth = 80,
    nameAlign = "left", healthAlign = "right", powerAlign = "right",
  })
  if layout.barShowBackground == nil then layout.barShowBackground = false end
  if layout.unshiftToCast == nil then layout.unshiftToCast = true end
  if layout.cooldownText == nil then layout.cooldownText = true end
  if layout.barRangeColor == nil then layout.barRangeColor = true end
  if layout.energyTick == nil then layout.energyTick = true end
  layout.energyTickWidth = tonumber(layout.energyTickWidth) or 1
  if layout.energyTickWidth < 1 then layout.energyTickWidth = 1 end
  if layout.energyTickWidth > 8 then layout.energyTickWidth = 8 end
  layout.energyTickAlpha = tonumber(layout.energyTickAlpha)
  if not layout.energyTickAlpha then layout.energyTickAlpha = .95 end
  if layout.energyTickAlpha < .1 then layout.energyTickAlpha = .1 end
  if layout.energyTickAlpha > 1 then layout.energyTickAlpha = 1 end
  if layout.eqCompare == nil then layout.eqCompare = true end
  if layout.showTargetTarget == nil then layout.showTargetTarget = true end
  layout.barBackground = EnsureColor(layout.barBackground, .025, .035, .045, .85)
  layout.barBorder = EnsureColor(layout.barBorder, .18, .24, .28, 1)
  if layout.slotShowBackground == nil then layout.slotShowBackground = true end
  layout.slotBackground = EnsureColor(layout.slotBackground, .02, .025, .03, .96)
  layout.slotBorder = EnsureColor(layout.slotBorder, .14, .18, .2, 1)
  if not layout.bagSlotSize then layout.bagSlotSize = 36 end
  layout.bagSlotSize = tonumber(layout.bagSlotSize) or 36
  if layout.bagSlotSize < 24 then layout.bagSlotSize = 24 end
  if layout.bagSlotSize > 52 then layout.bagSlotSize = 52 end
  if not layout.bagColumns then layout.bagColumns = 10 end
  layout.bagColumns = tonumber(layout.bagColumns) or 10
  if layout.bagColumns < 6 then layout.bagColumns = 6 end
  if layout.bagColumns > 16 then layout.bagColumns = 16 end
  if not layout.bars then layout.bars = {} end
  EnsureBar(layout.bars, "main", 12, 34, 1)
  if not layout.bars.extra and layout.bars.main then
    layout.bars.extra = {
      columns = layout.bars.main.columns,
      size = layout.bars.main.size,
      spacing = layout.bars.main.spacing,
      rows = 1,
    }
  end
  EnsureBar(layout.bars, "extra", 12, 34, 1)
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

function QtUI:GetLayout()
  return self:EnsureLayoutDefaults()
end

function QtUI:GetBarConfig(name)
  local layout = self:GetLayout()
  return layout.bars[name] or layout.bars.main
end

function QtUI:GetUnitStyle(name)
  local layout = self:GetLayout()
  if layout.unitStyle and layout.unitStyle[name] then return layout.unitStyle[name] end
  return layout.unitStyle and layout.unitStyle.player
end

function QtUI:IsBarEnabled(name)
  local bar = self:GetBarConfig(name)
  return not bar or bar.enabled ~= false
end

local function LayoutFlagOn(value)
  return value == true or value == 1 or value == "1"
end

local function BarPanels(self)
  return {
    { self.actionPanel, "main" },
    { self.extraActionPanel, "extra" },
    { self.utilityActionPanel, "utility" },
    { self.auxiliaryPanel, "aux" },
    { self.sideRightPanel, "sideRight" },
    { self.sideLeftPanel, "sideLeft" },
  }
end

local function NudgeBarPanels(self)
  -- Emberveil often ignores SetBackdrop until the frame is resized or shown.
  local panels = BarPanels(self)
  local i
  for i = 1, table.getn(panels) do
    local panel = panels[i][1]
    local key = panels[i][2]
    if panel and self:IsBarEnabled(key) and panel.GetWidth and panel.SetWidth then
      local width = panel:GetWidth() or 0
      local height = panel.GetHeight and panel:GetHeight() or 0
      if width > 0 then
        panel:SetWidth(width + 1)
        if height > 0 and panel.SetHeight then panel:SetHeight(height + 1) end
        panel:SetWidth(width)
        if height > 0 and panel.SetHeight then panel:SetHeight(height) end
      end
      if panel.Show then pcall(panel.Show, panel) end
    end
  end
end

function QtUI:ApplyActionBarBackground()
  local layout = self:GetLayout()
  local function Paint(panel, key)
    if not panel or not panel.SetBackdropColor then return end
    -- Always re-stamp the backdrop. Emberveil can keep a dead GetBackdrop()
    -- after login so a skipped SetBackdrop leaves the bar fully transparent.
    if panel.SetBackdrop then
      pcall(panel.SetBackdrop, panel, nil)
      panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
      })
    end
    if LayoutFlagOn(layout.barShowBackground) and self:IsBarEnabled(key) then
      local c = layout.barBackground or {}
      local b = layout.barBorder or {}
      panel:SetBackdropColor(c.r or .025, c.g or .035, c.b or .045, c.a or .85)
      panel:SetBackdropBorderColor(b.r or .18, b.g or .24, b.b or .28, b.a or 1)
      if panel.Show then pcall(panel.Show, panel) end
      if panel.SetAlpha then pcall(panel.SetAlpha, panel, 1) end
    else
      panel:SetBackdropColor(0, 0, 0, 0)
      panel:SetBackdropBorderColor(0, 0, 0, 0)
    end
  end
  Paint(self.actionPanel, "main")
  Paint(self.extraActionPanel, "extra")
  Paint(self.utilityActionPanel, "utility")
  Paint(self.auxiliaryPanel, "aux")
  Paint(self.sideRightPanel, "sideRight")
  Paint(self.sideLeftPanel, "sideLeft")
  NudgeBarPanels(self)
  -- Backdrop makes frames eat clicks. Only the buttons should be clickable.
  local panels = BarPanels(self)
  local i
  for i = 1, table.getn(panels) do
    local panel = panels[i][1]
    if panel and panel.EnableMouse then
      pcall(panel.EnableMouse, panel, false)
    end
  end
end

function QtUI:EnsureSlotCell(button, panel)
  if not button then return end
  if button.QtUISlotBg then
    button.QtUISlotBg:Hide()
    if button.QtUISlotBg.SetTexture then button.QtUISlotBg:SetTexture(nil) end
  end
  if button.QtUIBorder then
    button.QtUIBorder:Hide()
  end
  panel = panel or button:GetParent()
  if not panel then return end

  local size = 34
  if button.GetWidth then size = button:GetWidth() or 34 end
  local extra = 0
  local edge = 10
  local inset = 2
  -- Below 28 the tooltip border eats the fill. Grow the cell back toward 28
  -- and use a thinner edge so empty wells stay visible.
  if size < 28 then
    extra = math.floor((28 - size) / 2 + 0.5)
    if extra < 1 then extra = 1 end
    edge = 8
    inset = 1
  end

  local cell = button.QtUICell
  if not cell then
    cell = CreateFrame("Frame", nil, panel)
    button.QtUICell = cell
  elseif panel then
    cell:SetParent(panel)
  end
  if cell.art then
    if cell.art.SetTexture then cell.art:SetTexture(nil) end
    if cell.art.Hide then pcall(cell.art.Hide, cell.art) end
  end
  local stamp = tostring(size) .. ":" .. extra .. ":" .. edge
  if not self.forceSlotCell and cell.QtUIStamp == stamp then return cell end

  cell:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = edge,
    insets = { left = inset, right = inset, top = inset, bottom = inset },
  })

  local panelLevel = 1
  if panel.GetFrameLevel then panelLevel = panel:GetFrameLevel() or 1 end
  cell:SetFrameLevel(math.max(0, panelLevel))
  if button.SetFrameLevel then button:SetFrameLevel(panelLevel + 4) end
  cell:ClearAllPoints()
  cell:SetPoint("TOPLEFT", button, "TOPLEFT", -extra, extra)
  cell:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", extra, -extra)
  cell.QtUIStamp = stamp
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
  local action = button.QtUIAction or button.action
  if not action and button.GetID then action = button:GetID() end
  if action and type(GetActionTexture) == "function" then
    local ok, texture = pcall(GetActionTexture, action)
    if ok then return texture and texture ~= "" end
  end
  if action and type(HasAction) == "function" then
    local ok, has = pcall(HasAction, action)
    if ok and (has == true or has == 1 or has == "1") then return true end
  end
  return nil
end

local function ButtonIsOnQtBar(button)
  if not button then return nil end
  if button.QtUIStyled then return true end
  if button.IsShown then
    local ok, shown = pcall(button.IsShown, button)
    if ok and (shown == true or shown == 1 or shown == "1") then return true end
  end
  local parent = button.GetParent and button:GetParent()
  if parent and parent.GetName then
    local name = parent:GetName()
    if name and string.find(name, "QtUI", 1, true) then return true end
  end
  return nil
end

function QtUI:EnsureButtonRim(button, size, keepNormalIcon)
  if not button then return end
  size = size or (button.GetWidth and button:GetWidth()) or 34
  local keep = keepNormalIcon and 1 or 0
  -- Native ActionButton_Update can run many times per second. Re-stamping
  -- the rim on every call is the single biggest idle cost of the bars.
  if not self.forceButtonRim and button.QtUIRing and button.QtUIRingSize == size and button.QtUIRingKeep == keep then
    if button.QtUIRing.Show then pcall(button.QtUIRing.Show, button.QtUIRing) end
    return
  end
  if not keepNormalIcon and button.SetNormalTexture then
    button:SetNormalTexture("Interface\\Buttons\\UI-Quickslot2")
  end
  -- Emberveil often has no NormalTexture yet at login. An overlay rim
  -- survives the later native ActionButton_Update wipe.
  if not button.QtUIRing then
    button.QtUIRing = button:CreateTexture(nil, "OVERLAY")
  end
  local ring = button.QtUIRing
  if ring.SetTexture then ring:SetTexture("Interface\\Buttons\\UI-Quickslot2") end
  local pad = math.floor(size * 0.38)
  if pad < 10 then pad = 10 end
  ring:ClearAllPoints()
  ring:SetPoint("TOPLEFT", button, "TOPLEFT", -pad, pad)
  ring:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", pad, -pad)
  if ring.SetAlpha then ring:SetAlpha(1) end
  if ring.Show then pcall(ring.Show, ring) end
  local normal = button.GetNormalTexture and button:GetNormalTexture()
  if normal and not keepNormalIcon then
    if normal.SetAlpha then normal:SetAlpha(1) end
    normal:ClearAllPoints()
    normal:SetPoint("TOPLEFT", button, "TOPLEFT", -pad, pad)
    normal:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", pad, -pad)
  end
  button.QtUIRingSize = size
  button.QtUIRingKeep = keep
end

function QtUI:ApplySlotBackgrounds()
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
        local shown = ButtonIsOnQtBar(button)
        local cell = self:EnsureSlotCell(button, button:GetParent())
        if cell then
          if shown and LayoutFlagOn(layout.slotShowBackground) and not SlotHasSpell(button, names[n], i) then
            local c = layout.slotBackground
            cell:SetBackdropColor(c.r, c.g, c.b, c.a or .96)
            cell:SetBackdropBorderColor(c.r, c.g, c.b, 0)
            cell:Show()
          else
            cell:Hide()
          end
        end
        local filled = SlotHasSpell(button, names[n], i)
        local keepIcon = names[n] == "ShapeshiftButton" and filled
        self:EnsureButtonRim(button, button.GetWidth and button:GetWidth(), keepIcon)
      end
    end
  end
end

function QtUI:RefreshBarChrome()
  -- Delayed login restamps must rebuild chrome even if size is unchanged;
  -- Emberveil can wipe backdrops and overlay textures after the first apply.
  self.forceButtonRim = true
  self.forceSlotCell = true
  if self.ApplyActionBarBackground then self:ApplyActionBarBackground() end
  if self.ApplySlotBackgrounds then self:ApplySlotBackgrounds() end
  self.forceButtonRim = nil
  self.forceSlotCell = nil
end

function QtUI:ScheduleBarChromeRefresh()
  local frame = self.barChromeRefresher
  if not frame then
    frame = CreateFrame("Frame", "QtUIBarChromeRefresh")
    self.barChromeRefresher = frame
  end
  -- Emberveil wipes bar chrome shortly after login. Three delayed restamps
  -- are enough; a 0.3s loop for four seconds was a large hitch source.
  frame.elapsed = 0
  frame.step = 0
  frame.times = { 0.4, 1.8, 4.2 }
  frame:SetScript("OnUpdate", function()
    this.elapsed = this.elapsed + (arg1 or 0)
    local nextStep = this.step + 1
    local due = this.times[nextStep]
    if due and this.elapsed >= due then
      this.step = nextStep
      if QtUI.RefreshBarChrome then QtUI:RefreshBarChrome() end
      if nextStep >= table.getn(this.times) then
        this:SetScript("OnUpdate", nil)
      end
    end
  end)
end

function QtUI:ApplyLayout()
  self:EnsureLayoutDefaults()
  if self.LayoutActionBars then self:LayoutActionBars() end
  if self.RefreshBarChrome then self:RefreshBarChrome() end
  if self.ApplyUnitFrameLayout then self:ApplyUnitFrameLayout() end
  if self.ApplyPartyFrameLayout then self:ApplyPartyFrameLayout() end
  if self.UpdateUnitFrames then self:UpdateUnitFrames() end
  if self.UpdatePartyFrames then self:UpdatePartyFrames() end
  if self.bagFrame and self.UpdateBags then self:UpdateBags() end
  if self.moveMode and self.SetMoveMode then self:SetMoveMode(true) end
  if not self.pulsingBarBackground and self.ScheduleBarChromeRefresh then
    self:ScheduleBarChromeRefresh()
  end
end

function QtUI:PulseActionBarBackground()
  if self.pulsingBarBackground then return end
  local layout = self:GetLayout()
  local saved = layout.barShowBackground
  local on = saved == true or saved == 1 or saved == "1"
  self.pulsingBarBackground = true
  -- Same sequence as clicking "Show action-bar background": Emberveil only
  -- draws the bar frame after the panel is laid out again, not after a lone
  -- SetBackdrop. Skip unit frames and bags so this stays a login-only hitch.
  layout.barShowBackground = not on
  if self.LayoutActionBars then self:LayoutActionBars() end
  if self.RefreshBarChrome then self:RefreshBarChrome() end
  layout.barShowBackground = saved
  if self.LayoutActionBars then self:LayoutActionBars() end
  if self.RefreshBarChrome then self:RefreshBarChrome() end
  self.pulsingBarBackground = nil
end

function QtUI:ScheduleBackgroundPulse()
  if self.backgroundPulseFrame then return end
  local frame = CreateFrame("Frame", "QtUIBackgroundPulse")
  self.backgroundPulseFrame = frame
  frame.elapsed = 0
  frame.stage = 0
  -- Emberveil wipes bar chrome after login and again a couple of seconds
  -- later. The last pulse catches the late wipe that used to leave the
  -- frame missing until the settings toggle.
  frame:SetScript("OnUpdate", function()
    this.elapsed = this.elapsed + (arg1 or 0)
    if this.stage == 0 and this.elapsed >= 1.0 then
      this.stage = 1
      if QtUI.PulseActionBarBackground then QtUI:PulseActionBarBackground() end
    elseif this.stage == 1 and this.elapsed >= 2.8 then
      this.stage = 2
      if QtUI.PulseActionBarBackground then QtUI:PulseActionBarBackground() end
    elseif this.stage == 2 and this.elapsed >= 5.0 then
      this.stage = 3
      if QtUI.PulseActionBarBackground then QtUI:PulseActionBarBackground() end
      this:SetScript("OnUpdate", nil)
    end
  end)
end

function QtUI:EnsureDB()
  if not QtUIDB then
    local legacy = getglobal("P" .. "otatoUIDB")
    if type(legacy) == "table" then
      QtUIDB = legacy
    else
      QtUIDB = {}
    end
  end
  QtUIDB.scale = nil
  if self.EnsureFeatureDefaults then self:EnsureFeatureDefaults() end
  if self.EnsureLayoutDefaults then self:EnsureLayoutDefaults() end
end

function QtUI:Initialize()
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
  SafeSetup("cooldowns", self.SetupCooldowns)
  SafeSetup("eqCompare", self.SetupEqCompare)
  SafeSetup("settingsButton", self.SetupSettingsButton)
  SafeSetup("moveMode", self.SetupMoveMode)
  SafeSetup("applyLayout", self.ApplyLayout)
  if self.ScheduleBackgroundPulse then self:ScheduleBackgroundPulse() end

  Print("Loaded. Type /qtui for commands.")
end

SLASH_QTUI1 = "/qtui"
SLASH_QTUI2 = "/qt"
SlashCmdList["QTUI"] = function(message)
  local command = string.lower(message or "")
  command = string.gsub(command, "^%s+", "")
  command = string.gsub(command, "%s+$", "")
  if command == "reset" then
    QtUIDB = { positions = {} }
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
    if QtUI.ToggleBags then QtUI:ToggleBags() end
  elseif command == "move" then
    if QtUI.ToggleMoveMode then QtUI:ToggleMoveMode() end
  elseif command == "settings" or command == "config" then
    if QtUI.ToggleSettings then QtUI:ToggleSettings() end
  else
    Print("Loaded v" .. QtUI.version .. ". Commands: /qtui settings, /qtui move, /qtui bags, /qtui reload, /qtui reset")
  end
end

QtUI:SetScript("OnEvent", function()
  if event == "ADDON_LOADED" and arg1 == "QtUI" then
    QtUI:EnsureDB()
  elseif event == "PLAYER_ENTERING_WORLD" then
    QtUI:Initialize()
  end
end)
QtUI:RegisterEvent("ADDON_LOADED")
QtUI:RegisterEvent("PLAYER_ENTERING_WORLD")
