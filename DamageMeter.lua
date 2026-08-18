-- Minimal damage meter. Combat-log parse is ShaguDPS (locale-independent 1.12).

local MAX_BARS = 16
local MIN_BARS = 3
local TITLE_H = 20
local METER_PAD = 6

local CLASS_COLORS = {
  WARRIOR = { .78, .61, .43 }, MAGE = { .41, .80, .94 }, ROGUE = { 1, .96, .41 },
  DRUID = { 1, .49, .04 }, HUNTER = { .67, .83, .45 }, SHAMAN = { .14, .35, 1 },
  PRIEST = { 1, 1, 1 }, WARLOCK = { .58, .51, .79 }, PALADIN = { .96, .55, .73 },
}

local INTERNALS = {
  _sum = true, _ctime = true, _tick = true, _esum = true, _effective = true,
}

local data = {
  damage = { [0] = {}, [1] = {} },
  heal = { [0] = {}, [1] = {} },
  classes = {},
}

local startNextSegment
local parser = CreateFrame("Frame", "QtUIDamageParser")

local validUnits = { player = true }
local validPets = { pet = true }
do
  local i
  for i = 1, 4 do
    validUnits["party" .. i] = true
    validPets["partypet" .. i] = true
  end
  for i = 1, 40 do
    validUnits["raid" .. i] = true
    validPets["raidpet" .. i] = true
  end
end

local function Trim(str)
  return string.gsub(str, "^%s*(.-)%s*$", "%1")
end

local function Round(input, places)
  if type(input) ~= "number" then return 0 end
  places = places or 0
  local pow = 1
  local i
  for i = 1, places do pow = pow * 10 end
  return math.floor(input * pow + .5) / pow
end

local function AnyInCombat()
  if UnitAffectingCombat("player") or UnitAffectingCombat("pet") then return true end
  local raid = tonumber(GetNumRaidMembers()) or 0
  local group = tonumber(GetNumPartyMembers()) or 0
  local i
  if raid >= 1 then
    for i = 1, raid do
      if UnitAffectingCombat("raid" .. i) or UnitAffectingCombat("raidpet" .. i) then return true end
    end
  else
    for i = 1, group do
      if UnitAffectingCombat("party" .. i) or UnitAffectingCombat("partypet" .. i) then return true end
    end
  end
  return nil
end

local SELF_TOKENS = {
  you = true, your = true, yourself = true,
  ihr = true, euer = true, eure = true, euch = true,
}

local function StripMarkup(str)
  if type(str) ~= "string" then return str end
  str = string.gsub(str, "|c%x%x%x%x%x%x%x%x", "")
  str = string.gsub(str, "|r", "")
  str = string.gsub(str, "|H.-|h%[(.-)%]|h", "%1")
  str = string.gsub(str, "|H.-|h(.-)|h", "%1")
  return str
end

local function ResolveName(name)
  if type(name) ~= "string" then return name end
  name = Trim(StripMarkup(name))
  if SELF_TOKENS[string.lower(name)] then
    return UnitName("player") or name
  end
  return name
end

local function ScanName(name)
  name = ResolveName(name)
  if not name then return nil end
  local unit
  for unit in pairs(validUnits) do
    if UnitExists(unit) and UnitName(unit) == name and UnitIsPlayer(unit) then
      local _, class = UnitClass(unit)
      data.classes[name] = class
      return "PLAYER"
    end
  end
  local match, _, owner = string.find(name, "%((.*)%)", 1)
  if match and owner and ScanName(owner) == "PLAYER" then
    data.classes[name] = owner
    return "PET"
  end
  for unit in pairs(validPets) do
    if UnitExists(unit) and UnitName(unit) == name then
      if string.sub(unit, 1, 3) == "pet" then
        data.classes[name] = UnitName("player")
      elseif string.sub(unit, 1, 8) == "partypet" then
        data.classes[name] = UnitName("party" .. string.sub(unit, 9))
      elseif string.sub(unit, 1, 7) == "raidpet" then
        data.classes[name] = UnitName("raid" .. string.sub(unit, 8))
      end
      return "PET"
    end
  end
  return nil
end

local function MarkMetersDirty()
  if QtUI.meterFrames then
    local i
    for i = 1, table.getn(QtUI.meterFrames) do
      QtUI.meterFrames[i].dirty = true
    end
    return
  end
  if QtUI.meterFrame then QtUI.meterFrame.dirty = true end
end

local function AddData(source, action, target, value, school, datatype)
  if type(source) ~= "string" then return end
  if not tonumber(value) then return end
  if not datatype then datatype = "damage" end
  source = ResolveName(source)
  if type(target) == "string" then target = ResolveName(target) end
  if type(action) == "string" then action = StripMarkup(action) end
  if datatype == "damage" and source == target then return end

  if startNextSegment and data.classes[source] and data.classes[source] ~= "__other__" then
    data.damage[1] = {}
    data.heal[1] = {}
    startNextSegment = nil
  end

  local segment
  for segment = 0, 1 do
    local entry = data[datatype][segment]
    if not entry[source] then
      local kind = ScanName(source)
      if kind == "PET" then
        local owner = data.classes[source]
        if not entry[owner] and ScanName(owner) then
          entry[owner] = { _sum = 0, _ctime = 1 }
        end
      elseif not kind then
        break
      end
      entry[source] = { _sum = 0, _ctime = 1 }
    end

    local writeSource = source
    local writeAction = action
    if data.classes[source] and data.classes[source] ~= "__other__" and entry[data.classes[source]] then
      entry[source] = nil
      writeAction = "Pet: " .. source
      writeSource = data.classes[source]
      if not entry[writeSource] then
        entry[writeSource] = { _sum = 0, _ctime = 1 }
      end
    end

    if entry[writeSource] then
      local amount = tonumber(value)
      entry[writeSource][writeAction] = (entry[writeSource][writeAction] or 0) + amount
      entry[writeSource]._sum = (entry[writeSource]._sum or 0) + amount
      entry[writeSource]._ctime = entry[writeSource]._ctime or 1
      entry[writeSource]._tick = entry[writeSource]._tick or GetTime()
      if entry[writeSource]._tick + 5 < GetTime() then
        entry[writeSource]._tick = GetTime()
        entry[writeSource]._ctime = entry[writeSource]._ctime + 5
      else
        entry[writeSource]._ctime = entry[writeSource]._ctime + (GetTime() - entry[writeSource]._tick)
        entry[writeSource]._tick = GetTime()
      end
    end
  end

  MarkMetersDirty()
end

-- ShaguDPS locale-independent pattern sanitizer.
local sanitizeCache = {}
local function Sanitize(pattern)
  if not pattern then return nil end
  if not sanitizeCache[pattern] then
    local ret = pattern
    ret = string.gsub(ret, "([%+%-%*%(%)%?%[%]%^])", "%%%1")
    ret = string.gsub(ret, "%d%$", "")
    ret = string.gsub(ret, "(%%%a)", "%(%1+%)")
    ret = string.gsub(ret, "%%s%+", ".+")
    ret = string.gsub(ret, "%(.%+%)%(%%d%+%)", "%(.-%)%(%%d%+%)")
    sanitizeCache[pattern] = ret
  end
  return sanitizeCache[pattern]
end

local captureCache = {}
local function Captures(pat)
  local r = captureCache
  if not r[pat] then
    r[pat] = { nil, nil, nil, nil, nil }
    local a, b, c, d, e
    for a, b, c, d, e in string.gfind(string.gsub(pat, "%((.+)%)", "%1"), string.gsub(pat, "%d%$", "%%(.-)$")) do
      r[pat][1] = tonumber(a)
      r[pat][2] = tonumber(b)
      r[pat][3] = tonumber(c)
      r[pat][4] = tonumber(d)
      r[pat][5] = tonumber(e)
    end
  end
  return r[pat][1], r[pat][2], r[pat][3], r[pat][4], r[pat][5]
end

local function CFind(str, pat)
  local a, b, c, d, e = Captures(pat)
  local match, num, va, vb, vc, vd, ve = string.find(str, Sanitize(pat))
  if not match then return nil end
  local ra = e == 1 and ve or d == 1 and vd or c == 1 and vc or b == 1 and vb or va
  local rb = e == 2 and ve or d == 2 and vd or c == 2 and vc or a == 2 and va or vb
  local rc = e == 3 and ve or d == 3 and vd or a == 3 and va or b == 3 and vb or vc
  local rd = e == 4 and ve or a == 4 and va or c == 4 and vc or b == 4 and vb or vd
  local re = a == 5 and va or d == 5 and vd or c == 5 and vc or b == 5 and vb or ve
  return match, num, ra, rb, rc, rd, re
