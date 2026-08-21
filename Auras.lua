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
  ["siegel der rechtschaffenheit"] = 30,
  ["siegel des befehls"] = 30,
  ["siegel des kreuzfahrers"] = 30,
  ["siegel der gerechtigkeit"] = 30,
  ["siegel des lichts"] = 30,
  ["siegel der weisheit"] = 30,

  ["rend"] = 21,
  ["sunder armor"] = 30,
  ["hamstring"] = 15,
  ["thunder clap"] = 30,
  ["demoralizing shout"] = 30,
  ["disarm"] = 10,
  ["piercing howl"] = 6,
  ["taunt"] = 3,
  ["zerfetzen"] = 21,
  ["rüstungszerreißen"] = 30,
  ["sunderschlitzen"] = 30,
  ["donnerschlag"] = 30,
  ["demoralisierungsruf"] = 30,
  ["entwaffnen"] = 10,
  ["verkrüppeln"] = 15,

  ["sap"] = 45,
  ["cheap shot"] = 4,
  ["kidney shot"] = 6,
  ["garrote"] = 18,
  ["rupture"] = 16,
  ["expose armor"] = 30,
  ["blind"] = 10,
  ["gouge"] = 4,
  ["hemorrhage"] = 15,
  ["kopfnuss"] = 45,
  ["fieser trick"] = 4,
  ["nierenhieb"] = 6,
  ["erdrosseln"] = 18,
  ["blutung"] = 16,
  ["rüstung schwächen"] = 30,
  ["blenden"] = 10,
  ["solarplexus"] = 4,

  ["hunter's mark"] = 120,
  ["mark of the hunter"] = 120,
  ["mal des jagers"] = 120,
  ["mal des jägers"] = 120,
  ["serpent sting"] = 15,
  ["schlangenbiss"] = 15,
  ["concussive shot"] = 4,
  ["erschütternder schuss"] = 4,
  ["wing clip"] = 10,
  ["zurechtstutzen"] = 10,
  ["scatter shot"] = 4,
  ["streuschuss"] = 4,
  ["wyvern sting"] = 12,
  ["wyvernstich"] = 12,

  ["polymorph"] = 50,
  ["verwandlung"] = 50,
  ["frost nova"] = 8,
  ["frostnova"] = 8,
  ["counterspell"] = 4,
  ["gegenschlag"] = 4,
  ["slow"] = 15,
  ["verlangsamen"] = 15,

  ["fear"] = 20,
  ["furcht"] = 20,
  ["curse of exhaustion"] = 12,
  ["curse of weakness"] = 120,
  ["curse of recklessness"] = 120,
  ["curse of shadow"] = 300,
  ["curse of the elements"] = 300,
  ["curse of tongues"] = 30,
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

local ownSpells = {}
local ownTextures = {}
local SPELL_ALIASES = {
  ["judgement of the crusader"] = "seal of the crusader",
  ["judgment of the crusader"] = "seal of the crusader",
  ["judgement of light"] = "seal of light",
  ["judgment of light"] = "seal of light",
  ["judgement of wisdom"] = "seal of wisdom",
  ["judgment of wisdom"] = "seal of wisdom",
  ["judgement of justice"] = "seal of justice",
  ["judgment of justice"] = "seal of justice",
  ["richturteil des kreuzfahrers"] = "siegel des kreuzfahrers",
  ["richturteil des lichts"] = "siegel des lichts",
  ["richturteil der weisheit"] = "siegel der weisheit",
  ["richturteil der gerechtigkeit"] = "siegel der gerechtigkeit",
}

local function ScanSpellbook()
  ownSpells = {}
  ownTextures = {}
  if type(GetNumSpellTabs) ~= "function" or type(GetSpellName) ~= "function" then return end
  local tabs = tonumber(GetNumSpellTabs()) or 0
  local t
  for t = 1, tabs do
    local name, tex, offset, num = GetSpellTabInfo(t)
    offset = tonumber(offset) or 0
    num = tonumber(num) or 0
    local s
    for s = 1, num do
      local spellName = GetSpellName(offset + s, "spell")
      if type(spellName) == "string" and spellName ~= "" then
        ownSpells[string.lower(spellName)] = true
      end
      if type(GetSpellTexture) == "function" then
        local ok, path = pcall(GetSpellTexture, offset + s, "spell")
        if ok and type(path) == "string" then
          ownTextures[string.lower(path)] = true
        end
      end
    end
  end
