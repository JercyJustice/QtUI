local FEATURE_OPTIONS = {
  { key = "bags", label = "Custom Bags", description = "Use QtUI's combined bag and bank windows." },
  { key = "autoLoot", label = "Auto Loot", description = "Loot opened containers automatically unless Shift is held." },
  { key = "autoSell", label = "Auto-Sell Greys", description = "Sell grey-quality items when a merchant opens." },
  { key = "unitFrames", label = "Player / Target Frames", description = "Replace the native player, target and combo-point frames." },
  { key = "partyFrames", label = "Party / Pet Frames", description = "Replace native party and pet frames." },
  { key = "auras", label = "Aura Displays", description = "Buff and debuff icons on unit frames, plus timed personal buff and own-target-debuff trackers. Shift-click an aura to pin it." },
  { key = "actionBars", label = "Action Bar Edits", description = "Use QtUI's main, utility, stance and pet action-bar layout." },
  { key = "experienceBar", label = "Experience Bar", description = "Show the QtUI level and rested-experience bar." },
  { key = "castBar", label = "Cast Bar", description = "Replace the native player casting bar." },
  { key = "minimap", label = "Minimap Edits", description = "Use QtUI's compact minimap styling, zone text and coordinates. Turn off to keep the native minimap." },
  { key = "dataText", label = "Gold / Time / Performance", description = "Show money, clock, FPS and latency. Click the clock to switch server and local time." },
  { key = "questLog", label = "Custom Quest Log", description = "Replace the native quest log. Full quest text on the left, quest list on the right.", default = true },
  { key = "damageMeter", label = "Damage Meter", description = "Combat meter. Title cycles Current/Overall Damage, DPS and Heal. R resets that window. Add or close extra windows in Settings." },
}

QtUI.featureOptions = FEATURE_OPTIONS

function QtUI:EnsureFeatureDefaults()
  if not QtUIDB.features then QtUIDB.features = {} end
  local _, option
  for _, option in ipairs(FEATURE_OPTIONS) do
    if QtUIDB.features[option.key] == nil then
      if option.default == false then
        QtUIDB.features[option.key] = false
      else
        QtUIDB.features[option.key] = true
      end
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
  if key == "questLog" then
    if enabled then
      if self.SetupQuestLog then self:SetupQuestLog() end
    elseif self.RestoreQuestLogArt then
      self:RestoreQuestLogArt()
    end
  elseif key == "damageMeter" then
    if enabled then
      if self.SetupDamageMeter then self:SetupDamageMeter() end
    elseif self.HideDamageMeter then
      self:HideDamageMeter()
    end
  elseif key == "auras" then
    if enabled and self.SetupAuraWatch then self:SetupAuraWatch() end
    if self.RefreshAuraWatch then self:RefreshAuraWatch() end
    if self.UpdateUnitFrames then self:UpdateUnitFrames() end
  elseif key == "minimap" then
    if enabled then
      if self.SetupMinimap then self:SetupMinimap() end
      if self.ApplySavedPositions then self:ApplySavedPositions() end
    elseif self.RestoreMinimap then
      self:RestoreMinimap()
    end
  end
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
  row:SetHeight(20)
  row:SetPoint("TOPLEFT", parent, "TOPLEFT", 12 + column * 222, -4 - rowIndex * 22)
  row.featureKey = option.key
  row.description = option.description

  row.box = CreateFrame("Frame", nil, row)
  row.box:SetWidth(14)
  row.box:SetHeight(14)
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
  button:SetWidth(width or 88)
  button:SetHeight(20)
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

local function CreateStepper(parent, y, label, getter, setter, minValue, maxValue, step, digits, x)
  local row = CreateFrame("Frame", nil, parent)
  row:SetWidth(x and 220 or 440)
  row:SetHeight(20)
  row:SetPoint("TOPLEFT", parent, "TOPLEFT", x or 10, y)

  row.caption = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  row.caption:SetPoint("LEFT", row, "LEFT", 0, 0)
  row.caption:SetWidth(x and 96 or 210)
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
  minus:SetWidth(20)
  minus:SetHeight(18)
  minus:SetPoint("LEFT", row, "LEFT", x and 100 or 220, 0)
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
  plus:SetWidth(20)
  plus:SetHeight(18)
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

local function CreateHeader(parent, y, text, x, width)
  local row = CreateFrame("Frame", nil, parent)
  row:SetWidth(width or 460)
  row:SetHeight(20)
  row:SetPoint("TOPLEFT", parent, "TOPLEFT", x or 10, y)
  row.title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.title:SetPoint("LEFT", row, "LEFT", 0, 0)
  row.title:SetText("|cff33ffcc" .. text .. "|r")
  row.line = row:CreateTexture(nil, "ARTWORK")
  row.line:SetTexture(.18, .5, .46, .7)
  row.line:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 1)
  row.line:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -8, 1)
  if row.line.SetHeight then
    row.line:SetHeight(2)
    row.line:SetHeight(1)
  end
  return row
end

local activeDrop

local function CloseActiveDrop()
  if activeDrop and activeDrop.menu then
    activeDrop.menu:ClearAllPoints()
    activeDrop.menu:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -2000, 2000)
    if activeDrop.menu.Hide then pcall(activeDrop.menu.Hide, activeDrop.menu) end
    if activeDrop.menu.EnableMouse then activeDrop.menu:EnableMouse(false) end
  end
  activeDrop = nil
end

local function OptionLabel(options, key)
  local i
  for i = 1, table.getn(options) do
    if options[i].key == key then return options[i].label end
  end
  return tostring(key or "")
end

local function CreateDropdown(parent, y, label, getter, setter, options)
  local row = CreateFrame("Frame", nil, parent)
  row:SetWidth(460)
  row:SetHeight(20)
  -- Emberveil ignores SetWidth/SetHeight; opposite corners give the row a real box.
  row:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, y)
  row:SetPoint("BOTTOMRIGHT", parent, "TOPLEFT", 470, y - 20)
  row.options = options

  row.caption = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  row.caption:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
  row.caption:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
  row.caption:SetPoint("RIGHT", row, "LEFT", 160, 0)
  row.caption:SetJustifyH("LEFT")
  if row.caption.SetJustifyV then row.caption:SetJustifyV("CENTER") end
  row.caption:SetText(label)
  row.caption:SetTextColor(.82, .84, .86)

  row.button = CreateFrame("Button", nil, row)
  row.button:SetPoint("TOPLEFT", row, "TOPLEFT", 168, 0)
  row.button:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -20, 0)
  row.button:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 10,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  row.button:SetBackdropColor(.04, .05, .06, .96)
  row.button:SetBackdropBorderColor(.22, .28, .3, 1)
  row.button.text = row.button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  -- Fill the inner face so the value sits in the well, not on the tooltip border.
  row.button.text:SetPoint("TOPLEFT", row.button, "TOPLEFT", 8, -3)
  row.button.text:SetPoint("BOTTOMRIGHT", row.button, "BOTTOMRIGHT", -18, 3)
  row.button.text:SetJustifyH("LEFT")
  if row.button.text.SetJustifyV then row.button.text:SetJustifyV("CENTER") end
  row.button.arrow = row.button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  row.button.arrow:SetPoint("TOPRIGHT", row.button, "TOPRIGHT", -7, -5)
  row.button.arrow:SetPoint("BOTTOMRIGHT", row.button, "BOTTOMRIGHT", -7, 5)
  row.button.arrow:SetJustifyH("RIGHT")
  if row.button.arrow.SetJustifyV then row.button.arrow:SetJustifyV("CENTER") end
  row.button.arrow:SetText("|cff888888v|r")

  row.menu = CreateFrame("Frame", nil, UIParent)
  row.menu:SetFrameStrata("TOOLTIP")
  row.menu:SetFrameLevel(250)
  row.menu:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 10,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  row.menu:SetBackdropColor(.03, .035, .04, .98)
  row.menu:SetBackdropBorderColor(.25, .34, .36, 1)
  row.menu:EnableMouse(true)
  row.menu.buttons = {}

  local function RebuildMenu()
    local i
    for i = 1, table.getn(row.menu.buttons) do
      row.menu.buttons[i]:Hide()
    end
    local count = table.getn(row.options)
    local height = 6 + count * 16
    -- The menu lives on UIParent at TOOLTIP strata so it can escape the content
    -- pane, which means nothing stops it drawing past the bottom of the settings
    -- window. Open upwards when there is not room below inside the window.
    local flip
    local settings = QtUI.settingsFrame
    local buttonBottom = row.button.GetBottom and row.button:GetBottom()
    local windowBottom = settings and settings.GetBottom and settings:GetBottom()
    if buttonBottom and windowBottom and (buttonBottom - 2 - height) < windowBottom then
      local buttonTop = row.button.GetTop and row.button:GetTop()
      local windowTop = settings.GetTop and settings:GetTop()
      -- Only flip if the menu actually fits above; otherwise down is no worse.
      if buttonTop and windowTop and (buttonTop + 2 + height) <= windowTop then
        flip = true
      end
    end
    row.menu:ClearAllPoints()
    if flip then
      row.menu:SetPoint("BOTTOMLEFT", row.button, "TOPLEFT", 0, 2)
      row.menu:SetPoint("BOTTOMRIGHT", row.button, "TOPRIGHT", 0, 2)
      row.menu:SetPoint("TOPLEFT", row.button, "TOPLEFT", 0, 2 + height)
    else
      row.menu:SetPoint("TOPLEFT", row.button, "BOTTOMLEFT", 0, -2)
      row.menu:SetPoint("TOPRIGHT", row.button, "BOTTOMRIGHT", 0, -2)
      row.menu:SetPoint("BOTTOMLEFT", row.button, "BOTTOMLEFT", 0, -2 - height)
    end
    for i = 1, count do
      local spec = row.options[i]
      local btn = row.menu.buttons[i]
      if not btn then
        btn = CreateFrame("Button", nil, row.menu)
        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.text:SetPoint("TOPLEFT", btn, "TOPLEFT", 8, 0)
        btn.text:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -6, 0)
        btn.text:SetJustifyH("LEFT")
        if btn.text.SetJustifyV then btn.text:SetJustifyV("CENTER") end
        btn:EnableMouse(true)
        btn:RegisterForClicks("LeftButtonUp")
        btn:SetScript("OnEnter", function()
          if this.text then this.text:SetTextColor(1, .9, .48) end
        end)
        btn:SetScript("OnLeave", function()
          if this.text then this.text:SetTextColor(.82, .84, .86) end
        end)
        btn:SetScript("OnClick", function()
          setter(this.optionKey)
          row.Refresh()
          CloseActiveDrop()
          QtUI:ApplyLayout()
        end)
        row.menu.buttons[i] = btn
      end
      btn.optionKey = spec.key
      btn.text:SetText(spec.label)
      btn.text:SetTextColor(.82, .84, .86)
      btn:ClearAllPoints()
      btn:SetPoint("TOPLEFT", row.menu, "TOPLEFT", 4, -(3 + (i - 1) * 16))
      btn:SetPoint("TOPRIGHT", row.menu, "TOPRIGHT", -4, -(3 + (i - 1) * 16))
      btn:SetPoint("BOTTOMLEFT", row.menu, "TOPLEFT", 4, -(3 + i * 16))
      btn:Show()
    end
  end

  local function Refresh()
    row.button.text:SetText(OptionLabel(row.options, getter()))
  end

  row.button:SetScript("OnClick", function()
    if activeDrop == row then
      CloseActiveDrop()
      return
    end
    CloseActiveDrop()
    RebuildMenu()
    if row.menu.Show then pcall(row.menu.Show, row.menu) end
    if row.menu.EnableMouse then row.menu:EnableMouse(true) end
    activeDrop = row
  end)

  CloseActiveDrop()
  row.menu:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -2000, 2000)
  if row.menu.Hide then pcall(row.menu.Hide, row.menu) end
  Refresh()
  row.Refresh = Refresh
  return row
