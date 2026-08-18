local FEATURE_OPTIONS = {
  { key = "bags", label = "Custom Bags", description = "Use QtUI's combined bag window and item layout." },
  { key = "autoLoot", label = "Auto Loot", description = "Loot opened containers automatically unless Shift is held." },
  { key = "autoSell", label = "Auto-Sell Greys", description = "Sell grey-quality items when a merchant opens." },
  { key = "unitFrames", label = "Player / Target Frames", description = "Replace the native player, target and combo-point frames." },
  { key = "partyFrames", label = "Party / Pet Frames", description = "Replace native party and pet frames." },
  { key = "auras", label = "Aura Displays", description = "Show QtUI buff and debuff rows on enabled unit frames." },
  { key = "actionBars", label = "Action Bar Edits", description = "Use QtUI's main, utility, stance and pet action-bar layout." },
  { key = "experienceBar", label = "Experience Bar", description = "Show the QtUI level and rested-experience bar." },
  { key = "castBar", label = "Cast Bar", description = "Replace the native player casting bar." },
  { key = "minimap", label = "Minimap Edits", description = "Use QtUI's compact minimap styling and controls." },
  { key = "mapReveal", label = "Map Reveal", description = "Reveal unexplored terrain artwork on the world map." },
  { key = "dataText", label = "Gold / Time / Performance", description = "Show money, game time, FPS and latency." },
}

QtUI.featureOptions = FEATURE_OPTIONS

function QtUI:EnsureFeatureDefaults()
  if not QtUIDB.features then QtUIDB.features = {} end
  local _, option
  for _, option in ipairs(FEATURE_OPTIONS) do
    if QtUIDB.features[option.key] == nil then
      QtUIDB.features[option.key] = true
    end
  end
end

function QtUI:IsFeatureEnabled(key)
  if not QtUIDB or not QtUIDB.features then return true end
  return QtUIDB.features[key] ~= false
end

function QtUI:SetFeatureEnabled(key, enabled)
  self:EnsureFeatureDefaults()
  QtUIDB.features[key] = enabled and true or false
end

local function UpdateFeatureRow(row)
  local enabled = QtUI:IsFeatureEnabled(row.featureKey)
  row.mark:SetText("")
  if enabled then
    row.box:SetBackdropColor(.08, .4, .64, .95)
    row.box:SetBackdropBorderColor(.25, .72, 1, 1)
    row.label:SetTextColor(1, .9, .48)
  else
    row.box:SetBackdropColor(.04, .05, .06, .9)
    row.box:SetBackdropBorderColor(.25, .28, .3, 1)
    row.label:SetTextColor(.58, .6, .62)
  end
end

local function RefreshSettingsRows()
  local frame = QtUI.settingsFrame
  if not frame then return end
  local _, row
  for _, row in ipairs(frame.rows) do UpdateFeatureRow(row) end
end

local function CreateFeatureRow(parent, option, column, rowIndex)
  local row = CreateFrame("Button", nil, parent)
  row:SetWidth(214)
  row:SetHeight(24)
  row:SetPoint("TOPLEFT", parent, "TOPLEFT", 12 + column * 222, -4 - rowIndex * 26)
  row.featureKey = option.key
  row.description = option.description

  row.box = CreateFrame("Frame", nil, row)
  row.box:SetWidth(22)
  row.box:SetHeight(22)
  row.box:SetPoint("LEFT", row, "LEFT", 0, 0)
  row.box:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 9,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })

  row.mark = row.box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.mark:SetAllPoints(row.box)
  row.mark:SetJustifyH("CENTER")
  row.mark:SetTextColor(1, 1, 1)

  row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  row.label:SetPoint("LEFT", row.box, "RIGHT", 8, 0)
  row.label:SetJustifyH("LEFT")
  row.label:SetText(option.label)

  row:SetScript("OnClick", function()
    QtUI:SetFeatureEnabled(this.featureKey, not QtUI:IsFeatureEnabled(this.featureKey))
    UpdateFeatureRow(this)
  end)
  row:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText(this.label:GetText())
    GameTooltip:AddLine(this.description, .8, .85, .9, 1)
    GameTooltip:Show()
  end)
  row:SetScript("OnLeave", function() GameTooltip:Hide() end)
  UpdateFeatureRow(row)
  return row
end