end

local function IsOwnAura(auraName, texture)
  if auraName and auraName ~= "" then
    local key = string.lower(auraName)
    if ownSpells[key] then return true end
    local alias = SPELL_ALIASES[key]
    if alias and ownSpells[alias] then return true end
  end
  if texture and ownTextures[string.lower(texture)] and auraName and KNOWN_DURATIONS[string.lower(auraName)] then
    return true
  end
  return nil
end

local function CopyNameList(source)
  local copy = {}
  if type(source) ~= "table" then return copy end
  local i
  for i = 1, table.getn(source) do
    table.insert(copy, source[i])
  end
  return copy
end

local function WatchPinKey(kind)
  if kind == "target" then return "targetDebuffWatchPins" end
  return "playerBuffWatchPins"
end

local function WatchPins(kind)
  if not QtUIDB or not QtUIDB.layout then return nil end
  local layout = QtUIDB.layout
  if type(layout.auraWatchPins) == "table" and table.getn(layout.auraWatchPins) > 0 then
    if type(layout.playerBuffWatchPins) ~= "table" or table.getn(layout.playerBuffWatchPins) == 0 then
      layout.playerBuffWatchPins = CopyNameList(layout.auraWatchPins)
    end
    if type(layout.targetDebuffWatchPins) ~= "table" or table.getn(layout.targetDebuffWatchPins) == 0 then
      layout.targetDebuffWatchPins = CopyNameList(layout.auraWatchPins)
    end
    layout.auraWatchPins = {}
  end
  local key = WatchPinKey(kind)
  if type(layout[key]) ~= "table" then layout[key] = {} end
  return layout[key]
end

local function SplitWatchNames(text)
  local list = {}
  text = string.gsub(tostring(text or ""), "[\r\n;]+", ",")
  local start = 1
  local len = string.len(text)
  while start <= len do
    local s, e = string.find(text, ",", start, true)
    local part
    if s then
      part = string.sub(text, start, s - 1)
      start = e + 1
    else
      part = string.sub(text, start)
      start = len + 1
    end
    part = string.gsub(part, "^%s+", "")
    part = string.gsub(part, "%s+$", "")
    if part ~= "" then table.insert(list, string.lower(part)) end
  end
  return list
end

local function WatchListAsText(kind)
  local pins = WatchPins(kind)
  if not pins or table.getn(pins) == 0 then return "" end
  return table.concat(pins, ", ")
end

local function SetWatchListFromText(text, kind)
  local pins = WatchPins(kind)
  if not pins then return end
  local i
  for i = table.getn(pins), 1, -1 do table.remove(pins, i) end
  local names = SplitWatchNames(text)
  local seen = {}
  for i = 1, table.getn(names) do
    local name = names[i]
    if not seen[name] then
      seen[name] = true
      table.insert(pins, name)
    end
  end
end

local function IsPinned(auraName, kind)
  if not auraName or auraName == "" then return nil end
  local pins = WatchPins(kind)
  if not pins then return nil end
  local key = string.lower(auraName)
  local i
  for i = 1, table.getn(pins) do
    local pin = pins[i]
    if pin == key then return true end
    if string.len(pin) >= 3 and string.find(key, pin, 1, true) then return true end
  end
  return nil
end

local function ToggleWatchPin(auraName, kind)
  if not auraName or auraName == "" then return end
  local pins = WatchPins(kind)
  if not pins then return end
  local key = string.lower(auraName)
  local i
  for i = 1, table.getn(pins) do
    if pins[i] == key then
      table.remove(pins, i)
      if QtUI.Print then QtUI:Print("Removed from tracker: " .. auraName) end
      return
    end
  end
  table.insert(pins, key)
  if QtUI.Print then QtUI:Print("Tracking " .. auraName) end
end

function QtUI:GetAuraWatchListText(kind)
  return WatchListAsText(kind)
end

function QtUI:SetAuraWatchListText(text, kind)
  SetWatchListFromText(text, kind)
  if self.RefreshAuraWatch then self:RefreshAuraWatch() end
end

