QtUI = CreateFrame("Frame", "QtUIEventFrame", UIParent)
QtUI.version = "0.25.0"
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

-- Emberveil: FontString:SetFont is a no-op while a Font object is assigned,
-- and CreateFontString always assigns GameFontNormal. Own Font objects via
-- CreateFont + SetFontObject. SetTextColor writes through the Font object, so
-- pool by size+color instead of one Font per widget (that cut idle FPS in half).
local FONT_PATH = "Fonts\\FRIZQT__.TTF"
local fontSeq = 0
local fontPool = {}

function QtUI:ApplyFont(widget, size, r, g, b)
  if not widget then return end
  size = math.floor(tonumber(size) or 12)
  if size < 6 then size = 6 end
  if size > 32 then size = 32 end
  r = tonumber(r)
  g = tonumber(g)
  b = tonumber(b)
  if not r then r = 1 end
  if not g then g = 1 end
  if not b then b = 1 end
  local path = STANDARD_TEXT_FONT or FONT_PATH
  local key = size .. ":" .. string.format("%.2f:%.2f:%.2f", r, g, b)
  local font = fontPool[key]
  if not font and type(CreateFont) == "function" then
    fontSeq = fontSeq + 1
    local ok, created = pcall(CreateFont, "QtUIFont" .. fontSeq)
    if ok and created then
      font = created
      fontPool[key] = font
      if font.SetFont then pcall(font.SetFont, font, path, size) end
      if font.SetTextColor then pcall(font.SetTextColor, font, r, g, b) end
    end
  end
  if font and widget.SetFontObject then
    pcall(widget.SetFontObject, widget, font)
    widget.qtFontObject = font
    widget.qtFontSize = size
    widget.qtFontKey = key
    return
  end
  if widget.SetFont then
    pcall(widget.SetFont, widget, path, size)
    widget.qtFontSize = size
  end
  if widget.SetTextColor then pcall(widget.SetTextColor, widget, r, g, b) end
end

-- Single-point TOPLEFT/TOPRIGHT on FontStrings is unreliable here: Emberveil
-- ignores SetWidth, so a hotkey keeps its XML width and LEFT/RIGHT looks swapped.
-- Pin a pixel box from the parent's BOTTOMLEFT, same as the rest of the UI.
function QtUI:PlaceAlignedText(fontString, parent, align, pad, width, height, ox, oy)
  if not fontString or not parent then return end
  pad = tonumber(pad)
  if not pad then pad = 2 end
  width = tonumber(width)
  height = tonumber(height)
  if not width and parent.GetWidth then width = parent:GetWidth() end
  if not height and parent.GetHeight then height = parent:GetHeight() end
  width = tonumber(width) or 40
  height = tonumber(height) or 20
  if width < 8 then width = 8 end
  if height < 8 then height = 8 end
  if not align then align = "center" end
  ox = tonumber(ox) or 0
  oy = tonumber(oy) or 0

  local left = pad
  local bottom = pad
  local right = width - pad
  local top = height - pad
  local colW = math.floor((width - pad * 2) * .58)
  local rowH = math.floor((height - pad * 2) * .5)
  if colW < 10 then colW = 10 end
  if rowH < 8 then rowH = 8 end

  if align == "left" or align == "topleft" or align == "bottomleft" then
    right = left + colW
  elseif align == "right" or align == "topright" or align == "bottomright" then
    left = right - colW
  end
  if align == "top" or align == "topleft" or align == "topright" then
    bottom = top - rowH
  elseif align == "bottom" or align == "bottomleft" or align == "bottomright" then
    top = bottom + rowH
  end

  fontString:ClearAllPoints()
  fontString:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", left + ox, bottom + oy)
  fontString:SetPoint("TOPRIGHT", parent, "BOTTOMLEFT", right + ox, top + oy)
  local boxW = right - left
  local boxH = top - bottom
  if fontString.SetWidth then
    fontString:SetWidth(boxW + 1)
    fontString:SetWidth(boxW)
  end
  if fontString.SetHeight then
    fontString:SetHeight(boxH + 1)
    fontString:SetHeight(boxH)
  end

  local justifyH = "CENTER"
  if align == "left" or align == "topleft" or align == "bottomleft" then
    justifyH = "LEFT"
  elseif align == "right" or align == "topright" or align == "bottomright" then
    justifyH = "RIGHT"
  end
  if fontString.SetJustifyH then fontString:SetJustifyH(justifyH) end
  local justifyV = "CENTER"
  if align == "top" or align == "topleft" or align == "topright" then
    justifyV = "TOP"
  elseif align == "bottom" or align == "bottomleft" or align == "bottomright" then
    justifyV = "BOTTOM"
  end
  if fontString.SetJustifyV then fontString:SetJustifyV(justifyV) end
