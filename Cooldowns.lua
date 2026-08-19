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
  if QtUI.ApplyFont then
    QtUI:ApplyFont(fontString, size)
  else
    local font = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    if fontString.SetFont then fontString:SetFont(font, size, "") end
  end
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

local SWEEP_BARS = {
  { "ActionButton", 12 },
  { "MultiBarBottomLeftButton", 12 },
  { "MultiBarBottomRightButton", 12 },
  { "MultiBarRightButton", 12 },
  { "MultiBarLeftButton", 12 },
  { "ShapeshiftButton", 10 },
  { "PetActionButton", 10 },
}

local function ButtonSlot(button)
  if not button then return nil end
  if button.QtUIAction then return button.QtUIAction end
  if button.action then return button.action end
  if type(ActionButton_GetPagedID) == "function" then
    local ok, slot = pcall(ActionButton_GetPagedID, button)
    if ok and slot then return slot end
  end
  if button.GetID then return button:GetID() end
  return nil
end

local function CooldownValues(button)
  local name = button and button.GetName and button:GetName() or ""
  if string.find(name, "PetActionButton", 1, true) then
    local id = button.GetID and button:GetID()
    if id and type(GetPetActionCooldown) == "function" then
      local ok, start, duration, enable = pcall(GetPetActionCooldown, id)
      if ok then return start, duration, enable end
    end
    return 0, 0, 0
  end
  if string.find(name, "ShapeshiftButton", 1, true) then
    local id = button.GetID and button:GetID()
    if id and type(GetShapeshiftFormCooldown) == "function" then
      local ok, start, duration, enable = pcall(GetShapeshiftFormCooldown, id)
      if ok then return start, duration, enable end
    end
    return 0, 0, 0
  end
  local slot = ButtonSlot(button)
  if slot and type(GetActionCooldown) == "function" then
    if type(HasAction) == "function" then
      local ok, has = pcall(HasAction, slot)
      if ok and not (has == true or has == 1 or has == "1") then
        return 0, 0, 0
      end
    end
    local ok, start, duration, enable = pcall(GetActionCooldown, slot)
    if ok then return start, duration, enable end
  end
  return 0, 0, 0
end

function QtUI:EnsureCooldownSweep(button)
  if not button then return nil end
  local cd = button.QtUICooldown
  if not cd then
    local name = button.GetName and button:GetName()
    if name then cd = getglobal(name .. "Cooldown") end
    if not cd and type(CreateFrame) == "function" then
      local cdName = name and (name .. "Cooldown") or nil
      local ok, created = pcall(CreateFrame, "Cooldown", cdName, button)
      if ok then cd = created end
    end
    if not cd then return nil end
    button.QtUICooldown = cd
  end
  if cd.SetParent then pcall(cd.SetParent, cd, button) end
  local size = button.QtUISize
  if not size or size < 8 then
    size = (button.GetWidth and button:GetWidth()) or 34
  end
  if size < 8 then size = 34 end
  local inset = 1
  cd:ClearAllPoints()
  -- Emberveil ignores SetWidth on MultiBar buttons; two corners from the
  -- button origin is what actually gives the sweep a box.
  cd:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", inset, inset)
  cd:SetPoint("TOPRIGHT", button, "BOTTOMLEFT", size - inset, size - inset)
  if cd.SetWidth then
    local inner = size - inset * 2
    cd:SetWidth(inner + 1)
    if cd.SetHeight then cd:SetHeight(inner + 1) end
    cd:SetWidth(inner)
    if cd.SetHeight then cd:SetHeight(inner) end
  end
  if cd.SetFrameLevel and button.GetFrameLevel then
    cd:SetFrameLevel((button:GetFrameLevel() or 4) + 2)
  end
  if cd.EnableMouse then pcall(cd.EnableMouse, cd, false) end
  return cd
end

function QtUI:ApplyButtonCooldown(button)
  if not button then return end
  local cd = self:EnsureCooldownSweep(button)
  if not cd or type(CooldownFrame_SetTimer) ~= "function" then return end
  local start, duration, enable = CooldownValues(button)
  start = tonumber(start) or 0
  duration = tonumber(duration) or 0
  enable = tonumber(enable)
  if enable == nil then enable = 1 end
  pcall(CooldownFrame_SetTimer, cd, start, duration, enable)
end

function QtUI:RefreshBarCooldowns()
  local n
  for n = 1, table.getn(SWEEP_BARS) do
    local prefix = SWEEP_BARS[n][1]
    local last = SWEEP_BARS[n][2]
    local i
    for i = 1, last do
      local button = getglobal(prefix .. i)
      if button then self:ApplyButtonCooldown(button) end
    end
  end
end

function QtUI:SetupCooldowns()
  if self.cooldownsReady then return end
  self.cooldownsReady = true
  if type(CooldownFrame_SetTimer) == "function" then
    local original = CooldownFrame_SetTimer
    CooldownFrame_SetTimer = function(cooldown, start, duration, enable)
      original(cooldown, start, duration, enable)
      if not cooldown then return end
      local parent = cooldown.GetParent and cooldown:GetParent()
      if parent then
        local size = 13
        if parent.QtUISize then
          size = math.floor(parent.QtUISize * 0.42)
        elseif parent.GetWidth then
          size = math.floor((parent:GetWidth() or 34) * 0.42)
        end
        QtUI:SetCooldownText(parent, start, duration, enable, size)
      end
    end
  end

  if type(ActionButton_UpdateCooldown) == "function" then
    local originalUpdate = ActionButton_UpdateCooldown
    ActionButton_UpdateCooldown = function()
      originalUpdate()
      if this then QtUI:ApplyButtonCooldown(this) end
    end
  end

  if self.cooldownEvents then return end
  local events = CreateFrame("Frame", "QtUICooldownEvents")
  pcall(events.RegisterEvent, events, "ACTIONBAR_UPDATE_COOLDOWN")
  pcall(events.RegisterEvent, events, "SPELL_UPDATE_COOLDOWN")
  pcall(events.RegisterEvent, events, "BAG_UPDATE_COOLDOWN")
  pcall(events.RegisterEvent, events, "PET_BAR_UPDATE_COOLDOWN")
  events.elapsed = 0
  events:SetScript("OnEvent", function()
    this.pending = true
    this.elapsed = 0
    this:SetScript("OnUpdate", function()
      this.elapsed = this.elapsed + (arg1 or 0)
      if this.elapsed < .03 then return end
      this:SetScript("OnUpdate", nil)
      this.pending = nil
      QtUI:RefreshBarCooldowns()
    end)
  end)
  self.cooldownEvents = events
  self:RefreshBarCooldowns()
end