local function TargetOwnDebuffsOn()
  if not QtUI.GetLayout then return true end
  local layout = QtUI:GetLayout()
  return not layout or layout.targetOwnDebuffs ~= false
end

local function AuraWatchOn()
  if QtUI.IsFeatureEnabled and not QtUI:IsFeatureEnabled("auras") then return nil end
  if not QtUI.GetLayout then return true end
  local layout = QtUI:GetLayout()
  return not layout or layout.auraWatch ~= false
end

local function PlayerBuffWatchOn()
  if not AuraWatchOn() then return nil end
  if not QtUI.GetLayout then return true end
  local layout = QtUI:GetLayout()
  return not layout or layout.playerBuffWatch ~= false
end

local function TargetDebuffWatchOn()
  if not AuraWatchOn() then return nil end
  if not QtUI.GetLayout then return true end
  local layout = QtUI:GetLayout()
  return not layout or layout.targetDebuffWatch ~= false
end

local function WatchThreshold()
  if not QtUI.GetLayout then return 120 end
  local layout = QtUI:GetLayout()
  local value = tonumber(layout and layout.auraWatchThreshold)
  if not value then return 120 end
  if value < 0 then return 0 end
  if value > 600 then return 600 end
  return value
end

local function WatchWidth(kind)
  if not QtUI.GetLayout then return 220 end
  local layout = QtUI:GetLayout()
  local value
  if kind == "target" then
    value = tonumber(layout and layout.targetDebuffWatchWidth)
  else
    value = tonumber(layout and layout.playerBuffWatchWidth)
  end
  if not value then value = tonumber(layout and layout.auraWatchWidth) or 220 end
  if value < 140 then return 140 end
  if value > 360 then return 360 end
  return value
end

local function WatchBarHeight(kind)
  if not QtUI.GetLayout then return 18 end
  local layout = QtUI:GetLayout()
  local value
  if kind == "target" then
    value = tonumber(layout and layout.targetDebuffWatchBarHeight)
  else
    value = tonumber(layout and layout.playerBuffWatchBarHeight)
  end
  if not value then value = tonumber(layout and layout.auraWatchBarHeight) or 18 end
  if value < 14 then return 14 end
  if value > 28 then return 28 end
  return value
end

local function WatchListOn(kind)
  if not QtUI.GetLayout then return true end
  local layout = QtUI:GetLayout()
  if not layout then return true end
  if kind == "target" then
    return layout.targetDebuffWatchWhitelist ~= false
  end
  return layout.playerBuffWatchWhitelist ~= false
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
  local cacheKey = tostring(buffIndex) .. ":" .. string.lower(texture)
  local cached = scanCache[cacheKey]
  local now = GetTime()
  if cached and cached.name and (now - cached.time) < 8 then
    auraName = cached.name
  elseif GameTooltip and GameTooltip.SetPlayerBuff then
    if not auraScanner then
      auraScanner = CreateFrame("GameTooltip", "QtUIAuraScanTooltip", UIParent, "GameTooltipTemplate")
      auraScanner:SetOwner(UIParent, "ANCHOR_NONE")
    end
    auraScanner:ClearLines()
    pcall(auraScanner.SetPlayerBuff, auraScanner, buffIndex)
    local nameLine = getglobal("QtUIAuraScanTooltipTextLeft1")
    auraName = nameLine and nameLine:GetText()
    auraScanner:Hide()
    scanCache[cacheKey] = { name = auraName, time = now }
  end

  local duration = GetKnownDuration(auraName, texture)
  local expiration
  if timeLeft and timeLeft > 0 then
    expiration = GetTime() + timeLeft
  end
  return texture, applications, nil, duration, expiration, auraName, buffIndex
end