local function CreateSmallButton(parent, textValue, x, handler, width)
  local button = CreateFrame("Button", nil, parent)
  button:SetWidth(width or 104)
  button:SetHeight(26)
  button:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", x, 12)
  button:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 9,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  button:SetBackdropColor(.035, .05, .06, .94)
  button:SetBackdropBorderColor(.25, .34, .36, 1)
  button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  button.text:SetPoint("CENTER", button, "CENTER", 0, 0)
  button.text:SetJustifyH("CENTER")
  button.text:SetText(textValue)
  button.text:SetTextColor(1, .82, .2)
  button:SetScript("OnClick", handler)
  button:SetScript("OnEnter", function()
    this:SetBackdropColor(.08, .4, .64, .95)
    this:SetBackdropBorderColor(.25, .72, 1, 1)
    if this.text then this.text:SetTextColor(1, .92, .48) end
  end)
  button:SetScript("OnLeave", function()
    this:SetBackdropColor(.035, .05, .06, .94)
    this:SetBackdropBorderColor(.25, .34, .36, 1)
    if this.text then this.text:SetTextColor(1, .82, .2) end
  end)
  return button
end

local function CreateStepper(parent, y, label, getter, setter, minValue, maxValue, step, digits)
  local row = CreateFrame("Frame", nil, parent)
  row:SetWidth(440)
  row:SetHeight(24)
  row:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, y)

  row.caption = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  row.caption:SetPoint("LEFT", row, "LEFT", 0, 0)
  row.caption:SetWidth(210)
  row.caption:SetJustifyH("LEFT")
  row.caption:SetText(label)

  local function Refresh()
    local value = getter()
    if digits and digits > 0 then
      row.value:SetText(string.format("%." .. digits .. "f", value))
    else
      row.value:SetText(tostring(value))
    end
  end

  local minus = CreateFrame("Button", nil, row)
  minus:SetWidth(24)
  minus:SetHeight(22)
  minus:SetPoint("LEFT", row, "LEFT", 220, 0)
  minus:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  minus:SetBackdropColor(.04, .05, .06, .95)
  minus.text = minus:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  minus.text:SetPoint("CENTER", minus, "CENTER", 0, 0)
  minus.text:SetText("-")
  minus:SetScript("OnClick", function()
    local value = getter() - step
    if value < minValue then value = minValue end
    setter(value)
    Refresh()
    QtUI:ApplyLayout()
  end)

  row.value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.value:SetPoint("LEFT", minus, "RIGHT", 8, 0)
  row.value:SetWidth(50)
  row.value:SetJustifyH("CENTER")

  local plus = CreateFrame("Button", nil, row)
  plus:SetWidth(24)
  plus:SetHeight(22)
  plus:SetPoint("LEFT", row.value, "RIGHT", 8, 0)
  plus:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  plus:SetBackdropColor(.04, .05, .06, .95)
  plus.text = plus:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  plus.text:SetPoint("CENTER", plus, "CENTER", 0, 0)
  plus.text:SetText("+")
  plus:SetScript("OnClick", function()
    local value = getter() + step
    if value > maxValue then value = maxValue end
    setter(value)
    Refresh()
    QtUI:ApplyLayout()
  end)

  Refresh()
  row.Refresh = Refresh
  return row
end

local COLOR_PRESETS = {
  { .78, .12, .12 }, { .15, .72, .22 }, { .2, .75, .25 }, { .82, .68, .16 },
  { .12, .38, .82 }, { .88, .58, .16 }, { .96, .55, .73 }, { .78, .61, .43 },
}

local function CreateColorRow(parent, y, label, getter, setter)
  local row = CreateFrame("Frame", nil, parent)
  row:SetWidth(440)
  row:SetHeight(24)
  row:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, y)

  row.caption = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  row.caption:SetPoint("LEFT", row, "LEFT", 0, 0)
  row.caption:SetWidth(150)
  row.caption:SetJustifyH("LEFT")
  row.caption:SetText(label)

  row.preview = CreateFrame("Frame", nil, row)
  row.preview:SetWidth(22)
  row.preview:SetHeight(22)
  row.preview:SetPoint("LEFT", row, "LEFT", 158, 0)
  row.preview:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })

  local function Refresh()
    local c = getter()
    row.preview:SetBackdropColor(c.r or 1, c.g or 1, c.b or 1, 1)
  end

  local i
  for i = 1, table.getn(COLOR_PRESETS) do
    local preset = COLOR_PRESETS[i]
    local swatch = CreateFrame("Button", nil, row)
    swatch:SetWidth(16)
    swatch:SetHeight(16)
    swatch:SetPoint("LEFT", row.preview, "RIGHT", 10 + (i - 1) * 20, 0)
    swatch:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 8, edgeSize = 8,
      insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    swatch:SetBackdropColor(preset[1], preset[2], preset[3], 1)
    swatch:SetBackdropBorderColor(.2, .2, .2, 1)
    swatch:SetScript("OnClick", function()
      setter({ r = preset[1], g = preset[2], b = preset[3] })
      Refresh()
      QtUI:ApplyLayout()
    end)
  end

  Refresh()
  row.Refresh = Refresh
  return row
