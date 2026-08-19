local auraScanner
local scanCache = {}

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
  ["erneuerung"] = 15,
  ["machtwort: schild"] = 30,
  ["geschwächte seele"] = 15,
  ["geschwachte seele"] = 15,
  ["machtwort: seelenstärke"] = 1800,
  ["machtwort: seelenstarke"] = 1800,
  ["gebet der seelenstärke"] = 3600,
  ["gebet der seelenstarke"] = 3600,
  ["göttlicher geist"] = 1800,
  ["gottlicher geist"] = 1800,
  ["gebet der geistigen stärke"] = 3600,
  ["schattenschutz"] = 600,
  ["gebet des schattenschutzes"] = 1200,
  ["furchtzauberschutz"] = 600,
  ["schattenwort: schmerz"] = 18,
  ["verschlingende seuche"] = 24,
  ["heiliges feuer"] = 10,
  ["vampirumarmung"] = 60,
  ["gedankenbenebelung"] = 3,
  ["psychischer schrei"] = 8,
  ["stille"] = 5,
  ["untote fesseln"] = 50,

  ["rejuvenation"] = 12,
  ["regrowth"] = 21,
  ["verjüngung"] = 12,
  ["verjungung"] = 12,
  ["nachwachsen"] = 21,
  ["moonfire"] = 12,
  ["mondfeuer"] = 12,
  ["insect swarm"] = 12,
  ["insektenschwarm"] = 12,
  ["entangling roots"] = 27,
  ["wucherwurzeln"] = 27,
  ["thorns"] = 600,
  ["dornen"] = 600,
  ["mark of the wild"] = 1800,
  ["gift of the wild"] = 3600,
  ["mal der wildnis"] = 1800,
  ["gabe der wildnis"] = 3600,

  ["flame shock"] = 12,
  ["flammenschock"] = 12,
  ["frost shock"] = 8,
  ["frostschock"] = 8,
  ["earthbind"] = 5,

  ["arcane intellect"] = 1800,
  ["arcane brilliance"] = 3600,
  ["arkane intelligenz"] = 1800,
  ["arkane brillanz"] = 3600,
  ["frost armor"] = 1800,
  ["ice armor"] = 1800,
  ["mage armor"] = 1800,
  ["frostrüstung"] = 1800,
  ["eisrüstung"] = 1800,
  ["magische rüstung"] = 1800,

  ["power word: shield"] = 30,
  ["mend pet"] = 15,
  ["tier heilen"] = 15,
  ["corruption"] = 18,
  ["verderbnis"] = 18,
  ["immolate"] = 15,
  ["immolation"] = 15,
  ["feierbrand"] = 15,
  ["curse of agony"] = 24,
  ["fluch der pein"] = 24,
  ["siphon life"] = 30,
  ["lebensentzug"] = 30,

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

local function ParseAnyTime(text)
  if not text then return nil end
  local lower = string.lower(text)
  local _, _, value = string.find(lower, "(%d+%.?%d*)%s*stunde")
  if not value then _, _, value = string.find(lower, "(%d+%.?%d*)%s*hour") end
  if value then return tonumber(value) * 3600 end
  _, _, value = string.find(lower, "(%d+%.?%d*)%s*min")
  if value then return tonumber(value) * 60 end
  _, _, value = string.find(lower, "(%d+%.?%d*)%s*sek")
  if not value then _, _, value = string.find(lower, "(%d+%.?%d*)%s*sec") end
  if value then return tonumber(value) end
  return nil
end

local function ParseTimeLine(text, requireRemaining)
  if not text then return nil end
  local lower = string.lower(text)
  local isRemaining = string.find(lower, "remaining", 1, true)
    or string.find(lower, "verbleib", 1, true)
    or string.find(lower, "bleibt", 1, true)
  if requireRemaining and not isRemaining then return nil end
  if not requireRemaining then
    if isRemaining then return nil end
    if not (string.find(lower, " for ", 1, true) or string.find(lower, " over ", 1, true)
        or string.find(lower, "lasts", 1, true) or string.find(lower, "hält", 1, true)
        or string.find(lower, "halt", 1, true) or string.find(lower, "dauer", 1, true)
        or string.find(lower, "sek", 1, true) or string.find(lower, "min", 1, true)) then
      return nil
    end
  end
  return ParseAnyTime(text)