local function GetAura(unit, index, auraType)
  if UnitIsPlayerUnit(unit) then
    local texture, applications, auraKind, duration, expiration, auraName, buffIndex =
      GetPlayerAura(index, auraType)
    if texture then
      return texture, applications, auraKind, duration, expiration, auraName, buffIndex
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

  if not duration or duration <= 0 or not auraName then
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
  icon.well = icon:CreateTexture(nil, "BACKGROUND")
  icon.well:SetAllPoints(icon)
  icon.well:SetTexture("Interface\\Buttons\\WHITE8X8")
  icon.well:SetVertexColor(.015, .02, .025, 1)
  icon.ring = icon:CreateTexture(nil, "BORDER")
  icon.ring:SetAllPoints(icon)
  icon.ring:SetTexture("Interface\\Buttons\\WHITE8X8")
  icon.ring:SetVertexColor(.16, .62, .82, 1)

  icon.texture = icon:CreateTexture(nil, "ARTWORK")
  icon.texture:SetPoint("TOPLEFT", icon, "TOPLEFT", 1, -1)
  icon.texture:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 1)

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
  icon:EnableMouse(true)
  if icon.RegisterForClicks then icon:RegisterForClicks("LeftButtonUp") end
  icon:SetScript("OnMouseUp", function()
    if arg1 ~= "LeftButton" and arg1 ~= nil then return end
    if type(IsShiftKeyDown) == "function" then
      local ok, held = pcall(IsShiftKeyDown)
      if ok and (held == true or held == 1) and this.auraName then
        local kind = "player"
        if this.unit == "target" then kind = "target" end
        ToggleWatchPin(this.auraName, kind)
        if QtUI.RefreshAuraWatch then QtUI:RefreshAuraWatch() end
      end
    end
  end)
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

  local ownOnly = row.ownOnly
  if row.unit == "target" and row.auraType == "DEBUFF" and TargetOwnDebuffsOn() then
    ownOnly = true
  end

  local hasAura
  local shown = 0
  local maxIcons = table.getn(row.icons)
  local scanMax = 16
  if row.auraType == "BUFF" then scanMax = 32 end
  local i
  for i = 1, scanMax do
    if shown >= maxIcons then break end
    local texture, applications, auraKind, duration, expiration, auraName =
      GetAura(row.unit, i, row.auraType)
    if not texture then break end
    if ownOnly and not IsOwnAura(auraName, texture) and not IsPinned(auraName, "target") then
      texture = nil
    end
    if texture then
      shown = shown + 1
      local icon = row.icons[shown]
      icon.unit = row.unit
      icon.auraIndex = i
      icon.auraType = row.auraType
      icon.auraName = auraName
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
      if icon.ring then
        if row.auraType == "DEBUFF" then
          icon.ring:SetVertexColor(.85, .16, .16, 1)
        else
          icon.ring:SetVertexColor(.16, .62, .82, 1)
        end
      end
      icon:Show()
      hasAura = true
    end
  end
  for i = shown + 1, maxIcons do
    local icon = row.icons[i]
    icon:Hide()
    icon.auraKey = nil
    icon.auraName = nil
    icon.duration = nil
    icon.expiration = nil
    icon.timer:SetText("")
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

local WATCH_MAX = 12
local watchFrames = {}

local function PlaceWatchBox(widget, parent, left, bottom, width, height)
  if not widget or not parent then return end
  widget:ClearAllPoints()
  widget:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", left, bottom)
  widget:SetPoint("TOPRIGHT", parent, "BOTTOMLEFT", left + width, bottom + height)
  if widget.SetWidth then widget:SetWidth(width) end
  if widget.SetHeight then widget:SetHeight(height) end
end

local function FormatWatchTime(seconds)
  if seconds >= 3600 then return string.format("%dh", math.floor(seconds / 3600)) end
  if seconds >= 60 then
    local minutes = math.floor(seconds / 60)
    local rest = math.floor(math.mod(seconds, 60))
    if rest > 0 and minutes < 10 then return minutes .. ":" .. string.format("%02d", rest) end
    return minutes .. "m"
  end
  if seconds >= 10 then return string.format("%d", math.ceil(seconds)) end
  return string.format("%.1f", seconds)
end

local function ShowWatchTooltip()
  GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
  if this.buffIndex and GameTooltip.SetPlayerBuff then
    pcall(GameTooltip.SetPlayerBuff, GameTooltip, this.buffIndex)
  elseif this.auraType == "DEBUFF" and this.unit and this.auraIndex and GameTooltip.SetUnitDebuff then
    GameTooltip:SetUnitDebuff(this.unit, this.auraIndex)
  elseif this.auraType == "BUFF" and this.unit and this.auraIndex and GameTooltip.SetUnitBuff then
    GameTooltip:SetUnitBuff(this.unit, this.auraIndex)
  end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("Shift-Click: add / remove from whitelist", .55, .85, .95)
  if this.buffIndex then
    GameTooltip:AddLine("Right-Click: cancel buff", .55, .85, .95)
  end
  GameTooltip:Show()
