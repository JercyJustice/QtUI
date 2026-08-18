-- Cooldown numbers: white text plus one black copy 1px down-right.
-- No native OUTLINE (Emberveil stacks that as extra glyphs) and no SetAlpha
-- (Emberveil does not restore a fontstring after SetAlpha(0)).

local GCD = 2

local function FeatureOn()
  if not QtUI.GetLayout then return true end
  local layout = QtUI:GetLayout()
  local value = layout and layout.cooldownText
  return value ~= false and value ~= 0 and value ~= "0"
end

local function FormatCD(remaining)
  if remaining >= 3600 then
    return math.ceil(remaining / 3600) .. "h"
  end
  if remaining >= 60 then
    return math.ceil(remaining / 60) .. "m"
  end
  if remaining > 5 then
    return tostring(math.ceil(remaining))
  end
  return string.format("%.1f", remaining)
end

local function ClampSize(size)
  size = tonumber(size) or 13
  if size < 11 then size = 11 end
  if size > 18 then size = 18 end
  return size
end

local function StyleCDFont(fontString, size, r, g, b)
  local font = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
  if fontString.SetFont then fontString:SetFont(font, size, "") end
  if fontString.SetShadowColor then fontString:SetShadowColor(0, 0, 0, 0) end
  if fontString.SetShadowOffset then fontString:SetShadowOffset(0, 0) end
  if fontString.SetTextColor then fontString:SetTextColor(r, g, b) end
end

local function RemainingFor(start, duration)
  local now = GetTime()
  if start < now then return duration - (now - start) end
  return duration
end

local function PaintCD(overlay)
  if not overlay or not overlay.text then return end
  local parent = overlay:GetParent()
  local start = parent and parent.QtUICDStart
  local duration = parent and parent.QtUICDDuration
  if not start or not duration or not FeatureOn() then
    overlay.text:SetText("")
    if overlay.shadow then overlay.shadow:SetText("") end
    return
  end
  local remaining = RemainingFor(start, duration)
  if remaining <= 0 then
    parent.QtUICDStart = nil
    parent.QtUICDDuration = nil
    overlay.text:SetText("")
    if overlay.shadow then overlay.shadow:SetText("") end
    return
  end
  local text = FormatCD(remaining)
  -- Emberveil treats SetTextColor(0,0,0) as white. Color codes stick.
  if overlay.shadow then
    overlay.shadow:SetText("|cff010101" .. text)
    if overlay.shadow.SetTextColor then overlay.shadow:SetTextColor(.01, .01, .01) end
  end
  overlay.text:SetText("|cffffffff" .. text)
  if overlay.text.SetTextColor then overlay.text:SetTextColor(1, 1, 1) end
end

local function OverlayOnUpdate()
  this.elapsed = (this.elapsed or 0) + (arg1 or 0)
  if this.elapsed < .1 then return end
  this.elapsed = 0
  PaintCD(this)
  local parent = this:GetParent()
  if not parent or not parent.QtUICDStart then
    this:SetScript("OnUpdate", nil)
  end
end

function QtUI:EnsureCooldownOverlay(parent, size)
  if not parent then return nil end
  size = ClampSize(size)

  if parent.QtUICDText then
    parent.QtUICDText:SetText("")
    parent.QtUICDText = nil
  end

  local overlay = parent.QtUICDOverlay
  if not overlay then
    overlay = CreateFrame("Frame", nil, parent)
    overlay:SetAllPoints(parent)
    overlay:SetFrameLevel((parent.GetFrameLevel and parent:GetFrameLevel() or 1) + 8)
    if overlay.EnableMouse then overlay:EnableMouse(false) end
    parent.QtUICDOverlay = overlay
  end

  if overlay.stroke then
    local i
    for i = 1, table.getn(overlay.stroke) do
      if overlay.stroke[i] then overlay.stroke[i]:SetText("") end
    end
    overlay.stroke = nil
  end

  if not overlay.shadow then
    overlay.shadow = overlay:CreateFontString(nil, "OVERLAY")
    overlay.shadow:SetPoint("CENTER", overlay, "CENTER", 1, -1)
  end
  if not overlay.text then
    overlay.text = overlay:CreateFontString(nil, "OVERLAY")
    overlay.text:SetPoint("CENTER", overlay, "CENTER", 0, 0)
  end

  if overlay.fontSize ~= size then
    overlay.fontSize = size
    StyleCDFont(overlay.shadow, size, .01, .01, .01)
    StyleCDFont(overlay.text, size, 1, 1, 1)
  end
  return overlay
end

function QtUI:SetCooldownText(parent, start, duration, enable, size)
  if not parent then return end
  start = tonumber(start) or 0
  duration = tonumber(duration) or 0
  local overlay = self:EnsureCooldownOverlay(parent, size)
  if not overlay then return end
  if not FeatureOn() or start <= 0 or duration <= GCD or enable == 0 then
    parent.QtUICDStart = nil
    parent.QtUICDDuration = nil
    overlay.text:SetText("")
    if overlay.shadow then overlay.shadow:SetText("") end
    overlay:SetScript("OnUpdate", nil)
    return
  end
  parent.QtUICDStart = start
  parent.QtUICDDuration = duration
  PaintCD(overlay)
  overlay.elapsed = 0
  overlay:SetScript("OnUpdate", OverlayOnUpdate)
end

function QtUI:SetupCooldowns()
  if self.cooldownsReady then return end
  self.cooldownsReady = true
  if type(CooldownFrame_SetTimer) ~= "function" then return end
  local original = CooldownFrame_SetTimer
  CooldownFrame_SetTimer = function(cooldown, start, duration, enable)
    original(cooldown, start, duration, enable)
    if not cooldown then return end
    local parent = cooldown.GetParent and cooldown:GetParent()
    if parent then
      local size = 13
      if parent.GetWidth then size = math.floor((parent:GetWidth() or 34) * 0.42) end
      QtUI:SetCooldownText(parent, start, duration, enable, size)
    end
  end
end
