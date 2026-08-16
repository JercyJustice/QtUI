local auraScanner

-- Vanilla does not expose target aura durations. These base durations provide
-- countdowns when Emberveil and the aura tooltip expose no timing metadata.
local KNOWN_DURATIONS = {
  ["shadow word: pain"] = 18,
  ["devouring plague"] = 24,
  ["holy fire"] = 10,
  ["vampiric embrace"] = 60,
  ["mind flay"] = 3,
  ["psychic scream"] = 8,
  ["silence"] = 5,
  ["blackout"] = 3,
  ["shackle undead"] = 50,
  ["weakened soul"] = 15,
  ["renew"] = 15,
  ["power word: shield"] = 30,
  ["power word: fortitude"] = 1800,
  ["prayer of fortitude"] = 3600,
  ["divine spirit"] = 1800,
  ["prayer of spirit"] = 3600,
  ["shadow protection"] = 600,
  ["prayer of shadow protection"] = 1200,
  ["fear ward"] = 600,
  ["inspiration"] = 15,

  -- Paladin judgements and control effects
  ["judgement of the crusader"] = 10,
  ["judgment of the crusader"] = 10,
  ["judgement of light"] = 10,
  ["judgment of light"] = 10,
  ["judgement of wisdom"] = 10,
  ["judgment of wisdom"] = 10,
  ["judgement of justice"] = 10,
  ["judgment of justice"] = 10,
  ["hammer of justice"] = 6,
  ["repentance"] = 6,
  ["turn undead"] = 20,

  -- Paladin short defensive and utility effects
  ["blessing of protection"] = 10,
  ["blessing of freedom"] = 10,
  ["blessing of sacrifice"] = 30,
  ["divine protection"] = 8,
  ["divine shield"] = 12,
  ["forbearance"] = 60,
  ["holy shield"] = 10,
  ["divine favor"] = 15,
  ["divine illumination"] = 15,
  ["avenging wrath"] = 20,

  -- Paladin blessings, seals and persistent personal buffs
  ["blessing of might"] = 300,
  ["blessing of wisdom"] = 300,
  ["blessing of kings"] = 300,
  ["blessing of salvation"] = 300,
  ["blessing of sanctuary"] = 300,
  ["blessing of light"] = 300,
  ["greater blessing of might"] = 900,
  ["greater blessing of wisdom"] = 900,
  ["greater blessing of kings"] = 900,
  ["greater blessing of salvation"] = 900,
  ["greater blessing of sanctuary"] = 900,
  ["greater blessing of light"] = 900,
  ["seal of righteousness"] = 30,
  ["seal of command"] = 30,
  ["seal of the crusader"] = 30,
  ["seal of justice"] = 30,
  ["seal of light"] = 30,
  ["seal of wisdom"] = 30,
  ["righteous fury"] = 1800,
}

local KNOWN_TEXTURE_DURATIONS = {
  ["spell_shadow_shadowwordpain"] = 18,
  ["spell_shadow_blackplague"] = 24,
  ["spell_holy_searinglight"] = 10,
  ["spell_shadow_unsummonbuilding"] = 60,
  ["spell_shadow_siphonmana"] = 3,
  ["spell_shadow_psychicscream"] = 8,
  ["spell_shadow_impphaseshift"] = 5,
  ["spell_shadow_gathershadows"] = 3,
  ["spell_nature_slow"] = 50,
  ["spell_holy_ashesToashes"] = 15,
  ["spell_holy_renew"] = 15,
  ["spell_holy_powerwordshield"] = 30,
  ["spell_holy_sealofmight"] = 6,
  ["spell_holy_prayerofhealing"] = 6,
  ["spell_holy_divineintervention"] = 12,
  ["spell_holy_removecurse"] = 60,
  ["spell_holy_sealofprotection"] = 10,
  ["spell_holy_sealofvalor"] = 10,
  ["spell_holy_sealofsacrifice"] = 30,
  ["spell_holy_blessingofprotection"] = 10,
  ["spell_holy_righteousfury"] = 1800,
}