end

local function WatchBarOnMouseUp()
  if arg1 == "RightButton" and this.buffIndex and type(CancelPlayerBuff) == "function" then
    pcall(CancelPlayerBuff, this.buffIndex)
    if QtUI.RefreshAuraWatch then QtUI:RefreshAuraWatch() end
    return
  end
  if arg1 ~= "LeftButton" and arg1 ~= nil then return end
  if type(IsShiftKeyDown) ~= "function" then return end
  local ok, held = pcall(IsShiftKeyDown)
  if ok and (held == true or held == 1) and this.auraName then
    local kind = "player"
    local parent = this:GetParent()
    if parent and parent.kind then kind = parent.kind end
    ToggleWatchPin(this.auraName, kind)
    if QtUI.RefreshAuraWatch then QtUI:RefreshAuraWatch() end
  end
end

local function CreateWatchBar(parent, index)
  local frame = CreateFrame("Button", nil, parent)
  frame:EnableMouse(true)
  if frame.RegisterForClicks then frame:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
  frame:SetScript("OnEnter", ShowWatchTooltip)
  frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
  frame:SetScript("OnMouseUp", WatchBarOnMouseUp)

  frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 8,
    edgeSize = 8,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  frame:SetBackdropColor(.02, .025, .03, .92)
  frame:SetBackdropBorderColor(.18, .24, .28, 1)

  frame.icon = frame:CreateTexture(nil, "ARTWORK")
  frame.stacks = frame:CreateFontString(nil, "OVERLAY")
  if frame.stacks.SetJustifyH then frame.stacks:SetJustifyH("CENTER") end
  if QtUI.ApplyFont then QtUI:ApplyFont(frame.stacks, 10) end
  frame.stacks:SetTextColor(1, 1, 1)

  frame.bar = CreateFrame("StatusBar", nil, frame)
  frame.bar:SetStatusBarTexture(QtUI.media and QtUI.media.statusbar or "Interface\\TargetingFrame\\UI-StatusBar")
  frame.bar:SetMinMaxValues(0, 1)
  frame.bar:SetValue(0)
  frame.bar.bg = frame.bar:CreateTexture(nil, "BACKGROUND")
  frame.bar.bg:SetAllPoints(frame.bar)
  frame.bar.bg:SetTexture(QtUI.media and QtUI.media.statusbar or "Interface\\TargetingFrame\\UI-StatusBar")
  frame.bar.bg:SetVertexColor(.04, .05, .06, .95)

  frame.nameText = frame.bar:CreateFontString(nil, "OVERLAY")
  if frame.nameText.SetJustifyH then frame.nameText:SetJustifyH("RIGHT") end
  if QtUI.ApplyFont then QtUI:ApplyFont(frame.nameText, 11) end
  frame.nameText:SetTextColor(1, 1, 1)

  frame.timeText = frame.bar:CreateFontString(nil, "OVERLAY")
  if frame.timeText.SetJustifyH then frame.timeText:SetJustifyH("LEFT") end
  if QtUI.ApplyFont then QtUI:ApplyFont(frame.timeText, 11) end
  frame.timeText:SetTextColor(1, 1, 1)

  frame.index = index
  frame:Hide()
  return frame
end

local function LayoutWatchBar(bar, width, height)
  local iconW = height - 2
  PlaceWatchBox(bar, bar:GetParent(), 0, (bar.index - 1) * (height + 1), width, height)
  PlaceWatchBox(bar.icon, bar, 1, 1, iconW, height - 2)
  PlaceWatchBox(bar.stacks, bar, 1, 1, iconW, height - 2)
  local barLeft = iconW + 2
  local barW = width - barLeft - 2
  if barW < 40 then barW = 40 end
  PlaceWatchBox(bar.bar, bar, barLeft, 1, barW, height - 2)
  local timeW = 42
  PlaceWatchBox(bar.timeText, bar.bar, 4, 1, timeW, height - 4)
  PlaceWatchBox(bar.nameText, bar.bar, timeW + 6, 1, barW - timeW - 10, height - 4)
  if bar.timeText.SetJustifyH then bar.timeText:SetJustifyH("LEFT") end
  if bar.nameText.SetJustifyH then bar.nameText:SetJustifyH("RIGHT") end
  if bar.nameText.SetNonSpaceWrap then bar.nameText:SetNonSpaceWrap(nil) end