end

local function CreateToggleRow(parent, y, label, getter, setter)
  local row = CreateFrame("Button", nil, parent)
  row:SetWidth(440)
  row:SetHeight(24)
  row:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, y)

  row.box = CreateFrame("Frame", nil, row)
  row.box:SetWidth(18)
  row.box:SetHeight(18)
  row.box:SetPoint("LEFT", row, "LEFT", 0, 0)
  row.box:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })

  row.caption = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  row.caption:SetPoint("LEFT", row.box, "RIGHT", 8, 0)
  row.caption:SetText(label)

  local function Refresh()
    if getter() then
      row.box:SetBackdropColor(.08, .4, .64, .95)
      row.box:SetBackdropBorderColor(.25, .72, 1, 1)
    else
      row.box:SetBackdropColor(.04, .05, .06, .9)
      row.box:SetBackdropBorderColor(.25, .28, .3, 1)
    end
  end

  row:SetScript("OnClick", function()
    setter(not getter())
    Refresh()
    QtUI:ApplyLayout()
  end)
  Refresh()
  row.Refresh = Refresh
  return row
end

local GRID_PRESETS = {
  { label = "1x12", columns = 1, rows = 12 },
  { label = "2x6", columns = 2, rows = 6 },
  { label = "3x4", columns = 3, rows = 4 },
  { label = "4x3", columns = 4, rows = 3 },
  { label = "6x2", columns = 6, rows = 2 },
  { label = "12x1", columns = 12, rows = 1 },
}

local function CreateGridPicker(parent, y, barKey)
  local row = CreateFrame("Frame", nil, parent)
  row:SetWidth(440)
  row:SetHeight(48)
  row:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, y)
  row.barKey = barKey

  row.caption = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  row.caption:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
  row.caption:SetText("Layout")

  row.buttons = {}
  local i
  for i = 1, table.getn(GRID_PRESETS) do
    local preset = GRID_PRESETS[i]
    local button = CreateFrame("Button", nil, row)
    button:SetWidth(50)
    button:SetHeight(22)
    button:SetPoint("TOPLEFT", row, "TOPLEFT", (i - 1) * 54, -20)
    button:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 8, edgeSize = 8,
      insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    button.gridColumns = preset.columns
    button.gridRows = preset.rows
    button.barKey = barKey
    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.text:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.text:SetText(preset.label)
    button:SetScript("OnClick", function()
      local bar = QtUI:GetBarConfig(this.barKey)
      bar.columns = this.gridColumns
      bar.rows = this.gridRows
      row.Refresh()
      QtUI:ApplyLayout()
    end)
    table.insert(row.buttons, button)
  end

  local function Refresh()
    local bar = QtUI:GetBarConfig(row.barKey)
    local columns = bar.columns or 12
    local n
    for n = 1, table.getn(row.buttons) do
      local button = row.buttons[n]
      if button.gridColumns == columns then
        button:SetBackdropColor(.08, .4, .64, .95)
        button:SetBackdropBorderColor(.25, .72, 1, 1)
        button.text:SetTextColor(1, .9, .48)
      else
        button:SetBackdropColor(.04, .05, .06, .95)
        button:SetBackdropBorderColor(.25, .28, .3, 1)
        button.text:SetTextColor(.78, .8, .82)
      end
    end
  end

  Refresh()
  row.Refresh = Refresh
  return row
end

local ALIGN_OPTIONS = {
  { key = "topleft", label = "TL" },
  { key = "top", label = "T" },
  { key = "topright", label = "TR" },
  { key = "left", label = "L" },
  { key = "center", label = "C" },
  { key = "right", label = "R" },
  { key = "bottomleft", label = "BL" },
  { key = "bottom", label = "B" },
  { key = "bottomright", label = "BR" },
}

local function CreateAlignPicker(parent, y, label, getter, setter)
  local row = CreateFrame("Frame", nil, parent)
  row:SetWidth(460)
  row:SetHeight(24)
  row:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, y)

  row.caption = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  row.caption:SetPoint("LEFT", row, "LEFT", 0, 0)
  row.caption:SetWidth(86)
  row.caption:SetJustifyH("LEFT")
  row.caption:SetText(label)

  row.buttons = {}
  local i
  for i = 1, table.getn(ALIGN_OPTIONS) do
    local option = ALIGN_OPTIONS[i]
    local button = CreateFrame("Button", nil, row)
    button:SetWidth(28)
    button:SetHeight(20)
    button:SetPoint("LEFT", row, "LEFT", 90 + (i - 1) * 30, 0)
    button:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 8, edgeSize = 8,
      insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    button.alignKey = option.key
    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.text:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.text:SetText(option.label)
    button:SetScript("OnClick", function()
      setter(this.alignKey)
      row.Refresh()
      QtUI:ApplyLayout()
    end)
    table.insert(row.buttons, button)
  end

  local function Refresh()
    local current = getter()
    local n
    for n = 1, table.getn(row.buttons) do
      local button = row.buttons[n]
      if button.alignKey == current then
        button:SetBackdropColor(.08, .4, .64, .95)
        button:SetBackdropBorderColor(.25, .72, 1, 1)
        button.text:SetTextColor(1, .9, .48)
      else
        button:SetBackdropColor(.04, .05, .06, .95)
        button:SetBackdropBorderColor(.25, .28, .3, 1)
        button.text:SetTextColor(.78, .8, .82)
      end
    end
  end

  Refresh()
  row.Refresh = Refresh
  return row