local function GetKnownDuration(auraName, texture)
  if auraName then
    local duration = KNOWN_DURATIONS[string.lower(auraName)]
    if duration then return duration end
  end

  if texture then
    local lowerTexture = string.lower(texture)
    local key, duration
    for key, duration in pairs(KNOWN_TEXTURE_DURATIONS) do
      if string.find(lowerTexture, key, 1, true) then return duration end
    end
  end
  return nil
end

local function GetRawAura(unit, index, auraType)
  if auraType == "DEBUFF" then
    return UnitDebuff(unit, index)
  end
  return UnitBuff(unit, index)
end

local function ParseTimeLine(text, requireRemaining)
  if not text then return nil end
  local lower = string.lower(text)
  if requireRemaining and not string.find(lower, "remaining") then return nil end
  if not requireRemaining and not (string.find(lower, " for ") or
      string.find(lower, " over ") or string.find(lower, "lasts")) then
    return nil
  end

  local _, _, value = string.find(lower, "(%d+%.?%d*)%s*hour")
  if value then return tonumber(value) * 3600 end
  _, _, value = string.find(lower, "(%d+%.?%d*)%s*min")
  if value then return tonumber(value) * 60 end
  _, _, value = string.find(lower, "(%d+%.?%d*)%s*sec")
  if value then return tonumber(value) end
  return nil
end

local function ScanAuraTooltip(unit, index, auraType)
  if not auraScanner then
    auraScanner = CreateFrame("GameTooltip", "PotatoUIAuraScanTooltip", UIParent, "GameTooltipTemplate")
    auraScanner:SetOwner(UIParent, "ANCHOR_NONE")
  end

  auraScanner:ClearLines()
  if auraType == "DEBUFF" and auraScanner.SetUnitDebuff then
    auraScanner:SetUnitDebuff(unit, index)
  elseif auraType == "BUFF" and auraScanner.SetUnitBuff then
    auraScanner:SetUnitBuff(unit, index)
  else
    return nil, nil, nil
  end

  local nameLine = getglobal("PotatoUIAuraScanTooltipTextLeft1")
  local auraName = nameLine and nameLine:GetText()
  local duration
  local remaining
  local lines = auraScanner.NumLines and auraScanner:NumLines() or 8
  local line
  for line = 2, lines do
    local fontString = getglobal("PotatoUIAuraScanTooltipTextLeft" .. line)
    local text = fontString and fontString:GetText()
    if text then
      remaining = remaining or ParseTimeLine(text, true)
      duration = duration or ParseTimeLine(text, false)
    end
  end
  auraScanner:Hide()
  return auraName, duration, remaining
end

local function GetAura(unit, index, auraType)
  local first, second, third, fourth, fifth, sixth, seventh =
    GetRawAura(unit, index, auraType)
  if not first then return nil end

  local texture, applications, auraKind, duration, expiration, auraName
  -- Accept both Vanilla's texture-first values and extended modern-style
  -- values used by some Emberveil client builds.
  if type(third) == "string" and string.find(third, "[\\/]") then
    auraName = first
    texture = third
    applications = fourth
    auraKind = fifth
    duration = tonumber(sixth)
    expiration = tonumber(seventh)
  else
    texture = first
    applications = second
    auraKind = third
    duration = tonumber(fourth)
    expiration = tonumber(fifth)
  end

  local scannedName, scannedDuration, scannedRemaining = ScanAuraTooltip(unit, index, auraType)
  auraName = auraName or scannedName
  duration = duration or scannedDuration or GetKnownDuration(auraName, texture)
  if scannedRemaining then expiration = GetTime() + scannedRemaining end
  return texture, applications, auraKind, duration, expiration, auraName
end

local function FormatAuraTime(seconds)
  if seconds >= 3600 then return math.ceil(seconds / 3600) .. "h" end
  if seconds >= 60 then return math.ceil(seconds / 60) .. "m" end
  return tostring(math.ceil(seconds))
end