end

local function UrlEncode(str)
  str = tostring(str or "")
  str = string.gsub(str, "\r\n", "\n")
  str = string.gsub(str, "\n", "\r\n")
  str = string.gsub(str, "([^%w])", function(c)
    return string.format("%%%02X", string.byte(c))
  end)
  return str
end

local function HtmlEscape(str)
  str = tostring(str or "")
  str = string.gsub(str, "&", "&amp;")
  str = string.gsub(str, "<", "&lt;")
  str = string.gsub(str, ">", "&gt;")
  return str
end

function QtUI:OpenTextInBrowser(text, title)
  if type(LaunchURL) ~= "function" then return nil end
  title = title or "QtUI"
  local html = "<!DOCTYPE html><html><head><meta charset=\"utf-8\"><title>"
    .. HtmlEscape(title)
    .. "</title></head><body style=\"margin:0;background:#111;color:#9ef\">"
    .. "<textarea readonly style=\"box-sizing:border-box;width:100%;height:100%;"
    .. "padding:16px;background:#111;color:#9ef;border:0;outline:0;"
    .. "font:13px/1.4 Consolas,monospace\">"
    .. HtmlEscape(text)
    .. "</textarea></body></html>"
  local ok = pcall(LaunchURL, "data:text/html;charset=utf-8," .. UrlEncode(html))
  if ok then return true end
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

-- Emberveil re-enters OnHide from Hide(), so calling Hide() inside a frame's own
-- OnShow nests visibility changes and stacks until the client hangs or
-- access-violates (0x338) -- the hazard SafeHidePopup and the move-mode parkers
-- already avoid. These frames are native (PlayerFrame, MultiBar*, ContainerFrame*
-- and friends) and the client shows them constantly, so the handler must never
-- Hide inline. Queue the hide onto the next frame instead; anchors and layout are
-- left exactly as they were, so nothing anchored to these frames moves.
local hideQueue = {}
local hideDriver

local function FlushHideQueue()
  local frame = table.remove(hideQueue)
  while frame do
    if frame.Hide then pcall(frame.Hide, frame) end
    frame = table.remove(hideQueue)
  end
  this:SetScript("OnUpdate", nil)
end

local function QueueHide(frame)
  if not frame then return end
  local i
  for i = 1, table.getn(hideQueue) do
    if hideQueue[i] == frame then return end
  end
  table.insert(hideQueue, frame)
  if not hideDriver then
    hideDriver = CreateFrame("Frame", "QtUIHideQueue")
  end
  hideDriver:SetScript("OnUpdate", FlushHideQueue)
end