end

local COLOR_PRESETS = {
  { .78, .12, .12 }, { .15, .72, .22 }, { .2, .75, .25 }, { .82, .68, .16 },
  { .12, .38, .82 }, { .88, .58, .16 }, { .96, .55, .73 }, { .78, .61, .43 },
}

local colorPicker

local function ClampByte(value)
  value = math.floor((tonumber(value) or 0) + .5)
  if value < 0 then value = 0 end
  if value > 255 then value = 255 end
  return value
end

local function EnsureColorPicker()
  if colorPicker then return colorPicker end
  local p = CreateFrame("Frame", "QtUIColorPicker", UIParent)
  p:SetFrameStrata("FULLSCREEN_DIALOG")
  p:SetFrameLevel(320)
  p:SetPoint("TOPLEFT", UIParent, "CENTER", -110, 80)
  p:SetPoint("BOTTOMRIGHT", UIParent, "CENTER", 110, -80)
  p:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  p:SetBackdropColor(.015, .018, .022, .98)
  p:SetBackdropBorderColor(.4, .52, .54, 1)
  p:EnableMouse(true)
  p.title = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  p.title:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -10)
  p.title:SetText("|cff33ffccColor|r")
  p.preview = CreateFrame("Frame", nil, p)
  p.preview:SetPoint("TOPRIGHT", p, "TOPRIGHT", -12, -10)
  p.preview:SetPoint("BOTTOMRIGHT", p, "TOPRIGHT", -12, -36)
  p.preview:SetPoint("BOTTOMLEFT", p, "TOPRIGHT", -48, -36)
  p.preview:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  p.r = 255
  p.g = 255
  p.b = 255
  local function PaintPreview()
    p.preview:SetBackdropColor(p.r / 255, p.g / 255, p.b / 255, 1)
    if p.rLabel then p.rLabel:SetText("R  " .. p.r) end
    if p.gLabel then p.gLabel:SetText("G  " .. p.g) end
    if p.bLabel then p.bLabel:SetText("B  " .. p.b) end
  end
  local function MakeChannel(key, y)
    local label = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", p, "TOPLEFT", 12, y)
    p[key .. "Label"] = label
    local minus = CreateFrame("Button", nil, p)
    minus:SetPoint("TOPLEFT", p, "TOPLEFT", 86, y + 2)
    minus:SetPoint("BOTTOMRIGHT", p, "TOPLEFT", 106, y - 16)
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
      p[key] = ClampByte(p[key] - 5)
      PaintPreview()
    end)
    local plus = CreateFrame("Button", nil, p)
    plus:SetPoint("TOPLEFT", p, "TOPLEFT", 184, y + 2)
    plus:SetPoint("BOTTOMRIGHT", p, "TOPLEFT", 204, y - 16)
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
      p[key] = ClampByte(p[key] + 5)
      PaintPreview()
    end)
  end
  MakeChannel("r", -44)
  MakeChannel("g", -68)
  MakeChannel("b", -92)
  local ok = CreateFrame("Button", nil, p)
  ok:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 12, 10)
  ok:SetPoint("TOPRIGHT", p, "BOTTOMLEFT", 100, 30)
  ok:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  ok:SetBackdropColor(.08, .4, .64, .95)
  ok.text = ok:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  ok.text:SetPoint("CENTER", ok, "CENTER", 0, 0)
  ok.text:SetText("OK")
  ok:SetScript("OnClick", function()
    if p.apply then
      p.apply({ r = p.r / 255, g = p.g / 255, b = p.b / 255 })
    end
    p:Hide()
  end)
  local cancel = CreateFrame("Button", nil, p)
  cancel:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 108, 10)
  cancel:SetPoint("TOPRIGHT", p, "BOTTOMLEFT", 196, 30)
  cancel:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  cancel:SetBackdropColor(.04, .05, .06, .95)
  cancel.text = cancel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  cancel.text:SetPoint("CENTER", cancel, "CENTER", 0, 0)
  cancel.text:SetText("Cancel")
  cancel:SetScript("OnClick", function() p:Hide() end)
  p.PaintPreview = PaintPreview
  p:Hide()
  colorPicker = p
  return p
end

local function OpenColorPicker(color, apply)
  local p = EnsureColorPicker()
  color = color or {}
  p.r = ClampByte((tonumber(color.r) or 1) * 255)
  p.g = ClampByte((tonumber(color.g) or 1) * 255)
  p.b = ClampByte((tonumber(color.b) or 1) * 255)
  p.apply = apply
  p.PaintPreview()
  if p.Show then pcall(p.Show, p) end
end

local function CreateColorRow(parent, y, label, getter, setter)
  local row = CreateFrame("Frame", nil, parent)
  row:SetWidth(440)
  row:SetHeight(20)
  row:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, y)

  row.caption = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  row.caption:SetPoint("LEFT", row, "LEFT", 0, 0)
  row.caption:SetWidth(150)
  row.caption:SetJustifyH("LEFT")
  row.caption:SetText(label)

  row.preview = CreateFrame("Button", nil, row)
  row.preview:SetWidth(18)
  row.preview:SetHeight(16)
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

  row.preview:SetScript("OnClick", function()
    OpenColorPicker(getter(), function(color)
      setter(color)
      Refresh()
      QtUI:ApplyLayout()
    end)
  end)

  local i
  for i = 1, table.getn(COLOR_PRESETS) do
    local preset = COLOR_PRESETS[i]
    local swatch = CreateFrame("Button", nil, row)
    swatch:SetWidth(12)
    swatch:SetHeight(12)
    swatch:SetPoint("LEFT", row.preview, "RIGHT", 8 + (i - 1) * 16, 0)
    swatch:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 8, edgeSize = 6,
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

local function CreateToggleRow(parent, y, label, getter, setter, x, width)
  local row = CreateFrame("Button", nil, parent)
  row:SetWidth(width or 440)
  row:SetHeight(20)
  row:SetPoint("TOPLEFT", parent, "TOPLEFT", x or 10, y)

  row.box = CreateFrame("Frame", nil, row)
  row.box:SetWidth(14)
  row.box:SetHeight(14)
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

local function CreateWatchListBox(parent, y, kind)
  local row = CreateFrame("Frame", nil, parent)
  row:SetWidth(440)
  row:SetHeight(42)
  row:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, y)

  row.caption = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  row.caption:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
  row.caption:SetText("Spell names, comma-separated")

  local box = CreateFrame("EditBox", nil, row)
  box:SetAutoFocus(false)
  if box.SetMultiLine then box:SetMultiLine(nil) end
  if box.SetFontObject then box:SetFontObject(GameFontHighlightSmall) end
  box:SetTextInsets(6, 4, 4, 4)
  if box.SetMaxLetters then box:SetMaxLetters(400) end
  box:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  box:SetBackdropColor(.04, .05, .06, 1)
  box:SetBackdropBorderColor(.18, .24, .28, 1)
  box:ClearAllPoints()
  box:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
  box:SetPoint("TOPRIGHT", row, "BOTTOMLEFT", 430, 20)
  if box.SetWidth then box:SetWidth(430) end
  if box.SetHeight then box:SetHeight(20) end
  if box.EnableMouse then box:EnableMouse(true) end

  local function Load()
    if QtUI.GetAuraWatchListText then box:SetText(QtUI:GetAuraWatchListText(kind) or "") end
  end
  local function Save()
    if QtUI.SetAuraWatchListText then QtUI:SetAuraWatchListText(box:GetText(), kind) end
  end
  box:SetScript("OnEnterPressed", function()
    Save()
    this:ClearFocus()
  end)
  box:SetScript("OnEscapePressed", function()
    Load()
    this:ClearFocus()
  end)
  box:SetScript("OnEditFocusGained", function()
    Load()
  end)
  box:SetScript("OnEditFocusLost", function()
    Save()
  end)
  Load()
  row.box = box
  row.Refresh = Load
  return row
end