end

-- Emberveil ships almost no FrameXML GlobalStrings. Prefer client strings,
-- then hard-coded enUS / deDE so the Shagu-style matcher still has patterns.
local function GlobalOr(name, fallback)
  local value = getglobal(name)
  if type(value) == "string" and value ~= "" then return value end
  return fallback
end

local combatlogStrings = {
  ["Hit Damage (self vs. other)"] = {
    COMBATHITSELFOTHER, COMBATHITSCHOOLSELFOTHER, COMBATHITCRITSELFOTHER, COMBATHITCRITSCHOOLSELFOTHER
  },
  ["Hit Damage (other vs. self)"] = {
    COMBATHITOTHERSELF, COMBATHITCRITOTHERSELF, COMBATHITSCHOOLOTHERSELF, COMBATHITCRITSCHOOLOTHERSELF
  },
  ["Hit Damage (other vs. other)"] = {
    COMBATHITOTHEROTHER, COMBATHITCRITOTHEROTHER, COMBATHITSCHOOLOTHEROTHER, COMBATHITCRITSCHOOLOTHEROTHER
  },
  ["Spell Damage (self vs. self/other)"] = {
    SPELLLOGSCHOOLSELFSELF, SPELLLOGCRITSCHOOLSELFSELF, SPELLLOGSELFSELF, SPELLLOGCRITSELFSELF,
    SPELLLOGSCHOOLSELFOTHER, SPELLLOGCRITSCHOOLSELFOTHER, SPELLLOGSELFOTHER, SPELLLOGCRITSELFOTHER
  },
  ["Spell Damage (other vs. self)"] = {
    SPELLLOGSCHOOLOTHERSELF, SPELLLOGCRITSCHOOLOTHERSELF, SPELLLOGOTHERSELF, SPELLLOGCRITOTHERSELF
  },
  ["Spell Damage (other vs. other)"] = {
    SPELLLOGSCHOOLOTHEROTHER, SPELLLOGCRITSCHOOLOTHEROTHER, SPELLLOGOTHEROTHER, SPELLLOGCRITOTHEROTHER
  },
  ["Shield Damage (self vs. other)"] = { DAMAGESHIELDSELFOTHER },
  ["Shield Damage (other vs. self/other)"] = { DAMAGESHIELDOTHERSELF, DAMAGESHIELDOTHEROTHER },
  ["Periodic Damage (self/other vs. other)"] = {
    PERIODICAURADAMAGESELFOTHER, PERIODICAURADAMAGEOTHEROTHER
  },
  ["Periodic Damage (self/other vs. self)"] = {
    PERIODICAURADAMAGESELFSELF, PERIODICAURADAMAGEOTHERSELF
  },
  ["Heal (self vs. self/other)"] = {
    HEALEDCRITSELFSELF, HEALEDSELFSELF, HEALEDCRITSELFOTHER, HEALEDSELFOTHER
  },
  ["Heal (other vs. self/other)"] = {
    HEALEDCRITOTHERSELF, HEALEDOTHERSELF, HEALEDCRITOTHEROTHER, HEALEDOTHEROTHER
  },
  ["Periodic Heal (self/other vs. other)"] = {
    PERIODICAURAHEALSELFOTHER, PERIODICAURAHEALOTHEROTHER
  },
  ["Periodic Heal (other vs. self/other)"] = {
    PERIODICAURAHEALSELFSELF, PERIODICAURAHEALOTHERSELF
  },
}

local combatlogEvents = {
  CHAT_MSG_COMBAT_SELF_HITS = combatlogStrings["Hit Damage (self vs. other)"],
  CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS = combatlogStrings["Hit Damage (other vs. self)"],
  CHAT_MSG_COMBAT_PARTY_HITS = combatlogStrings["Hit Damage (other vs. other)"],
  CHAT_MSG_COMBAT_FRIENDLYPLAYER_HITS = combatlogStrings["Hit Damage (other vs. other)"],
  CHAT_MSG_COMBAT_HOSTILEPLAYER_HITS = combatlogStrings["Hit Damage (other vs. other)"],
  CHAT_MSG_COMBAT_CREATURE_VS_CREATURE_HITS = combatlogStrings["Hit Damage (other vs. other)"],
  CHAT_MSG_COMBAT_CREATURE_VS_PARTY_HITS = combatlogStrings["Hit Damage (other vs. other)"],
  CHAT_MSG_COMBAT_PET_HITS = combatlogStrings["Hit Damage (other vs. other)"],
  CHAT_MSG_SPELL_SELF_DAMAGE = combatlogStrings["Spell Damage (self vs. self/other)"],
  CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE = combatlogStrings["Spell Damage (other vs. self)"],
  CHAT_MSG_SPELL_PARTY_DAMAGE = combatlogStrings["Spell Damage (other vs. other)"],
  CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE = combatlogStrings["Spell Damage (other vs. other)"],
  CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE = combatlogStrings["Spell Damage (other vs. other)"],
  CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE = combatlogStrings["Spell Damage (other vs. other)"],
  CHAT_MSG_SPELL_CREATURE_VS_PARTY_DAMAGE = combatlogStrings["Spell Damage (other vs. other)"],
  CHAT_MSG_SPELL_PET_DAMAGE = combatlogStrings["Spell Damage (other vs. other)"],
  CHAT_MSG_SPELL_DAMAGESHIELDS_ON_SELF = combatlogStrings["Shield Damage (self vs. other)"],
  CHAT_MSG_SPELL_DAMAGESHIELDS_ON_OTHERS = combatlogStrings["Shield Damage (other vs. self/other)"],
  CHAT_MSG_SPELL_PERIODIC_PARTY_DAMAGE = combatlogStrings["Periodic Damage (self/other vs. other)"],
  CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE = combatlogStrings["Periodic Damage (self/other vs. other)"],
  CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_DAMAGE = combatlogStrings["Periodic Damage (self/other vs. other)"],
  CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE = combatlogStrings["Periodic Damage (self/other vs. other)"],
  CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE = combatlogStrings["Periodic Damage (self/other vs. self)"],
  CHAT_MSG_SPELL_SELF_BUFF = combatlogStrings["Heal (self vs. self/other)"],
  CHAT_MSG_SPELL_FRIENDLYPLAYER_BUFF = combatlogStrings["Heal (other vs. self/other)"],
  CHAT_MSG_SPELL_HOSTILEPLAYER_BUFF = combatlogStrings["Heal (other vs. self/other)"],
  CHAT_MSG_SPELL_PARTY_BUFF = combatlogStrings["Heal (other vs. self/other)"],
  CHAT_MSG_SPELL_PERIODIC_PARTY_BUFFS = combatlogStrings["Periodic Heal (self/other vs. other)"],
  CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_BUFFS = combatlogStrings["Periodic Heal (self/other vs. other)"],
  CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_BUFFS = combatlogStrings["Periodic Heal (self/other vs. other)"],
  CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS = combatlogStrings["Periodic Heal (other vs. self/other)"],
}

local combatlogParser = {}
if SPELLLOGSCHOOLSELFSELF then
  combatlogParser[SPELLLOGSCHOOLSELFSELF] = function(d, attack, value, school)
    return d.source, attack, d.target, value, school, "damage"
  end
end
if SPELLLOGCRITSCHOOLSELFSELF then
  combatlogParser[SPELLLOGCRITSCHOOLSELFSELF] = function(d, attack, value, school)
    return d.source, attack, d.target, value, school, "damage"
  end
end
if SPELLLOGSELFSELF then
  combatlogParser[SPELLLOGSELFSELF] = function(d, attack, value)
    return d.source, attack, d.target, value, d.school, "damage"
  end
end
if SPELLLOGCRITSELFSELF then
  combatlogParser[SPELLLOGCRITSELFSELF] = function(d, attack, value)
    return d.source, attack, d.target, value, d.school, "damage"
  end
end
if PERIODICAURADAMAGESELFSELF then
  combatlogParser[PERIODICAURADAMAGESELFSELF] = function(d, value, school, attack)
    return d.source, attack, d.target, value, school, "damage"
  end