function QtUI:HideFrame(frame)
  if not frame then return end
  -- Safe here: this call is not running inside the frame's own OnShow.
  if frame.Hide then pcall(frame.Hide, frame) end
  if frame.qtHideHooked then return end
  frame.qtHideHooked = true
  if type(frame.SetScript) == "function" then
    frame:SetScript("OnShow", function()
      -- Best effort against a one-frame flicker; Emberveil may ignore it.
      if this.SetAlpha then pcall(this.SetAlpha, this, 0) end
      QueueHide(this)
    end)
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
  if layout.classTooltip == nil then layout.classTooltip = true end
  if layout.clockLocal == nil then layout.clockLocal = false end
  if layout.dataTextCompact == nil then layout.dataTextCompact = false end
  layout.chatWidth = tonumber(layout.chatWidth) or 380
  if layout.chatWidth < 180 then layout.chatWidth = 180 end
  if layout.chatWidth > 700 then layout.chatWidth = 700 end
  layout.chatHeight = tonumber(layout.chatHeight) or 190
  if layout.chatHeight < 80 then layout.chatHeight = 80 end
  if layout.chatHeight > 500 then layout.chatHeight = 500 end
  layout.chatFontSize = tonumber(layout.chatFontSize) or 12
  if layout.chatFontSize < 8 then layout.chatFontSize = 8 end
  if layout.chatFontSize > 20 then layout.chatFontSize = 20 end
  if layout.chatTime == nil then layout.chatTime = true end
  if layout.chatClassNames == nil then layout.chatClassNames = true end
  if layout.chatSocial == nil then layout.chatSocial = true end
  layout.xpBarWidth = tonumber(layout.xpBarWidth) or 442
  if layout.xpBarWidth < 80 then layout.xpBarWidth = 80 end
  if layout.xpBarWidth > 800 then layout.xpBarWidth = 800 end
  if layout.meterShowBackground == nil then layout.meterShowBackground = true end
  if layout.estimateMobHealth == nil then layout.estimateMobHealth = true end
  layout.snapRange = tonumber(layout.snapRange) or 10
  if layout.snapRange < 2 then layout.snapRange = 2 end
  if layout.snapRange > 40 then layout.snapRange = 40 end
  layout.snapPadLeft = tonumber(layout.snapPadLeft) or 0
  layout.snapPadRight = tonumber(layout.snapPadRight) or 0
  layout.snapPadTop = tonumber(layout.snapPadTop) or 0
  layout.snapPadBottom = tonumber(layout.snapPadBottom) or 0
  layout.xpBarHeight = tonumber(layout.xpBarHeight) or 20
  if layout.xpBarHeight < 12 then layout.xpBarHeight = 12 end
  if layout.xpBarHeight > 32 then layout.xpBarHeight = 32 end
  layout.xpBarFontSize = tonumber(layout.xpBarFontSize) or 12
  if layout.xpBarFontSize < 8 then layout.xpBarFontSize = 8 end
  if layout.xpBarFontSize > 18 then layout.xpBarFontSize = 18 end
  if layout.xpBarText == nil then layout.xpBarText = true end
  if layout.showTargetTarget == nil then layout.showTargetTarget = true end
  layout.comboPointSize = tonumber(layout.comboPointSize) or 15
  if layout.comboPointSize < 8 then layout.comboPointSize = 8 end
  if layout.comboPointSize > 28 then layout.comboPointSize = 28 end
  layout.comboSpacing = tonumber(layout.comboSpacing)
  if layout.comboSpacing == nil then layout.comboSpacing = 2 end
  if layout.comboSpacing < 0 then layout.comboSpacing = 0 end
  if layout.comboSpacing > 12 then layout.comboSpacing = 12 end
  if layout.comboShowBackground == nil then layout.comboShowBackground = true end
  layout.comboColor = EnsureColor(layout.comboColor, 1, .42, .08, 1)
  layout.meterWidth = tonumber(layout.meterWidth) or 190
  if layout.meterWidth < 140 then layout.meterWidth = 140 end
  if layout.meterWidth > 400 then layout.meterWidth = 400 end
  layout.meterBars = tonumber(layout.meterBars) or 8
  if layout.meterBars < 3 then layout.meterBars = 3 end
  if layout.meterBars > 16 then layout.meterBars = 16 end
  layout.meterBarHeight = tonumber(layout.meterBarHeight) or 16
  if layout.meterBarHeight < 12 then layout.meterBarHeight = 12 end
  if layout.meterBarHeight > 24 then layout.meterBarHeight = 24 end
  layout.meterBarSpacing = tonumber(layout.meterBarSpacing)
  if layout.meterBarSpacing == nil then layout.meterBarSpacing = 0 end
  if layout.meterBarSpacing < 0 then layout.meterBarSpacing = 0 end
  if layout.meterBarSpacing > 8 then layout.meterBarSpacing = 8 end
  if layout.meterAskInstance == nil then layout.meterAskInstance = false end
  layout.barBackground = EnsureColor(layout.barBackground, .025, .035, .045, .85)
  layout.barBorder = EnsureColor(layout.barBorder, .18, .24, .28, 1)
  if layout.slotShowBackground == nil then layout.slotShowBackground = true end
  if layout.slotShowRim == nil then layout.slotShowRim = true end
  if layout.hideEmptySlots == nil then layout.hideEmptySlots = true end
  layout.slotBackground = EnsureColor(layout.slotBackground, .02, .025, .03, .96)
  layout.slotBorder = EnsureColor(layout.slotBorder, .14, .18, .2, 1)
  if not layout.bagSlotSize then layout.bagSlotSize = 36 end
  layout.bagSlotSize = tonumber(layout.bagSlotSize) or 36
  if layout.bagSlotSize < 24 then layout.bagSlotSize = 24 end
  if layout.bagSlotSize > 52 then layout.bagSlotSize = 52 end
  if layout.bagShowKeys == nil then layout.bagShowKeys = true end
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
  if layout.auraWatch == nil then layout.auraWatch = true end
  if layout.playerBuffWatch == nil then layout.playerBuffWatch = true end
  if layout.targetDebuffWatch == nil then layout.targetDebuffWatch = true end
  if layout.targetOwnDebuffs == nil then layout.targetOwnDebuffs = true end
  if layout.playerBuffWatchWhitelist == nil then
    if layout.auraWatchWhitelist ~= nil then
      layout.playerBuffWatchWhitelist = layout.auraWatchWhitelist
    else
      layout.playerBuffWatchWhitelist = true
    end
  end
  if layout.targetDebuffWatchWhitelist == nil then
    if layout.auraWatchWhitelist ~= nil then
      layout.targetDebuffWatchWhitelist = layout.auraWatchWhitelist
    else
      layout.targetDebuffWatchWhitelist = true
    end
  end
  if type(layout.playerBuffWatchPins) ~= "table" then layout.playerBuffWatchPins = {} end
  if type(layout.targetDebuffWatchPins) ~= "table" then layout.targetDebuffWatchPins = {} end
  if type(layout.auraWatchPins) ~= "table" then layout.auraWatchPins = {} end
  layout.auraWatchThreshold = tonumber(layout.auraWatchThreshold) or 120
  if layout.auraWatchThreshold < 0 then layout.auraWatchThreshold = 0 end
  if layout.auraWatchThreshold > 600 then layout.auraWatchThreshold = 600 end
  layout.auraWatchWidth = tonumber(layout.auraWatchWidth) or 220
  if layout.auraWatchWidth < 140 then layout.auraWatchWidth = 140 end
  if layout.auraWatchWidth > 360 then layout.auraWatchWidth = 360 end
  layout.auraWatchBarHeight = tonumber(layout.auraWatchBarHeight) or 18
  if layout.auraWatchBarHeight < 14 then layout.auraWatchBarHeight = 14 end
  if layout.auraWatchBarHeight > 28 then layout.auraWatchBarHeight = 28 end
  layout.playerBuffWatchWidth = tonumber(layout.playerBuffWatchWidth) or layout.auraWatchWidth
  if layout.playerBuffWatchWidth < 140 then layout.playerBuffWatchWidth = 140 end
  if layout.playerBuffWatchWidth > 360 then layout.playerBuffWatchWidth = 360 end
  layout.targetDebuffWatchWidth = tonumber(layout.targetDebuffWatchWidth) or layout.auraWatchWidth
  if layout.targetDebuffWatchWidth < 140 then layout.targetDebuffWatchWidth = 140 end
  if layout.targetDebuffWatchWidth > 360 then layout.targetDebuffWatchWidth = 360 end
  layout.playerBuffWatchBarHeight = tonumber(layout.playerBuffWatchBarHeight) or layout.auraWatchBarHeight
  if layout.playerBuffWatchBarHeight < 14 then layout.playerBuffWatchBarHeight = 14 end
  if layout.playerBuffWatchBarHeight > 28 then layout.playerBuffWatchBarHeight = 28 end
  layout.targetDebuffWatchBarHeight = tonumber(layout.targetDebuffWatchBarHeight) or layout.auraWatchBarHeight
  if layout.targetDebuffWatchBarHeight < 14 then layout.targetDebuffWatchBarHeight = 14 end
  if layout.targetDebuffWatchBarHeight > 28 then layout.targetDebuffWatchBarHeight = 28 end
  return layout
