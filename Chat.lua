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

local function ConfigureChat(frame, panel, index)
  if not frame then return end
  frame:SetParent(panel)
  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -8)
  frame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8, index == 2 and 29 or -8)
  if frame.SetFading then frame:SetFading(false) end
  if frame.SetFont then frame:SetFont("Fonts\\FRIZQT__.TTF", 12) end
  if frame.SetMaxLines then frame:SetMaxLines(500) end
  frame:Show()
  HideChatChrome(index)
end

local function PreservePrimaryChat(frame)
  if not frame then return end
  -- Leave parent, anchors, dimensions, font and tab controls untouched so
  -- Emberveil can restore the user's own ChatFrame1 layout after a reload.
  if frame.SetFading then frame:SetFading(false) end
  frame:Show()
end

function PotatoUI:SetupChat()
  local width = math.min(430, UIParent:GetWidth() * .27)
  local height = 190

  -- These are positioning anchors only. Chat text remains, but the two large
  -- side panels from the first PotatoUI build are intentionally removed.
  local left = CreateFrame("Frame", "PotatoUILeftChatPanel", UIParent)
  left:SetWidth(width)
  left:SetHeight(height)
  left:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 14, 14)
  self.leftChatPanel = left

  local right = CreateFrame("Frame", "PotatoUIRightChatPanel", UIParent)
  right:SetWidth(width)
  right:SetHeight(height)
  right:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -14, 14)
  self.rightChatPanel = right

  local chat1 = ChatFrame1
  local chat2 = ChatFrame2
  if not chat2 and type(FCF_OpenNewWindow) == "function" then
    pcall(FCF_OpenNewWindow, "Potato Social")
    chat2 = getglobal("ChatFrame" .. (NUM_CHAT_WINDOWS or 2))
  end

  PreservePrimaryChat(chat1)
  ConfigureChat(chat2, right, 2)

  for _, group in ipairs(leftGroups) do
    SafeChatCall(ChatFrame_AddMessageGroup, chat1, group)
  end
  for _, group in ipairs(rightGroups) do
    SafeChatCall(ChatFrame_AddMessageGroup, chat2, group)
  end

  if type(FCF_SetLocked) == "function" then
    pcall(FCF_SetLocked, chat2, 1)
  end

  self.leftChat = chat1
  self.rightChat = chat2
end
