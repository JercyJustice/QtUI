-- Profile save/load and share. Import always takes a name so the same
-- string can be imported more than once for testing.

local function CopyTable(src)
  if type(src) ~= "table" then return src end
  local copy = {}
  local k, v
  for k, v in pairs(src) do
    if type(v) == "table" then
      copy[k] = CopyTable(v)
    else
      copy[k] = v
    end
  end
  return copy
end

local function CurrentScreen()
  local width = (UIParent and UIParent.GetWidth and UIParent:GetWidth()) or 1024
  local height = (UIParent and UIParent.GetHeight and UIParent:GetHeight()) or 768
  if width < 200 then width = 1024 end
  if height < 200 then height = 768 end
  return width, height
end

local function JsonEscape(str)
  str = string.gsub(str, "\\", "\\\\")
  str = string.gsub(str, "\"", "\\\"")
  str = string.gsub(str, "\n", "\\n")
  str = string.gsub(str, "\r", "\\r")
  str = string.gsub(str, "\t", "\\t")
  return str
end

local function IsArray(value)
  local n = table.getn(value)
  local count = 0
  local k
  for k in pairs(value) do
    if type(k) ~= "number" or k < 1 or k ~= math.floor(k) then
      return false
    end
    if k > n then n = k end
    count = count + 1
  end
  return count == n
end

local function Pad(level)
  local out = ""
  local i
  for i = 1, level do
    out = out .. "  "
  end
  return out
end

local function ToJSON(value, level, compact)
  level = level or 0
  local t = type(value)
  if value == nil then
    return "null"
  elseif t == "boolean" then
    if value then return "true" end
    return "false"
  elseif t == "number" then
    return tostring(value)
  elseif t == "string" then
    return "\"" .. JsonEscape(value) .. "\""
  elseif t ~= "table" then
    return "null"
  end
  local pad = Pad(level)
  local inner = Pad(level + 1)
  if IsArray(value) then
    local n = table.getn(value)
    if n == 0 then return "[]" end
    local i
    local out = "["
    for i = 1, n do
      if i > 1 then out = out .. "," end
      out = out .. ToJSON(value[i], level + 1, compact)
    end
    return out .. "]"
  end
  local keys = {}
  local k
  for k in pairs(value) do
    table.insert(keys, k)
  end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  local count = table.getn(keys)
  if count == 0 then return "{}" end
  local out = "{"
  local i
  for i = 1, count do
    if i > 1 then
      if compact then out = out .. "," else out = out .. "," end
    end
    local key = keys[i]
    if compact then
      out = out .. "\"" .. JsonEscape(tostring(key)) .. "\":" .. ToJSON(value[key], level + 1, true)
    else
      out = out .. inner .. "\"" .. JsonEscape(tostring(key)) .. "\": " .. ToJSON(value[key], level + 1, nil)
    end
  end
  if compact then return out .. "}" end
  return out .. "}"
end

