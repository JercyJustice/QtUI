local TEXT_FONT = "Fonts\\FRIZQT__.TTF"
local TEXT_SIZE = 11

local function CompactOn()
  if not QtUI.GetLayout then return nil end
  local layout = QtUI:GetLayout()
  local value = layout and layout.dataTextCompact
  return value == true or value == 1 or value == "1"
end

local function CellMetrics()
  if CompactOn() then
    return 4, 46, 54, 40, 76, 96
  end
  return 24, 54, 66, 44, 86, 110
end

local function FormatMoney(copper)
  copper = copper or 0
  local gold = math.floor(copper / 10000)
  local silver = math.floor(math.mod(copper / 100, 100))
  local remainder = math.mod(copper, 100)
  return string.format("|cffffd700%dg|r |cffc7c7cf%ds|r |cffeda55f%dc|r", gold, silver, remainder)
end

local function UpdateBagSpace(frame)
  local free, total = 0, 0
  local bag, slot
  for bag = 0, 4 do
    local slots = tonumber(GetContainerNumSlots(bag)) or 0
    total = total + slots
    for slot = 1, slots do
      if not GetContainerItemLink(bag, slot) then free = free + 1 end
    end
  end
  frame.freeBagSlots = free
  frame.totalBagSlots = total
  frame.bagsDirty = nil
end

local function FormatBagSpace(free, total)
  local color = "7fff7f"
  if free <= 0 then
    color = "ff4040"
  elseif free <= 4 then
    color = "ff9f40"
  end
  return "|cff" .. color .. free .. "/" .. total .. " slots|r"
end

local function FormatHM(hour, minute)
  return string.format("%02d:%02d", tonumber(hour) or 0, tonumber(minute) or 0)
end

local function GetServerClock()
  local hour, minute = GetGameTime()
  return tonumber(hour) or 0, tonumber(minute) or 0
end

local function GetClientClock()
  local fn = date
  if type(fn) ~= "function" and os and type(os.date) == "function" then
    fn = os.date
  end
  if type(fn) ~= "function" then return nil end

  local ok, stamp = pcall(fn, "*t")
  if ok and type(stamp) == "table" then
    return tonumber(stamp.hour) or 0, tonumber(stamp.min) or 0
  end

  ok, stamp = pcall(fn, "%H:%M")
  if ok and type(stamp) == "string" then
    local _, _, hour, minute = string.find(stamp, "(%d+):(%d+)")
    if hour then return tonumber(hour), tonumber(minute) end
  end
  return nil
end

local function ClockUsesLocal()
  if not QtUI.GetLayout then return nil end
  local layout = QtUI:GetLayout()
  return layout and layout.clockLocal == true
end

-- Emberveil ignores SetWidth. Size cells with corner anchors so hit boxes
-- and column widths stay put when 99 fps becomes 164 fps.
local function PlaceCell(cell, bar, rightFrame, width, gap)
  cell:ClearAllPoints()
  cell:SetPoint("TOP", bar, "TOP", 0, 0)
  cell:SetPoint("BOTTOM", bar, "BOTTOM", 0, 0)
  if rightFrame == bar then
    cell:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
    cell:SetPoint("LEFT", bar, "RIGHT", -width, 0)
  else
    cell:SetPoint("RIGHT", rightFrame, "LEFT", -gap, 0)
    cell:SetPoint("LEFT", rightFrame, "LEFT", -gap - width, 0)
  end
end

local function LabelInCell(parent, align)
  local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  if QtUI.ApplyFont then
    QtUI:ApplyFont(text, TEXT_SIZE)
  elseif text.SetFont then
    pcall(text.SetFont, text, TEXT_FONT, TEXT_SIZE, "")
  end
  text:ClearAllPoints()
  -- One shared vertical point so every column sits on the same baseline.
  -- Stretching LEFT+RIGHT without TOP/BOTTOM lets Emberveil pick a random Y.
  if align == "CENTER" then
    text:SetPoint("CENTER", parent, "CENTER", 0, 0)
    if text.SetJustifyH then text:SetJustifyH("CENTER") end
  else
    text:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    if text.SetJustifyH then text:SetJustifyH("RIGHT") end
  end
  if text.SetJustifyV then text:SetJustifyV("MIDDLE") end
  return text
end

local function UpdateDataText(frame)
  local fps = math.floor((GetFramerate() or 0) + .5)
  local _, _, latency = GetNetStats()
  latency = math.floor((latency or 0) + .5)

  frame.gold:SetText(FormatMoney(GetMoney()))
  frame.bags:SetText(FormatBagSpace(frame.freeBagSlots or 0, frame.totalBagSlots or 0))
  frame.fps:SetText(string.format("|cff7fdfff%d fps|r", fps))
  frame.ms:SetText(string.format("|cff7fff7f%d ms|r", latency))

  local hour, minute
  if ClockUsesLocal() then
    hour, minute = GetClientClock()
  end
  if hour == nil then
    hour, minute = GetServerClock()
  end
  frame.clock.text:SetText(string.format("|cffffffff%s|r", FormatHM(hour, minute)))
end

local function PlaceClockTooltip(owner)
  if not GameTooltip or not owner then return end
  GameTooltip:ClearAllPoints()
  GameTooltip:SetPoint("BOTTOM", owner, "TOP", 0, 8)
end