end
if SPELLLOGSCHOOLSELFOTHER then
  combatlogParser[SPELLLOGSCHOOLSELFOTHER] = function(d, attack, target, value, school)
    return d.source, attack, target, value, school, "damage"
  end
end
if SPELLLOGCRITSCHOOLSELFOTHER then
  combatlogParser[SPELLLOGCRITSCHOOLSELFOTHER] = function(d, attack, target, value, school)
    return d.source, attack, target, value, school, "damage"
  end
end
if SPELLLOGSELFOTHER then
  combatlogParser[SPELLLOGSELFOTHER] = function(d, attack, target, value)
    return d.source, attack, target, value, d.school, "damage"
  end
end
if SPELLLOGCRITSELFOTHER then
  combatlogParser[SPELLLOGCRITSELFOTHER] = function(d, attack, target, value)
    return d.source, attack, target, value, d.school, "damage"
  end
end
if PERIODICAURADAMAGESELFOTHER then
  combatlogParser[PERIODICAURADAMAGESELFOTHER] = function(d, target, value, school, attack)
    return d.source, attack, target, value, school, "damage"
  end
end
if COMBATHITSELFOTHER then
  combatlogParser[COMBATHITSELFOTHER] = function(d, target, value)
    return d.source, d.attack, target, value, d.school, "damage"
  end
end
if COMBATHITCRITSELFOTHER then
  combatlogParser[COMBATHITCRITSELFOTHER] = function(d, target, value)
    return d.source, d.attack, target, value, d.school, "damage"
  end
end
if COMBATHITSCHOOLSELFOTHER then
  combatlogParser[COMBATHITSCHOOLSELFOTHER] = function(d, target, value, school)
    return d.source, d.attack, target, value, school, "damage"
  end
end
if COMBATHITCRITSCHOOLSELFOTHER then
  combatlogParser[COMBATHITCRITSCHOOLSELFOTHER] = function(d, target, value, school)
    return d.source, d.attack, target, value, school, "damage"
  end
end
if DAMAGESHIELDSELFOTHER then
  combatlogParser[DAMAGESHIELDSELFOTHER] = function(d, value, school, target)
    return d.source, "Reflect", target, value, school, "damage"
  end
end
if SPELLLOGSCHOOLOTHERSELF then
  combatlogParser[SPELLLOGSCHOOLOTHERSELF] = function(d, source, attack, value, school)
    return source, attack, d.target, value, school, "damage"
  end
end
if SPELLLOGCRITSCHOOLOTHERSELF then
  combatlogParser[SPELLLOGCRITSCHOOLOTHERSELF] = function(d, source, attack, value, school)
    return source, attack, d.target, value, school, "damage"
  end
end
if SPELLLOGOTHERSELF then
  combatlogParser[SPELLLOGOTHERSELF] = function(d, source, attack, value)
    return source, attack, d.target, value, d.school, "damage"
  end
end
if SPELLLOGCRITOTHERSELF then
  combatlogParser[SPELLLOGCRITOTHERSELF] = function(d, source, attack, value)
    return source, attack, d.target, value, d.school, "damage"
  end
end
if PERIODICAURADAMAGEOTHERSELF then
  combatlogParser[PERIODICAURADAMAGEOTHERSELF] = function(d, value, school, source, attack)
    return source, attack, d.target, value, school, "damage"
  end
end
if COMBATHITOTHERSELF then
  combatlogParser[COMBATHITOTHERSELF] = function(d, source, value)
    return source, d.attack, d.target, value, d.school, "damage"
  end
end
if COMBATHITCRITOTHERSELF then
  combatlogParser[COMBATHITCRITOTHERSELF] = function(d, source, value)
    return source, d.attack, d.target, value, d.school, "damage"
  end
end
if COMBATHITSCHOOLOTHERSELF then
  combatlogParser[COMBATHITSCHOOLOTHERSELF] = function(d, source, value, school)
    return source, d.attack, d.target, value, school, "damage"
  end
end
if COMBATHITCRITSCHOOLOTHERSELF then
  combatlogParser[COMBATHITCRITSCHOOLOTHERSELF] = function(d, source, value, school)
    return source, d.attack, d.target, value, school, "damage"
  end
end
if SPELLLOGSCHOOLOTHEROTHER then
  combatlogParser[SPELLLOGSCHOOLOTHEROTHER] = function(d, source, attack, target, value, school)
    return source, attack, target, value, school, "damage"
  end
end
if SPELLLOGCRITSCHOOLOTHEROTHER then
  combatlogParser[SPELLLOGCRITSCHOOLOTHEROTHER] = function(d, source, attack, target, value, school)
    return source, attack, target, value, school, "damage"
  end
end
if SPELLLOGOTHEROTHER then
  combatlogParser[SPELLLOGOTHEROTHER] = function(d, source, attack, target, value)
    return source, attack, target, value, d.school, "damage"
  end
end
if SPELLLOGCRITOTHEROTHER then
  combatlogParser[SPELLLOGCRITOTHEROTHER] = function(d, source, attack, target, value, school)
    return source, attack, target, value, school or d.school, "damage"
  end
end
if PERIODICAURADAMAGEOTHEROTHER then
  combatlogParser[PERIODICAURADAMAGEOTHEROTHER] = function(d, target, value, school, source, attack)
    return source, attack, target, value, school, "damage"
  end
end
if COMBATHITOTHEROTHER then
  combatlogParser[COMBATHITOTHEROTHER] = function(d, source, target, value)
    return source, d.attack, target, value, d.school, "damage"
  end
end
if COMBATHITCRITOTHEROTHER then
  combatlogParser[COMBATHITCRITOTHEROTHER] = function(d, source, target, value)
    return source, d.attack, target, value, d.school, "damage"
  end
end
if COMBATHITSCHOOLOTHEROTHER then
  combatlogParser[COMBATHITSCHOOLOTHEROTHER] = function(d, source, target, value, school)
    return source, d.attack, target, value, school, "damage"
  end
end
if COMBATHITCRITSCHOOLOTHEROTHER then
  combatlogParser[COMBATHITCRITSCHOOLOTHEROTHER] = function(d, source, target, value, school)
    return source, d.attack, target, value, school, "damage"
  end
end
if DAMAGESHIELDOTHERSELF then
  combatlogParser[DAMAGESHIELDOTHERSELF] = function(d, source, value, school)
    return source, "Reflect", d.target, value, school, "damage"
  end
end
if DAMAGESHIELDOTHEROTHER then
  combatlogParser[DAMAGESHIELDOTHEROTHER] = function(d, source, value, school, target)
    return source, "Reflect", target, value, school, "damage"
  end
end
if HEALEDCRITOTHERSELF then
  combatlogParser[HEALEDCRITOTHERSELF] = function(d, source, spell, value)
    return source, spell, d.target, value, d.school, "heal"
  end
end
if HEALEDOTHERSELF then
  combatlogParser[HEALEDOTHERSELF] = function(d, source, spell, value)
    return source, spell, d.target, value, d.school, "heal"
  end
end
if PERIODICAURAHEALOTHERSELF then
  combatlogParser[PERIODICAURAHEALOTHERSELF] = function(d, value, source, spell)
    return source, spell, d.target, value, d.school, "heal"
  end
end
if HEALEDCRITSELFSELF then
  combatlogParser[HEALEDCRITSELFSELF] = function(d, spell, value)
    return d.source, spell, d.target, value, d.school, "heal"
  end
end
if HEALEDSELFSELF then
  combatlogParser[HEALEDSELFSELF] = function(d, spell, value)
    return d.source, spell, d.target, value, d.school, "heal"
  end
end
if PERIODICAURAHEALSELFSELF then
  combatlogParser[PERIODICAURAHEALSELFSELF] = function(d, value, spell)
    return d.source, spell, d.target, value, d.school, "heal"
  end
end
if HEALEDCRITSELFOTHER then
  combatlogParser[HEALEDCRITSELFOTHER] = function(d, spell, target, value)
    return d.source, spell, target, value, d.school, "heal"
  end
end
if HEALEDSELFOTHER then
  combatlogParser[HEALEDSELFOTHER] = function(d, spell, target, value)
    return d.source, spell, target, value, d.school, "heal"
  end
end
if PERIODICAURAHEALSELFOTHER then
  combatlogParser[PERIODICAURAHEALSELFOTHER] = function(d, target, value, spell)
    return d.source, spell, target, value, d.school, "heal"
  end