end

-- EnsureLayoutDefaults walks ~200 settings and allocates three closures plus five
-- tables every call (~7.8us and ~245 bytes of garbage). GetLayout is reached from
-- per-button, per-frame paths -- icon tinting via RangeColorOn and cooldown text
-- via FeatureOn -- so one GCD sweep of 82 buttons spent half its time here.
-- Memoise the validated table. The identity check is the invalidation: a profile
-- load replaces QtUIDB.layout outright (Profiles.lua), and /qtui reset replaces
-- QtUIDB, so both miss the cache and revalidate. Direct EnsureLayoutDefaults
-- callers (ApplyLayout, EnsureDB, Settings, Profiles) still re-clamp on demand.
local layoutCache
function QtUI:GetLayout()
  local cached = layoutCache
  if cached and QtUIDB and cached == QtUIDB.layout then return cached end
  layoutCache = self:EnsureLayoutDefaults()
  return layoutCache
end

function QtUI:GetBarConfig(name)
  local layout = self:GetLayout()
  return layout.bars[name] or layout.bars.main
end

local BAR_COPY_KEYS = { "main", "extra", "utility", "aux", "sideRight", "sideLeft" }

function QtUI:ApplyBarConfigToAll(sourceKey)
  local src = self:GetBarConfig(sourceKey)
  if not src then return end
  local i
  for i = 1, table.getn(BAR_COPY_KEYS) do
    local dst = self:GetBarConfig(BAR_COPY_KEYS[i])
    if dst and dst ~= src then
      dst.columns = src.columns
      dst.rows = src.rows
      dst.size = src.size
      dst.spacing = src.spacing
      dst.hotkeyAlign = src.hotkeyAlign
      dst.hotkeySize = src.hotkeySize
      dst.hotkeyShadow = src.hotkeyShadow
    end
  end
  if self.ApplyLayout then self:ApplyLayout() end
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
    if not panel then return end
    if LayoutFlagOn(layout.barShowBackground) and self:IsBarEnabled(key) then
      -- Re-stamp only when the chrome should be visible. Emberveil keeps
      -- the last drawn backdrop if we SetBackdrop and then paint alpha 0.
      if panel.SetBackdrop then
        pcall(panel.SetBackdrop, panel, nil)
        panel:SetBackdrop({
          bgFile = "Interface\\Buttons\\WHITE8X8",
          edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
          tile = true, tileSize = 8, edgeSize = 12,
          insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
      end
      if panel.SetBackdropColor then
        local c = layout.barBackground or {}
        local b = layout.barBorder or {}
        panel:SetBackdropColor(c.r or .025, c.g or .035, c.b or .045, c.a or .85)
        panel:SetBackdropBorderColor(b.r or .18, b.g or .24, b.b or .28, b.a or 1)
      end
      if panel.Show then pcall(panel.Show, panel) end
      if panel.SetAlpha then pcall(panel.SetAlpha, panel, 1) end
    else
      if panel.SetBackdrop then pcall(panel.SetBackdrop, panel, nil) end
      if panel.SetBackdropColor then
        panel:SetBackdropColor(0, 0, 0, 0)
        panel:SetBackdropBorderColor(0, 0, 0, 0)
      end
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

local SLOT_EXTRA = 2

local function ParkSlotCell(cell)
  if not cell then return end
  if cell.art then
    if cell.art.SetTexture then cell.art:SetTexture(nil) end
    if cell.art.Hide then pcall(cell.art.Hide, cell.art) end
  end
  if cell.ClearAllPoints then
    cell:ClearAllPoints()
    cell:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -4000, 4000)
    cell:SetPoint("BOTTOMRIGHT", UIParent, "TOPLEFT", -3999, 3999)
  end
  if cell.Hide then pcall(cell.Hide, cell) end
  cell.qtParked = 1
end

local function PlaceSlotCell(cell, button, extra)
  if not cell or not button then return end
  extra = extra or SLOT_EXTRA
  if cell.art and cell.art.SetTexture then
    cell.art:SetTexture("Interface\\AddOns\\QtUI\\Media\\HDActionBarBtn")
  end
  if cell.art and cell.art.Show then pcall(cell.art.Show, cell.art) end
  cell:ClearAllPoints()
  cell:SetPoint("TOPLEFT", button, "TOPLEFT", -extra, extra)
  cell:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", extra, -extra)
  if cell.Show then pcall(cell.Show, cell) end
  cell.qtParked = nil
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
  -- A couple of pixels past the icon so the winged well matches the
  -- filled-slot footprint. extra=0 sat inside the art; extra=3 overshot.
  local extra = SLOT_EXTRA

  local cell = button.QtUICell
  if not cell then
    cell = CreateFrame("Frame", nil, panel)
    button.QtUICell = cell
  elseif panel then
    cell:SetParent(panel)
  end
  if not cell.art then
    cell.art = cell:CreateTexture(nil, "ARTWORK")
    cell.art:SetAllPoints(cell)
  end
  local stamp = tostring(size) .. ":" .. extra .. ":hd-btn"
  if not self.forceSlotCell and cell.QtUIStamp == stamp then return cell end

  -- Vanilla 1.12 TGA from DragonflightUI-Reforged (same format as QtIcon).
  if cell.SetBackdrop then pcall(cell.SetBackdrop, cell, nil) end

  local panelLevel = 1
  if panel.GetFrameLevel then panelLevel = panel:GetFrameLevel() or 1 end
  cell:SetFrameLevel(math.max(0, panelLevel))
  if button.SetFrameLevel then button:SetFrameLevel(panelLevel + 4) end
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

local function ParkTexture(tex)
  if not tex then return end
  if tex.SetTexture then tex:SetTexture(nil) end
  if tex.ClearAllPoints then
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -2000, 2000)
    tex:SetPoint("BOTTOMRIGHT", UIParent, "TOPLEFT", -1999, 1999)
  end
  if tex.SetAlpha then tex:SetAlpha(0) end
  if tex.Hide then pcall(tex.Hide, tex) end