local function ShowClockTooltip()
  if not GameTooltip then return end
  local owner = this
  GameTooltip:SetOwner(owner, "ANCHOR_NONE")
  GameTooltip:ClearLines()

  local server = FormatHM(GetServerClock())
  local ch, cm = GetClientClock()
  local localText = "n/a"
  if ch ~= nil then localText = FormatHM(ch, cm) end

  local useLocal = ClockUsesLocal() and ch ~= nil
  if useLocal then
    GameTooltip:AddLine("Local Time")
  else
    GameTooltip:AddLine("Server Time")
  end
  GameTooltip:AddDoubleLine("Server", "|cffffffff" .. server .. "|r")
  GameTooltip:AddDoubleLine("Local", "|cffffffff" .. localText .. "|r")
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("Click to switch", .7, .75, .8)
  GameTooltip:Show()
  PlaceClockTooltip(owner)
end

function QtUI:SetupDataText()
  -- Keep data text independent from chat frames; QtUI no longer owns or
  -- modifies either chat window.
  local parent = UIParent
  local bar = CreateFrame("Frame", "QtUIDataBar", parent)
  bar:SetWidth(math.min(460, UIParent:GetWidth() * .3))
  if self.utilityActionPanel then
    bar:SetPoint("BOTTOMRIGHT", self.utilityActionPanel, "TOPRIGHT", 0, 4)
  else
    bar:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -14, 62)
  end
  bar:SetHeight(20)
  if bar.EnableMouse then bar:EnableMouse(false) end

  bar.msCell = CreateFrame("Frame", nil, bar)
  if bar.msCell.EnableMouse then bar.msCell:EnableMouse(false) end
  bar.ms = LabelInCell(bar.msCell)

  bar.fpsCell = CreateFrame("Frame", nil, bar)
  if bar.fpsCell.EnableMouse then bar.fpsCell:EnableMouse(false) end
  bar.fps = LabelInCell(bar.fpsCell)

  -- Frame, not Button: Emberveil Button padding shifts the clock off the row.
  -- Real hit box via corner anchors; a leftover SetWidth(48) was ignored
  -- and left the clock unclickable.
  bar.clock = CreateFrame("Frame", "QtUIDataClock", bar)
  if bar.clock.EnableMouse then bar.clock:EnableMouse(true) end
  if bar.clock.SetFrameLevel then
    bar.clock:SetFrameLevel((bar:GetFrameLevel() or 1) + 5)
  end
  -- Invisible fill so Emberveil actually hit-tests the cell.
  bar.clock.hit = bar.clock:CreateTexture(nil, "BACKGROUND")
  bar.clock.hit:SetPoint("TOPLEFT", bar.clock, "TOPLEFT", 0, 0)
  bar.clock.hit:SetPoint("BOTTOMRIGHT", bar.clock, "BOTTOMRIGHT", 0, 0)
  bar.clock.hit:SetTexture("Interface\\Buttons\\WHITE8X8")
  if bar.clock.hit.SetVertexColor then bar.clock.hit:SetVertexColor(0, 0, 0, 0) end
  bar.clock.text = LabelInCell(bar.clock, "CENTER")
  local function ToggleClock()
    local layout = QtUI:GetLayout()
    if layout.clockLocal then
      layout.clockLocal = false
    else
      layout.clockLocal = true
    end
    UpdateDataText(bar)
    if GameTooltip and GameTooltip.IsShown and GameTooltip:IsShown() then ShowClockTooltip() end
  end
  bar.clock:SetScript("OnMouseUp", function()
    if arg1 == "LeftButton" then ToggleClock() end
  end)
  bar.clock:SetScript("OnEnter", ShowClockTooltip)
  bar.clock:SetScript("OnLeave", function()
    if GameTooltip then GameTooltip:Hide() end
  end)

  bar.bagsCell = CreateFrame("Frame", nil, bar)
  if bar.bagsCell.EnableMouse then bar.bagsCell:EnableMouse(false) end
  bar.bags = LabelInCell(bar.bagsCell)

  bar.goldCell = CreateFrame("Frame", nil, bar)
  if bar.goldCell.EnableMouse then bar.goldCell:EnableMouse(false) end
  bar.gold = LabelInCell(bar.goldCell)

  self.dataBar = bar
  self:LayoutDataText()

  bar.elapsed = 0
  bar:RegisterEvent("BAG_UPDATE")
  bar:SetScript("OnEvent", function() this.bagsDirty = true end)
  bar:SetScript("OnUpdate", function()
    this.elapsed = this.elapsed + arg1
    if this.elapsed >= 1 then
      this.elapsed = 0
      if this.bagsDirty then UpdateBagSpace(this) end
      UpdateDataText(this)
    end
  end)

  UpdateBagSpace(bar)
  UpdateDataText(bar)
end

function QtUI:LayoutDataText()
  local bar = self.dataBar
  if not bar then return end
  local gap, msW, fpsW, clockW, bagsW, goldW = CellMetrics()
  PlaceCell(bar.msCell, bar, bar, msW, gap)
  PlaceCell(bar.fpsCell, bar, bar.msCell, fpsW, gap)
  PlaceCell(bar.clock, bar, bar.fpsCell, clockW, gap)
  PlaceCell(bar.bagsCell, bar, bar.clock, bagsW, gap)
  PlaceCell(bar.goldCell, bar, bar.bagsCell, goldW, gap)
end