end

local function ScanAuraTooltip(unit, index, auraType)
  if not auraScanner then
    auraScanner = CreateFrame("GameTooltip", "QtUIAuraScanTooltip", UIParent, "GameTooltipTemplate")
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

  local nameLine = getglobal("QtUIAuraScanTooltipTextLeft1")
  local auraName = nameLine and nameLine:GetText()
  local duration
  local remaining
  local lines = auraScanner.NumLines and auraScanner:NumLines() or 8
  local line
  for line = 2, lines do
    local fontString = getglobal("QtUIAuraScanTooltipTextLeft" .. line)
    local text = fontString and fontString:GetText()
    if text then
      remaining = remaining or ParseTimeLine(text, true)
      duration = duration or ParseTimeLine(text, false)
    end
  end
  auraScanner:Hide()
  return auraName, duration, remaining
end

-- Emberveil sometimes hands durations in milliseconds. Session GetTime()
-- is seconds; anything beyond a day is not a real aura length.
local function AsSeconds(value)
  value = tonumber(value)
  if not value or value <= 0 then return nil end
  if value > 86400 then return value / 1000 end
  return value
end

local function AsExpiration(value)
  value = AsSeconds(value)
  if not value then return nil end
  local now = GetTime()
  if value > now then return value end
  if value < 86400 then return now + value end
  return nil
end

local function UnitIsPlayerUnit(unit)
  if unit == "player" then return true end
  if type(UnitIsUnit) == "function" then
    local ok, same = pcall(UnitIsUnit, unit, "player")
    if ok and (same == true or same == 1 or same == "1") then return true end
  end
  return nil
end

local function GetPlayerAura(index, auraType)
  if type(GetPlayerBuff) ~= "function" then return nil end
  local filter = "HELPFUL"
  if auraType == "DEBUFF" then filter = "HARMFUL" end
  local ok, buffIndex = pcall(GetPlayerBuff, index - 1, filter)
  if not ok then ok, buffIndex = pcall(GetPlayerBuff, index, filter) end
  if not ok then return nil end
  buffIndex = tonumber(buffIndex)
  if not buffIndex or buffIndex == 0 or buffIndex == -1 then return nil end

  local texture
  if type(GetPlayerBuffTexture) == "function" then
    local texOk, tex = pcall(GetPlayerBuffTexture, buffIndex)
    if texOk then texture = tex end
  end
  if not texture then return nil end

  local applications = 0
  if type(GetPlayerBuffApplications) == "function" then
    local countOk, count = pcall(GetPlayerBuffApplications, buffIndex)
    if countOk then applications = tonumber(count) or 0 end
  end

  local timeLeft
  if type(GetPlayerBuffTimeLeft) == "function" then
    local timeOk, remaining = pcall(GetPlayerBuffTimeLeft, buffIndex)
    if timeOk then timeLeft = AsSeconds(remaining) end
  end

  local auraName
  -- Name is only needed as a fallback for known durations. GetPlayerBuffTimeLeft
  -- already supplies the countdown, so skip the tooltip scan in that case.
  if (not timeLeft or timeLeft <= 0) and GameTooltip and GameTooltip.SetPlayerBuff then
    if not auraScanner then
      auraScanner = CreateFrame("GameTooltip", "QtUIAuraScanTooltip", UIParent, "GameTooltipTemplate")
      auraScanner:SetOwner(UIParent, "ANCHOR_NONE")
    end
    auraScanner:ClearLines()
    pcall(auraScanner.SetPlayerBuff, auraScanner, buffIndex)
    local nameLine = getglobal("QtUIAuraScanTooltipTextLeft1")
    auraName = nameLine and nameLine:GetText()
    auraScanner:Hide()
  end

  local duration = GetKnownDuration(auraName, texture)
  local expiration
  if timeLeft and timeLeft > 0 then
    expiration = GetTime() + timeLeft
    if not duration or duration < timeLeft then duration = timeLeft end
  end
  return texture, applications, nil, duration, expiration, auraName
