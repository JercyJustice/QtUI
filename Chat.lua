local leftGroups = {
  "SAY", "EMOTE", "YELL", "MONSTER_SAY", "MONSTER_EMOTE", "MONSTER_YELL",
  "CHANNEL", "SYSTEM",
}

local rightGroups = {
  "GUILD", "OFFICER", "PARTY", "RAID", "RAID_LEADER", "RAID_WARNING",
  "WHISPER", "LOOT", "MONEY", "SKILL", "COMBAT_XP_GAIN", "COMBAT_HONOR_GAIN",
}

local function SafeChatCall(func, frame, value)
  if type(func) == "function" and frame then pcall(func, frame, value) end
end

local function HideChatChrome(index)
  local names = {
    "ChatFrame" .. index .. "Tab",
    "ChatFrame" .. index .. "ButtonFrame",
    "ChatFrame" .. index .. "UpButton",
    "ChatFrame" .. index .. "DownButton",
    "ChatFrame" .. index .. "BottomButton",
  }
  for _, name in ipairs(names) do
    local frame = getglobal(name)
    if frame then
      frame:SetAlpha(0)
      frame:EnableMouse(false)
    end
  end
end

local function ConfigureChat(frame, panel, index, fontSize)
  if not frame then return end
  if panel then
    frame:SetParent(panel)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -8)
    frame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8, index == 2 and 29 or -8)
  end
  if frame.SetFading then frame:SetFading(false) end
  fontSize = tonumber(fontSize) or 12
  if QtUI.ApplyFont then
    QtUI:ApplyFont(frame, fontSize)
  elseif frame.SetFont then
    frame:SetFont("Fonts\\FRIZQT__.TTF", fontSize)
  end
  -- CreateFont defaults to black on Emberveil. Chat must stay readable.
  if frame.SetTextColor then pcall(frame.SetTextColor, frame, 1, 1, 1) end
  if frame.qtFontObject and frame.qtFontObject.SetTextColor then
    pcall(frame.qtFontObject.SetTextColor, frame.qtFontObject, 1, 1, 1)
  end
  if frame.SetMaxLines then frame:SetMaxLines(500) end
  if frame.Show then pcall(frame.Show, frame) end
  HideChatChrome(index)
  local edit = getglobal("ChatFrame" .. tostring(index) .. "EditBox")
  if edit then
    if QtUI.ApplyFont then QtUI:ApplyFont(edit, fontSize) end
    if edit.SetTextColor then pcall(edit.SetTextColor, edit, 1, 1, 1) end
    if edit.SetTextInsets then pcall(edit.SetTextInsets, edit, 6, 6, 2, 2) end
  end
end

local function SizeChatPanel(panel, key, width, height, defaultLeft, defaultBottom)
  if not panel then return end
  local left, bottom = defaultLeft, defaultBottom
  local saved = QtUIDB and QtUIDB.positions and key and QtUIDB.positions[key]
  if saved and saved.x and saved.y then
    left, bottom = saved.x, saved.y
    if saved.gv == "bottom" then
      local sh = (UIParent.GetHeight and UIParent:GetHeight()) or 768
      if sh < 200 then sh = 768 end
      if bottom > sh * .55 then
        bottom = sh - bottom - (saved.h or height)
        if bottom < 0 then bottom = 0 end
      end
    end
  end
  panel:ClearAllPoints()
  panel:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
  panel:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", left + width, bottom + height)
  if panel.SetWidth then
    panel:SetWidth(width + 1)
    panel:SetWidth(width)
  end
  if panel.SetHeight then
    panel:SetHeight(height + 1)
    panel:SetHeight(height)
  end
end

local function SocialOn(layout)
  if not layout then return true end
  local value = layout.chatSocial
  return value ~= false and value ~= 0 and value ~= "0"
end

function QtUI:IsChatSocialEnabled()
  return SocialOn(self.GetLayout and self:GetLayout())
end