end

local function RimPad(size)
  local pad = math.floor((size or 34) * 0.38)
  if pad < 10 then pad = 10 end
  return pad
end

local function ParkRimFrame(frame)
  if not frame then return end
  if frame.art then
    if frame.art.SetTexture then frame.art:SetTexture(nil) end
    if frame.art.Hide then pcall(frame.art.Hide, frame.art) end
  end
  if frame.ClearAllPoints then
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -4000, 4000)
    frame:SetPoint("BOTTOMRIGHT", UIParent, "TOPLEFT", -3999, 3999)
  end
  if frame.Hide then pcall(frame.Hide, frame) end
  frame.qtParked = 1
end

function QtUI:HideButtonRim(button, keepNormalIcon)
  if not button then return end
  ParkTexture(button.QtUIRing)
  ParkRimFrame(button.QtUIRimFrame)
  if not keepNormalIcon then
    if button.SetNormalTexture then button:SetNormalTexture("") end
    local normal = button.GetNormalTexture and button:GetNormalTexture()
    ParkTexture(normal)
  end
  button.QtUIRingOn = 0
end

function QtUI:EnsureButtonRim(button, size, keepNormalIcon)
  if not button then return end
  if not size or size < 8 then
    size = button.QtUISize
  end
  if not size or size < 8 then
    size = button.GetWidth and button:GetWidth()
  end
  if not size or size < 8 then size = 34 end
  local keep = keepNormalIcon and 1 or 0
  local layout = self.GetLayout and self:GetLayout()
  local show = 1
  if layout then
    local rim = layout.slotShowRim
    if rim == false or rim == 0 or rim == "0" then show = 0 end
  end
  if show == 1 and not self.forceButtonRim and button.QtUIRimFrame
      and button.QtUIRingSize == size and button.QtUIRingKeep == keep
      and button.QtUIRingOn == 1 and not button.QtUIRimFrame.qtParked then
    return
  end
  if show == 0 then
    self:HideButtonRim(button, keepNormalIcon)
    button.QtUIRingSize = size
    button.QtUIRingKeep = keep
    return
  end

  -- MultiBarLeft/Right wipe textures created on the native button.
  -- The rim is a sibling on the Qt panel, sized in pixels like slot cells.
  if not keepNormalIcon then
    if button.SetNormalTexture then button:SetNormalTexture("") end
    ParkTexture(button.GetNormalTexture and button:GetNormalTexture())
  end
  ParkTexture(button.QtUIRing)

  local panel = button.GetParent and button:GetParent()
  if not panel then return end
  local rim = button.QtUIRimFrame
  if not rim then
    rim = CreateFrame("Frame", nil, panel)
    button.QtUIRimFrame = rim
    rim.art = rim:CreateTexture(nil, "ARTWORK")
    rim.art:SetAllPoints(rim)
  elseif rim.SetParent then
    rim:SetParent(panel)
  end
  if rim.art and rim.art.SetTexture then
    rim.art:SetTexture("Interface\\Buttons\\UI-Quickslot2")
  end
  if rim.art and rim.art.Show then pcall(rim.art.Show, rim.art) end

  local pad = RimPad(size)
  local panelLevel = 1
  if panel.GetFrameLevel then panelLevel = panel:GetFrameLevel() or 1 end
  rim:SetFrameLevel(math.max(0, panelLevel + 3))
  if button.SetFrameLevel then button:SetFrameLevel(panelLevel + 4) end

  rim:ClearAllPoints()
  if button.QtUIGridX ~= nil and button.QtUIGridY ~= nil then
    local x = button.QtUIGridX
    local y = button.QtUIGridY
    rim:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", x - pad, y - pad)
    rim:SetPoint("TOPRIGHT", panel, "BOTTOMLEFT", x + size + pad, y + size + pad)
  else
    rim:SetPoint("TOPLEFT", button, "TOPLEFT", -pad, pad)
    rim:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", pad, -pad)
  end
  if rim.Show then pcall(rim.Show, rim) end
  rim.qtParked = nil
  button.QtUIRingSize = size
  button.QtUIRingKeep = keep
  button.QtUIRingOn = 1
  if self.LayerActionCooldown then self:LayerActionCooldown(button) end
