local FEATURE_OPTIONS = {
  { key = "bags", label = "Custom Bags", description = "Use PotatoUI's combined bag window and item layout." },
  { key = "autoLoot", label = "Auto Loot", description = "Loot opened containers automatically unless Shift is held." },
  { key = "autoSell", label = "Auto-Sell Greys", description = "Sell grey-quality items when a merchant opens." },
  { key = "unitFrames", label = "Player / Target Frames", description = "Replace the native player, target and combo-point frames." },
  { key = "partyFrames", label = "Party / Pet Frames", description = "Replace native party and pet frames." },
  { key = "auras", label = "Aura Displays", description = "Show PotatoUI buff and debuff rows on enabled unit frames." },
  { key = "actionBars", label = "Action Bar Edits", description = "Use PotatoUI's main, utility, stance and pet action-bar layout." },
  { key = "experienceBar", label = "Experience Bar", description = "Show the PotatoUI level and rested-experience bar." },
  { key = "castBar", label = "Cast Bar", description = "Replace the native player casting bar." },
  { key = "minimap", label = "Minimap Edits", description = "Use PotatoUI's compact minimap styling and controls." },
  { key = "mapReveal", label = "Map Reveal", description = "Reveal unexplored terrain artwork on the world map." },
  { key = "dataText", label = "Gold / Time / Performance", description = "Show money, game time, FPS and latency." },
}

PotatoUI.featureOptions = FEATURE_OPTIONS

function PotatoUI:EnsureFeatureDefaults()
  if not PotatoUIDB.features then PotatoUIDB.features = {} end
  local _, option
  for _, option in ipairs(FEATURE_OPTIONS) do
    if PotatoUIDB.features[option.key] == nil then
      PotatoUIDB.features[option.key] = true
    end
  end
end

function PotatoUI:IsFeatureEnabled(key)
  if not PotatoUIDB or not PotatoUIDB.features then return true end
  return PotatoUIDB.features[key] ~= false
end

function PotatoUI:SetFeatureEnabled(key, enabled)
  self:EnsureFeatureDefaults()
  PotatoUIDB.features[key] = enabled and true or false
end

local function UpdateFeatureRow(row)
  local enabled = PotatoUI:IsFeatureEnabled(row.featureKey)
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
  local frame = PotatoUI.settingsFrame
  if not frame then return end
  local _, row
  for _, row in ipairs(frame.rows) do UpdateFeatureRow(row) end
end

local function CreateFeatureRow(parent, option, column, rowIndex)
  local row = CreateFrame("Button", nil, parent)
  row:SetWidth(248)
  row:SetHeight(28)
  row:SetPoint("TOPLEFT", parent, "TOPLEFT", 12 + column * 258, -8 - rowIndex * 32)
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
    PotatoUI:SetFeatureEnabled(this.featureKey, not PotatoUI:IsFeatureEnabled(this.featureKey))
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

local function CreateSmallButton(parent, textValue, x, handler)
  local button = CreateFrame("Button", nil, parent)
  button:SetWidth(104)
  button:SetHeight(26)
  button:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", x, 18)
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
  button:SetScript("OnClick", handler)
  return button
end

local function CreateStepper(parent, y, label, getter, setter, minValue, maxValue, step, digits)
  local row = CreateFrame("Frame", nil, parent)
  row:SetWidth(500)
  row:SetHeight(26)
  row:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, y)

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
    PotatoUI:ApplyLayout()
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
    PotatoUI:ApplyLayout()
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
  row:SetWidth(500)
  row:SetHeight(26)
  row:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, y)

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
      PotatoUI:ApplyLayout()
    end)
  end

  Refresh()
  row.Refresh = Refresh
  return row
end