local function CreateSection(parent, y, height, x, width)
  local box = CreateFrame("Frame", nil, parent)
  x = x or 4
  width = width or 462
  box:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  box:SetPoint("BOTTOMRIGHT", parent, "TOPLEFT", x + width, y - height)
  box:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 10,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  box:SetBackdropColor(.018, .022, .026, .55)
  box:SetBackdropBorderColor(.14, .28, .26, .75)
  local parentLevel = parent.GetFrameLevel and parent:GetFrameLevel() or 1
  if box.SetFrameLevel then box:SetFrameLevel(parentLevel) end
  return box
end

local function CreateFeatureToggle(parent, y, key, x, width)
  local spec
  local i
  for i = 1, table.getn(FEATURE_OPTIONS) do
    if FEATURE_OPTIONS[i].key == key then
      spec = FEATURE_OPTIONS[i]
      break
    end
  end
  if not spec then return end
  return CreateToggleRow(parent, y, spec.label, function()
    return QtUI:IsFeatureEnabled(key)
  end, function(value)
    QtUI:SetFeatureEnabled(key, value)
  end, x, width)
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
  { key = "topleft", label = "Top Left" },
  { key = "top", label = "Top" },
  { key = "topright", label = "Top Right" },
  { key = "left", label = "Left" },
  { key = "center", label = "Center" },
  { key = "right", label = "Right" },
  { key = "bottomleft", label = "Bottom Left" },
  { key = "bottom", label = "Bottom" },
  { key = "bottomright", label = "Bottom Right" },
}

local function CreateAlignPicker(parent, y, label, getter, setter)
  return CreateDropdown(parent, y, label, getter, setter, ALIGN_OPTIONS)
end

local function ShowPage(frame, key)
  CloseActiveDrop()
  -- Hide() alone is not reliable on Emberveil, and a page that fails to hide keeps
  -- drawing over the incoming page and over the window chrome -- nothing here clips.
  -- Park the outgoing pages off-screen as well, the way the rest of the addon does,
  -- and re-anchor the incoming one to the content pane.
  local name, page
  for name, page in pairs(frame.pages) do
    if name == key then
      page:ClearAllPoints()
      if frame.contentPane then
        page:SetAllPoints(frame.contentPane)
      end
      if page.Show then pcall(page.Show, page) end
    else
      page:ClearAllPoints()
      page:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -4000, 4000)
      page:SetPoint("BOTTOMRIGHT", UIParent, "TOPLEFT", -3600, 3600)
      if page.Hide then pcall(page.Hide, page) end
    end
  end
  local _, button
  for _, button in ipairs(frame.navButtons) do
    if button.pageKey == key then
      button:SetBackdropColor(.16, .16, .18, .95)
      button:SetBackdropBorderColor(.45, .38, .18, 1)
      if button.text then button.text:SetTextColor(1, .82, .2) end
    else
      button:SetBackdropColor(.03, .035, .04, .7)
      button:SetBackdropBorderColor(.16, .18, .2, 1)
      if button.text then button.text:SetTextColor(.72, .74, .76) end
    end
  end
  if key == "damagemeter" and frame.RefreshMeterWindows then
    frame.RefreshMeterWindows()
  end
  if key == "profiles" and frame.RefreshProfiles then
    frame.RefreshProfiles()
  end
end