end
if HEALEDCRITOTHEROTHER then
  combatlogParser[HEALEDCRITOTHEROTHER] = function(d, source, spell, target, value)
    return source, spell, target, value, d.school, "heal"
  end
end
if HEALEDOTHEROTHER then
  combatlogParser[HEALEDOTHEROTHER] = function(d, source, spell, target, value)
    return source, spell, target, value, d.school, "heal"
  end
end
if PERIODICAURAHEALOTHEROTHER then
  combatlogParser[PERIODICAURAHEALOTHEROTHER] = function(d, target, value, source, spell)
    return source, spell, target, value, d.school, "heal"
  end
end

local allPatterns = {}

local function BindPattern(pattern, handler, eventKeys)
  if type(pattern) ~= "string" or pattern == "" or not handler then return end
  if not combatlogParser[pattern] then
    combatlogParser[pattern] = handler
  end
  table.insert(allPatterns, pattern)
  if eventKeys then
    local i
    for i = 1, table.getn(eventKeys) do
      local list = combatlogEvents[eventKeys[i]]
      if list then table.insert(list, pattern) end
    end
  end
end

-- Handlers match ShaguDPS capture order for the fallback format strings.
local hitSelfOther = function(d, target, value)
  return d.source, d.attack, target, value, d.school, "damage"
end
local hitOtherSelf = function(d, source, value)
  return source, d.attack, d.target, value, d.school, "damage"
end
local hitOtherOther = function(d, source, target, value)
  return source, d.attack, target, value, d.school, "damage"
end
local spellSelfOther = function(d, attack, target, value)
  return d.source, attack, target, value, d.school, "damage"
end
local spellOtherOther = function(d, source, attack, target, value)
  return source, attack, target, value, d.school, "damage"
end
local spellOtherSelf = function(d, source, attack, value)
  return source, attack, d.target, value, d.school, "damage"
end
local healSelfOther = function(d, spell, target, value)
  return d.source, spell, target, value, d.school, "heal"
end
local healSelfSelf = function(d, spell, value)
  return d.source, spell, d.target, value, d.school, "heal"
end
local healOtherOther = function(d, source, spell, target, value)
  return source, spell, target, value, d.school, "heal"
end
local healOtherSelf = function(d, source, spell, value)
  return source, spell, d.target, value, d.school, "heal"
end
local dotSelfOther = function(d, target, value, school, attack)
  return d.source, attack, target, value, school, "damage"
end
local dotOtherOther = function(d, target, value, school, source, attack)
  return source, attack, target, value, school, "damage"
end

local selfHitEvents = { "CHAT_MSG_COMBAT_SELF_HITS" }
local otherSelfHitEvents = { "CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS" }
local otherHitEvents = {
  "CHAT_MSG_COMBAT_PARTY_HITS", "CHAT_MSG_COMBAT_FRIENDLYPLAYER_HITS",
  "CHAT_MSG_COMBAT_HOSTILEPLAYER_HITS", "CHAT_MSG_COMBAT_CREATURE_VS_CREATURE_HITS",
  "CHAT_MSG_COMBAT_CREATURE_VS_PARTY_HITS", "CHAT_MSG_COMBAT_PET_HITS",
}
local selfSpellEvents = { "CHAT_MSG_SPELL_SELF_DAMAGE" }
local otherSelfSpellEvents = { "CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE" }
local otherSpellEvents = {
  "CHAT_MSG_SPELL_PARTY_DAMAGE", "CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE",
  "CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE", "CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE",
  "CHAT_MSG_SPELL_CREATURE_VS_PARTY_DAMAGE", "CHAT_MSG_SPELL_PET_DAMAGE",
}
local selfHealEvents = { "CHAT_MSG_SPELL_SELF_BUFF" }
local otherHealEvents = {
  "CHAT_MSG_SPELL_FRIENDLYPLAYER_BUFF", "CHAT_MSG_SPELL_HOSTILEPLAYER_BUFF",
  "CHAT_MSG_SPELL_PARTY_BUFF",
}

BindPattern(GlobalOr("COMBATHITSELFOTHER", "You hit %s for %d."), hitSelfOther, selfHitEvents)
BindPattern("You crit %s for %d.", hitSelfOther, selfHitEvents)
BindPattern("You hit %s for %d %s damage.", hitSelfOther, selfHitEvents)
BindPattern("Ihr trefft %s für %d Schaden.", hitSelfOther, selfHitEvents)
BindPattern("Ihr trefft %s kritisch für %d Schaden.", hitSelfOther, selfHitEvents)
BindPattern(GlobalOr("COMBATHITOTHERSELF", "%s hits you for %d."), hitOtherSelf, otherSelfHitEvents)
BindPattern("%s trifft Euch für %d Schaden.", hitOtherSelf, otherSelfHitEvents)
BindPattern(GlobalOr("COMBATHITOTHEROTHER", "%s hits %s for %d."), hitOtherOther, otherHitEvents)
BindPattern("%s crits %s for %d.", hitOtherOther, otherHitEvents)
BindPattern("%s trifft %s für %d Schaden.", hitOtherOther, otherHitEvents)
BindPattern("%s trifft %s kritisch für %d Schaden.", hitOtherOther, otherHitEvents)
BindPattern(GlobalOr("SPELLLOGSELFOTHER", "Your %s hits %s for %d."), spellSelfOther, selfSpellEvents)
BindPattern("Your %s crits %s for %d.", spellSelfOther, selfSpellEvents)
BindPattern("Your %s hits %s for %d %s damage.", spellSelfOther, selfSpellEvents)
BindPattern("Euer %s trifft %s für %d Schaden.", spellSelfOther, selfSpellEvents)
BindPattern("Euer %s trifft %s kritisch für %d Schaden.", spellSelfOther, selfSpellEvents)
BindPattern(GlobalOr("SPELLLOGOTHEROTHER", "%s's %s hits %s for %d."), spellOtherOther, otherSpellEvents)
BindPattern("%ss %s trifft %s für %d Schaden.", spellOtherOther, otherSpellEvents)
BindPattern(GlobalOr("SPELLLOGOTHERSELF", "%s's %s hits you for %d."), spellOtherSelf, otherSelfSpellEvents)
BindPattern(GlobalOr("HEALEDSELFOTHER", "Your %s heals %s for %d."), healSelfOther, selfHealEvents)
BindPattern("Your %s critically heals %s for %d.", healSelfOther, selfHealEvents)
BindPattern(GlobalOr("HEALEDSELFSELF", "Your %s heals you for %d."), healSelfSelf, selfHealEvents)
BindPattern(GlobalOr("HEALEDOTHEROTHER", "%s's %s heals %s for %d."), healOtherOther, otherHealEvents)
BindPattern(GlobalOr("HEALEDOTHERSELF", "%s's %s heals you for %d."), healOtherSelf, otherHealEvents)
BindPattern(GlobalOr("PERIODICAURADAMAGESELFOTHER", "%s suffers %d %s damage from your %s."), dotSelfOther, {
  "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE", "CHAT_MSG_SPELL_PERIODIC_PARTY_DAMAGE",
  "CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE", "CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_DAMAGE",
})
BindPattern(GlobalOr("PERIODICAURADAMAGEOTHEROTHER", "%s suffers %d %s damage from %s's %s."), dotOtherOther, {
  "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE", "CHAT_MSG_SPELL_PERIODIC_PARTY_DAMAGE",
})

local genericRules = {
  { "^You hit (.+) for (%d+)", hitSelfOther },
  { "^You crit (.+) for (%d+)", hitSelfOther },
  { "^Your (.+) hits (.+) for (%d+)", spellSelfOther },
  { "^Your (.+) crits (.+) for (%d+)", spellSelfOther },
  { "^Your (.+) heals you for (%d+)", healSelfSelf },
  { "^Your (.+) heals (.+) for (%d+)", healSelfOther },
  { "^(.+) hits you for (%d+)", hitOtherSelf },
  { "^(.+) crits you for (%d+)", hitOtherSelf },
  { "^(.+)'s (.+) hits you for (%d+)", spellOtherSelf },
  { "^(.+)'s (.+) hits (.+) for (%d+)", spellOtherOther },
  { "^(.+) hits (.+) for (%d+)", hitOtherOther },
  { "^(.+) crits (.+) for (%d+)", hitOtherOther },
  { "^Ihr trefft (.+) kritisch für (%d+)", hitSelfOther },
  { "^Ihr trefft (.+) für (%d+)", hitSelfOther },
  { "^Euer (.+) trifft (.+) kritisch für (%d+)", spellSelfOther },
  { "^Euer (.+) trifft (.+) für (%d+)", spellSelfOther },
  { "^(.+) trifft Euch kritisch für (%d+)", hitOtherSelf },
  { "^(.+) trifft Euch für (%d+)", hitOtherSelf },
  { "^(.+) trifft (.+) kritisch für (%d+)", hitOtherOther },
  { "^(.+) trifft (.+) für (%d+)", hitOtherOther },
}