local function UpdateAuraTimers(row)
  local now = GetTime()
  local i
  for i = 1, table.getn(row.icons) do
    local icon = row.icons[i]
    if icon:IsShown() and icon.expiration then
      local remaining = icon.expiration - now
      if remaining > 0 then
        icon.timer:SetText(FormatAuraTime(remaining))
        if remaining <= 5 then
          icon.timer:SetTextColor(1, .22, .16)
        elseif remaining <= 10 then
          icon.timer:SetTextColor(1, .82, .12)
        else
          icon.timer:SetTextColor(1, 1, 1)
        end
      else
        icon.timer:SetText("")
        icon.expiration = nil
      end
    else
      icon.timer:SetText("")
    end
  end
end

local function ShowAuraTooltip()
  if not this.unit or not this.auraIndex then return end
  GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
  if this.auraType == "DEBUFF" and GameTooltip.SetUnitDebuff then
    GameTooltip:SetUnitDebuff(this.unit, this.auraIndex)
  elseif this.auraType == "BUFF" and GameTooltip.SetUnitBuff then
    GameTooltip:SetUnitBuff(this.unit, this.auraIndex)
  end
  GameTooltip:Show()
end

local function CreateAuraIcon(row, index, size)
  local icon = CreateFrame("Button", nil, row)
  icon:SetWidth(size)
  icon:SetHeight(size)
  icon:SetPoint("LEFT", row, "LEFT", (index - 1) * (size + 2), 0)
  icon:SetFrameLevel(row:GetFrameLevel() + 1)
  icon:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 8,
    edgeSize = 8,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  icon:SetBackdropColor(.015, .02, .025, .92)

  icon.texture = icon:CreateTexture(nil, "ARTWORK")
  icon.texture:SetPoint("TOPLEFT", icon, "TOPLEFT", 2, -2)
  icon.texture:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -2, 2)

  icon.count = icon:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
  icon.count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 1)
  icon.count:SetTextColor(1, 1, 1)

  icon.timer = icon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  icon.timer:SetPoint("TOP", icon, "TOP", 0, -1)
  icon.timer:SetTextColor(1, 1, 1)

  icon:SetScript("OnEnter", ShowAuraTooltip)
  icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
  icon:Hide()
  return icon
end

function PotatoUI:CreateAuraRow(parent, unit, auraType, maximum, size)
  local row = CreateFrame("Frame", nil, parent)
  row:SetWidth(maximum * (size + 2) - 2)
  row:SetHeight(size)
  row:SetFrameLevel(parent:GetFrameLevel() + 8)
  row.unit = unit
  row.auraType = auraType
  row.icons = {}

  local i
  for i = 1, maximum do
    row.icons[i] = CreateAuraIcon(row, i, size)
  end
  row.elapsed = 0
  row:SetScript("OnUpdate", function()
    this.elapsed = this.elapsed + arg1
    if this.elapsed >= .1 then
      this.elapsed = 0
      UpdateAuraTimers(this)
    end
  end)
  return row
end

function PotatoUI:UpdateAuraRow(row)
  if not row then return end

  local hasAura
  local i
  for i = 1, table.getn(row.icons) do
    local texture, applications, auraKind, duration, expiration, auraName =
      GetAura(row.unit, i, row.auraType)
    local icon = row.icons[i]
    if texture then
      icon.unit = row.unit
      icon.auraIndex = i
      icon.auraType = row.auraType
      icon.texture:SetTexture(texture)

      local auraKey = texture .. ":" .. (auraName or "")
      if expiration and expiration > GetTime() then
        icon.expiration = expiration
        icon.duration = duration
      elseif auraKey ~= icon.auraKey and duration and duration > 0 then
        icon.duration = duration
        icon.expiration = GetTime() + duration
      end
      icon.auraKey = auraKey

      applications = tonumber(applications) or 0
      icon.count:SetText(applications > 1 and applications or "")
      if row.auraType == "DEBUFF" then
        icon:SetBackdropBorderColor(.85, .16, .16, 1)
      else
        icon:SetBackdropBorderColor(.16, .62, .82, 1)
      end
      icon:Show()
      hasAura = true
    else
      icon:Hide()
      icon.auraKey = nil
      icon.duration = nil
      icon.expiration = nil
      icon.timer:SetText("")
    end
  end

  UpdateAuraTimers(row)
  if hasAura then row:Show() else row:Hide() end
end