local function FromJSON(str)
  if type(str) ~= "string" then return nil, "Not a string" end
  local i = 1
  local n = string.len(str)

  local function Peek()
    return string.sub(str, i, i)
  end

  local function SkipWS()
    while i <= n do
      local c = string.sub(str, i, i)
      if c ~= " " and c ~= "\n" and c ~= "\r" and c ~= "\t" then return end
      i = i + 1
    end
  end

  local parseValue

  local function ParseString()
    if Peek() ~= "\"" then return nil, "Expected string" end
    i = i + 1
    local out = ""
    while i <= n do
      local c = string.sub(str, i, i)
      if c == "\"" then
        i = i + 1
        return out
      elseif c == "\\" then
        local e = string.sub(str, i + 1, i + 1)
        if e == "n" then out = out .. "\n"
        elseif e == "r" then out = out .. "\r"
        elseif e == "t" then out = out .. "\t"
        elseif e == "\"" then out = out .. "\""
        elseif e == "\\" then out = out .. "\\"
        elseif e == "/" then out = out .. "/"
        elseif e == "u" then
          i = i + 4
          out = out .. "?"
        else
          out = out .. e
        end
        i = i + 2
      else
        out = out .. c
        i = i + 1
      end
    end
    return nil, "Unterminated string"
  end

  local function ParseNumber()
    -- ^ only matches the start of the whole string, so search a suffix.
    local rest = string.sub(str, i)
    local s, e = string.find(rest, "^[-+]?%d+%.?%d*[eE]?[-+]?%d*")
    if not s then return nil, "Expected number" end
    local num = tonumber(string.sub(rest, s, e))
    i = i + e
    if num == nil then return nil, "Bad number" end
    return num
  end

  local function ParseLiteral(word, value)
    if string.sub(str, i, i + string.len(word) - 1) ~= word then
      return nil, "Expected " .. word
    end
    i = i + string.len(word)
    return value
  end

  local function ParseArray()
    i = i + 1
    local arr = {}
    SkipWS()
    if Peek() == "]" then
      i = i + 1
      return arr
    end
    while i <= n do
      local val, err = parseValue()
      if err then return nil, err end
      table.insert(arr, val)
      SkipWS()
      local c = Peek()
      if c == "]" then
        i = i + 1
        return arr
      elseif c == "," then
        i = i + 1
      else
        return nil, "Expected comma in array"
      end
    end
    return nil, "Unterminated array"
  end

  local function ParseObject()
    i = i + 1
    local obj = {}
    SkipWS()
    if Peek() == "}" then
      i = i + 1
      return obj
    end
    while i <= n do
      SkipWS()
      local key, kerr = ParseString()
      if kerr then return nil, kerr end
      SkipWS()
      if Peek() ~= ":" then return nil, "Expected colon" end
      i = i + 1
      local val, verr = parseValue()
      if verr then return nil, verr end
      obj[key] = val
      SkipWS()
      local c = Peek()
      if c == "}" then
        i = i + 1
        return obj
      elseif c == "," then
        i = i + 1
      else
        return nil, "Expected comma in object"
      end
    end
    return nil, "Unterminated object"
  end

  parseValue = function()
    SkipWS()
    local c = Peek()
    if c == "{" then return ParseObject()
    elseif c == "[" then return ParseArray()
    elseif c == "\"" then return ParseString()
    elseif c == "t" then return ParseLiteral("true", true)
    elseif c == "f" then return ParseLiteral("false", false)
    elseif c == "n" then return ParseLiteral("null", nil)
    elseif c == "-" or c == "+" or (c >= "0" and c <= "9") then return ParseNumber()
    end
    return nil, "Unexpected character"
  end

  local value, err = parseValue()
  if err then return nil, err end
  return value
end

-- Legacy QtUI:1! decoder. New exports are JSON (QtUI:2!).
local function DecodeLua(encoded)
  if type(loadstring) ~= "function" then return nil, "Cannot decode" end
  local chunk, err = loadstring("return " .. encoded)
  if not chunk then return nil, err or "Invalid profile" end
  local ok, snap = pcall(chunk)
  if not ok or type(snap) ~= "table" then return nil, "Invalid profile" end
  return snap
end

local function RemapPoint(x, y, srcW, srcH, dstW, dstH)
  x = tonumber(x)
  y = tonumber(y)
  if not x or not y then return x, y end
  if srcW and srcH and srcW >= 200 and srcH >= 200 and dstW and dstH then
    if srcW ~= dstW then x = x * (dstW / srcW) end
    if srcH ~= dstH then y = y * (dstH / srcH) end
  end
  if x < 0 then x = 0 end
  if y < 0 then y = 0 end
  if dstW and x > dstW - 24 then x = dstW - 24 end
  if dstH and y > dstH - 24 then y = dstH - 24 end
  return x, y
end

local function RemapPositions(positions, srcW, srcH)
  if type(positions) ~= "table" then return {} end
  local dstW, dstH = CurrentScreen()
  local out = {}
  local key, pos
  for key, pos in pairs(positions) do
    if type(pos) == "table" and (pos.sh or pos.sv or pos.gh or pos.gv) then
      out[key] = CopyTable(pos)
    elseif type(pos) == "table" and pos.x ~= nil and pos.y ~= nil then
      local x, y = RemapPoint(pos.x, pos.y, srcW, srcH, dstW, dstH)
      out[key] = { x = x, y = y }
    else
      out[key] = CopyTable(pos)
    end
  end
  return out
end

local function Trim(str)
  if type(str) ~= "string" then return "" end
  return string.gsub(str, "^%s*(.-)%s*$", "%1")
end

local function SnapshotCurrent()
  if not QtUIDB then QtUIDB = {} end
  local width, height = CurrentScreen()
  return {
    features = CopyTable(QtUIDB.features or {}),
    layout = CopyTable(QtUIDB.layout or {}),
    positions = CopyTable(QtUIDB.positions or {}),
    settingsButtonPosition = CopyTable(QtUIDB.settingsButtonPosition),
    screen = { w = width, h = height },
  }
end