local event
for event in pairs(combatlogEvents) do
  pcall(parser.RegisterEvent, parser, event)
end
pcall(parser.RegisterEvent, parser, "COMBAT_LOG_EVENT_UNFILTERED")
pcall(parser.RegisterEvent, parser, "COMBAT_LOG_EVENT")
pcall(parser.RegisterEvent, parser, "CHAT_MSG_COMBAT_MISC_INFO")

local pattern
for pattern in pairs(combatlogParser) do
  Sanitize(pattern)
end

local absorb = ABSORB_TRAILER and Sanitize(ABSORB_TRAILER)
local resist = RESIST_TRAILER and Sanitize(RESIST_TRAILER)
local empty = ""
local defaults = {}
local lastParse, lastParseTime = "", 0

local function PrepareMessage(msg)
  if type(msg) ~= "string" then return nil end
  msg = StripMarkup(msg)
  if absorb then msg = string.gsub(msg, absorb, empty) end
  if resist then msg = string.gsub(msg, resist, empty) end
  return msg
end

local function ParseCombatMessage(msg, eventName)
  msg = PrepareMessage(msg)
  if not msg or msg == "" then return end
  local now = GetTime()
  if msg == lastParse and now - lastParseTime < .05 then return end

  defaults.source = UnitName("player")
  defaults.target = defaults.source
  defaults.school = "physical"
  defaults.attack = "Auto Hit"

  local function TryList(list)
    if not list then return nil end
    local _, pat
    for _, pat in pairs(list) do
      if pat and combatlogParser[pat] then
        local result, _, a1, a2, a3, a4, a5 = CFind(msg, pat)
        if result then
          lastParse, lastParseTime = msg, now
          AddData(combatlogParser[pat](defaults, a1, a2, a3, a4, a5))
          return true
        end
      end
    end
    return nil
  end

  if TryList(eventName and combatlogEvents[eventName]) then return end

  local i
  for i = 1, table.getn(genericRules) do
    local rule = genericRules[i]
    local found, _, a1, a2, a3, a4 = string.find(msg, rule[1])
    if found then
      lastParse, lastParseTime = msg, now
      AddData(rule[2](defaults, a1, a2, a3, a4))
      return
    end
  end

  TryList(allPatterns)
end

local function HandleCLEU()
  local subevent, source, dest, swingAmt, spellName, spellAmt
  if type(CombatLogGetCurrentEventInfo) == "function" then
    local ok, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16 = pcall(CombatLogGetCurrentEventInfo)
    if ok and type(a2) == "string" then
      subevent = a2
      if a3 == true or a3 == false then
        if type(a7) == "number" then
          source, dest = a5, a9
          swingAmt, spellName, spellAmt = a12, a13, a16
        else
          source, dest = a5, a8
          swingAmt, spellName, spellAmt = a10, a11, a13
        end
      else
        source, dest = a4, a7
        swingAmt, spellName, spellAmt = a9, a10, a12
      end
    end
  end
  if not subevent then
    subevent = arg2
    if type(subevent) ~= "string" then return end
    if arg3 == true or arg3 == false or arg3 == 0 or arg3 == 1 then
      source, dest = arg5, arg8
      swingAmt, spellName, spellAmt = arg10, arg11, arg13
    else
      source, dest = arg4, arg7
      swingAmt, spellName, spellAmt = arg9, arg10, arg12
    end
  end
  if subevent == "SWING_DAMAGE" then
    AddData(source, "Auto Hit", dest, swingAmt, nil, "damage")
  elseif subevent == "SPELL_DAMAGE" or subevent == "RANGE_DAMAGE" or subevent == "SPELL_PERIODIC_DAMAGE" or subevent == "DAMAGE_SHIELD" or subevent == "DAMAGE_SPLIT" then
    AddData(source, spellName or "Spell", dest, spellAmt or swingAmt, nil, "damage")
  elseif subevent == "SPELL_HEAL" or subevent == "SPELL_PERIODIC_HEAL" then
    AddData(source, spellName or "Heal", dest, spellAmt or swingAmt, nil, "heal")
  end
end

parser:SetScript("OnEvent", function()
  if event == "COMBAT_LOG_EVENT_UNFILTERED" or event == "COMBAT_LOG_EVENT" then
    HandleCLEU()
    return
  end
  if arg1 then ParseCombatMessage(arg1, event) end
end)

local function HookChatMeter(frame)
  if not frame or frame.qtMeterHooked then return end
  local orig = frame.AddMessage
  if type(orig) ~= "function" then return end
  frame.qtMeterHooked = true
  frame.AddMessage = function(self, msg, r, g, b, id)
    if type(msg) == "string" then pcall(ParseCombatMessage, msg, nil) end
    return orig(self, msg, r, g, b, id)
  end
end

HookChatMeter(DEFAULT_CHAT_FRAME)
HookChatMeter(ChatFrame1)
HookChatMeter(ChatFrame2)

local combatWatch = CreateFrame("Frame", "QtUIDamageCombat")
combatWatch.state = "NO_COMBAT"
combatWatch:RegisterEvent("PLAYER_REGEN_DISABLED")
combatWatch:RegisterEvent("PLAYER_REGEN_ENABLED")
local function UpdateCombatState()
  local state = AnyInCombat() and "COMBAT" or "NO_COMBAT"
  if combatWatch.state ~= state then
    combatWatch.state = state
    if state == "NO_COMBAT" then startNextSegment = true end
  end
end
combatWatch:SetScript("OnEvent", UpdateCombatState)
combatWatch.elapsed = 0
combatWatch:SetScript("OnUpdate", function()
  this.elapsed = this.elapsed + (arg1 or 0)
  if this.elapsed >= 1 then
    this.elapsed = 0
    UpdateCombatState()
  end
end)

local function SortedNames(segment, byRate)
  local keys = {}
  local name
  for name in pairs(segment) do
    table.insert(keys, name)
  end
  table.sort(keys, function(a, b)
    local sa, sb = segment[a]._sum or 0, segment[b]._sum or 0
    if byRate then
      local ca, cb = segment[a]._ctime or 1, segment[b]._ctime or 1
      if ca < 1 then ca = 1 end
      if cb < 1 then cb = 1 end
      return (sb / cb) < (sa / ca)
    end
    return sb < sa
  end)
  return keys
end

local function ClassColor(name)
  local class = data.classes[name]
  local c = class and CLASS_COLORS[class]
  if c then return c[1], c[2], c[3] end
  return .35, .4, .45
end

local function ShortNumber(value)
  value = tonumber(value) or 0
  if value >= 1000000 then return string.format("%.1fm", value / 1000000) end
  if value >= 10000 then return string.format("%.1fk", value / 1000) end
  return tostring(math.floor(value + .5))
end

local MAX_WINDOWS = 6
local BTN = 16
local MODES = {
  { view = "damage", segment = 1, label = "Current Damage" },
  { view = "dps",    segment = 1, label = "Current DPS" },
  { view = "heal",   segment = 1, label = "Current Heal" },
  { view = "damage", segment = 0, label = "Overall Damage" },
  { view = "dps",    segment = 0, label = "Overall DPS" },
  { view = "heal",   segment = 0, label = "Overall Heal" },
}

local function ModeLabel(view, segment)
  local i
  for i = 1, table.getn(MODES) do
    if MODES[i].view == view and MODES[i].segment == segment then
      return MODES[i].label
    end
  end
  return "Current Damage"
end

local function ModeIndex(view, segment)
  local i
  for i = 1, table.getn(MODES) do
    if MODES[i].view == view and MODES[i].segment == segment then return i end
  end
  return 1
end

local function MeterMoveKey(id)
  if tonumber(id) == 1 then return "damageMeter" end
  return "damageMeter" .. tostring(id)
end

local function FormatRate(value)
  value = tonumber(value) or 0
  if value >= 10000 then return ShortNumber(value) end
  if value >= 100 then return string.format("%.0f", value) end
  return string.format("%.1f", value)
