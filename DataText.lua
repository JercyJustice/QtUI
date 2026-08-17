local function FormatMoney(copper)
  copper = copper or 0
  local gold = math.floor(copper / 10000)
  local silver = math.floor(math.mod(copper / 100, 100))
  local remainder = math.mod(copper, 100)
  return string.format("|cffffd700%dg|r |cffc7c7cf%ds|r |cffeda55f%dc|r", gold, silver, remainder)
end

local function UpdateDataText(frame)
  local hour, minute = GetGameTime()
  local fps = math.floor((GetFramerate() or 0) + .5)
  local _, _, latency = GetNetStats()
  latency = math.floor((latency or 0) + .5)

  frame.left:SetText(FormatMoney(GetMoney()))
  frame.right:SetText(string.format("|cffffffff%02d:%02d|r   |cff7fdfff%d fps|r   |cff7fff7f%d ms|r", hour, minute, fps, latency))
end

function PotatoUI:SetupDataText()
  -- Keep data text independent from chat frames; PotatoUI no longer owns or
  -- modifies either chat window.
  local parent = UIParent
  local bar = CreateFrame("Frame", "PotatoUIDataBar", parent)
  bar:SetWidth(math.min(430, UIParent:GetWidth() * .27))
  if self.utilityActionPanel then
    bar:SetPoint("BOTTOMRIGHT", self.utilityActionPanel, "TOPRIGHT", 0, 4)
  else
    bar:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -14, 62)
  end
  bar:SetHeight(20)

  bar.left = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  bar.left:SetPoint("LEFT", bar, "LEFT", 3, 0)
  bar.left:SetJustifyH("LEFT")

  bar.right = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  bar.right:SetPoint("RIGHT", bar, "RIGHT", -3, 0)
  bar.right:SetJustifyH("RIGHT")

  bar.elapsed = 0
  bar:SetScript("OnUpdate", function()
    this.elapsed = this.elapsed + arg1
    if this.elapsed >= 1 then
      this.elapsed = 0
      UpdateDataText(this)
    end
  end)

  self.dataBar = bar
  UpdateDataText(bar)
end
