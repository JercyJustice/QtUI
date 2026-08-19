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
  if frame.SetMaxLines then frame:SetMaxLines(500) end
  if frame.Show then pcall(frame.Show, frame) end
  HideChatChrome(index)
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
    if layout and layout.chatTime ~= false and type(text) == "string" then
      if not string.find(text, "^|cff888888%[%d%d:%d%d%]") then
        local stamp = TimeStamp()
        if stamp then
          text = "|cff888888[" .. stamp .. "]|r " .. text
        end
      end
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
  local sw = (UIParent.GetWidth and UIParent:GetWidth()) or 1024
  SizeChatPanel(self.rightChatPanel, "chatSocial", width, height, sw - width - 14, 14)

  if self.leftChat then ConfigureChat(self.leftChat, self.leftChatPanel, 1, fontSize) end
  if self.rightChat then ConfigureChat(self.rightChat, self.rightChatPanel, 2, fontSize) end
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