end

local function AnnounceLine(text, chatType)
  if type(SendChatMessage) ~= "function" then return end
  if type(chatType) ~= "string" or chatType == "" then chatType = "SAY" end
  pcall(SendChatMessage, text, chatType)
end

local function ReportMeter(frame, chatType)
  if not frame then return end
  local view = frame.view or "damage"
  local segmentId = frame.segment or 1
  local store = view == "heal" and data.heal or data.damage
  local segment = store[segmentId] or {}
  local keys = SortedNames(segment, view == "dps")
  local count = table.getn(keys)
  if count < 1 then
    AnnounceLine("QtUI - " .. ModeLabel(view, segmentId) .. ": no data", chatType)
    return
  end
  AnnounceLine("QtUI - " .. ModeLabel(view, segmentId) .. ":", chatType)
  if count > 8 then count = 8 end
  local n
  for n = 1, count do
    local name = keys[n]
    local row = segment[name]
    local sum = row._sum or 0
    local ctime = row._ctime or 1
    if ctime < 1 then ctime = 1 end
    local rate = sum / ctime
    if view == "dps" then
      AnnounceLine(n .. ". " .. name .. " " .. FormatRate(rate) .. " (" .. ShortNumber(sum) .. ")", chatType)
    else
      AnnounceLine(n .. ". " .. name .. " " .. ShortNumber(sum) .. " (" .. FormatRate(rate) .. ")", chatType)
    end
  end
end

local reportMenu
local reportSource

local function HideReportMenu()
  if not reportMenu then return end
  reportMenu:ClearAllPoints()
  reportMenu:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -2000, 2000)
  if reportMenu.EnableMouse then reportMenu:EnableMouse(false) end
  if reportMenu.Hide then pcall(reportMenu.Hide, reportMenu) end
  reportSource = nil
end

local function EnsureReportMenu()
  if reportMenu then return reportMenu end
  local menu = CreateFrame("Frame", "QtUIMeterReportMenu", UIParent)
  menu:SetFrameStrata("TOOLTIP")
  menu:SetFrameLevel(200)
  if menu.SetBackdrop then
    pcall(menu.SetBackdrop, menu, {
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 8, edgeSize = 10,
      insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    if menu.SetBackdropColor then menu:SetBackdropColor(.04, .05, .06, .96) end
    if menu.SetBackdropBorderColor then menu:SetBackdropBorderColor(.25, .34, .36, 1) end
  end
  local channels = {
    { "SAY", "Say" },
    { "PARTY", "Party" },
    { "RAID", "Raid" },
  }
  local rowH = 18
  local width = 72
  local height = 8 + table.getn(channels) * rowH
  menu:ClearAllPoints()
  menu:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -2000, 2000)
  menu:SetPoint("BOTTOMRIGHT", UIParent, "TOPLEFT", -2000 + width, 2000 - height)
  local i
  for i = 1, table.getn(channels) do
    local spec = channels[i]
    local btn = CreateFrame("Button", nil, menu)
    btn:SetPoint("TOPLEFT", menu, "TOPLEFT", 4, -(4 + (i - 1) * rowH))
    btn:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -4, -(4 + (i - 1) * rowH))
    btn:SetPoint("BOTTOMLEFT", menu, "TOPLEFT", 4, -(4 + i * rowH))
    btn:EnableMouse(true)
    btn:RegisterForClicks("LeftButtonUp")
    btn.chatType = spec[1]
    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.text:SetPoint("LEFT", btn, "LEFT", 6, 0)
    btn.text:SetText(spec[2])
    btn:SetScript("OnEnter", function()
      if this.text then this.text:SetTextColor(1, .9, .48) end
    end)
    btn:SetScript("OnLeave", function()
      if this.text then this.text:SetTextColor(1, .82, .2) end
    end)
    btn:SetScript("OnClick", function()
      local source = reportSource
      HideReportMenu()
      if source then ReportMeter(source, this.chatType) end
    end)
  end
  menu:EnableMouse(true)
  menu:SetScript("OnLeave", function()
    local focus = GetMouseFocus and GetMouseFocus()
    if focus and focus.GetParent and focus:GetParent() == this then return end
    HideReportMenu()
  end)
  reportMenu = menu
  HideReportMenu()
  return menu
end

local function ToggleReportMenu(anchor, frame)
  local menu = EnsureReportMenu()
  if reportSource == frame and menu.IsShown and menu:IsShown() then
    HideReportMenu()
    return
  end
  reportSource = frame
  menu:ClearAllPoints()
  local width, height = 72, 62
  menu:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -2)
  menu:SetPoint("BOTTOMLEFT", anchor, "BOTTOMRIGHT", -width, -2 - height)
  if menu.EnableMouse then menu:EnableMouse(true) end
  if menu.Show then pcall(menu.Show, menu) end
  if menu.SetFrameLevel then menu:SetFrameLevel(200) end
end

function QtUI:FillMeterDemo()
  local names = { "Thrall", "Jaina", "Sylvanas", "Anduin", "Valeera", "Medivh", "Tyrande", "Gul'dan" }
  local classes = { "SHAMAN", "MAGE", "HUNTER", "PRIEST", "ROGUE", "MAGE", "DRUID", "WARLOCK" }
  data.damage[0] = {}
  data.damage[1] = {}
  data.heal[0] = {}
  data.heal[1] = {}
  local i
  for i = 1, table.getn(names) do
    local name = names[i]
    data.classes[name] = classes[i]
    local dmg = 14000 - i * 1300
    local heal = 9000 - i * 800
    data.damage[1][name] = { _sum = dmg, _ctime = 28, ["Auto Hit"] = math.floor(dmg * .35), ["Wrath"] = math.floor(dmg * .65) }
    data.damage[0][name] = { _sum = dmg * 3, _ctime = 96, ["Auto Hit"] = math.floor(dmg * 1.1), ["Wrath"] = math.floor(dmg * 1.9) }
    data.heal[1][name] = { _sum = heal, _ctime = 28, ["Healing Touch"] = heal }
    data.heal[0][name] = { _sum = heal * 3, _ctime = 96, ["Healing Touch"] = heal * 3 }
  end
  local me = UnitName and UnitName("player")
  if me and me ~= "" then
    local _, class = UnitClass("player")
    data.classes[me] = class
    data.damage[1][me] = { _sum = 16200, _ctime = 28, ["Auto Hit"] = 5400, ["Starfire"] = 10800 }
    data.damage[0][me] = { _sum = 48600, _ctime = 96, ["Auto Hit"] = 16200, ["Starfire"] = 32400 }
    data.heal[1][me] = { _sum = 4100, _ctime = 28, ["Rejuvenation"] = 4100 }
    data.heal[0][me] = { _sum = 12300, _ctime = 96, ["Rejuvenation"] = 12300 }
  end
  MarkMetersDirty()
  if self.ApplyDamageMeterLayout then self:ApplyDamageMeterLayout() end
end

local function ResetSegment(segmentId)
  segmentId = tonumber(segmentId)
  if segmentId ~= 0 and segmentId ~= 1 then return end
  data.damage[segmentId] = {}
  data.heal[segmentId] = {}
  MarkMetersDirty()
end

local function PersistMeters()
  if not QtUI.GetLayout then return end
  local layout = QtUI:GetLayout()
  if not layout then return end
  layout.meterWindows = {}
  local frames = QtUI.meterFrames
  if not frames then return end
  local i
  for i = 1, table.getn(frames) do
    local frame = frames[i]
    table.insert(layout.meterWindows, {
      id = frame.meterId,
      view = frame.view,
      segment = frame.segment,
    })
  end
end

local function MeterLayout()
  local width, bars, barH, spacing = 190, 8, 16, 0
  if QtUI.GetLayout then
    local layout = QtUI:GetLayout()
    if layout then
      width = tonumber(layout.meterWidth) or width
      bars = tonumber(layout.meterBars) or bars
      barH = tonumber(layout.meterBarHeight) or barH
      spacing = tonumber(layout.meterBarSpacing) or spacing
    end
  end
  if width < 140 then width = 140 end
  if width > 400 then width = 400 end
  if bars < MIN_BARS then bars = MIN_BARS end
  if bars > MAX_BARS then bars = MAX_BARS end
  if barH < 12 then barH = 12 end
  if barH > 24 then barH = 24 end
  if spacing < 0 then spacing = 0 end
  if spacing > 8 then spacing = 8 end
  local height = TITLE_H + bars * barH + (bars - 1) * spacing + METER_PAD
  return width, height, bars, barH, spacing