local function ApplySnapshot(snap)
  if type(snap) ~= "table" then return end
  if type(snap.features) == "table" then QtUIDB.features = CopyTable(snap.features) end
  if type(snap.layout) == "table" then QtUIDB.layout = CopyTable(snap.layout) end
  local srcW, srcH
  if type(snap.screen) == "table" then
    srcW = tonumber(snap.screen.w) or tonumber(snap.screen.width)
    srcH = tonumber(snap.screen.h) or tonumber(snap.screen.height)
  end
  if type(snap.positions) == "table" then
    QtUIDB.positions = RemapPositions(snap.positions, srcW, srcH)
  end
  if snap.settingsButtonPosition ~= nil then
    QtUIDB.settingsButtonPosition = CopyTable(snap.settingsButtonPosition)
  end
  if QtUI.EnsureFeatureDefaults then QtUI:EnsureFeatureDefaults() end
  if QtUI.EnsureLayoutDefaults then QtUI:EnsureLayoutDefaults() end
  if QtUI.ApplyLayout then QtUI:ApplyLayout() end
  if QtUI.ApplySavedPositions then QtUI:ApplySavedPositions() end
  if QtUI.RefreshSettingsButton and not (QtUIDB.positions and QtUIDB.positions.minimapIcon) then
    QtUI:RefreshSettingsButton()
  end
end

function QtUI:EnsureProfiles()
  if not QtUIDB then QtUIDB = {} end
  if type(QtUIDB.profiles) ~= "table" then QtUIDB.profiles = {} end
  if type(QtUIDB.activeProfile) ~= "string" or QtUIDB.activeProfile == "" then
    QtUIDB.activeProfile = "Default"
  end
  if not QtUIDB.profiles[QtUIDB.activeProfile] then
    QtUIDB.profiles[QtUIDB.activeProfile] = SnapshotCurrent()
  end
end

function QtUI:ProfileNames()
  self:EnsureProfiles()
  local names = {}
  local name
  for name in pairs(QtUIDB.profiles) do
    table.insert(names, name)
  end
  table.sort(names)
  return names
end

function QtUI:UniqueProfileName(name)
  self:EnsureProfiles()
  name = Trim(name)
  if name == "" then name = "Import" end
  if not QtUIDB.profiles[name] then return name end
  local i = 2
  while QtUIDB.profiles[name .. " " .. i] do
    i = i + 1
  end
  return name .. " " .. i
end

function QtUI:SaveProfile(name)
  self:EnsureProfiles()
  name = Trim(name)
  if name == "" then return nil end
  QtUIDB.profiles[name] = SnapshotCurrent()
  QtUIDB.activeProfile = name
  return name
end

function QtUI:LoadProfile(name)
  self:EnsureProfiles()
  if type(name) ~= "string" or not QtUIDB.profiles[name] then return nil end
  ApplySnapshot(QtUIDB.profiles[name])
  QtUIDB.activeProfile = name
  return name
end

function QtUI:DeleteProfile(name)
  self:EnsureProfiles()
  if type(name) ~= "string" or not QtUIDB.profiles[name] then return end
  QtUIDB.profiles[name] = nil
  if QtUIDB.activeProfile == name then
    local names = self:ProfileNames()
    if table.getn(names) > 0 then
      QtUIDB.activeProfile = names[1]
    else
      QtUIDB.activeProfile = "Default"
      QtUIDB.profiles.Default = SnapshotCurrent()
    end
  end
end

function QtUI:ExportProfile()
  self:EnsureProfiles()
  return "QtUI:2!" .. ToJSON(SnapshotCurrent(), 0, true)
end

function QtUI:ImportProfile(name, encoded)
  self:EnsureProfiles()
  name = Trim(name)
  if name == "" then return nil, "Name required" end
  if type(encoded) ~= "string" then return nil, "Nothing to import" end
  encoded = Trim(encoded)
  local snap, err
  local jsonBody, luaBody
  if string.sub(encoded, 1, 7) == "QtUI:2!" then
    jsonBody = Trim(string.sub(encoded, 8))
  elseif string.sub(encoded, 1, 7) == "QtUI:1!" then
    luaBody = Trim(string.sub(encoded, 8))
  end
  if jsonBody then
    snap, err = FromJSON(jsonBody)
  elseif luaBody then
    snap, err = DecodeLua(luaBody)
  else
    snap, err = FromJSON(encoded)
    if not snap then
      snap, err = DecodeLua(encoded)
    end
  end
  if type(snap) ~= "table" then return nil, err or "Invalid profile" end
  local unique = self:UniqueProfileName(name)
  QtUIDB.profiles[unique] = snap
  return unique
end