function QtUI:SetupSettingsWindow()
  if self.settingsFrame then return end
  self:EnsureFeatureDefaults()
  self:EnsureLayoutDefaults()

  local frame = self:CreatePanel("QtUISettingsFrame", UIParent, 40)
  frame:SetFrameStrata("DIALOG")
  frame:SetWidth(640)
  frame:SetHeight(540)
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
  frame.close:SetScript("OnClick", function()
    CloseActiveDrop()
    QtUI.settingsFrame:Hide()
  end)
  frame:SetScript("OnHide", function() CloseActiveDrop() end)

  local nav = CreateFrame("Frame", nil, frame)
  nav:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -34)
  nav:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 42)
  nav:SetWidth(124)
  if nav.EnableMouse then nav:EnableMouse(false) end

  local content = CreateFrame("Frame", nil, frame)
  content:SetPoint("TOPLEFT", nav, "TOPRIGHT", 10, 0)
  content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 42)
  if content.EnableMouse then content:EnableMouse(false) end
  -- ShowPage needs this to re-anchor a page it previously parked off-screen.
  frame.contentPane = content

  frame.pages = {}
  frame.navButtons = {}

  local navY = 0
  local function AddNavHeader(label)
    local header = nav:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    header:SetPoint("TOPLEFT", nav, "TOPLEFT", 4, -navY - 2)
    header:SetText("|cff33ffcc" .. string.upper(label) .. "|r")
    navY = navY + 16
    return header
  end

  local function AddNav(key, label, child)
    local button = CreateFrame("Button", nil, nav)
    local height = 18
    local x = child and 6 or 0
    local width = child and 116 or 122
    button:SetWidth(width)
    button:SetHeight(height)
    button:SetPoint("TOPLEFT", nav, "TOPLEFT", x, -navY)
    button:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 8, edgeSize = 8,
      insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    button:SetBackdropColor(.03, .035, .04, .7)
    button:SetBackdropBorderColor(.16, .18, .2, 1)
    button.pageKey = key
    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.text:SetPoint("LEFT", button, "LEFT", child and 8 or 8, 0)
    button.text:SetText(label)
    button.text:SetTextColor(.72, .74, .76)
    button:SetScript("OnClick", function() ShowPage(frame, this.pageKey) end)
    table.insert(frame.navButtons, button)
    navY = navY + height + 1
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
  AddNav("profiles", "Profiles")
  AddNav("chat", "Chat")
  AddNav("actionbars", "Action Bars")
  AddNav("xpbar", "Experience", true)
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
  AddNav("unit-combo", "Combo Points", true)
  AddNav("damagemeter", "Damage Meter")

  local general = AddPage("general")
  CreateHeader(general, 0, "General")
  general.note = general:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  general.note:SetPoint("TOPLEFT", general, "TOPLEFT", 12, -26)
  general.note:SetText("Most toggles need a relog. Bag size applies immediately.")
  CreateSection(general, -48, 122)
  CreateHeader(general, -56, "Bags")
  CreateFeatureToggle(general, -76, "bags")
  CreateStepper(general, -96, "Bag slot size", function()
    return QtUI:GetLayout().bagSlotSize
  end, function(value)
    QtUI:GetLayout().bagSlotSize = value
  end, 24, 52, 2, 0)
  CreateStepper(general, -116, "Bag columns", function()
    return QtUI:GetLayout().bagColumns
  end, function(value)
    QtUI:GetLayout().bagColumns = value
  end, 6, 16, 1, 0)
  CreateToggleRow(general, -136, "Show keyring", function()
    local value = QtUI:GetLayout().bagShowKeys
    return value ~= false and value ~= 0 and value ~= "0"
  end, function(value)
    QtUI:GetLayout().bagShowKeys = value and true or false
    if QtUI.UpdateBags then QtUI:UpdateBags() end
  end)
  CreateSection(general, -180, 118, 4, 226)
  CreateHeader(general, -188, "World", 12, 210)
  CreateFeatureToggle(general, -208, "autoLoot", 12, 210)
  CreateFeatureToggle(general, -228, "autoSell", 12, 210)
  CreateToggleRow(general, -248, "Compare equipped items", function()
    local value = QtUI:GetLayout().eqCompare
    return value ~= false and value ~= 0 and value ~= "0"
  end, function(value)
    QtUI:GetLayout().eqCompare = value and true or false
  end, 12, 210)
  CreateSection(general, -180, 118, 236, 230)
  CreateHeader(general, -188, "Map / Extra", 244, 214)
  CreateFeatureToggle(general, -208, "minimap", 244, 214)
  CreateFeatureToggle(general, -228, "dataText", 244, 214)
  CreateFeatureToggle(general, -248, "questLog", 244, 214)
  CreateSection(general, -308, 104)
  CreateHeader(general, -316, "Snap")
  CreateStepper(general, -336, "Snap range (tolerance)", function()
    return QtUI:GetLayout().snapRange or 10
  end, function(value)
    QtUI:GetLayout().snapRange = value
  end, 2, 40, 1, 0)
  CreateStepper(general, -356, "Inset bottom", function()
    return QtUI:GetLayout().snapPadBottom or 0
  end, function(value)
    QtUI:GetLayout().snapPadBottom = value
  end, 0, 80, 1, 0, 10)
  CreateStepper(general, -356, "Inset top", function()
    return QtUI:GetLayout().snapPadTop or 0
  end, function(value)
    QtUI:GetLayout().snapPadTop = value
  end, 0, 80, 1, 0, 240)
  CreateStepper(general, -376, "Inset left", function()
    return QtUI:GetLayout().snapPadLeft or 0
  end, function(value)
    QtUI:GetLayout().snapPadLeft = value
  end, 0, 80, 1, 0, 10)
  CreateStepper(general, -376, "Inset right", function()
    return QtUI:GetLayout().snapPadRight or 0
  end, function(value)
    QtUI:GetLayout().snapPadRight = value
  end, 0, 80, 1, 0, 240)

  frame.rows = {}

  local function SizeDialog(dialog, width, height)
    dialog:ClearAllPoints()
    dialog:SetWidth(width)
    dialog:SetHeight(height)
    dialog:SetPoint("TOPLEFT", UIParent, "CENTER", -(width / 2), (height / 2) + 20)
    dialog:SetPoint("BOTTOMRIGHT", UIParent, "CENTER", width / 2, -(height / 2) + 20)
  end

  local function ParkFrame(f)
    if not f then return end
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -4000, 4000)
    if f.Hide then pcall(f.Hide, f) end
  end

  local function PlaceDialogButton(button, dialog, x)
    button:ClearAllPoints()
    button:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", x, 12)
    button:SetPoint("TOPRIGHT", dialog, "BOTTOMLEFT", x + 90, 38)
    if button.Show then pcall(button.Show, button) end
  end

  local function PlaceLine(box, dialog, top)
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", dialog, "TOPLEFT", 16, top)
    box:SetPoint("BOTTOMRIGHT", dialog, "TOPLEFT", 504, top - 24)
    if box.SetWidth then
      box:SetWidth(489)
      box:SetWidth(488)
    end
    if box.SetHeight then
      box:SetHeight(23)
      box:SetHeight(22)
    end
    if box.Show then pcall(box.Show, box) end
  end

  local function TryCopyText(text)
    local names = { "CopyToClipboard", "SetClipboard", "SetClipboardText" }
    local i
    for i = 1, table.getn(names) do
      local fn = getglobal(names[i])
      if type(fn) == "function" then
        local ok = pcall(fn, text)
        if ok then return true end
      end
    end
    local clipApi = getglobal("C_Clipboard")
    if type(clipApi) == "table" then
      if type(clipApi.CopyToClipboard) == "function" then
        local ok = pcall(clipApi.CopyToClipboard, text)
        if ok then return true end
      elseif type(clipApi.SetClipboard) == "function" then
        local ok = pcall(clipApi.SetClipboard, text)
        if ok then return true end
      end
    end
    return nil
  end

  -- pfUI urlcopy: a tiny standalone EditBox popup. AutoFocus stays on,
  -- and HighlightText runs from the parent OnShow so Ctrl+C works.
  local function EnsureCopyPopup()
    if frame.copyPopup then return frame.copyPopup end
    local popup = CreateFrame("Frame", "QtUICopyPopup", UIParent)
    popup:SetFrameStrata("FULLSCREEN")
    popup:SetFrameLevel(400)
    popup:SetWidth(420)
    popup:SetHeight(70)
    popup:SetPoint("TOPLEFT", UIParent, "CENTER", -210, 55)
    popup:SetPoint("BOTTOMRIGHT", UIParent, "CENTER", 210, -15)
    popup:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 8, edgeSize = 14,
      insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    popup:SetBackdropColor(.015, .018, .022, .98)
    popup:SetBackdropBorderColor(.4, .52, .54, 1)
    popup:EnableMouse(true)
    popup:SetMovable(true)
    popup:RegisterForDrag("LeftButton")
    popup:SetScript("OnDragStart", function() this:StartMoving() end)
    popup:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    popup:SetScript("OnShow", function()
      if this.text and this.text.HighlightText then
        pcall(this.text.HighlightText, this.text)
      end
    end)

    popup.caption = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    popup.caption:SetPoint("BOTTOMLEFT", popup, "BOTTOMLEFT", 12, 12)
    popup.caption:SetText("Ctrl+C to copy, Esc to close")

    popup.text = CreateFrame("EditBox", "QtUICopyEditBox", popup)
    popup.text:SetTextColor(.2, 1, .8, 1)
    popup.text:SetJustifyH("LEFT")
    popup.text:SetPoint("TOPLEFT", popup, "TOPLEFT", 12, -12)
    popup.text:SetPoint("BOTTOMRIGHT", popup, "TOPRIGHT", -12, -36)
    if popup.text.SetWidth then
      popup.text:SetWidth(397)
      popup.text:SetWidth(396)
    end
    if popup.text.SetHeight then
      popup.text:SetHeight(21)
      popup.text:SetHeight(20)
    end
    popup.text:SetFontObject(GameFontNormal)
    if popup.text.SetMaxLetters then popup.text:SetMaxLetters(0) end
    popup.text:SetAutoFocus(true)
    popup.text:SetTextInsets(4, 4, 2, 2)
    popup.text:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 8, edgeSize = 8,
      insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    popup.text:SetBackdropColor(.04, .05, .06, 1)
    popup.text:SetScript("OnEscapePressed", function()
      popup:Hide()
    end)
    popup.text:SetScript("OnEditFocusGained", function()
      if this.HighlightText then pcall(this.HighlightText, this) end
    end)

    popup.CopyText = function(text)
      popup.text:SetText(text or "")
      popup:Show()
      if popup.text.SetFocus then popup.text:SetFocus() end
      if popup.text.HighlightText then pcall(popup.text.HighlightText, popup.text) end
    end

    popup:Hide()
    if UISpecialFrames then table.insert(UISpecialFrames, "QtUICopyPopup") end
    frame.copyPopup = popup
    return popup
  end

  local function EnsureProfileDialog()
    if frame.profileDialog then return frame.profileDialog end
    local dialog = CreateFrame("Frame", "QtUIProfileDialog", UIParent)
    dialog:SetFrameStrata("FULLSCREEN_DIALOG")
    dialog:SetFrameLevel(300)
    SizeDialog(dialog, 520, 170)
    dialog:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 8, edgeSize = 14,
      insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    dialog:SetBackdropColor(.015, .018, .022, .98)
    dialog:SetBackdropBorderColor(.4, .52, .54, 1)
    dialog:EnableMouse(true)
    dialog.title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dialog.title:SetPoint("TOPLEFT", dialog, "TOPLEFT", 16, -12)
    dialog.note = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dialog.note:SetPoint("TOPLEFT", dialog, "TOPLEFT", 16, -32)
    dialog.note:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -16, -32)
    dialog.note:SetPoint("BOTTOMLEFT", dialog, "TOPLEFT", 16, -52)
    dialog.note:SetJustifyH("LEFT")
    if dialog.note.SetJustifyV then dialog.note:SetJustifyV("TOP") end
    dialog.nameLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dialog.nameLabel:SetPoint("TOPLEFT", dialog, "TOPLEFT", 16, -54)
    dialog.nameLabel:SetText("Name")
    dialog.nameBox = CreateFrame("EditBox", "QtUIProfileNameBox", dialog)
    dialog.nameBox:SetAutoFocus(false)
    if dialog.nameBox.SetFontObject then dialog.nameBox:SetFontObject(GameFontHighlightSmall) end
    dialog.nameBox:SetTextInsets(6, 6, 4, 4)
    if dialog.nameBox.SetMaxLetters then dialog.nameBox:SetMaxLetters(60) end
    dialog.nameBox:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 8, edgeSize = 8,
      insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    dialog.nameBox:SetBackdropColor(.04, .05, .06, 1)
    PlaceLine(dialog.nameBox, dialog, -70)

    dialog.dataLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dialog.dataLabel:SetPoint("TOPLEFT", dialog, "TOPLEFT", 16, -98)
    dialog.dataLabel:SetText("Data")
    -- Single-line only. A multiline EditBox on Emberveil grows through the UI.
    dialog.data = CreateFrame("EditBox", "QtUIProfileDataBox", dialog)
    dialog.data:SetAutoFocus(false)
    if dialog.data.SetMultiLine then dialog.data:SetMultiLine(nil) end
    if dialog.data.SetFontObject then dialog.data:SetFontObject(GameFontHighlightSmall) end
    dialog.data:SetTextInsets(6, 6, 4, 4)
    if dialog.data.SetMaxLetters then dialog.data:SetMaxLetters(40000) end
    dialog.data:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 8, edgeSize = 8,
      insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    dialog.data:SetBackdropColor(.04, .05, .06, 1)
    dialog.data:SetScript("OnEditFocusGained", function()
      if this.HighlightText then pcall(this.HighlightText, this) end
    end)
    dialog.data:SetScript("OnMouseDown", function()
      if this.SetFocus then this:SetFocus() end
      if this.HighlightText then pcall(this.HighlightText, this) end
    end)
    dialog.data:SetScript("OnEscapePressed", function()
      if this.ClearFocus then this:ClearFocus() end
    end)
    PlaceLine(dialog.data, dialog, -114)

    dialog.accept = CreateSmallButton(dialog, "OK", 16, function()
      if dialog.onAccept then dialog.onAccept(dialog) end
    end, 90)
    dialog.cancel = CreateSmallButton(dialog, "Close", 116, function()
      if frame.copyPopup then frame.copyPopup:Hide() end
      dialog:Hide()
    end, 90)
    dialog.copy = CreateSmallButton(dialog, "Browser", 216, function()
      local text = ""
      if dialog.data and dialog.data.GetText then text = dialog.data:GetText() or "" end
      if text == "" then
        QtUI:Print("Nothing to export.")
        return
      end
      if QtUI.OpenTextInBrowser and QtUI:OpenTextInBrowser(text, "QtUI Export") then
        QtUI:Print("Opened export in your browser.")
        if dialog.copy.text then dialog.copy.text:SetText("Opened") end
        return
      end
      if TryCopyText(text) then
        QtUI:Print("Profile copied.")
        if dialog.copy.text then dialog.copy.text:SetText("Copied") end
        return
      end
      local popup = EnsureCopyPopup()
      popup.CopyText(text)
    end, 90)
    dialog:Hide()
    frame.profileDialog = dialog
    return dialog
  end

  local function OpenProfileDialog(kind)
    local dialog = EnsureProfileDialog()
    dialog.kind = kind
    dialog.nameBox:SetText("")
    dialog.data:SetText("")
    if kind == "save" then
      SizeDialog(dialog, 520, 150)
      dialog.title:SetText("|cff33ffccSave Profile|r")
      dialog.note:SetText("Store the current UI as a named profile.")
      dialog.nameLabel:Show()
      PlaceLine(dialog.nameBox, dialog, -70)
      dialog.dataLabel:Hide()
      ParkFrame(dialog.data)
      ParkFrame(dialog.copy)
      PlaceDialogButton(dialog.accept, dialog, 16)
      PlaceDialogButton(dialog.cancel, dialog, 116)
      dialog.onAccept = function(d)
        local name = QtUI:SaveProfile(d.nameBox:GetText())
        if name then
          QtUI:Print("Saved profile '" .. name .. "'.")
          d:Hide()
          if frame.RefreshProfiles then frame.RefreshProfiles() end
        else
          QtUI:Print("Enter a profile name.")
        end
      end
    elseif kind == "export" then
      SizeDialog(dialog, 520, 170)
      dialog.title:SetText("|cff33ffccExport Profile|r")
      dialog.note:SetText("Browser opens the string so you can copy it. Positions scale on import.")
      ParkFrame(dialog.nameBox)
      dialog.nameLabel:Hide()
      dialog.dataLabel:Show()
      dialog.dataLabel:ClearAllPoints()
      dialog.dataLabel:SetPoint("TOPLEFT", dialog, "TOPLEFT", 16, -54)
      PlaceLine(dialog.data, dialog, -70)
      dialog.data:SetText(QtUI:ExportProfile() or "")
      if dialog.data.SetFocus then dialog.data:SetFocus() end
      if dialog.data.HighlightText then pcall(dialog.data.HighlightText, dialog.data) end
      PlaceDialogButton(dialog.copy, dialog, 16)
      PlaceDialogButton(dialog.cancel, dialog, 116)
      ParkFrame(dialog.accept)
      if dialog.copy.text then dialog.copy.text:SetText("Browser") end
      dialog.onAccept = function(d) d:Hide() end
    else
      SizeDialog(dialog, 520, 200)
      dialog.title:SetText("|cff33ffccImport Profile|r")
      dialog.note:SetText("Name is required. Duplicate names get a number suffix.")
      dialog.nameLabel:Show()
      PlaceLine(dialog.nameBox, dialog, -70)
      dialog.dataLabel:Show()
      dialog.dataLabel:ClearAllPoints()
      dialog.dataLabel:SetPoint("TOPLEFT", dialog, "TOPLEFT", 16, -98)
      PlaceLine(dialog.data, dialog, -114)
      ParkFrame(dialog.copy)
      PlaceDialogButton(dialog.accept, dialog, 16)
      PlaceDialogButton(dialog.cancel, dialog, 116)
      dialog.onAccept = function(d)
        local name, err = QtUI:ImportProfile(d.nameBox:GetText(), d.data:GetText())
        if name then
          QtUI:Print("Imported as '" .. name .. "'.")
          d:Hide()
          if frame.RefreshProfiles then frame.RefreshProfiles() end
        else
          QtUI:Print(err or "Import failed.")
        end
      end
    end
    dialog:Show()
  end

  local profiles = AddPage("profiles")
  CreateSection(profiles, 0, 196)
  CreateHeader(profiles, -8, "Profiles")
  profiles.note = profiles:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  profiles.note:SetPoint("TOPLEFT", profiles, "TOPLEFT", 16, -34)
  profiles.note:SetWidth(450)
  profiles.note:SetJustifyH("LEFT")
  profiles.note:SetText("Save the current layout or load another profile. Share is disabled until Emberveil can copy text.")

  local profileOptions = { { key = "Default", label = "Default" } }
  local profileDrop = CreateDropdown(profiles, -58, "Profile", function()
    return QtUIDB.activeProfile or "Default"
  end, function(value)
    QtUIDB.activeProfile = value
  end, profileOptions)

  local function RefreshProfiles()
    QtUI:EnsureProfiles()
    local names = QtUI:ProfileNames()
    local opts = {}
    local i
    for i = 1, table.getn(names) do
      table.insert(opts, { key = names[i], label = names[i] })
    end
    if table.getn(opts) < 1 then
      table.insert(opts, { key = "Default", label = "Default" })
    end
    profileDrop.options = opts
    profileDrop.Refresh()
  end
  frame.RefreshProfiles = RefreshProfiles
  RefreshProfiles()

  CreateHeader(profiles, -80, "Manage")
  local loadBtn = CreateSmallButton(profiles, "Load", 12, function()
    local name = QtUIDB.activeProfile
    if QtUI:LoadProfile(name) then
      QtUI:Print("Loaded '" .. name .. "'. Some toggles need a relog.")
      RefreshSettingsRows()
      RefreshProfiles()
    end
  end, 90)
  loadBtn:ClearAllPoints()
  loadBtn:SetPoint("TOPLEFT", profiles, "TOPLEFT", 12, -104)

  local saveBtn = CreateSmallButton(profiles, "Save", 110, function()
    local name = QtUIDB.activeProfile
    if name and QtUI:SaveProfile(name) then
      QtUI:Print("Saved '" .. name .. "'.")
      RefreshProfiles()
    end
  end, 90)
  saveBtn:ClearAllPoints()
  saveBtn:SetPoint("TOPLEFT", profiles, "TOPLEFT", 110, -104)

  local saveAsBtn = CreateSmallButton(profiles, "Save As", 208, function()
    OpenProfileDialog("save")
  end, 90)
  saveAsBtn:ClearAllPoints()
  saveAsBtn:SetPoint("TOPLEFT", profiles, "TOPLEFT", 208, -104)

  local delBtn = CreateSmallButton(profiles, "Delete", 306, function()
    local name = QtUIDB.activeProfile
    if name then
      QtUI:DeleteProfile(name)
      QtUI:Print("Deleted '" .. name .. "'.")
      RefreshProfiles()
    end
  end, 90)
  delBtn:ClearAllPoints()
  delBtn:SetPoint("TOPLEFT", profiles, "TOPLEFT", 306, -104)

  CreateHeader(profiles, -140, "Share")
  local function DisableShareButton(button, why)
    button:SetScript("OnClick", nil)
    button:SetScript("OnEnter", function()
      if GameTooltip then
        GameTooltip:SetOwner(this, "ANCHOR_TOP")
        GameTooltip:SetText("Unavailable")
        GameTooltip:AddLine(why, .8, .85, .9, 1)
        GameTooltip:Show()
      end
    end)
    button:SetScript("OnLeave", function()
      if GameTooltip then GameTooltip:Hide() end
    end)
    button:SetBackdropColor(.03, .03, .035, .7)
    button:SetBackdropBorderColor(.16, .16, .18, 1)
    if button.text then button.text:SetTextColor(.42, .42, .44) end
    if button.EnableMouse then button:EnableMouse(true) end
    if button.Disable then pcall(button.Disable, button) end
  end

  local exportBtn = CreateSmallButton(profiles, "Export", 12, function() end, 90)
  exportBtn:ClearAllPoints()
  exportBtn:SetPoint("TOPLEFT", profiles, "TOPLEFT", 12, -164)
  DisableShareButton(exportBtn, "Emberveil cannot copy text from an EditBox.")

  local importBtn = CreateSmallButton(profiles, "Import", 110, function() end, 90)
  importBtn:ClearAllPoints()
  importBtn:SetPoint("TOPLEFT", profiles, "TOPLEFT", 110, -164)
  DisableShareButton(importBtn, "Emberveil cannot paste a profile string.")

  local bars = AddPage("actionbars")
  CreateSection(bars, 0, 400)
  CreateHeader(bars, -8, "Action Bars")
  CreateFeatureToggle(bars, -28, "actionBars")
  bars.note = bars:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  bars.note:SetPoint("TOPLEFT", bars, "TOPLEFT", 12, -22)
  bars.note:SetWidth(450)
  bars.note:SetJustifyH("LEFT")
  bars.note:SetText("")

  CreateToggleRow(bars, -48, "Show action-bar background", function()
    local value = QtUI:GetLayout().barShowBackground
    return value == true or value == 1 or value == "1"
  end, function(value)
    QtUI:GetLayout().barShowBackground = value and 1 or 0
  end)
  CreateColorRow(bars, -64, "Bar background", function()
    return QtUI:GetLayout().barBackground
  end, function(color)
    local current = QtUI:GetLayout().barBackground
    color.a = current.a or .85
    QtUI:GetLayout().barBackground = color
  end)
  CreateStepper(bars, -104, "Background opacity", function()
    return QtUI:GetLayout().barBackground.a or .85
  end, function(value)
    QtUI:GetLayout().barBackground.a = value
  end, 0.1, 1, 0.05, 2)
  CreateColorRow(bars, -132, "Bar border", function()
    return QtUI:GetLayout().barBorder
  end, function(color)
    QtUI:GetLayout().barBorder = color
  end)
  CreateToggleRow(bars, -160, "Show slot background", function()
    local value = QtUI:GetLayout().slotShowBackground
    return value ~= false and value ~= 0 and value ~= "0"
  end, function(value)
    QtUI:GetLayout().slotShowBackground = value and 1 or 0
  end)
  CreateToggleRow(bars, -188, "Show button frame", function()
    local value = QtUI:GetLayout().slotShowRim
    return value ~= false and value ~= 0 and value ~= "0"
  end, function(value)
    QtUI:GetLayout().slotShowRim = value and 1 or 0
  end)
  CreateToggleRow(bars, -208, "Hide empty slots", function()
    local value = QtUI:GetLayout().hideEmptySlots
    return value == true or value == 1 or value == "1"
  end, function(value)
    QtUI:GetLayout().hideEmptySlots = value and true or false
    if QtUI.ApplyEmptySlotVisibility then QtUI:ApplyEmptySlotVisibility() end
  end)
  CreateColorRow(bars, -236, "Slot background", function()
    return QtUI:GetLayout().slotBackground
  end, function(color)
    local current = QtUI:GetLayout().slotBackground
    color.a = current.a or .96
    QtUI:GetLayout().slotBackground = color
  end)
  CreateStepper(bars, -264, "Slot opacity", function()
    return QtUI:GetLayout().slotBackground.a or .96
  end, function(value)
    QtUI:GetLayout().slotBackground.a = value
  end, 0.1, 1, 0.05, 2)
  CreateColorRow(bars, -292, "Slot border", function()
    return QtUI:GetLayout().slotBorder
  end, function(color)
    QtUI:GetLayout().slotBorder = color
  end)
  CreateToggleRow(bars, -320, "Leave shapeshift to cast", function()
    local value = QtUI:GetLayout().unshiftToCast
    return value ~= false and value ~= 0 and value ~= "0"
  end, function(value)
    QtUI:GetLayout().unshiftToCast = value and true or false
  end)
  CreateToggleRow(bars, -348, "Cooldown numbers", function()
    local value = QtUI:GetLayout().cooldownText
    return value ~= false and value ~= 0 and value ~= "0"
  end, function(value)
    QtUI:GetLayout().cooldownText = value and true or false
  end)
  CreateToggleRow(bars, -376, "Color out of range / OOM", function()
    local value = QtUI:GetLayout().barRangeColor
    return value ~= false and value ~= 0 and value ~= "0"
  end, function(value)
    QtUI:GetLayout().barRangeColor = value and true or false
  end)

  local xp = AddPage("xpbar")
  CreateSection(xp, 0, 162)
  CreateHeader(xp, -8, "Experience Bar")
  CreateFeatureToggle(xp, -28, "experienceBar")
  xp.note = xp:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  xp.note:SetPoint("TOPLEFT", xp, "TOPLEFT", 12, -22)
  xp.note:SetWidth(450)
  xp.note:SetJustifyH("LEFT")
  xp.note:SetText("")
  CreateStepper(xp, -48, "Width", function()
    return QtUI:GetLayout().xpBarWidth or 442
  end, function(value)
    QtUI:GetLayout().xpBarWidth = value
  end, 80, 800, 10, 0)
  CreateStepper(xp, -70, "Height", function()
    return QtUI:GetLayout().xpBarHeight or 20
  end, function(value)
    QtUI:GetLayout().xpBarHeight = value
  end, 12, 32, 1, 0)
  CreateStepper(xp, -92, "Text size", function()
    return QtUI:GetLayout().xpBarFontSize or 12
  end, function(value)
    QtUI:GetLayout().xpBarFontSize = value
  end, 8, 18, 1, 0)
  CreateToggleRow(xp, -118, "Show text on the bar", function()
    local value = QtUI:GetLayout().xpBarText
    return value ~= false and value ~= 0 and value ~= "0"
  end, function(value)
    QtUI:GetLayout().xpBarText = value and true or false
  end)

  local LAYOUT_OPTIONS = {
    { key = "1x12", label = "1 x 12" },
    { key = "2x6", label = "2 x 6" },
    { key = "3x4", label = "3 x 4" },
    { key = "4x3", label = "4 x 3" },
    { key = "6x2", label = "6 x 2" },
    { key = "12x1", label = "12 x 1" },
  }

  local function LayoutKeyForBar(bar)
    local c = bar.columns or 12
    local r = bar.rows or 1
    local i
    for i = 1, table.getn(GRID_PRESETS) do
      if GRID_PRESETS[i].columns == c and GRID_PRESETS[i].rows == r then
        return GRID_PRESETS[i].label
      end
    end
    return "12x1"
  end

  local function BuildBarPage(pageKey, barKey, blurb)
    local page = AddPage(pageKey)
    CreateSection(page, 0, 228)
    page.note = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    page.note:SetPoint("TOPLEFT", page, "TOPLEFT", 16, -12)
    page.note:SetWidth(430)
    page.note:SetJustifyH("LEFT")
    page.note:SetText(blurb)
    CreateToggleRow(page, -34, "Show this bar", function()
      return QtUI:GetBarConfig(barKey).enabled ~= false
    end, function(value)
      QtUI:GetBarConfig(barKey).enabled = value and true or false
    end)
    CreateStepper(page, -56, "Button size", function()
      return QtUI:GetBarConfig(barKey).size
    end, function(value)
      QtUI:GetBarConfig(barKey).size = value
    end, 20, 52, 2, 0)
    CreateStepper(page, -78, "Spacing", function()
      return QtUI:GetBarConfig(barKey).spacing
    end, function(value)
      QtUI:GetBarConfig(barKey).spacing = value
    end, 0, 12, 1, 0)
    CreateDropdown(page, -100, "Layout", function()
      return LayoutKeyForBar(QtUI:GetBarConfig(barKey))
    end, function(key)
      local i
      for i = 1, table.getn(GRID_PRESETS) do
        if GRID_PRESETS[i].label == key then
          local bar = QtUI:GetBarConfig(barKey)
          bar.columns = GRID_PRESETS[i].columns
          bar.rows = GRID_PRESETS[i].rows
          break
        end
      end
    end, LAYOUT_OPTIONS)
    CreateAlignPicker(page, -122, "Hotkey", function()
      return QtUI:GetBarConfig(barKey).hotkeyAlign
    end, function(value)
      QtUI:GetBarConfig(barKey).hotkeyAlign = value
    end)
    CreateStepper(page, -144, "Hotkey size", function()
      return QtUI:GetBarConfig(barKey).hotkeySize
    end, function(value)
      QtUI:GetBarConfig(barKey).hotkeySize = value
    end, 7, 16, 1, 0)
    CreateStepper(page, -166, "Hotkey outline (0 off)", function()
      return QtUI:GetBarConfig(barKey).hotkeyShadow
    end, function(value)
      QtUI:GetBarConfig(barKey).hotkeyShadow = value
    end, 0, 4, 1, 0)
    local applyAll = CreateSmallButton(page, "Apply to all", 12, function()
      if QtUI.ApplyBarConfigToAll then QtUI:ApplyBarConfigToAll(barKey) end
      QtUI:Print("Copied this bar's layout and hotkey settings to all bars.")
    end, 110)
    applyAll:ClearAllPoints()
    applyAll:SetPoint("TOPLEFT", page, "TOPLEFT", 16, -196)
    return page
  end

  BuildBarPage("bar-main", "main", "Primary action buttons 1-12. Pick a grid; it applies only to this bar.")
  BuildBarPage("bar-extra", "extra", "Second bar (bottom-left multi-bar). Independent size, spacing and grid.")
  BuildBarPage("bar-utility", "utility", "Bottom-right utility bar. Independent size, spacing and grid.")
  BuildBarPage("bar-aux", "aux", "Stance, shapeshift and pet buttons. Only learned stances are shown; the grid wraps those plus the pet bar.")
  BuildBarPage("bar-sideright", "sideRight", "Right side bar. All 12 buttons stay visible.")
  BuildBarPage("bar-sideleft", "sideLeft", "Left side bar. All 12 buttons stay visible.")

  local units = AddPage("unitframes")
  CreateSection(units, 0, 356)
  CreateHeader(units, -8, "Unit Frames")
  CreateFeatureToggle(units, -28, "unitFrames")
  CreateFeatureToggle(units, -48, "partyFrames")
  CreateFeatureToggle(units, -68, "auras")
  CreateFeatureToggle(units, -88, "castBar")
  units.note = units:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  units.note:SetPoint("TOPLEFT", units, "TOPLEFT", 12, -22)
  units.note:SetWidth(450)
  units.note:SetJustifyH("LEFT")
  units.note:SetText("")

  CreateToggleRow(units, -108, "Class on player tooltips", function()
    local value = QtUI:GetLayout().classTooltip
    return value ~= false and value ~= 0 and value ~= "0"
  end, function(value)
    QtUI:GetLayout().classTooltip = value and true or false
  end)
  CreateToggleRow(units, -128, "Gradient bars", function()
    local value = QtUI:GetLayout().unitGradient
    return value == true or value == 1 or value == "1"
  end, function(value)
    QtUI:GetLayout().unitGradient = value and true or false
  end)
  CreateColorRow(units, -148, "Player health", function()
    return QtUI:GetLayout().playerHealth
  end, function(color)
    QtUI:GetLayout().playerHealth = color
  end)
  CreateColorRow(units, -170, "Enemy health", function()
    return QtUI:GetLayout().enemyHealth
  end, function(color)
    QtUI:GetLayout().enemyHealth = color
  end)
  CreateColorRow(units, -192, "Friend health", function()
    return QtUI:GetLayout().friendHealth
  end, function(color)
    QtUI:GetLayout().friendHealth = color
  end)
  CreateColorRow(units, -214, "Neutral health", function()
    return QtUI:GetLayout().neutralHealth
  end, function(color)
    QtUI:GetLayout().neutralHealth = color
  end)
  CreateColorRow(units, -236, "Party health", function()
    return QtUI:GetLayout().partyHealth
  end, function(color)
    QtUI:GetLayout().partyHealth = color
  end)
  CreateToggleRow(units, -258, "Target of target", function()
    local value = QtUI:GetLayout().showTargetTarget
    return value ~= false and value ~= 0 and value ~= "0"
  end, function(value)
    QtUI:GetLayout().showTargetTarget = value and true or false
  end)
  CreateToggleRow(units, -280, "Energy / mana tick", function()
    local value = QtUI:GetLayout().energyTick
    return value ~= false and value ~= 0 and value ~= "0"
  end, function(value)
    QtUI:GetLayout().energyTick = value and true or false
  end)
  CreateStepper(units, -302, "Tick width", function()
    return QtUI:GetLayout().energyTickWidth or 1
  end, function(value)
    QtUI:GetLayout().energyTickWidth = value
  end, 1, 8, 1, 0)
  CreateStepper(units, -324, "Tick opacity", function()
    return QtUI:GetLayout().energyTickAlpha or .95
  end, function(value)
    QtUI:GetLayout().energyTickAlpha = value
  end, 0.1, 1, 0.05, 2)

  local function BuildUnitPage(pageKey, styleKey, blurb, extras)
    local page = AddPage(pageKey)
    -- Provisional height only. The real extent is not known until the rows are
    -- built, so the box is re-anchored to the final y at the end of this
    -- function. The old fixed 590 for tracker pages was taller than the content
    -- pane (464), and nothing in this window clips, so its border drew across
    -- the bottom of the settings frame and onto the world.
    local section = CreateSection(page, 0, 360)
    page.note = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    page.note:SetPoint("TOPLEFT", page, "TOPLEFT", 16, -10)
    page.note:SetWidth(430)
    page.note:SetJustifyH("LEFT")
    page.note:SetText(blurb)
    local y = -32
    CreateHeader(page, y, "Size")
    y = y - 24
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
    CreateHeader(page, y, "Labels")
    y = y - 24
    CreateAlignPicker(page, y, "Name", function()
      return QtUI:GetUnitStyle(styleKey).nameAlign
    end, function(value)
      QtUI:GetUnitStyle(styleKey).nameAlign = value
    end)
    y = y - 26
    CreateAlignPicker(page, y, "Health", function()
      return QtUI:GetUnitStyle(styleKey).healthAlign
    end, function(value)
      QtUI:GetUnitStyle(styleKey).healthAlign = value
    end)
    y = y - 26
    if extras.powerText then
      CreateAlignPicker(page, y, "Mana", function()
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
      y = y - 26
    end
    if extras.healthDb then
      CreateToggleRow(page, y, "Enemy health database", function()
        local value = QtUI:GetLayout().estimateMobHealth
        return value ~= false and value ~= 0 and value ~= "0"
      end, function(value)
        QtUI:GetLayout().estimateMobHealth = value and true or false
      end)
      y = y - 26
    end
    if extras.watchBuffs then
      -- The personal buff tracker is disabled in Auras.lua (PLAYER_WATCH_SAFE):
      -- scanning player buffs access-violates this client at 0x338. Say so rather
      -- than presenting a toggle that silently does nothing.
      CreateHeader(page, y, "Buff tracker  |cff888888(unavailable on this client)|r")
      y = y - 24
      CreateToggleRow(page, y, "Track timed personal buffs", function()
        local value = QtUI:GetLayout().playerBuffWatch
        return value ~= false and value ~= 0 and value ~= "0"
      end, function(value)
        QtUI:GetLayout().playerBuffWatch = value and true or false
        if QtUI.RefreshAuraWatch then QtUI:RefreshAuraWatch() end
      end)
      y = y - 26
      CreateStepper(page, y, "Hide longer than (sec)", function()
        return QtUI:GetLayout().auraWatchThreshold or 120
      end, function(value)
        QtUI:GetLayout().auraWatchThreshold = value
        if QtUI.RefreshAuraWatch then QtUI:RefreshAuraWatch() end
      end, 0, 600, 30, 0)
      y = y - 26
      CreateStepper(page, y, "Tracker width", function()
        return QtUI:GetLayout().playerBuffWatchWidth or 220
      end, function(value)
        QtUI:GetLayout().playerBuffWatchWidth = value
        if QtUI.LayoutAuraWatch then QtUI:LayoutAuraWatch() end
      end, 140, 360, 10, 0)
      y = y - 26
      CreateStepper(page, y, "Bar height", function()
        return QtUI:GetLayout().playerBuffWatchBarHeight or 18
      end, function(value)
        QtUI:GetLayout().playerBuffWatchBarHeight = value
        if QtUI.LayoutAuraWatch then QtUI:LayoutAuraWatch() end
      end, 14, 28, 1, 0)
      y = y - 26
      CreateToggleRow(page, y, "Whitelist only", function()
        local value = QtUI:GetLayout().playerBuffWatchWhitelist
        return value ~= false and value ~= 0 and value ~= "0"
      end, function(value)
        QtUI:GetLayout().playerBuffWatchWhitelist = value and true or false
        if QtUI.RefreshAuraWatch then QtUI:RefreshAuraWatch() end
      end)
      y = y - 26
      CreateWatchListBox(page, y, "player")
    end
    if extras.watchDebuffs then
      CreateHeader(page, y, "Debuff tracker")
      y = y - 24
      CreateToggleRow(page, y, "Track own debuffs on target", function()
        local value = QtUI:GetLayout().targetDebuffWatch
        return value ~= false and value ~= 0 and value ~= "0"
      end, function(value)
        QtUI:GetLayout().targetDebuffWatch = value and true or false
        if QtUI.RefreshAuraWatch then QtUI:RefreshAuraWatch() end
      end)
      y = y - 26
      CreateToggleRow(page, y, "Only own debuffs on target frame", function()
        local value = QtUI:GetLayout().targetOwnDebuffs
        return value ~= false and value ~= 0 and value ~= "0"
      end, function(value)
        QtUI:GetLayout().targetOwnDebuffs = value and true or false
        if QtUI.UpdateUnitFrames then QtUI:UpdateUnitFrames() end
      end)
      y = y - 26
      CreateStepper(page, y, "Tracker width", function()
        return QtUI:GetLayout().targetDebuffWatchWidth or 220
      end, function(value)
        QtUI:GetLayout().targetDebuffWatchWidth = value
        if QtUI.LayoutAuraWatch then QtUI:LayoutAuraWatch() end
      end, 140, 360, 10, 0)
      y = y - 26
      CreateStepper(page, y, "Bar height", function()
        return QtUI:GetLayout().targetDebuffWatchBarHeight or 18
      end, function(value)
        QtUI:GetLayout().targetDebuffWatchBarHeight = value
        if QtUI.LayoutAuraWatch then QtUI:LayoutAuraWatch() end
      end, 14, 28, 1, 0)
      y = y - 26
      CreateToggleRow(page, y, "Whitelist only", function()
        local value = QtUI:GetLayout().targetDebuffWatchWhitelist
        return value ~= false and value ~= 0 and value ~= "0"
      end, function(value)
        QtUI:GetLayout().targetDebuffWatchWhitelist = value and true or false
        if QtUI.RefreshAuraWatch then QtUI:RefreshAuraWatch() end
      end)
      y = y - 26
      CreateWatchListBox(page, y, "target")
    end

    -- Wrap the rows that were actually built, and never spill past the content
    -- pane. CreateSection anchors x=4 width=462, so mirror that here.
    if section then
      -- Fixed geometry on purpose: the content pane is the settings frame (540)
      -- less the 34px title strip and the 42px button strip, so 464. GetHeight is
      -- not trustworthy here and a bad reading would collapse the box.
      local bottom = y - 14
      if bottom < -458 then bottom = -458 end
      section:ClearAllPoints()
      section:SetPoint("TOPLEFT", page, "TOPLEFT", 4, 0)
      section:SetPoint("BOTTOMRIGHT", page, "TOPLEFT", 466, bottom)
    end
    return page
  end

  BuildUnitPage("unit-player", "player", "Player frame size, mana bar and text anchors. Whitelist which buffs to track, or Shift-click an aura. Enter to save names.", {
    height = true, powerHeight = true, powerText = true,
    classColor = "Health uses class color", classColorKey = "playerClassColor",
    minHeight = 40, maxHeight = 100, watchBuffs = true,
  })
  BuildUnitPage("unit-target", "target", "Target frame size, mana bar and text anchors. Whitelist DoTs and CC, or Shift-click a debuff. Own list, separate from player buffs.", {
    height = true, powerHeight = true, powerText = true, classText = true,
    healthDb = true, minHeight = 40, maxHeight = 100, watchDebuffs = true,
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

  local combo = AddPage("unit-combo")
  CreateSection(combo, 0, 140)
  combo.note = combo:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  combo.note:SetPoint("TOPLEFT", combo, "TOPLEFT", 16, -10)
  combo.note:SetWidth(450)
  combo.note:SetJustifyH("LEFT")
  combo.note:SetText("Rogue and cat-form combo points. Drag the bar in Toggle Anchor.")
  CreateStepper(combo, -28, "Point size", function()
    return QtUI:GetLayout().comboPointSize
  end, function(value)
    QtUI:GetLayout().comboPointSize = value
  end, 8, 28, 1, 0)
  CreateStepper(combo, -54, "Spacing", function()
    return QtUI:GetLayout().comboSpacing
  end, function(value)
    QtUI:GetLayout().comboSpacing = value
  end, 0, 12, 1, 0)
  CreateToggleRow(combo, -80, "Show bar background", function()
    local value = QtUI:GetLayout().comboShowBackground
    return value ~= false and value ~= 0 and value ~= "0"
  end, function(value)
    QtUI:GetLayout().comboShowBackground = value and true or false
  end)
  CreateColorRow(combo, -106, "Point color", function()
    return QtUI:GetLayout().comboColor
  end, function(color)
    local current = QtUI:GetLayout().comboColor
    color.a = current.a or 1
    QtUI:GetLayout().comboColor = color
  end)

  local meter = AddPage("damagemeter")
  CreateSection(meter, 0, 242)
  CreateFeatureToggle(meter, -10, "damageMeter")
  meter.note = meter:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  meter.note:SetPoint("TOPLEFT", meter, "TOPLEFT", 16, -32)
  meter.note:SetWidth(450)
  meter.note:SetJustifyH("LEFT")
  meter.note:SetText("Values persist through reload. Ask on instance is off by default.")
  CreateToggleRow(meter, -42, "Ask to reset when entering an instance", function()
    local value = QtUI:GetLayout().meterAskInstance
    return value == true or value == 1 or value == "1"
  end, function(value)
    QtUI:GetLayout().meterAskInstance = value and true or false
  end)
  CreateStepper(meter, -64, "Width", function()
    return QtUI:GetLayout().meterWidth
  end, function(value)
    QtUI:GetLayout().meterWidth = value
  end, 140, 400, 10, 0)
  CreateStepper(meter, -86, "Height", function()
    local layout = QtUI:GetLayout()
    local bars = tonumber(layout.meterBars) or 8
    local barH = tonumber(layout.meterBarHeight) or 16
    local spacing = tonumber(layout.meterBarSpacing) or 0
    return 20 + bars * barH + (bars - 1) * spacing + 6
  end, function(value)
    local layout = QtUI:GetLayout()
    local barH = tonumber(layout.meterBarHeight) or 16
    local spacing = tonumber(layout.meterBarSpacing) or 0
    if barH < 12 then barH = 12 end
    if spacing < 0 then spacing = 0 end
    local bars = math.floor((value - 26 + spacing) / (barH + spacing) + .5)
    if bars < 3 then bars = 3 end
    if bars > 16 then bars = 16 end
    layout.meterBars = bars
  end, 62, 410, 16, 0)
  CreateStepper(meter, -108, "Bar height", function()
    return QtUI:GetLayout().meterBarHeight
  end, function(value)
    QtUI:GetLayout().meterBarHeight = value
  end, 12, 24, 1, 0)
  CreateStepper(meter, -130, "Bar spacing", function()
    return QtUI:GetLayout().meterBarSpacing or 0
  end, function(value)
    QtUI:GetLayout().meterBarSpacing = value
  end, 0, 8, 1, 0)
  CreateToggleRow(meter, -154, "Show window background", function()
    local value = QtUI:GetLayout().meterShowBackground
    return value ~= false and value ~= 0 and value ~= "0"
  end, function(value)
    QtUI:GetLayout().meterShowBackground = value and true or false
  end)

  meter.count = meter:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  meter.count:SetPoint("TOPLEFT", meter, "TOPLEFT", 12, -176)
  meter.count:SetJustifyH("LEFT")
  local function RefreshMeterWindows()
    local n = 0
    if QtUI.MeterWindowCount then n = QtUI:MeterWindowCount() end
    if meter.count then meter.count:SetText("Windows: " .. n .. " / 6") end
  end
  frame.RefreshMeterWindows = RefreshMeterWindows
  RefreshMeterWindows()

  local function PlaceMeterAction(button, left, top, width)
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", meter, "TOPLEFT", left, top)
    button:SetPoint("BOTTOMRIGHT", meter, "TOPLEFT", left + width, top - 20)
    if button.SetWidth then
      button:SetWidth(width + 1)
      button:SetWidth(width)
    end
    if button.SetHeight then
      button:SetHeight(21)
      button:SetHeight(20)
    end
    if button.text then
      button.text:ClearAllPoints()
      button.text:SetPoint("TOPLEFT", button, "TOPLEFT", 4, 0)
      button.text:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -4, 0)
      button.text:SetJustifyH("CENTER")
      if button.text.SetJustifyV then button.text:SetJustifyV("CENTER") end
    end
  end

  local addBtn = CreateSmallButton(meter, "New window", 12, function()
    if QtUI.AddDamageMeterWindow then QtUI:AddDamageMeterWindow() end
    RefreshMeterWindows()
  end, 128)
  PlaceMeterAction(addBtn, 16, -198, 128)

  local closeBtn = CreateSmallButton(meter, "Close window", 150, function()
    if QtUI.CloseLastDamageMeterWindow then QtUI:CloseLastDamageMeterWindow() end
    RefreshMeterWindows()
  end, 128)
  PlaceMeterAction(closeBtn, 152, -198, 128)

  local demoBtn = CreateSmallButton(meter, "Demo values", 12, function()
    if QtUI.FillMeterDemo then QtUI:FillMeterDemo() end
  end, 128)
  PlaceMeterAction(demoBtn, 288, -198, 128)

  local chat = AddPage("chat")
  CreateSection(chat, 0, 254)
  CreateHeader(chat, -8, "Chat")
  CreateFeatureToggle(chat, -28, "dataText")
  chat.note = chat:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  chat.note:SetPoint("TOPLEFT", chat, "TOPLEFT", 16, -50)
  chat.note:SetWidth(430)
  chat.note:SetJustifyH("LEFT")
  chat.note:SetText("Both windows share size and font.")
  CreateToggleRow(chat, -70, "Show social chat", function()
    local value = QtUI:GetLayout().chatSocial
    return value ~= false and value ~= 0 and value ~= "0"
  end, function(value)
    QtUI:GetLayout().chatSocial = value and true or false
  end)
  CreateStepper(chat, -92, "Width", function()
    return QtUI:GetLayout().chatWidth
  end, function(value)
    QtUI:GetLayout().chatWidth = value
  end, 180, 700, 10, 0)
  CreateStepper(chat, -114, "Height", function()
    return QtUI:GetLayout().chatHeight
  end, function(value)
    QtUI:GetLayout().chatHeight = value
  end, 80, 500, 10, 0)
  CreateStepper(chat, -136, "Font size", function()
    return QtUI:GetLayout().chatFontSize
  end, function(value)
    QtUI:GetLayout().chatFontSize = value
  end, 8, 20, 1, 0)
  CreateToggleRow(chat, -158, "Show time on messages", function()
    local value = QtUI:GetLayout().chatTime
    return value ~= false and value ~= 0 and value ~= "0"
  end, function(value)
    QtUI:GetLayout().chatTime = value and true or false
  end)
  CreateToggleRow(chat, -180, "Use local clock on the info bar", function()
    local value = QtUI:GetLayout().clockLocal
    return value == true or value == 1 or value == "1"
  end, function(value)
    QtUI:GetLayout().clockLocal = value and true or false
  end)
  CreateToggleRow(chat, -202, "Compact gold / time / fps", function()
    local value = QtUI:GetLayout().dataTextCompact
    return value == true or value == 1 or value == "1"
  end, function(value)
    QtUI:GetLayout().dataTextCompact = value and true or false
    if QtUI.LayoutDataText then QtUI:LayoutDataText() end
  end)
  CreateToggleRow(chat, -224, "Color names by class", function()
    local value = QtUI:GetLayout().chatClassNames
    return value == true or value == 1 or value == "1"
  end, function(value)
    QtUI:GetLayout().chatClassNames = value and true or false
  end)

  CreateSmallButton(frame, "Reload UI", 18, function()
    if SlashCmdList and SlashCmdList["QTUI"] then
      SlashCmdList["QTUI"]("reload")
    end
  end)
  CreateSmallButton(frame, "Apply", 130, function()
    QtUI:ApplyLayout()
  end)
  CreateSmallButton(frame, "Toggle Anchor", 242, function()
    if QtUI.UnlockAnchorsFromSettings then
      QtUI:UnlockAnchorsFromSettings()
    else
      QtUI.moveFromSettings = true
      if QtUI.SetMoveMode then QtUI:SetMoveMode(true) end
    end
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

local function PlaceMinimapIcon(button, x, y)
  if not button then return end
  button:ClearAllPoints()
  if Minimap then
    button:SetPoint("CENTER", Minimap, "CENTER", x or -65, y or 65)
  else
    button:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -18, -18)
  end
  if button.SetWidth then
    button:SetWidth(32)
    if button.SetHeight then button:SetHeight(32) end
    button:SetWidth(31)
    if button.SetHeight then button:SetHeight(31) end
  end
end

local function SaveMinimapIconPosition(button)
  if not button or not Minimap or not Minimap.GetCenter then return end
  local buttonX, buttonY = button:GetCenter()
  local mapX, mapY = Minimap:GetCenter()
  if not buttonX or not buttonY or not mapX or not mapY then return end
  local x, y = buttonX - mapX, buttonY - mapY
  QtUIDB.settingsButtonPosition = { x = x, y = y }
  PlaceMinimapIcon(button, x, y)
end

function QtUI:SetupSettingsButton()
  if self.settingsButton then return end
  local parent = Minimap or UIParent
  local button = CreateFrame("Button", "QtUISettingsButton", parent)
  local saved = QtUIDB.settingsButtonPosition
  PlaceMinimapIcon(button, saved and saved.x, saved and saved.y)
  button:SetFrameStrata("HIGH")
  button:SetFrameLevel(30)
  button:SetClampedToScreen(true)
  button:SetMovable(true)
  button:EnableMouse(true)
  button:RegisterForDrag("LeftButton")
  button:RegisterForClicks("LeftButtonUp")

  button.icon = button:CreateTexture(nil, "BACKGROUND")
  button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 6, -5)
  button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -5, 6)
  button.icon:SetTexture("Interface\\AddOns\\QtUI\\Media\\QtIcon")
  button.icon:SetTexCoord(.05, .95, .05, .95)

  button.overlay = button:CreateTexture(nil, "OVERLAY")
  button.overlay:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
  button.overlay:SetPoint("BOTTOMRIGHT", button, "TOPLEFT", 53, -53)
  button.overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

  local function StopIconDrag()
    if not this.dragging then return end
    this:StopMovingOrSizing()
    this.dragging = nil
    this:SetScript("OnUpdate", nil)
    if this.moved then SaveMinimapIconPosition(this) end
  end
  local function DragIconUpdate()
    if not this.dragging then
      this:SetScript("OnUpdate", nil)
      return
    end
    if type(IsMouseButtonDown) == "function" then
      local ok, held = pcall(IsMouseButtonDown, "LeftButton")
      if ok and held ~= true and held ~= 1 and held ~= "1" then
        StopIconDrag()
        return
      end
    end
    local x, y = GetCursorPosition()
    if this.moved or not x or not y then return end
    local dx = x - (this.dragx or x)
    local dy = y - (this.dragy or y)
    if dx * dx + dy * dy > 16 then
      this.moved = true
      this:StartMoving()
    end
  end
  button:SetScript("OnMouseDown", function()
    if arg1 ~= "LeftButton" then return end
    this.dragx, this.dragy = GetCursorPosition()
    this.dragging = true
    this.moved = nil
    this:SetScript("OnUpdate", DragIconUpdate)
  end)
  button:SetScript("OnMouseUp", StopIconDrag)
  button:SetScript("OnDragStart", function()
    this.moved = true
    this.dragging = true
    this:StartMoving()
  end)
  button:SetScript("OnDragStop", StopIconDrag)
  button:SetScript("OnClick", function()
    if this.moved then
      this.moved = nil
      return
    end
    QtUI:ToggleSettings()
  end)
  button:SetScript("OnEnter", function()
    if this.icon and this.icon.SetVertexColor then
      this.icon:SetVertexColor(.4, 1, .8)
    end
    if not GameTooltip then return end
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:SetText("|cffffcc00Qt|rUI", 1, 1, 1)
    GameTooltip:AddDoubleLine("Left-Click", "Settings", 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Left-Click", "Move Button", 1, 1, 1, 1, 1, 1)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function()
    if this.icon and this.icon.SetVertexColor then
      this.icon:SetVertexColor(1, 1, 1)
    end
    if GameTooltip then GameTooltip:Hide() end
  end)
  self.settingsButton = button
end

function QtUI:RefreshSettingsButton()
  if not self.settingsButton then return end
  local saved = QtUIDB and QtUIDB.settingsButtonPosition
  PlaceMinimapIcon(self.settingsButton, saved and saved.x, saved and saved.y)
end