end

function QtUI:ApplySlotBackgrounds()
  local layout = self:GetLayout()
  local names = {
    "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
    "MultiBarRightButton", "MultiBarLeftButton",
    "ShapeshiftButton", "PetActionButton", "BonusActionButton",
  }
  local maxCount = { 12, 12, 12, 12, 12, 10, 10, 12 }
  local n
  for n = 1, table.getn(names) do
    local i
    local last = maxCount[n]
    for i = 1, last do
      local button = getglobal(names[n] .. i)
      if button then
        if button.qtEmptyHidden then
          local cell = button.QtUICell
          if cell then ParkSlotCell(cell) end
          self:HideButtonRim(button)
        else
          local shown = ButtonIsOnQtBar(button)
          local cell = self:EnsureSlotCell(button, button:GetParent())
          if cell then
            if shown and LayoutFlagOn(layout.slotShowBackground) and not SlotHasSpell(button, names[n], i) then
              PlaceSlotCell(cell, button, SLOT_EXTRA)
            else
              ParkSlotCell(cell)
            end
          end
          local filled = SlotHasSpell(button, names[n], i)
          local keepIcon = names[n] == "ShapeshiftButton" and filled
          self:EnsureButtonRim(button, button.QtUISize, keepIcon)
        end
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
  if self.RefreshAllActionButtons then self.RefreshAllActionButtons() end
  if self.ApplyUnitFrameLayout then self:ApplyUnitFrameLayout() end
  if self.ApplyPartyFrameLayout then self:ApplyPartyFrameLayout() end
  if self.UpdateUnitFrames then self:UpdateUnitFrames() end
  if self.UpdatePartyFrames then self:UpdatePartyFrames() end
  if self.bagFrame and self.UpdateBags then self:UpdateBags() end
  if self.bankFrame and self.UpdateBank then self:UpdateBank() end
  if self.ApplyDamageMeterLayout then self:ApplyDamageMeterLayout() end
  if self.LayoutChat then self:LayoutChat() end
  if self.LayoutDataText then self:LayoutDataText() end
  if self.ApplySavedPositions then self:ApplySavedPositions() end
  if self.LayoutAuraWatch then self:LayoutAuraWatch() end
  -- Never turn anchor mode on from layout. Login and Apply must stay locked.
  if not self.pulsingBarBackground and self.ScheduleBarChromeRefresh then
    self:ScheduleBarChromeRefresh()
  end