end

local function RememberWatchAura(store, key, remaining, duration, now)
  local rec = store[key]
  if remaining and remaining > 0 then
    if rec then
      if remaining > (rec.remaining or 0) + 1 then
        local newMax = duration or remaining
        if remaining > newMax then newMax = remaining end
        if rec.max and rec.max > newMax then newMax = rec.max end
        rec.max = newMax
      end
    else
      rec = {}
      rec.max = duration or remaining
      if remaining and remaining > rec.max then rec.max = remaining end
    end
    rec.remaining = remaining
    rec.expiration = now + remaining
    rec.seen = now
    store[key] = rec
    return rec
  end
  if rec and rec.expiration and rec.expiration > now then
    rec.remaining = rec.expiration - now
    rec.seen = now
    return rec
  end
  if duration and duration > 0 then
    rec = rec or {}
    rec.max = duration
    rec.remaining = duration
    rec.expiration = now + duration
    rec.seen = now
    store[key] = rec
    return rec
  end
  return nil
end

local function CollectWatchAuras(frame, unit, auraType, ownOnly, threshold)
  local list = {}
  if not frame.track then frame.track = {} end
  local store = frame.track
  local now = GetTime()
  local seen = {}
  local kind = frame.kind or "player"
  local whitelist = WatchListOn(kind)
  local scanMax = 32
  if auraType == "DEBUFF" then scanMax = 16 end
  local i
  for i = 1, scanMax do
    local texture, applications, _, duration, expiration, auraName, buffIndex =
      GetAura(unit, i, auraType)
    if not texture then break end
    local remaining = 0
    if expiration and expiration > now then remaining = expiration - now end
    local pinned = IsPinned(auraName, kind)
    local own = IsOwnAura(auraName, texture)
    local pass
    if whitelist then
      pass = pinned
    else
      if ownOnly and not own and not pinned then
        texture = nil
      end
      pass = texture and (pinned or threshold <= 0 or remaining <= threshold)
    end
    if texture and pass then
      local key = string.lower(auraName or "")
      if key == "" then key = string.lower(texture or "") .. ":" .. tostring(i) end
      local rec = RememberWatchAura(store, key, remaining, duration, now)
      if rec and rec.remaining and rec.remaining > 0 then
        seen[key] = true
        table.insert(list, {
          texture = texture,
          applications = tonumber(applications) or 0,
          duration = rec.max or duration or rec.remaining,
          expiration = rec.expiration,
          remaining = rec.remaining,
          name = auraName or "",
          auraIndex = i,
          buffIndex = buffIndex,
          pinned = pinned,
          key = key,
        })
      end
    end
  end
  local key, rec
  for key, rec in pairs(store) do
    if not seen[key] and (now - (rec.seen or 0)) > 1.5 then
      store[key] = nil
    end
  end
  table.sort(list, function(a, b)
    return (a.remaining or 0) < (b.remaining or 0)
  end)
  return list
end

local function PaintWatchTime(bar, remaining)
  bar.timeText:SetText(FormatWatchTime(remaining))
  if remaining <= 5 then
    bar.timeText:SetTextColor(1, .22, .16)
  elseif remaining <= 10 then
    bar.timeText:SetTextColor(1, .82, .12)
  else
    bar.timeText:SetTextColor(1, 1, 1)
  end
end

local function PaintWatchBar(bar, entry, auraType)
  bar.unit = bar:GetParent().unit
  bar.auraType = auraType
  bar.auraIndex = entry.auraIndex
  bar.buffIndex = entry.buffIndex
  bar.auraName = entry.name
  bar.expiration = entry.expiration
  bar.maxDuration = entry.duration
  if not bar.maxDuration or bar.maxDuration < 0.1 then bar.maxDuration = 0.1 end
  bar.icon:SetTexture(entry.texture)
  bar.nameText:SetText(entry.name or "")
  bar.stacks:SetText(entry.applications > 1 and entry.applications or "")
  bar.bar:SetMinMaxValues(0, bar.maxDuration)
  bar.bar:SetValue(entry.remaining)
  if auraType == "DEBUFF" then
    bar.bar:SetStatusBarColor(.82, .18, .16, .95)
    bar:SetBackdropBorderColor(.7, .18, .16, 1)
  else
    bar.bar:SetStatusBarColor(.16, .62, .82, .95)
    bar:SetBackdropBorderColor(.18, .5, .68, 1)
  end
  PaintWatchTime(bar, entry.remaining)
  bar:Show()
