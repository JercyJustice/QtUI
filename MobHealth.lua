-- Enemy NPC HP from the static 1.12 table. No combat estimate.

local function Enabled()
  if not QtUI.GetLayout then return true end
  local layout = QtUI:GetLayout()
  local value = layout and layout.estimateMobHealth
  return value ~= false and value ~= 0 and value ~= "0"
end

local function True(v)
  return v == true or v == 1 or v == "1"
end

local function NeedsLookup(unit)
  if not unit or not Enabled() then return nil end
  if type(UnitIsPlayer) == "function" then
    local ok, v = pcall(UnitIsPlayer, unit)
    if ok and True(v) then return nil end
  end
  local max = tonumber(UnitHealthMax(unit)) or 0
  if max > 100 or max < 1 then return nil end
  if type(UnitCanAttack) == "function" then
    local ok, v = pcall(UnitCanAttack, "player", unit)
    if ok and True(v) then return true end
  end
  return nil
end

local function ClassRank(classif)
  if classif == "elite" then return 1 end
  if classif == "rareelite" then return 2 end
  if classif == "worldboss" then return 3 end
  if classif == "rare" then return 4 end
  return 0
end

local function RankFit(have, want)
  if have == want then return 1 end
  if want == 4 and have == 0 then return 2 end
  if want == 2 and have == 1 then return 2 end
  return nil
end

local function InterpHp(minl, maxl, minh, maxh, level)
  if maxl <= minl then return minh end
  if level <= minl then return minh end
  if level >= maxl then return maxh end
  return minh + (maxh - minh) * (level - minl) / (maxl - minl)
end

local function StaticMax(unit)
  local static = QtUI.MobHealthStatic
  if not static then return nil end
  local name = UnitName(unit)
  if not name then return nil end
  local row = static[name]
  if not row then return nil end
  local level = tonumber(UnitLevel(unit)) or 0
  local classif = "normal"
  if type(UnitClassification) == "function" then
    local ok, v = pcall(UnitClassification, unit)
    if ok and type(v) == "string" and v ~= "" then classif = v end
  end
  local want = ClassRank(classif)
  local n = table.getn(row)
  local best, bestScore
  local i = 1
  while i + 4 <= n do
    local minl, maxl, minh, maxh, rank = row[i], row[i + 1], row[i + 2], row[i + 3], row[i + 4]
    local fit = RankFit(rank, want)
    if fit then
      local hp, score
      if level < 1 then
        hp = maxh
        score = fit * 1000 - maxl
      elseif level >= minl and level <= maxl then
        hp = InterpHp(minl, maxl, minh, maxh, level)
        score = fit
      else
        local dist = minl - level
        if dist < 0 then dist = level - maxl end
        if dist <= 2 then
          hp = InterpHp(minl, maxl, minh, maxh, level)
          score = fit * 100 + dist
        end
      end
      if hp and (not bestScore or score < bestScore) then
        best = hp
        bestScore = score
      end
    end
    i = i + 5
  end
  if best and best >= 20 then return best end
  return nil
end

function QtUI:GetMobHealth(unit)
  if not NeedsLookup(unit) then return nil end
  local pct = tonumber(UnitHealth(unit)) or 0
  if pct < 0 then pct = 0 end
  if pct > 100 then pct = 100 end
  local maxHp = StaticMax(unit)
  if maxHp and maxHp >= 20 then
    local cur = math.floor(pct / 100 * maxHp + .5)
    if pct > 0 and cur < 1 then cur = 1 end
    if pct <= 0 then cur = 0 end
    return cur, math.floor(maxHp + .5), "hp"
  end
  return pct, nil, "pct"
end

function QtUI:SetupMobHealth()
  self.mobHealthReady = true
end