local function ParkSocial(panel, frame)
  local function Park(f)
    if not f then return end
    if f.SetClampedToScreen then pcall(f.SetClampedToScreen, f, false) end
    if f.EnableMouse then pcall(f.EnableMouse, f, false) end
    if f.ClearAllPoints then
      f:ClearAllPoints()
      f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", -4000, -4000)
      f:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", -3600, -3700)
    end
  end
  if frame and panel and frame.SetParent then pcall(frame.SetParent, frame, panel) end
  Park(panel)
  Park(frame)
  HideChatChrome(2)
  Park(getglobal("ChatFrame2EditBox"))
  Park(getglobal("ChatFrame2Tab"))
end

local CLASS_HEX = {
  WARRIOR = "c79c6e", MAGE = "69ccf0", ROGUE = "fff569",
  DRUID = "ff7d0a", HUNTER = "abd473", SHAMAN = "2459ff",
  PRIEST = "ffffff", WARLOCK = "9482c9", PALADIN = "f58cba",
}

local classCache = {}

local function RememberUnit(unit)
  if type(UnitName) ~= "function" or type(UnitClass) ~= "function" then return end
  if type(UnitExists) == "function" then
    local ok, exists = pcall(UnitExists, unit)
    if not ok or not (exists == true or exists == 1 or exists == "1") then return end
  end
  local name = UnitName(unit)
  local ok, _, token = pcall(UnitClass, unit)
  if ok and name and token and CLASS_HEX[token] then
    classCache[string.lower(name)] = token
  end
end

local function HexForName(name)
  if type(name) ~= "string" or name == "" then return "ffffff" end
  RememberUnit("player")
  RememberUnit("target")
  RememberUnit("mouseover")
  local token = classCache[string.lower(name)]
  if token and CLASS_HEX[token] then return CLASS_HEX[token] end
  return "ffffff"
end

local function ColorPlayerNames(text, byClass)
  if type(text) ~= "string" then return text end
  if not string.find(text, "|Hplayer:", 1, true) then return text end
  local out = ""
  local pos = 1
  local len = string.len(text)
  while pos <= len do
    local startAt, payloadEnd, payload = string.find(text, "|Hplayer:([^|]+)|h", pos)
    if not startAt then
      out = out .. string.sub(text, pos)
      break
    end
    local close = string.find(text, "|h", payloadEnd + 1, true)
    if not close then
      out = out .. string.sub(text, pos)
      break
    end
    local display = string.sub(text, payloadEnd + 1, close - 1)
    display = string.gsub(display, "|c%x%x%x%x%x%x%x%x", "")
    display = string.gsub(display, "|r", "")
    local name = payload
    local colon = string.find(name, ":", 1, true)
    if colon then name = string.sub(name, 1, colon - 1) end
    local hex = "ffffff"
    if byClass then hex = HexForName(name) end
    out = out .. string.sub(text, pos, startAt - 1) .. "|Hplayer:" .. payload .. "|h|cff" .. hex .. display .. "|r|h"
    pos = close + 2
  end
  return out
end

local function TimeStamp()
  if type(date) == "function" then
    local ok, value = pcall(date, "%H:%M")
    if ok and type(value) == "string" and string.len(value) >= 4 then return value end
  end
  if type(GetGameTime) == "function" then
    local hour, minute = GetGameTime()
    return string.format("%02d:%02d", tonumber(hour) or 0, tonumber(minute) or 0)
  end
  return nil
end

local function HookChatTimestamp(frame)
  if not frame or frame.qtTimeHooked then return end
  local original = frame.AddMessage
  if type(original) ~= "function" then return end
  frame.qtTimeHooked = true
  frame.AddMessage = function(self, text, r, g, b, id)
    local layout = QtUI.GetLayout and QtUI:GetLayout()
    if type(text) == "string" then
      if layout and layout.chatTime ~= false then
        if not string.find(text, "^|cff888888%[%d%d:%d%d%]") then
          local stamp = TimeStamp()
          if stamp then
            text = "|cff888888[" .. stamp .. "]|r " .. text
          end
        end
      end
      local byClass = layout and (layout.chatClassNames == true or layout.chatClassNames == 1 or layout.chatClassNames == "1")
      text = ColorPlayerNames(text, byClass)
    end
    r = tonumber(r)
    g = tonumber(g)
    b = tonumber(b)
    if not r or not g or not b or (r <= .04 and g <= .04 and b <= .04) then
      r, g, b = 1, 1, 1
    end
    return original(self, text, r, g, b, id)
  end