end

local function GetAura(unit, index, auraType)
  if UnitIsPlayerUnit(unit) then
    local texture, applications, auraKind, duration, expiration, auraName =
      GetPlayerAura(index, auraType)
    if texture then
      return texture, applications, auraKind, duration, expiration, auraName
    end
  end

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
    duration = AsSeconds(sixth)
    expiration = AsExpiration(seventh)
  else
    texture = first
    applications = second
    auraKind = third
    duration = AsSeconds(fourth)
    expiration = AsExpiration(fifth)
  end

  if not duration or duration <= 0 then
    local key = (unit or "") .. ":" .. (auraType or "") .. ":" .. tostring(index) .. ":" .. (texture or "")
    local now = GetTime()
    local cached = scanCache[key]
    if cached and (now - cached.time) < 5 then
      auraName = auraName or cached.name
      duration = duration or cached.duration
      if cached.expiration and cached.expiration > now then
        expiration = cached.expiration
      end
    else
      local scannedName, scannedDuration, scannedRemaining = ScanAuraTooltip(unit, index, auraType)
      auraName = auraName or scannedName
      duration = duration or scannedDuration or GetKnownDuration(auraName, texture)
      if scannedRemaining then expiration = now + scannedRemaining end
      scanCache[key] = {
        name = scannedName,
        duration = duration,
        expiration = expiration,
        time = now,
      }
    end
  end
  duration = duration or GetKnownDuration(auraName, texture)
  return texture, applications, auraKind, duration, expiration, auraName
end

local function FormatAuraTime(seconds)
  if seconds >= 3600 then return math.floor(seconds / 3600) .. "h" end
  if seconds >= 60 then return math.floor(seconds / 60) .. "m" end
  return math.ceil(seconds) .. "s"
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

  icon.timer = icon:CreateFontString(nil, "OVERLAY")
  icon.timer:SetPoint("BOTTOM", icon, "BOTTOM", 0, 1)
  icon.timer:SetTextColor(1, 1, 1)
  if icon.timer.SetJustifyH then icon.timer:SetJustifyH("CENTER") end
  local timerSize = math.floor(size * 0.48)
  if timerSize < 9 then timerSize = 9 end
  if timerSize > 13 then timerSize = 13 end
  if QtUI.ApplyFont then
    QtUI:ApplyFont(icon.timer, timerSize)
  else
    local font = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    if icon.timer.SetFont then icon.timer:SetFont(font, timerSize, "OUTLINE") end
  end

  icon:SetScript("OnEnter", ShowAuraTooltip)
  icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
  icon:Hide()
  return icon
end

function QtUI:CreateAuraRow(parent, unit, auraType, maximum, size)
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
  return row
end

local function AuraTimerOnUpdate()
  this.elapsed = (this.elapsed or 0) + arg1
  if this.elapsed >= .25 then
    this.elapsed = 0
    UpdateAuraTimers(this)
  end
end

function QtUI:UpdateAuraRow(row)
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
  local hasTimers
  local n
  for n = 1, table.getn(row.icons) do
    if row.icons[n]:IsShown() and row.icons[n].expiration then
      hasTimers = true
      break
    end
  end
  if hasTimers then
    if not row.timerOn then
      row.timerOn = true
      row.elapsed = 0
      row:SetScript("OnUpdate", AuraTimerOnUpdate)
    end
  elseif row.timerOn then
    row.timerOn = nil
    row:SetScript("OnUpdate", nil)
  end
  if hasAura or QtUI.moveMode then
    if row.Show then pcall(row.Show, row) end
  else
    if row.Hide then pcall(row.Hide, row) end
  end
end