end

function QtUI:PulseActionBarBackground()
  if self.pulsingBarBackground then return end
  self.pulsingBarBackground = true
  -- Restamp the saved chrome only. Flipping barShowBackground used to force
  -- Emberveil to draw, then left the backdrop stuck on and could write the
  -- inverted value into SavedVariables.
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
  if self.EnsureProfiles then self:EnsureProfiles() end
end

local PANEL_NAMES = {
  "CharacterFrame", "PaperDollFrame", "ReputationFrame", "SkillFrame", "HonorFrame",
  "PetPaperDollFrame", "TradeFrame", "MailFrame", "SendMailFrame", "OpenMailFrame",
  "AuctionFrame", "CraftFrame", "TradeSkillFrame", "ClassTrainerFrame",
  "MerchantFrame", "GossipFrame", "QuestFrame", "QuestLogFrame",
  "TaxiFrame", "InspectFrame", "TalentFrame", "SpellBookFrame", "FriendsFrame",
  "GuildFrame", "WhoFrame", "PetitionFrame", "TabardFrame", "PetStableFrame",
  "DressUpFrame", "ItemTextFrame", "LootFrame", "BattlefieldFrame",
  "MacroFrame", "KeyBindingFrame", "GameMenuFrame", "OptionsFrame",
  "SoundOptionsFrame", "UIOptionsFrame", "HelpFrame", "ColorPickerFrame",
  "StaticPopup1", "StaticPopup2", "StaticPopup3", "StaticPopup4",
  "GroupLootFrame1", "GroupLootFrame2", "GroupLootFrame3", "GroupLootFrame4",
}

local function IsBagPanel(frame)
  if not frame or not frame.GetName then return nil end
  local name = frame:GetName()
  if not name then return nil end
  if name == "QtUIBagFrame" or name == "QtUIBankFrame" or name == "QtUIStackSplit" then return true end
  if string.find(name, "ContainerFrame", 1, true) then return true end
  if string.find(name, "Backpack", 1, true) then return true end
  return nil