end

local function ShowPage(frame, key)
  local name, page
  for name, page in pairs(frame.pages) do
    if name == key then page:Show() else page:Hide() end
  end
  local _, button
  for _, button in ipairs(frame.navButtons) do
    if button.pageKey == key then
      button:SetBackdropColor(.08, .4, .64, .95)
      button:SetBackdropBorderColor(.25, .72, 1, 1)
    else
      button:SetBackdropColor(.03, .04, .05, .94)
      button:SetBackdropBorderColor(.22, .28, .3, 1)
    end
  end
end

function QtUI:SetupSettingsWindow()
  if self.settingsFrame then return end
  self:EnsureFeatureDefaults()
  self:EnsureLayoutDefaults()

  local frame = self:CreatePanel("QtUISettingsFrame", UIParent, 40)
  frame:SetFrameStrata("DIALOG")
  frame:SetWidth(640)
  frame:SetHeight(460)
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
  frame:SetBackdropColor(.012, .018, .024, .97)
  frame:SetBackdropBorderColor(.4, .52, .54, 1)
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  if QtUIDB.settingsX and QtUIDB.settingsY then
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", QtUIDB.settingsX, QtUIDB.settingsY)
  end

  local function StopSettingsDrag()
    frame:StopMovingOrSizing()
    local left, bottom = frame:GetLeft(), frame:GetBottom()
    if left and bottom then
      QtUIDB.settingsX = left
      QtUIDB.settingsY = bottom
      frame:ClearAllPoints()
      frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
    end
  end

  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function() this:StartMoving() end)
  frame:SetScript("OnDragStop", StopSettingsDrag)

  frame.dragHandle = CreateFrame("Button", "QtUISettingsDragHandle", frame)
  frame.dragHandle:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  frame.dragHandle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  frame.dragHandle:SetHeight(30)
  frame.dragHandle:SetFrameLevel((frame:GetFrameLevel() or 40) + 20)
  frame.dragHandle:EnableMouse(true)
  frame.dragHandle:RegisterForDrag("LeftButton")
  frame.dragHandle:SetScript("OnDragStart", function()
    this:GetParent():StartMoving()
  end)
  frame.dragHandle:SetScript("OnDragStop", StopSettingsDrag)

  frame.title = frame.dragHandle:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  frame.title:SetPoint("LEFT", frame.dragHandle, "LEFT", 16, 0)
  frame.title:SetText("|cffffcc00Qt|rUI Settings")

  frame.close = CreateFrame("Button", nil, frame)
  frame.close:SetWidth(28)
  frame.close:SetHeight(28)
  frame.close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -9, -8)
  frame.close:SetFrameLevel((frame:GetFrameLevel() or 40) + 21)
  frame.close.text = frame.close:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  frame.close.text:SetAllPoints(frame.close)
  frame.close.text:SetJustifyH("CENTER")
  frame.close.text:SetText("|cffff6666X|r")
  frame.close:SetScript("OnClick", function() QtUI.settingsFrame:Hide() end)

  local nav = CreateFrame("Frame", nil, frame)
  nav:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -34)
  nav:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 42)
  nav:SetWidth(124)
  if nav.EnableMouse then nav:EnableMouse(false) end

  local content = CreateFrame("Frame", nil, frame)
  content:SetPoint("TOPLEFT", nav, "TOPRIGHT", 10, 0)
  content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 42)
  if content.EnableMouse then content:EnableMouse(false) end

  frame.pages = {}
  frame.navButtons = {}

  local navY = 0
  local function AddNav(key, label, child)
    local button = CreateFrame("Button", nil, nav)
    local height = 24
    local x = 0
    local width = 122
    if child then
      height = 20
      x = 10
      width = 112
    end
    button:SetWidth(width)
    button:SetHeight(height)
    button:SetPoint("TOPLEFT", nav, "TOPLEFT", x, -navY)
    button:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 8, edgeSize = 8,
      insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    button.pageKey = key
    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.text:SetPoint("LEFT", button, "LEFT", child and 8 or 10, 0)
    button.text:SetText(label)
    button:SetScript("OnClick", function() ShowPage(frame, this.pageKey) end)
    table.insert(frame.navButtons, button)
    navY = navY + height + 3
    return button
  end

  local function AddPage(key)
    local page = CreateFrame("Frame", nil, content)
    page:SetAllPoints(content)
    if page.EnableMouse then page:EnableMouse(false) end
    page:Hide()
    frame.pages[key] = page
    return page
  end

  AddNav("general", "General")
  AddNav("actionbars", "Action Bars")
  AddNav("bar-main", "Main Bar", true)
  AddNav("bar-extra", "Extra Bar", true)
  AddNav("bar-utility", "Utility Bar", true)
  AddNav("bar-aux", "Stance / Pet", true)
  AddNav("bar-sideright", "Right Side", true)
  AddNav("bar-sideleft", "Left Side", true)
  AddNav("unitframes", "Unit Frames")
  AddNav("unit-player", "Player", true)
  AddNav("unit-target", "Target", true)
  AddNav("unit-tot", "Target of Target", true)
  AddNav("unit-party", "Party", true)
  AddNav("unit-pet", "Pet", true)

  local general = AddPage("general")
  general.note = general:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  general.note:SetPoint("TOPLEFT", general, "TOPLEFT", 12, 0)
  general.note:SetText("Feature toggles need a relog. Bag size applies immediately.")
  CreateStepper(general, -22, "Bag slot size", function()
    return QtUI:GetLayout().bagSlotSize
  end, function(value)
    QtUI:GetLayout().bagSlotSize = value
  end, 24, 52, 2, 0)
  CreateStepper(general, -48, "Bag columns", function()
    return QtUI:GetLayout().bagColumns
  end, function(value)
    QtUI:GetLayout().bagColumns = value
  end, 6, 16, 1, 0)
  CreateToggleRow(general, -74, "Compare equipped items", function()
    local value = QtUI:GetLayout().eqCompare
    return value ~= false and value ~= 0 and value ~= "0"
  end, function(value)
    QtUI:GetLayout().eqCompare = value and true or false
  end)

  frame.rows = {}
  local index, option
  for index, option in ipairs(FEATURE_OPTIONS) do
    local column = index > 6 and 1 or 0
    local rowIndex = math.mod(index - 1, 6)
    table.insert(frame.rows, CreateFeatureRow(general, option, column, rowIndex + 4))
  end

  local bars = AddPage("actionbars")
  bars.note = bars:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  bars.note:SetPoint("TOPLEFT", bars, "TOPLEFT", 12, 0)
  bars.note:SetWidth(450)
  bars.note:SetJustifyH("LEFT")
  bars.note:SetText("Shared chrome for every bar. Open a bar on the left to set its size, spacing and 1x12 / 2x6 / 3x4 / 4x3 / 6x2 / 12x1 layout.")

  CreateToggleRow(bars, -28, "Show action-bar background", function()
    local value = QtUI:GetLayout().barShowBackground
    return value == true or value == 1 or value == "1"
  end, function(value)
    QtUI:GetLayout().barShowBackground = value and true or false
  end)
  CreateColorRow(bars, -54, "Bar background", function()
    return QtUI:GetLayout().barBackground
  end, function(color)
    local current = QtUI:GetLayout().barBackground
    color.a = current.a or .85
    QtUI:GetLayout().barBackground = color
  end)
  CreateStepper(bars, -80, "Background opacity", function()
    return QtUI:GetLayout().barBackground.a or .85
  end, function(value)
    QtUI:GetLayout().barBackground.a = value
  end, 0.1, 1, 0.05, 2)
  CreateColorRow(bars, -106, "Bar border", function()
    return QtUI:GetLayout().barBorder
  end, function(color)
    QtUI:GetLayout().barBorder = color
  end)
  CreateToggleRow(bars, -132, "Show slot background", function()
    local value = QtUI:GetLayout().slotShowBackground
    return value ~= false and value ~= 0 and value ~= "0"
  end, function(value)
    QtUI:GetLayout().slotShowBackground = value and true or false
  end)
  CreateColorRow(bars, -158, "Slot background", function()
    return QtUI:GetLayout().slotBackground
  end, function(color)
    local current = QtUI:GetLayout().slotBackground
    color.a = current.a or .96
    QtUI:GetLayout().slotBackground = color
  end)
  CreateStepper(bars, -184, "Slot opacity", function()
    return QtUI:GetLayout().slotBackground.a or .96
  end, function(value)
    QtUI:GetLayout().slotBackground.a = value
  end, 0.1, 1, 0.05, 2)
  CreateColorRow(bars, -210, "Slot border", function()
    return QtUI:GetLayout().slotBorder
  end, function(color)
    QtUI:GetLayout().slotBorder = color
  end)
  CreateToggleRow(bars, -236, "Leave shapeshift to cast", function()
    local value = QtUI:GetLayout().unshiftToCast
    return value ~= false and value ~= 0 and value ~= "0"
  end, function(value)
    QtUI:GetLayout().unshiftToCast = value and true or false
  end)
  CreateToggleRow(bars, -262, "Cooldown numbers", function()
    local value = QtUI:GetLayout().cooldownText
    return value ~= false and value ~= 0 and value ~= "0"
  end, function(value)
    QtUI:GetLayout().cooldownText = value and true or false
  end)
  CreateToggleRow(bars, -288, "Color out of range / OOM", function()
    local value = QtUI:GetLayout().barRangeColor
    return value ~= false and value ~= 0 and value ~= "0"
  end, function(value)
    QtUI:GetLayout().barRangeColor = value and true or false
  end)

  local function BuildBarPage(pageKey, barKey, blurb)
    local page = AddPage(pageKey)
    page.note = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    page.note:SetPoint("TOPLEFT", page, "TOPLEFT", 12, 0)
    page.note:SetWidth(450)
    page.note:SetJustifyH("LEFT")
    page.note:SetText(blurb)
    CreateToggleRow(page, -28, "Show this bar", function()
      return QtUI:GetBarConfig(barKey).enabled ~= false
    end, function(value)
      QtUI:GetBarConfig(barKey).enabled = value and true or false
    end)
    CreateStepper(page, -54, "Button size", function()
      return QtUI:GetBarConfig(barKey).size
    end, function(value)
      QtUI:GetBarConfig(barKey).size = value
    end, 20, 52, 2, 0)
    CreateStepper(page, -80, "Spacing", function()
      return QtUI:GetBarConfig(barKey).spacing
    end, function(value)
      QtUI:GetBarConfig(barKey).spacing = value
    end, 0, 12, 1, 0)
    CreateGridPicker(page, -114, barKey)
    CreateAlignPicker(page, -170, "Hotkey", function()
      return QtUI:GetBarConfig(barKey).hotkeyAlign
    end, function(value)
      QtUI:GetBarConfig(barKey).hotkeyAlign = value
    end)
    CreateStepper(page, -196, "Hotkey size", function()
      return QtUI:GetBarConfig(barKey).hotkeySize
    end, function(value)
      QtUI:GetBarConfig(barKey).hotkeySize = value
    end, 7, 16, 1, 0)
    CreateStepper(page, -222, "Hotkey shadow", function()
      return QtUI:GetBarConfig(barKey).hotkeyShadow
    end, function(value)
      QtUI:GetBarConfig(barKey).hotkeyShadow = value
    end, 0, 4, 1, 0)
    return page
  end

  BuildBarPage("bar-main", "main", "Primary action buttons 1-12. Pick a grid; it applies only to this bar.")
  BuildBarPage("bar-extra", "extra", "Second bar (bottom-left multi-bar). Independent size, spacing and grid.")
  BuildBarPage("bar-utility", "utility", "Bottom-right utility bar. Independent size, spacing and grid.")
  BuildBarPage("bar-aux", "aux", "Stance, shapeshift and pet buttons. Only learned stances are shown; the grid wraps those plus the pet bar.")
  BuildBarPage("bar-sideright", "sideRight", "Right side bar. All 12 buttons stay visible.")
  BuildBarPage("bar-sideleft", "sideLeft", "Left side bar. All 12 buttons stay visible.")

  local units = AddPage("unitframes")
  units.note = units:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  units.note:SetPoint("TOPLEFT", units, "TOPLEFT", 12, 0)
  units.note:SetWidth(450)
  units.note:SetJustifyH("LEFT")
  units.note:SetText("Shared colors and gradient. Open Player, Target, Party or Pet for size, mana height and text positions.")

  CreateToggleRow(units, -22, "Gradient bars", function()
    local value = QtUI:GetLayout().unitGradient
    return value == true or value == 1 or value == "1"
  end, function(value)
    QtUI:GetLayout().unitGradient = value and true or false
  end)
  CreateToggleRow(units, -190, "Target of target", function()
    local value = QtUI:GetLayout().showTargetTarget
    return value ~= false and value ~= 0 and value ~= "0"
  end, function(value)
    QtUI:GetLayout().showTargetTarget = value and true or false
  end)
  CreateToggleRow(units, -216, "Energy / mana tick", function()
    local value = QtUI:GetLayout().energyTick
    return value ~= false and value ~= 0 and value ~= "0"
  end, function(value)
    QtUI:GetLayout().energyTick = value and true or false
  end)
  CreateStepper(units, -242, "Tick width", function()
    return QtUI:GetLayout().energyTickWidth or 1
  end, function(value)
    QtUI:GetLayout().energyTickWidth = value
  end, 1, 8, 1, 0)
  CreateStepper(units, -268, "Tick opacity", function()
    return QtUI:GetLayout().energyTickAlpha or .95
  end, function(value)
    QtUI:GetLayout().energyTickAlpha = value
  end, 0.1, 1, 0.05, 2)
  CreateColorRow(units, -50, "Player health", function()
    return QtUI:GetLayout().playerHealth
  end, function(color)
    QtUI:GetLayout().playerHealth = color
  end)
  CreateColorRow(units, -78, "Enemy health", function()
    return QtUI:GetLayout().enemyHealth
  end, function(color)
    QtUI:GetLayout().enemyHealth = color
  end)
  CreateColorRow(units, -106, "Friend health", function()
    return QtUI:GetLayout().friendHealth
  end, function(color)
    QtUI:GetLayout().friendHealth = color
  end)
  CreateColorRow(units, -134, "Neutral health", function()
    return QtUI:GetLayout().neutralHealth
  end, function(color)
    QtUI:GetLayout().neutralHealth = color
  end)
  CreateColorRow(units, -162, "Party health", function()
    return QtUI:GetLayout().partyHealth
  end, function(color)
    QtUI:GetLayout().partyHealth = color
  end)

  local function BuildUnitPage(pageKey, styleKey, blurb, extras)
    local page = AddPage(pageKey)
    page.note = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    page.note:SetPoint("TOPLEFT", page, "TOPLEFT", 12, 0)
    page.note:SetWidth(450)
    page.note:SetJustifyH("LEFT")
    page.note:SetText(blurb)
    local y = -24
    CreateStepper(page, y, "Width", function()
      return QtUI:GetUnitStyle(styleKey).width
    end, function(value)
      QtUI:GetUnitStyle(styleKey).width = value
    end, extras.minWidth or 100, 420, extras.widthStep or 10, 0)
    y = y - 26
    if extras.height then
      CreateStepper(page, y, "Height", function()
        return QtUI:GetUnitStyle(styleKey).height
      end, function(value)
        QtUI:GetUnitStyle(styleKey).height = value
      end, extras.minHeight or 32, extras.maxHeight or 100, 2, 0)
      y = y - 26
    end
    if extras.powerHeight then
      CreateStepper(page, y, "Mana bar height", function()
        return QtUI:GetUnitStyle(styleKey).powerHeight
      end, function(value)
        QtUI:GetUnitStyle(styleKey).powerHeight = value
      end, 6, 28, 1, 0)
      y = y - 26
    end
    if extras.spacing then
      CreateStepper(page, y, "Space between frames", function()
        return QtUI:GetUnitStyle(styleKey).spacing
      end, function(value)
        QtUI:GetUnitStyle(styleKey).spacing = value
      end, 4, 40, 1, 0)
      y = y - 26
    end
    if extras.classColor then
      CreateToggleRow(page, y, extras.classColor, function()
        return QtUI:GetLayout()[extras.classColorKey]
      end, function(value)
        QtUI:GetLayout()[extras.classColorKey] = value and true or false
      end)
      y = y - 26
    end
    CreateAlignPicker(page, y, "Name", function()
      return QtUI:GetUnitStyle(styleKey).nameAlign
    end, function(value)
      QtUI:GetUnitStyle(styleKey).nameAlign = value
    end)
    y = y - 26
    CreateAlignPicker(page, y, "Health text", function()
      return QtUI:GetUnitStyle(styleKey).healthAlign
    end, function(value)
      QtUI:GetUnitStyle(styleKey).healthAlign = value
    end)
    y = y - 26
    if extras.powerText then
      CreateAlignPicker(page, y, "Mana text", function()
        return QtUI:GetUnitStyle(styleKey).powerAlign
      end, function(value)
        QtUI:GetUnitStyle(styleKey).powerAlign = value
      end)
      y = y - 26
    end
    if extras.classText then
      CreateAlignPicker(page, y, "Elite / rare", function()
        return QtUI:GetUnitStyle(styleKey).classAlign
      end, function(value)
        QtUI:GetUnitStyle(styleKey).classAlign = value
      end)
    end
    return page
  end

  BuildUnitPage("unit-player", "player", "Player frame size, mana bar and text anchors.", {
    height = true, powerHeight = true, powerText = true,
    classColor = "Health uses class color", classColorKey = "playerClassColor",
    minHeight = 40, maxHeight = 100,
  })
  BuildUnitPage("unit-target", "target", "Target frame size, mana bar and text anchors.", {
    height = true, powerHeight = true, powerText = true, classText = true,
    minHeight = 40, maxHeight = 100,
  })
  BuildUnitPage("unit-tot", "targettarget", "Target-of-target size, mana bar and text anchors.", {
    height = true, powerHeight = true, powerText = true,
    minWidth = 80, widthStep = 5, minHeight = 24, maxHeight = 80,
  })
  BuildUnitPage("unit-party", "party", "Party frames. Text anchors apply to every member.", {
    height = true, powerHeight = true, powerText = true, spacing = true,
    classColor = "Health uses class color", classColorKey = "partyClassColor",
    minHeight = 32, maxHeight = 80,
  })
  BuildUnitPage("unit-pet", "pet", "Player and party pet frames.", {
    height = true, minHeight = 20, maxHeight = 50,
  })

  CreateSmallButton(frame, "Reload UI", 18, function()
    if SlashCmdList and SlashCmdList["QTUI"] then
      SlashCmdList["QTUI"]("reload")
    end
  end)
  CreateSmallButton(frame, "Apply", 130, function()
    QtUI:ApplyLayout()
  end)
  CreateSmallButton(frame, "Toggle Anchor", 242, function()
    QtUI.moveFromSettings = true
    if QtUI.settingsFrame then QtUI.settingsFrame:Hide() end
    if QtUI.SetMoveMode then QtUI:SetMoveMode(true) end
    QtUI:Print("Anchors unlocked. Drag the green fields. Press Escape to lock and return here.")
  end, 118)

  ShowPage(frame, "general")
  frame:Hide()
  self.settingsFrame = frame
  if UISpecialFrames then table.insert(UISpecialFrames, "QtUISettingsFrame") end
