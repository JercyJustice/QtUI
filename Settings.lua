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
  row:SetWidth(228)
  row:SetHeight(34)
  row:SetPoint("TOPLEFT", parent, "TOPLEFT", 18 + column * 246, -70 - rowIndex * 42)
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

function PotatoUI:SetupSettingsWindow()
  if self.settingsFrame then return end
  self:EnsureFeatureDefaults()

  local frame = self:CreatePanel("PotatoUISettingsFrame", UIParent, 40)
  frame:SetFrameStrata("DIALOG")
  frame:SetWidth(510)
  frame:SetHeight(386)
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
  frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -16)
  frame.title:SetText("|cffffcc00Potato|rUI Settings")

  frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.subtitle:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -7)
  frame.subtitle:SetText("Choose which parts PotatoUI manages. All features are enabled by default.")

  frame.close = CreateFrame("Button", nil, frame)
  frame.close:SetWidth(28)
  frame.close:SetHeight(28)
  frame.close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -9, -8)
  frame.close.text = frame.close:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  frame.close.text:SetAllPoints(frame.close)
  frame.close.text:SetJustifyH("CENTER")
  frame.close.text:SetText("|cffff6666X|r")
  frame.close:SetScript("OnClick", function() PotatoUI.settingsFrame:Hide() end)

  frame.rows = {}
  local index, option
  for index, option in ipairs(FEATURE_OPTIONS) do
    local column = index > 6 and 1 or 0
    local rowIndex = math.mod(index - 1, 6)
    table.insert(frame.rows, CreateFeatureRow(frame, option, column, rowIndex))
  end

  CreateSmallButton(frame, "Reload UI", 18, function()
    if SlashCmdList and SlashCmdList["POTATOUI"] then
      SlashCmdList["POTATOUI"]("reload")
    end
  end)

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