end

-- The world map must keep its native FULLSCREEN strata. pfQuest parents its
-- pins to WorldMapButton (a child of WorldMapFrame), so demoting the frame to
-- DIALOG and re-Raise()ing it on every show reorders the map against its pins
-- and the markers stop drawing. ShowUIPanel receives WorldMapFrame from
-- ToggleWorldMap, so it has to be excluded here rather than in PANEL_NAMES.
local function IsMapPanel(frame)
  if not frame or not frame.GetName then return nil end
  local name = frame:GetName()
  if not name then return nil end
  if string.find(name, "WorldMap", 1, true) then return true end
  if string.find(name, "BattlefieldMinimap", 1, true) then return true end
  return nil
end

local function RaiseGamePanel(frame)
  if not frame or IsBagPanel(frame) or IsMapPanel(frame) then return end
  if frame.SetFrameStrata then pcall(frame.SetFrameStrata, frame, "DIALOG") end
  if frame.SetToplevel then pcall(frame.SetToplevel, frame, true) end
  if frame.Raise then pcall(frame.Raise, frame) end
end

local function HookGamePanel(frame)
  if not frame or frame.qtPanelRaised or IsBagPanel(frame) or IsMapPanel(frame) then return end
  frame.qtPanelRaised = true
  local prev
  if type(frame.GetScript) == "function" then
    prev = frame:GetScript("OnShow")
  end
  frame:SetScript("OnShow", function()
    if prev then pcall(prev) end
    RaiseGamePanel(this)
  end)
  if frame.IsShown then
    local ok, shown = pcall(frame.IsShown, frame)
    if ok and (shown == true or shown == 1 or shown == "1") then
      RaiseGamePanel(frame)
    end
  end
end

function QtUI:SetupPanelStrata()
  if self.panelStrataReady then return end
  self.panelStrataReady = true
  local i
  for i = 1, table.getn(PANEL_NAMES) do
    HookGamePanel(getglobal(PANEL_NAMES[i]))
  end
  if type(ShowUIPanel) == "function" then
    local original = ShowUIPanel
    ShowUIPanel = function(frame, force)
      original(frame, force)
      RaiseGamePanel(frame)
      HookGamePanel(frame)
    end
  end
  local watch = CreateFrame("Frame", "QtUIPanelStrata")
  pcall(watch.RegisterEvent, watch, "ADDON_LOADED")
  pcall(watch.RegisterEvent, watch, "PLAYER_ENTERING_WORLD")
  watch:SetScript("OnEvent", function()
    local n
    for n = 1, table.getn(PANEL_NAMES) do
      HookGamePanel(getglobal(PANEL_NAMES[n]))
    end
  end)
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
  SafeSetup("mobHealth", self.SetupMobHealth)
  if self:IsFeatureEnabled("unitFrames") then SafeSetup("unitFrames", self.SetupUnitFrames) end
  if self:IsFeatureEnabled("auras") then SafeSetup("auraWatch", self.SetupAuraWatch) end
  if self:IsFeatureEnabled("castBar") then SafeSetup("castBar", self.SetupCastBar) end
  if self:IsFeatureEnabled("partyFrames") then SafeSetup("partyFrames", self.SetupPartyFrames) end
  if self:IsFeatureEnabled("bags") then SafeSetup("bags", self.SetupBags) end
  if self:IsFeatureEnabled("minimap") then SafeSetup("minimap", self.SetupMinimap) end
  if self:IsFeatureEnabled("autoLoot") then SafeSetup("autoLoot", self.SetupAutoLoot) end
  if self:IsFeatureEnabled("autoSell") then SafeSetup("autoSell", self.SetupAutoSell) end
  if self:IsFeatureEnabled("dataText") then SafeSetup("dataText", self.SetupDataText) end
  if self:IsFeatureEnabled("damageMeter") then SafeSetup("damageMeter", self.SetupDamageMeter) end
  SafeSetup("chat", self.SetupChat)
  SafeSetup("questLog", self.SetupQuestLog)
  SafeSetup("cooldowns", self.SetupCooldowns)
  SafeSetup("eqCompare", self.SetupEqCompare)
  SafeSetup("classTooltip", self.SetupClassTooltip)
  SafeSetup("settingsButton", self.SetupSettingsButton)
  SafeSetup("moveMode", self.SetupMoveMode)
  SafeSetup("panelStrata", self.SetupPanelStrata)
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