end

local function UpdateWatchTimers(frame)
  local now = GetTime()
  local i
  for i = 1, table.getn(frame.bars) do
    local bar = frame.bars[i]
    if bar:IsShown() and bar.expiration then
      local remaining = bar.expiration - now
      if remaining < 0 then remaining = 0 end
      local maxDuration = bar.maxDuration
      if not maxDuration or maxDuration < 0.1 then maxDuration = 0.1 end
      bar.bar:SetMinMaxValues(0, maxDuration)
      bar.bar:SetValue(remaining)
      PaintWatchTime(bar, remaining)
    end
  end
end

local function PlaceWatchFrame(frame, width, height)
  if not frame then return end
  local key = "playerBuffWatch"
  if frame.kind == "target" then key = "targetDebuffWatch" end
  local left, bottom
  local saved = QtUIDB and QtUIDB.positions and QtUIDB.positions[key]
  if saved and saved.x and saved.y then
    left = saved.x
    bottom = saved.y
  elseif frame.GetLeft and frame.GetBottom then
    left = frame:GetLeft()
    bottom = frame:GetBottom()
  end
  if not left or not bottom then
    if frame.SetWidth then frame:SetWidth(width) end
    if frame.SetHeight then frame:SetHeight(height) end
    return
  end
  frame:ClearAllPoints()
  frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
  frame:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", left + width, bottom + height)
  if frame.SetWidth then frame:SetWidth(width) end
  if frame.SetHeight then frame:SetHeight(height) end
end

local function SizeWatchFrame(frame, shown)
  local kind = frame.kind or "player"
  local width = WatchWidth(kind)
  local barH = WatchBarHeight(kind)
  local count = shown
  if count < 1 then count = 1 end
  local height = count * (barH + 1) - 1
  if frame.qtWatchW ~= width or frame.qtWatchH ~= height then
    PlaceWatchFrame(frame, width, height)
    frame.qtWatchW = width
    frame.qtWatchH = height
  end
  local i
  for i = 1, table.getn(frame.bars) do
    LayoutWatchBar(frame.bars[i], width, barH)
  end
  if frame.placeholder then
    PlaceWatchBox(frame.placeholder, frame, 6, 2, width - 12, height - 4)
  end
end

local function RefreshWatchFrame(frame)
  if not frame then return end
  local enabled
  if frame.kind == "player" then
    enabled = PlayerBuffWatchOn()
  else
    enabled = TargetDebuffWatchOn()
  end
  if not enabled then
    if frame.Hide then pcall(frame.Hide, frame) end
    return
  end

  if frame.unit == "target" and not UnitName("target") then
    local i
    for i = 1, table.getn(frame.bars) do frame.bars[i]:Hide() end
    if frame.placeholder then frame.placeholder:Show() end
    if QtUI.moveMode then
      SizeWatchFrame(frame, 1)
      if frame.Show then pcall(frame.Show, frame) end
    elseif frame.Hide then
      pcall(frame.Hide, frame)
    end
    return
  end

  local ownOnly = frame.kind == "target"
  local threshold = WatchThreshold()
  if frame.kind == "target" then threshold = 0 end
  local list = CollectWatchAuras(frame, frame.unit, frame.auraType, ownOnly, threshold)
  local shown = 0
  local maxBars = table.getn(frame.bars)
  local i
  for i = 1, table.getn(list) do
    if shown >= maxBars then break end
    shown = shown + 1
    PaintWatchBar(frame.bars[shown], list[i], frame.auraType)
  end
  for i = shown + 1, maxBars do
    frame.bars[i]:Hide()
    frame.bars[i].expiration = nil
    frame.bars[i].auraName = nil
  end

  if frame.placeholder then
    if shown == 0 then frame.placeholder:Show() else frame.placeholder:Hide() end
  end
  if shown > 0 or QtUI.moveMode then
    SizeWatchFrame(frame, shown)
    if frame.Show then pcall(frame.Show, frame) end
  elseif frame.Hide then
    pcall(frame.Hide, frame)
  end