end

local function SizeMeterFrame(frame, width, height)
  if not frame then return end
  if frame.SetWidth then
    frame:SetWidth(width + 1)
    if frame.SetHeight then frame:SetHeight(height + 1) end
    frame:SetWidth(width)
    if frame.SetHeight then frame:SetHeight(height) end
  end
end

local function PlaceBar(bar, frame, index, barH, visible, spacing)
  if not bar then return end
  if index <= visible then
    spacing = spacing or 0
    local y = TITLE_H + 2 + (index - 1) * (barH + spacing)
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -y)
    bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -y)
    bar:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 4, -(y + barH))
    if bar.SetHeight then
      bar:SetHeight(barH + 1)
      bar:SetHeight(barH)
    end
    if bar.EnableMouse then bar:EnableMouse(true) end
    if bar.SetAlpha then bar:SetAlpha(1) end
    if bar.Show then pcall(bar.Show, bar) end
  else
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -2000, 2000)
    if bar.EnableMouse then bar:EnableMouse(false) end
    if bar.SetAlpha then bar:SetAlpha(0) end
  end
end

local function RefreshMeter(frame)
  if not frame then return end
  local view = frame.view or "damage"
  local segmentId = frame.segment or 1
  local store = view == "heal" and data.heal or data.damage
  local segment = store[segmentId] or {}
  local byRate = view == "dps"
  local keys = SortedNames(segment, byRate)
  local best = 0
  local bestRate = 0
  local total = 0
  local n
  for n = 1, table.getn(keys) do
    local row = segment[keys[n]]
    local sum = row._sum or 0
    local ctime = row._ctime or 1
    if ctime < 1 then ctime = 1 end
    local rate = sum / ctime
    total = total + sum
    if sum > best then best = sum end
    if rate > bestRate then bestRate = rate end
  end
  if best < 1 then best = 1 end
  if bestRate < .01 then bestRate = 1 end

  if frame.titleText then
    frame.titleText:SetText(ModeLabel(view, segmentId))
  end

  local _, _, visible = MeterLayout()
  for n = 1, MAX_BARS do
    local bar = frame.bars[n]
    if bar then
      local name = n <= visible and keys[n] or nil
      if name and segment[name] then
        local row = segment[name]
        local sum = row._sum or 0
        local ctime = row._ctime or 1
        if ctime < 1 then ctime = 1 end
        local rate = sum / ctime
        local pct = total > 0 and (sum / total * 100) or 0
        if byRate then
          bar:SetMinMaxValues(0, bestRate)
          bar:SetValue(rate)
          bar.right:SetText(FormatRate(rate) .. "  " .. ShortNumber(sum) .. "  " .. string.format("%.0f%%", pct))
        else
          bar:SetMinMaxValues(0, best)
          bar:SetValue(sum)
          bar.right:SetText(ShortNumber(sum) .. "  " .. FormatRate(rate) .. "  " .. string.format("%.0f%%", pct))
        end
        local r, g, b = ClassColor(name)
        bar:SetStatusBarColor(r, g, b, .85)
        bar.left:SetText(n .. ". " .. name)
        bar.unit = name
        bar.row = row
      else
        bar:SetValue(0)
        bar.left:SetText("")
        bar.right:SetText("")
        bar.unit = nil
        bar.row = nil
      end
    end
  end
end

local function ShowBarTooltip()
  if not this.unit or not this.row or not GameTooltip then return end
  GameTooltip:SetOwner(this, "ANCHOR_NONE")
  GameTooltip:ClearLines()
  GameTooltip:AddLine(this.unit)
  GameTooltip:AddDoubleLine("Total", ShortNumber(this.row._sum or 0))
  local ctime = this.row._ctime or 1
  if ctime < 1 then ctime = 1 end
  GameTooltip:AddDoubleLine("Per second", string.format("%.1f", (this.row._sum or 0) / ctime))
  GameTooltip:AddLine(" ")
  local spells = {}
  local key
  for key in pairs(this.row) do
    if not INTERNALS[key] then table.insert(spells, key) end
  end
  table.sort(spells, function(a, b)
    return (this.row[b] or 0) < (this.row[a] or 0)
  end)
  local i
  local max = table.getn(spells)
  if max > 8 then max = 8 end
  for i = 1, max do
    GameTooltip:AddDoubleLine(spells[i], ShortNumber(this.row[spells[i]] or 0))
  end
  GameTooltip:Show()
  GameTooltip:ClearAllPoints()
  GameTooltip:SetPoint("LEFT", this, "RIGHT", 6, 0)
end

local function PlaceMeterButton(btn, frame, fromRight)
  local x = -(2 + fromRight * (BTN + 2))
  btn:ClearAllPoints()
  btn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", x, -2)
  btn:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", x, -(2 + BTN))
  btn:SetPoint("TOPLEFT", frame, "TOPRIGHT", x - BTN, -2)
end

local function TitleInset(frame)
  return (BTN + 2) * 2 + 4
end

local function TooltipOn(frame, lines)
  frame:SetScript("OnEnter", function()
    if not GameTooltip then return end
    GameTooltip:SetOwner(this, "ANCHOR_NONE")
    GameTooltip:ClearLines()
    local i
    for i = 1, table.getn(lines) do
      if i == 1 then
        GameTooltip:AddLine(lines[i])
      else
        GameTooltip:AddLine(lines[i], .8, .85, .9)
      end
    end
    GameTooltip:Show()
    GameTooltip:ClearAllPoints()
    GameTooltip:SetPoint("BOTTOM", this, "TOP", 0, 4)
  end)
  frame:SetScript("OnLeave", function()
    if GameTooltip then GameTooltip:Hide() end
  end)
end

local METER_ICON = "Interface\\AddOns\\QtUI\\Media\\"

local function MakeMeterButton(parent, caption, lines, onClick, icon)
  local btn = CreateFrame("Button", nil, parent)
  btn:EnableMouse(true)
  btn:RegisterForClicks("LeftButtonUp")
  if btn.SetBackdrop then
    pcall(btn.SetBackdrop, btn, {
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 8, edgeSize = 8,
      insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    if btn.SetBackdropColor then btn:SetBackdropColor(.12, .12, .12, .9) end
    if btn.SetBackdropBorderColor then btn:SetBackdropBorderColor(.35, .35, .35, 1) end
  end
  if icon then
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 5, -5)
    btn.icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -5, 5)
    btn.icon:SetTexture(METER_ICON .. icon)
  else
    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.text:SetPoint("CENTER", btn, "CENTER", 0, 0)
    btn.text:SetText(caption)
  end
  btn:SetScript("OnClick", onClick)
  TooltipOn(btn, lines)
  return btn
end

local function LayoutMeterChrome(frame)
  PlaceMeterButton(frame.btnReset, frame, 0)
  if frame.btnReport then PlaceMeterButton(frame.btnReport, frame, 1) end
  frame.title:ClearAllPoints()
  frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -2)
  frame.title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -TitleInset(frame), -2)
  if frame.title.SetHeight then
    frame.title:SetHeight(TITLE_H + 1)
    frame.title:SetHeight(TITLE_H)
  end
end

local function ApplyMeterWindow(frame)
  if not frame then return end
  local width, height, visible, barH, spacing = MeterLayout()
  SizeMeterFrame(frame, width, height)
  LayoutMeterChrome(frame)
  local i
  for i = 1, MAX_BARS do
    PlaceBar(frame.bars[i], frame, i, barH, visible, spacing)
  end
  frame.dirty = true
  RefreshMeter(frame)
end

local function PlaceMeterWindow(frame)
  if not frame then return end
  local key = MeterMoveKey(frame.meterId)
  if QtUIDB.positions and QtUIDB.positions[key] then
    local pos = QtUIDB.positions[key]
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", pos.x or 20, pos.y or 220)
    return
  end
  local index = 1
  local i
  for i = 1, table.getn(QtUI.meterFrames or {}) do
    if QtUI.meterFrames[i] == frame then index = i end
  end
  frame:ClearAllPoints()
  frame:SetPoint("RIGHT", UIParent, "RIGHT", -20 - ((index - 1) * 24), -80 - ((index - 1) * 28))
end