end

local function HookAllChatTimestamps()
  local i
  for i = 1, 7 do
    HookChatTimestamp(getglobal("ChatFrame" .. i))
  end
  if DEFAULT_CHAT_FRAME then HookChatTimestamp(DEFAULT_CHAT_FRAME) end
end

function QtUI:LayoutChat()
  if not self.leftChatPanel and not self.rightChatPanel then return end
  local layout = self.GetLayout and self:GetLayout() or {}
  local width = tonumber(layout.chatWidth) or 380
  local height = tonumber(layout.chatHeight) or 190
  local fontSize = tonumber(layout.chatFontSize) or 12
  if width < 180 then width = 180 end
  if width > 700 then width = 700 end
  if height < 80 then height = 80 end
  if height > 500 then height = 500 end
  if fontSize < 8 then fontSize = 8 end
  if fontSize > 20 then fontSize = 20 end

  SizeChatPanel(self.leftChatPanel, "chat", width, height, 14, 14)
  if self.leftChat then ConfigureChat(self.leftChat, self.leftChatPanel, 1, fontSize) end
  if SocialOn(layout) then
    local sw = (UIParent.GetWidth and UIParent:GetWidth()) or 1024
    SizeChatPanel(self.rightChatPanel, "chatSocial", width, height, sw - width - 14, 14)
    if self.rightChat then ConfigureChat(self.rightChat, self.rightChatPanel, 2, fontSize) end
    local i
    for i = 1, table.getn(rightGroups) do
      SafeChatCall(ChatFrame_RemoveMessageGroup, self.leftChat, rightGroups[i])
      SafeChatCall(ChatFrame_AddMessageGroup, self.rightChat, rightGroups[i])
    end
  else
    ParkSocial(self.rightChatPanel, self.rightChat)
    local i
    for i = 1, table.getn(rightGroups) do
      SafeChatCall(ChatFrame_AddMessageGroup, self.leftChat, rightGroups[i])
    end
  end
  HookAllChatTimestamps()
end

function QtUI:SetupChat()
  if self.leftChatPanel then
    self:LayoutChat()
    return
  end

  local layout = self.GetLayout and self:GetLayout() or {}
  local width = tonumber(layout.chatWidth) or 380
  local height = tonumber(layout.chatHeight) or 190

  local left = CreateFrame("Frame", "QtUILeftChatPanel", UIParent)
  self.leftChatPanel = left
  local right = CreateFrame("Frame", "QtUIRightChatPanel", UIParent)
  self.rightChatPanel = right

  local chat1 = ChatFrame1
  local chat2 = ChatFrame2
  if not chat2 and type(FCF_OpenNewWindow) == "function" then
    pcall(FCF_OpenNewWindow, "Qt Social")
    chat2 = getglobal("ChatFrame" .. (NUM_CHAT_WINDOWS or 2))
  end

  self.leftChat = chat1
  self.rightChat = chat2
  HookAllChatTimestamps()

  for _, group in ipairs(leftGroups) do
    SafeChatCall(ChatFrame_AddMessageGroup, chat1, group)
  end
  for _, group in ipairs(rightGroups) do
    SafeChatCall(ChatFrame_AddMessageGroup, chat2, group)
  end

  if type(FCF_SetLocked) == "function" then
    pcall(FCF_SetLocked, chat2, 1)
    pcall(FCF_SetLocked, chat1, 1)
  end

  self:LayoutChat()
end