end

local function WatchOnUpdate()
  this.elapsed = (this.elapsed or 0) + (arg1 or 0)
  if this.elapsed < .2 then return end
  this.elapsed = 0
  this.ticks = (this.ticks or 0) + 1
  UpdateWatchTimers(this)
  if this.ticks >= 2 then
    this.ticks = 0
    RefreshWatchFrame(this)
  end
end

local function CreateWatchFrame(name, unit, auraType, kind)
  local frame = CreateFrame("Frame", name, UIParent)
  frame:SetFrameStrata("MEDIUM")
  frame:SetFrameLevel(20)
  frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 8,
    edgeSize = 8,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  frame:SetBackdropColor(.015, .02, .025, .4)
  if kind == "target" then
    frame:SetBackdropBorderColor(.7, .18, .16, .7)
  else
    frame:SetBackdropBorderColor(.16, .62, .82, .7)
  end
  frame.unit = unit
  frame.auraType = auraType
  frame.kind = kind
  frame.bars = {}
  frame.placeholder = frame:CreateFontString(nil, "OVERLAY")
  if QtUI.ApplyFont then QtUI:ApplyFont(frame.placeholder, 11) end
  frame.placeholder:SetTextColor(.55, .7, .78)
  if frame.placeholder.SetJustifyH then frame.placeholder:SetJustifyH("LEFT") end
  if kind == "target" then
    frame.placeholder:SetText("Shift-click a debuff or add names in Settings")
  else
    frame.placeholder:SetText("Shift-click a buff or add names in Settings")
  end
  local i
  for i = 1, WATCH_MAX do
    frame.bars[i] = CreateWatchBar(frame, i)
  end
  SizeWatchFrame(frame, 1)
  frame:SetScript("OnUpdate", WatchOnUpdate)
  frame:Hide()
  return frame
end

function QtUI:RefreshAuraWatch()
  RefreshWatchFrame(self.playerBuffWatch)
  RefreshWatchFrame(self.targetDebuffWatch)
end

function QtUI:LayoutAuraWatch()
  self:RefreshAuraWatch()
end

function QtUI:SetupAuraWatch()
  if self.auraWatchReady then
    self:LayoutAuraWatch()
    return
  end
  if QtUI.IsFeatureEnabled and not QtUI:IsFeatureEnabled("auras") then return end
  self.auraWatchReady = true
  ScanSpellbook()

  local player = CreateWatchFrame("QtUIPlayerBuffWatch", "player", "BUFF", "player")
  player:ClearAllPoints()
  player:SetPoint("BOTTOMLEFT", UIParent, "CENTER", -400, 40)
  self.playerBuffWatch = player

  local target = CreateWatchFrame("QtUITargetDebuffWatch", "target", "DEBUFF", "target")
  target:ClearAllPoints()
  target:SetPoint("BOTTOMLEFT", UIParent, "CENTER", 180, 40)
  self.targetDebuffWatch = target

  watchFrames[1] = player
  watchFrames[2] = target

  if self.RegisterMovable then
    self:RegisterMovable("playerBuffWatch", "Personal Buff Tracker", player, true)
    self:RegisterMovable("targetDebuffWatch", "Target Debuff Tracker", target, true)
  end

  local events = CreateFrame("Frame", "QtUIAuraWatchEvents")
  events:RegisterEvent("PLAYER_ENTERING_WORLD")
  events:RegisterEvent("PLAYER_AURAS_CHANGED")
  events:RegisterEvent("PLAYER_TARGET_CHANGED")
  events:RegisterEvent("UNIT_AURA")
  pcall(events.RegisterEvent, events, "SPELLS_CHANGED")
  events:SetScript("OnEvent", function()
    if event == "SPELLS_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
      ScanSpellbook()
    end
    if event == "UNIT_AURA" and arg1 and arg1 ~= "player" and arg1 ~= "target" then return end
    QtUI:RefreshAuraWatch()
  end)
  self.auraWatchEvents = events
  self:RefreshAuraWatch()
end