local function CreateToggleRow(parent, y, label, getter, setter)
  local row = CreateFrame("Button", nil, parent)
  row:SetWidth(500)
  row:SetHeight(26)
  row:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, y)

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
    PotatoUI:ApplyLayout()
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
  row:SetWidth(540)
  row:SetHeight(52)
  row:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, y)
  row.barKey = barKey

  row.caption = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  row.caption:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
  row.caption:SetText("Layout")

  row.buttons = {}
  local i
  for i = 1, table.getn(GRID_PRESETS) do
    local preset = GRID_PRESETS[i]
    local button = CreateFrame("Button", nil, row)
    button:SetWidth(56)
    button:SetHeight(24)
    button:SetPoint("TOPLEFT", row, "TOPLEFT", (i - 1) * 62, -20)
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
      local bar = PotatoUI:GetBarConfig(this.barKey)
      bar.columns = this.gridColumns
      bar.rows = this.gridRows
      row.Refresh()
      PotatoUI:ApplyLayout()
    end)
    table.insert(row.buttons, button)
  end

  local function Refresh()
    local bar = PotatoUI:GetBarConfig(row.barKey)
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

function PotatoUI:SetupSettingsWindow()
  if self.settingsFrame then return end
  self:EnsureFeatureDefaults()
  self:EnsureLayoutDefaults()

  local frame = self:CreatePanel("PotatoUISettingsFrame", UIParent, 40)
  frame:SetFrameStrata("DIALOG")
  frame:SetWidth(760)
  frame:SetHeight(580)
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
  frame:SetBackdropColor(.012, .018, .024, .97)
  frame:SetBackdropBorderColor(.4, .52, .54, 1)
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function() this:StartMoving() end)
  frame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)

  frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -14)
  frame.title:SetText("|cffffcc00Potato|rUI Settings")

  frame.close = CreateFrame("Button", nil, frame)
  frame.close:SetWidth(28)
  frame.close:SetHeight(28)
  frame.close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -9, -8)
  frame.close.text = frame.close:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  frame.close.text:SetAllPoints(frame.close)
  frame.close.text:SetJustifyH("CENTER")
  frame.close.text:SetText("|cffff6666X|r")
  frame.close:SetScript("OnClick", function() PotatoUI.settingsFrame:Hide() end)

  local nav = CreateFrame("Frame", nil, frame)
  nav:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -40)
  nav:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 52)
  nav:SetWidth(150)

  local content = CreateFrame("Frame", nil, frame)
  content:SetPoint("TOPLEFT", nav, "TOPRIGHT", 10, 0)
  content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 52)

  frame.pages = {}
  frame.navButtons = {}

  local navY = 0
  local function AddNav(key, label, child)
    local button = CreateFrame("Button", nil, nav)
    local height = 28
    local x = 0
    local width = 148
    if child then
      height = 24
      x = 14
      width = 134
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
    navY = navY + height + 4
    return button
  end

  local function AddPage(key)
    local page = CreateFrame("Frame", nil, content)
    page:SetAllPoints(content)
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
  AddNav("party", "Party / Pet")

  local general = AddPage("general")
  general.note = general:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  general.note:SetPoint("TOPLEFT", general, "TOPLEFT", 12, 0)
  general.note:SetText("Scale applies to PotatoUI frames only. Feature toggles need a relog.")
  CreateStepper(general, -22, "UI Scale", function()
    return PotatoUI:GetLayout().scale
  end, function(value)
    PotatoUI:GetLayout().scale = value
  end, 0.6, 1.6, 0.05, 2)

  frame.rows = {}
  local index, option
  for index, option in ipairs(FEATURE_OPTIONS) do
    local column = index > 6 and 1 or 0
    local rowIndex = math.mod(index - 1, 6)
    table.insert(frame.rows, CreateFeatureRow(general, option, column, rowIndex + 2))
  end

  local bars = AddPage("actionbars")
  bars.note = bars:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  bars.note:SetPoint("TOPLEFT", bars, "TOPLEFT", 12, 0)
  bars.note:SetWidth(520)
  bars.note:SetJustifyH("LEFT")
  bars.note:SetText("Shared chrome for every bar. Open a bar on the left to set its size, spacing and 1x12 / 2x6 / 3x4 / 4x3 / 6x2 / 12x1 layout.")

  CreateToggleRow(bars, -28, "Show action-bar background", function()
    return PotatoUI:GetLayout().barShowBackground
  end, function(value)
    PotatoUI:GetLayout().barShowBackground = value and true or false
  end)
  CreateColorRow(bars, -54, "Bar background", function()
    return PotatoUI:GetLayout().barBackground
  end, function(color)
    local current = PotatoUI:GetLayout().barBackground
    color.a = current.a or .85
    PotatoUI:GetLayout().barBackground = color
  end)
  CreateStepper(bars, -80, "Background opacity", function()
    return PotatoUI:GetLayout().barBackground.a or .85
  end, function(value)
    PotatoUI:GetLayout().barBackground.a = value
  end, 0.1, 1, 0.05, 2)
  CreateColorRow(bars, -106, "Bar border", function()
    return PotatoUI:GetLayout().barBorder
  end, function(color)
    PotatoUI:GetLayout().barBorder = color
  end)
  CreateToggleRow(bars, -132, "Show slot background", function()
    return PotatoUI:GetLayout().slotShowBackground
  end, function(value)
    PotatoUI:GetLayout().slotShowBackground = value and true or false
  end)
  CreateColorRow(bars, -158, "Slot background", function()
    return PotatoUI:GetLayout().slotBackground
  end, function(color)
    local current = PotatoUI:GetLayout().slotBackground
    color.a = current.a or .96
    PotatoUI:GetLayout().slotBackground = color
  end)
  CreateStepper(bars, -184, "Slot opacity", function()
    return PotatoUI:GetLayout().slotBackground.a or .96
  end, function(value)
    PotatoUI:GetLayout().slotBackground.a = value
  end, 0.1, 1, 0.05, 2)
  CreateColorRow(bars, -210, "Slot border", function()
    return PotatoUI:GetLayout().slotBorder
  end, function(color)
    PotatoUI:GetLayout().slotBorder = color
  end)

  local function BuildBarPage(pageKey, barKey, blurb)
    local page = AddPage(pageKey)
    page.note = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    page.note:SetPoint("TOPLEFT", page, "TOPLEFT", 12, 0)
    page.note:SetWidth(520)
    page.note:SetJustifyH("LEFT")
    page.note:SetText(blurb)
    CreateStepper(page, -28, "Button size", function()
      return PotatoUI:GetBarConfig(barKey).size
    end, function(value)
      PotatoUI:GetBarConfig(barKey).size = value
    end, 20, 52, 2, 0)
    CreateStepper(page, -54, "Spacing", function()
      return PotatoUI:GetBarConfig(barKey).spacing
    end, function(value)
      PotatoUI:GetBarConfig(barKey).spacing = value
    end, 0, 12, 1, 0)
    CreateGridPicker(page, -88, barKey)
    return page
  end

  BuildBarPage("bar-main", "main", "Primary action buttons 1-12. Pick a grid; it applies only to this bar.")
  BuildBarPage("bar-extra", "extra", "Second bar (bottom-left multi-bar). Independent size, spacing and grid.")
  BuildBarPage("bar-utility", "utility", "Bottom-right utility bar. Independent size, spacing and grid.")
  BuildBarPage("bar-aux", "aux", "Stance, shapeshift and pet buttons. Grid wraps the visible buttons.")
  BuildBarPage("bar-sideright", "sideRight", "Right side bar. All 12 buttons stay visible.")
  BuildBarPage("bar-sideleft", "sideLeft", "Left side bar. All 12 buttons stay visible.")

  local units = AddPage("unitframes")
  units.note = units:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  units.note:SetPoint("TOPLEFT", units, "TOPLEFT", 12, 0)
  units.note:SetText("Player and target frames. Colors apply immediately.")

  CreateStepper(units, -22, "Width", function()
    return PotatoUI:GetLayout().unitWidth
  end, function(value)
    PotatoUI:GetLayout().unitWidth = value
  end, 160, 420, 10, 0)
  CreateStepper(units, -48, "Height", function()
    return PotatoUI:GetLayout().unitHeight
  end, function(value)
    PotatoUI:GetLayout().unitHeight = value
  end, 40, 80, 2, 0)
  CreateToggleRow(units, -80, "Player health uses class color", function()
    return PotatoUI:GetLayout().playerClassColor
  end, function(value)
    PotatoUI:GetLayout().playerClassColor = value and true or false
  end)
  CreateColorRow(units, -112, "Player health", function()
    return PotatoUI:GetLayout().playerHealth
  end, function(color)
    PotatoUI:GetLayout().playerHealth = color
  end)
  CreateColorRow(units, -142, "Enemy health", function()
    return PotatoUI:GetLayout().enemyHealth
  end, function(color)
    PotatoUI:GetLayout().enemyHealth = color
  end)
  CreateColorRow(units, -172, "Friend health", function()
    return PotatoUI:GetLayout().friendHealth
  end, function(color)
    PotatoUI:GetLayout().friendHealth = color
  end)
  CreateColorRow(units, -202, "Neutral health", function()
    return PotatoUI:GetLayout().neutralHealth
  end, function(color)
    PotatoUI:GetLayout().neutralHealth = color
  end)

  local party = AddPage("party")
  party.note = party:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  party.note:SetPoint("TOPLEFT", party, "TOPLEFT", 12, 0)
  party.note:SetText("Party and pet frames. Changes apply immediately.")
  CreateStepper(party, -22, "Party width", function()
    return PotatoUI:GetLayout().partyWidth
  end, function(value)
    PotatoUI:GetLayout().partyWidth = value
  end, 140, 360, 10, 0)
  CreateStepper(party, -48, "Party height", function()
    return PotatoUI:GetLayout().partyHeight
  end, function(value)
    PotatoUI:GetLayout().partyHeight = value
  end, 32, 70, 2, 0)
  CreateStepper(party, -74, "Space between party frames", function()
    return PotatoUI:GetLayout().partySpacing
  end, function(value)
    PotatoUI:GetLayout().partySpacing = value
  end, 4, 40, 1, 0)
  CreateStepper(party, -100, "Player pet width", function()
    return PotatoUI:GetLayout().petWidth
  end, function(value)
    PotatoUI:GetLayout().petWidth = value
  end, 100, 280, 10, 0)
  CreateToggleRow(party, -132, "Party health uses class color", function()
    return PotatoUI:GetLayout().partyClassColor
  end, function(value)
    PotatoUI:GetLayout().partyClassColor = value and true or false
  end)
  CreateColorRow(party, -164, "Party health", function()
    return PotatoUI:GetLayout().partyHealth
  end, function(color)
    PotatoUI:GetLayout().partyHealth = color
  end)

  CreateSmallButton(frame, "Reload UI", 18, function()
    if SlashCmdList and SlashCmdList["POTATOUI"] then
      SlashCmdList["POTATOUI"]("reload")
    end
  end)
  CreateSmallButton(frame, "Apply", 130, function()
    PotatoUI:ApplyLayout()
  end)

  ShowPage(frame, "general")
  frame:Hide()
  self.settingsFrame = frame
  if UISpecialFrames then table.insert(UISpecialFrames, "PotatoUISettingsFrame") end
end

function PotatoUI:ToggleSettings()
  self:SetupSettingsWindow()
  RefreshSettingsRows()
  if self.settingsFrame:IsShown() then self.settingsFrame:Hide() else self.settingsFrame:Show() end
end

function PotatoUI:SetupSettingsButton()
  if self.settingsButton then return end
  local parent = Minimap or UIParent
  local button = CreateFrame("Button", "PotatoUISettingsButton", parent)
  button:SetWidth(31)
  button:SetHeight(31)
  if Minimap then
    local saved = PotatoUIDB.settingsButtonPosition
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
  button.icon:SetTexture("Interface\\AddOns\\PotatoUI\\Media\\PotatoIcon")
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
        PotatoUIDB.settingsButtonPosition = { x = x, y = y }
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
    PotatoUI:ToggleSettings()
  end)
  button:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:SetText("PotatoUI Settings")
    GameTooltip:AddLine("Click to configure the addon.", .8, .85, .9, 1)
    GameTooltip:AddLine("Shift-drag to move this button.", .45, .8, 1, 1)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function() GameTooltip:Hide() end)
  self.settingsButton = button
end