local function ShowMeterWindow(frame)
  if not frame then return end
  PlaceMeterWindow(frame)
  if frame.Show then pcall(frame.Show, frame) end
  if frame.EnableMouse then frame:EnableMouse(true) end
  if frame.SetAlpha then frame:SetAlpha(1) end
end

local function HideMeterWindow(frame)
  if not frame then return end
  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -2000, 2000)
  if frame.EnableMouse then frame:EnableMouse(false) end
  if frame.Hide then pcall(frame.Hide, frame) end
end

local function RefreshMeterCanClose()
  local frames = QtUI.meterFrames
  if not frames then return end
  local i
  for i = 1, table.getn(frames) do
    LayoutMeterChrome(frames[i])
  end
end

local CreateMeterWindow

local function NextMeterId()
  local used = {}
  local i
  for i = 1, table.getn(QtUI.meterFrames or {}) do
    used[QtUI.meterFrames[i].meterId] = true
  end
  for i = 1, MAX_WINDOWS do
    if not used[i] then return i end
  end
  return nil
end

local function NextUnusedMode()
  local used = {}
  local i
  for i = 1, table.getn(QtUI.meterFrames or {}) do
    local frame = QtUI.meterFrames[i]
    used[ModeIndex(frame.view, frame.segment)] = true
  end
  for i = 1, table.getn(MODES) do
    if not used[i] then return MODES[i] end
  end
  return MODES[1]
end

local function CycleMeterMode(frame, dir)
  local i = ModeIndex(frame.view, frame.segment) + (dir or 1)
  local n = table.getn(MODES)
  if i > n then i = 1 end
  if i < 1 then i = n end
  frame.view = MODES[i].view
  frame.segment = MODES[i].segment
  PersistMeters()
  RefreshMeter(frame)
end

function QtUI:CloseDamageMeterWindow(frame)
  if not frame or not self.meterFrames then return end
  if table.getn(self.meterFrames) <= 1 then return end
  local keep = {}
  local i
  for i = 1, table.getn(self.meterFrames) do
    if self.meterFrames[i] ~= frame then
      table.insert(keep, self.meterFrames[i])
    end
  end
  HideMeterWindow(frame)
  self.meterFrames = keep
  self.meterFrame = keep[1]
  RefreshMeterCanClose()
  PersistMeters()
  if self.moveMode and self.SetMoveMode then self:SetMoveMode(true) end
end

function QtUI:CloseLastDamageMeterWindow()
  if not self.meterFrames then return end
  local count = table.getn(self.meterFrames)
  if count <= 1 then return end
  self:CloseDamageMeterWindow(self.meterFrames[count])
end

function QtUI:MeterWindowCount()
  if not self.meterFrames then return 0 end
  return table.getn(self.meterFrames)
end

function QtUI:AddDamageMeterWindow(view, segment)
  if not self.meterFrames then return end
  if table.getn(self.meterFrames) >= MAX_WINDOWS then return end
  local id = NextMeterId()
  if not id then return end
  local mode = NextUnusedMode()
  if view then mode = { view = view, segment = segment or 1 } end
  local frame = CreateMeterWindow(id, mode.view, mode.segment)
  if not frame then return end
  table.insert(self.meterFrames, frame)
  RefreshMeterCanClose()
  PersistMeters()
  if self:IsFeatureEnabled("damageMeter") then
    ShowMeterWindow(frame)
    ApplyMeterWindow(frame)
  else
    HideMeterWindow(frame)
  end
  if self.RegisterMovable then
    self:RegisterMovable(MeterMoveKey(frame.meterId), "Damage Meter " .. frame.meterId, frame)
  end
  if self.moveMode and self.SetMoveMode then self:SetMoveMode(true) end
  return frame
end

CreateMeterWindow = function(id, view, segment)
  local width, height = MeterLayout()
  local frame = QtUI:CreatePanel("QtUIDamageMeter" .. tostring(id), UIParent, 4)
  SizeMeterFrame(frame, width, height)
  frame:SetFrameStrata("MEDIUM")
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame.meterId = id
  frame.view = view or "damage"
  frame.segment = segment
  if frame.segment ~= 0 then frame.segment = 1 end
  frame.dirty = true
  frame.bars = {}

  frame.title = CreateFrame("Button", nil, frame)
  frame.title:EnableMouse(true)
  frame.title:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  frame.titleText = frame.title:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  frame.titleText:SetAllPoints(frame.title)
  frame.titleText:SetJustifyH("LEFT")
  frame.titleText:SetText(ModeLabel(frame.view, frame.segment))
  frame.title:SetScript("OnClick", function()
    if arg1 == "RightButton" then
      CycleMeterMode(frame, -1)
    else
      CycleMeterMode(frame, 1)
    end
  end)
  TooltipOn(frame.title, {
    "Damage Meter",
    "Left-click: next view",
    "Right-click: previous view",
    "Views: Current/Overall Damage, DPS, Heal",
  })

  frame.btnReset = MakeMeterButton(frame, "R", { "Reset" }, function()
    ResetSegment(frame.segment)
    RefreshMeter(frame)
  end, "reset")
  frame.btnReport = MakeMeterButton(frame, "P", { "Report" }, function()
    ToggleReportMenu(this, frame)
  end, "announce")

  local i
  for i = 1, MAX_BARS do
    local bar = CreateFrame("StatusBar", nil, frame)
    bar:SetStatusBarTexture(QtUI.media.statusbar)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar:EnableMouse(true)
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints(bar)
    bar.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    bar.bg:SetVertexColor(.04, .05, .06, .7)
    bar.left = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.left:SetPoint("LEFT", bar, "LEFT", 4, 0)
    bar.left:SetJustifyH("LEFT")
    bar.right = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.right:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    bar.right:SetJustifyH("RIGHT")
    bar:SetScript("OnEnter", ShowBarTooltip)
    bar:SetScript("OnLeave", function()
      if GameTooltip then GameTooltip:Hide() end
    end)
    frame.bars[i] = bar
  end

  frame.elapsed = 0
  frame:SetScript("OnUpdate", function()
    this.elapsed = this.elapsed + (arg1 or 0)
    if this.elapsed >= .2 then
      this.elapsed = 0
      if this.dirty then
        this.dirty = nil
        RefreshMeter(this)
      end
    end
  end)

  LayoutMeterChrome(frame)
  PlaceMeterWindow(frame)
  return frame
end

function QtUI:ShowDamageMeter()
  local i
  for i = 1, table.getn(self.meterFrames or {}) do
    ShowMeterWindow(self.meterFrames[i])
  end
end

function QtUI:HideDamageMeter()
  local i
  for i = 1, table.getn(self.meterFrames or {}) do
    HideMeterWindow(self.meterFrames[i])
  end
end

function QtUI:ApplyDamageMeterLayout()
  local i
  for i = 1, table.getn(self.meterFrames or {}) do
    ApplyMeterWindow(self.meterFrames[i])
  end
end

function QtUI:SetupDamageMeter()
  if self.meterFrames and table.getn(self.meterFrames) > 0 then
    if self:IsFeatureEnabled("damageMeter") then
      self:ShowDamageMeter()
      self:ApplyDamageMeterLayout()
    else
      self:HideDamageMeter()
    end
    return
  end

  self.meterFrames = {}
  local specs = nil
  if self.GetLayout then
    local layout = self:GetLayout()
    if layout and type(layout.meterWindows) == "table" and table.getn(layout.meterWindows) > 0 then
      specs = layout.meterWindows
    end
  end
  if not specs then
    specs = { { id = 1, view = "damage", segment = 1 } }
  end

  local i
  for i = 1, table.getn(specs) do
    if table.getn(self.meterFrames) >= MAX_WINDOWS then break end
    local spec = specs[i]
    local id = tonumber(spec.id) or i
    local frame = CreateMeterWindow(id, spec.view, spec.segment)
    table.insert(self.meterFrames, frame)
    if self.RegisterMovable then
      self:RegisterMovable(MeterMoveKey(id), "Damage Meter " .. id, frame)
    end
  end

  self.meterFrame = self.meterFrames[1]
  RefreshMeterCanClose()
  PersistMeters()

  HookChatMeter(DEFAULT_CHAT_FRAME)
  HookChatMeter(ChatFrame1)
  HookChatMeter(ChatFrame2)

  self:ApplyDamageMeterLayout()
  if self:IsFeatureEnabled("damageMeter") then
    self:ShowDamageMeter()
  else
    self:HideDamageMeter()
  end
end