end

function QtUI:ToggleSettings()
  self:SetupSettingsWindow()
  RefreshSettingsRows()
  if self.settingsFrame:IsShown() then self.settingsFrame:Hide() else self.settingsFrame:Show() end
end

function QtUI:SetupSettingsButton()
  if self.settingsButton then return end
  local parent = Minimap or UIParent
  local button = CreateFrame("Button", "QtUISettingsButton", parent)
  button:SetWidth(31)
  button:SetHeight(31)
  if Minimap then
    local saved = QtUIDB.settingsButtonPosition
    button:SetPoint("CENTER", Minimap, "CENTER",
      saved and saved.x or -65, saved and saved.y or 65)
  else
    button:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -18, -18)
  end
  button:SetFrameStrata("HIGH")
  button:SetFrameLevel(30)
  button:SetClampedToScreen(true)
  button:SetMovable(true)
  button:EnableMouse(true)
  button:RegisterForDrag("LeftButton")
  button:RegisterForClicks("LeftButtonUp")
  button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  button.icon = button:CreateTexture(nil, "BACKGROUND")
  button.icon:SetWidth(20)
  button.icon:SetHeight(20)
  button.icon:SetPoint("CENTER", button, "CENTER", 1, 1)
  button.icon:SetTexture("Interface\\AddOns\\QtUI\\Media\\QtIcon")
  button.icon:SetTexCoord(.05, .95, .05, .95)

  button.overlay = button:CreateTexture(nil, "OVERLAY")
  button.overlay:SetWidth(53)
  button.overlay:SetHeight(53)
  button.overlay:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
  button.overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

  button:SetScript("OnDragStart", function()
    if IsShiftKeyDown() then
      this.dragging = true
      this:StartMoving()
    end
  end)
  button:SetScript("OnDragStop", function()
    if not this.dragging then return end
    this:StopMovingOrSizing()
    this.dragging = nil
    this.justDragged = true
    this:SetScript("OnUpdate", function()
      this.justDragged = nil
      this:SetScript("OnUpdate", nil)
    end)
    if Minimap then
      local buttonX, buttonY = this:GetCenter()
      local mapX, mapY = Minimap:GetCenter()
      if buttonX and buttonY and mapX and mapY then
        local x, y = buttonX - mapX, buttonY - mapY
        QtUIDB.settingsButtonPosition = { x = x, y = y }
        this:ClearAllPoints()
        this:SetPoint("CENTER", Minimap, "CENTER", x, y)
      end
    end
  end)
  button:SetScript("OnClick", function()
    if this.justDragged then
      this.justDragged = nil
      return
    end
    QtUI:ToggleSettings()
  end)
  button:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:SetText("QtUI Settings")
    GameTooltip:AddLine("Click to configure the addon.", .8, .85, .9, 1)
    GameTooltip:AddLine("Shift-drag to move this button.", .45, .8, 1, 1)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function() GameTooltip:Hide() end)
  self.settingsButton = button
end
