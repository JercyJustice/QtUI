-- Custom quest log: detail left, list right. Parks the native QuestLogFrame.

local WIN_W = 518
local WIN_H = 350
local LIST_W = 176
local PAD = 8
local ROW_H = 14
local MAX_ROWS = 18
local MAX_ITEMS = 8
local TEXT_SIZE = 11
local TITLE_SIZE = 13
local BTN_W = 78
local BTN_H = 22
local BTN_Y = 8
local TITLE_H = 26
local DETAIL_BOTTOM = 36
local DETAIL_TOP = WIN_H - 32
local DETAIL_H = DETAIL_TOP - DETAIL_BOTTOM

local nativeOnShow
local nativeToggle

local function True(v)
  return v == true or v == 1 or v == "1"
end

local function FeatureOn()
  return QtUI.IsFeatureEnabled and QtUI:IsFeatureEnabled("questLog")
end

local function PlaceBox(frame, parent, left, bottom, right, top)
  if not frame then return end
  frame:ClearAllPoints()
  frame:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", left, bottom)
  frame:SetPoint("TOPRIGHT", parent, "BOTTOMLEFT", right, top)
end

local function ParkFrame(frame)
  if not frame then return end
  if frame.EnableMouse then pcall(frame.EnableMouse, frame, false) end
  if frame.ClearAllPoints then
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", -4000, -4000)
    frame:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", -3600, -3700)
  end
  if frame.Hide then pcall(frame.Hide, frame) end
end

local function Paint(fs, size, r, g, b, justifyH, justifyV)
  if not fs then return end
  size = size or TEXT_SIZE
  if QtUI.ApplyFont then QtUI:ApplyFont(fs, size) end
  if fs.SetTextColor then pcall(fs.SetTextColor, fs, r or 1, g or 1, b or 1) end
  if fs.SetJustifyH then fs:SetJustifyH(justifyH or "LEFT") end
  if fs.SetJustifyV then fs:SetJustifyV(justifyV or "TOP") end
end

local function PaintWrap(fs, size, r, g, b)
  Paint(fs, size, r, g, b, "LEFT", "TOP")
  if fs.SetNonSpaceWrap then pcall(fs.SetNonSpaceWrap, fs, true) end
  if fs.SetWordWrap then pcall(fs.SetWordWrap, fs, true) end
end

local function ShiftDown()
  if type(IsShiftKeyDown) ~= "function" then return false end
  local ok, held = pcall(IsShiftKeyDown)
  return ok and True(held)
end

local function ToggleWatch(index)
  index = tonumber(index) or 0
  if index < 1 then return end
  local watched
  if type(IsQuestWatched) == "function" then
    local ok, v = pcall(IsQuestWatched, index)
    watched = ok and True(v)
  end
  if watched then
    if type(RemoveQuestWatch) == "function" then pcall(RemoveQuestWatch, index) end
  else
    if type(AddQuestWatch) == "function" then pcall(AddQuestWatch, index) end
  end
end

local function VisibleLen(s)
  s = string.gsub(s or "", "|c%x%x%x%x%x%x%x%x", "")
  s = string.gsub(s, "|r", "")
  return string.len(s)
end

local function WidthOf(fs, s, charW)
  if fs and fs.SetText and fs.GetStringWidth then
    fs:SetText(s)
    local w = tonumber(fs:GetStringWidth())
    if w and w > 1 then return w end
  end
  return VisibleLen(s) * charW
end

-- Emberveil FontStrings often ignore SetWidth, so wrap by inserting newlines.
local function WrapText(fs, text, wrapW, size)
  if not text or text == "" then return "" end
  text = string.gsub(text, "|n", "\n")
  text = string.gsub(text, "\r\n", "\n")
  text = string.gsub(text, "\r", "\n")
  wrapW = wrapW or 200
  size = size or TEXT_SIZE
  local charW = size * 0.52
  if charW < 4 then charW = 4 end

  local function WrapPara(para)
    if para == "" then return "" end
    if WidthOf(fs, para, charW) <= wrapW then return para end
    local out = ""
    local line = ""
    local pos = 1
    local len = string.len(para)
    while pos <= len do
      local ws, we = string.find(para, "%s+", pos)
      local word
      if not ws then
        word = string.sub(para, pos)
        pos = len + 1
      else
        if ws > pos then
          word = string.sub(para, pos, ws - 1)
        else
          word = ""
        end
        pos = we + 1
      end
      if word ~= "" then
        local test
        if line == "" then test = word else test = line .. " " .. word end
        if WidthOf(fs, test, charW) > wrapW and line ~= "" then
          if out ~= "" then out = out .. "\n" end
          out = out .. line
          line = word
          while WidthOf(fs, line, charW) > wrapW and string.len(line) > 1 do
            local cut = math.floor(wrapW / charW)
            if cut < 1 then cut = 1 end
            if cut >= string.len(line) then cut = string.len(line) - 1 end
            local piece = string.sub(line, 1, cut)
            while WidthOf(fs, piece, charW) > wrapW and cut > 1 do
              cut = cut - 1
              piece = string.sub(line, 1, cut)
            end
            if out ~= "" then out = out .. "\n" end
            out = out .. piece
            line = string.sub(line, cut + 1)
          end
        else
          line = test
        end
      end
    end
    if line ~= "" then
      if out ~= "" then out = out .. "\n" end
      out = out .. line
    end
    return out
  end

  local result = ""
  local start = 1
  while true do
    local nl = string.find(text, "\n", start, 1)
    local para
    if not nl then
      para = string.sub(text, start)
      if result ~= "" then result = result .. "\n" end
      result = result .. WrapPara(para)
      break
    end
    para = string.sub(text, start, nl - 1)
    if result ~= "" then result = result .. "\n" end
    result = result .. WrapPara(para)
    start = nl + 1
  end
  return result
end

local function CountLines(text)
  local n = 1
  if text and text ~= "" then
    string.gsub(text, "\n", function()
      n = n + 1
    end)
  end
  return n
end

local function TextHeight(text, size, minH, maxH)
  local h = CountLines(text) * (size + 3) + 2
  if minH and h < minH then h = minH end
  if maxH and h > maxH then h = maxH end
  return h
end

local function QuestLevelColor(level, complete)
  if complete == -1 then return 1, .25, .25 end
  if complete == 1 then return .2, 1, .35 end
  level = tonumber(level) or 0
  local player = tonumber(UnitLevel("player")) or 1
  local diff = level - player
  local green = 5
  if type(GetQuestGreenRange) == "function" then
    local ok, span = pcall(GetQuestGreenRange)
    if ok and tonumber(span) then green = tonumber(span) end
  end
  if diff >= 5 then return 1, .15, .15 end
  if diff >= 3 then return 1, .5, .15 end
  if diff >= -2 then return 1, .9, .15 end
  if diff >= -green then return .25, .9, .25 end
  return .55, .55, .55
end

local function ParkNativeQuestLog()
  local frame = getglobal("QuestLogFrame")
  if not frame then return end
  ParkFrame(frame)
end

local function RestoreNativeQuestLog()
  local frame = getglobal("QuestLogFrame")
  if not frame then return end
  if nativeOnShow and frame.SetScript then
    frame:SetScript("OnShow", nativeOnShow)
  end
  if frame.EnableMouse then pcall(frame.EnableMouse, frame, true) end
  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -104)
  if frame.SetAlpha then pcall(frame.SetAlpha, frame, 1) end
end

function QtUI:HideQuestLog()
  local frame = self.questLogFrame
  if frame then ParkFrame(frame) end
end

function QtUI:ShowQuestLog()
  if not FeatureOn() then return end
  self:SetupQuestLog()
  local frame = self.questLogFrame
  if not frame then return end
  ParkNativeQuestLog()
  if type(ExpandQuestHeader) == "function" then pcall(ExpandQuestHeader, 0) end
  local saved = QtUIDB and QtUIDB.positions and QtUIDB.positions.questLog
  frame:ClearAllPoints()
  if saved and saved.x and saved.y then
    frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", saved.x, saved.y)
    frame:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", saved.x + WIN_W, saved.y + WIN_H)
  else
    frame:SetPoint("BOTTOMLEFT", UIParent, "CENTER", -(WIN_W / 2), -(WIN_H / 2))
    frame:SetPoint("TOPRIGHT", UIParent, "CENTER", WIN_W / 2, WIN_H / 2)
  end
  if frame.EnableMouse then pcall(frame.EnableMouse, frame, true) end
  if frame.Show then pcall(frame.Show, frame) end
  if frame.Raise then pcall(frame.Raise, frame) end
  if frame.SetFrameStrata then pcall(frame.SetFrameStrata, frame, "DIALOG") end
  self:RefreshQuestLog()
end

function QtUI:ToggleQuestLog()
  if not FeatureOn() then
    if nativeToggle then nativeToggle() end
    return
  end
  local frame = self.questLogFrame
  local shown
  if frame and frame.IsShown then
    local ok, vis = pcall(frame.IsShown, frame)
    shown = ok and True(vis)
  end
  if shown then
    self:HideQuestLog()
  else
    self:ShowQuestLog()
  end
end

function QtUI:RestoreQuestLogArt()
  self:HideQuestLog()
  RestoreNativeQuestLog()
end

local function LayoutDetail(frame)
  local panel = frame.detailPanel
  if not panel then return end
  local wrapW = WIN_W - LIST_W - PAD * 3 - 8
  local y = 4
  local function PlaceFS(fs, h)
    local top = DETAIL_H - y
    local bottom = top - h
    if bottom < 0 then bottom = 0 end
    PlaceBox(fs, panel, 4, bottom, 4 + wrapW, top)
    y = y + h + 4
  end

  PlaceFS(frame.detailTitle, TITLE_SIZE + 6)

  local descH = TextHeight(frame.detailDesc and frame.detailDesc:GetText(), TEXT_SIZE, 28, 100)
  PlaceFS(frame.detailDesc, descH)

  PlaceFS(frame.objHeader, TEXT_SIZE + 4)
  local objH = TextHeight(frame.objText and frame.objText:GetText(), TEXT_SIZE, 16, 56)
  PlaceFS(frame.objText, objH)

  PlaceFS(frame.rewardHeader, TEXT_SIZE + 4)
  PlaceFS(frame.rewardMoney, TEXT_SIZE + 4)

  local i
  for i = 1, MAX_ITEMS do
    local btn = frame.itemBtns[i]
    local col = math.mod(i - 1, 4)
    local row = math.floor((i - 1) / 4)
    local left = 4 + col * 36
    local top = y + row * 36
    local boxTop = DETAIL_H - top
    local boxBot = boxTop - 34
    if boxBot < 0 then boxBot = 0 end
    btn:ClearAllPoints()
    PlaceBox(btn, panel, left, boxBot, left + 34, boxTop)
  end
end

local function PaintItems(frame)
  local i
  for i = 1, MAX_ITEMS do
    local btn = frame.itemBtns[i]
    btn.kind = nil
    btn.index = nil
    if btn.icon then btn.icon:SetTexture(nil) end
    if btn.count then btn.count:SetText("") end
    if btn.Hide then pcall(btn.Hide, btn) end
  end
  local slot = 1
  local function AddItems(kind, count, getter)
    local n = tonumber(count) or 0
    local i
    for i = 1, n do
      if slot > MAX_ITEMS then return end
      local ok, name, tex, num = pcall(getter, i)
      if ok and tex then
        local btn = frame.itemBtns[slot]
        btn.kind = kind
        btn.index = i
        if btn.icon then btn.icon:SetTexture(tex) end
        if btn.count then
          num = tonumber(num) or 1
          if num > 1 then btn.count:SetText(tostring(num)) else btn.count:SetText("") end
        end
        if btn.Show then pcall(btn.Show, btn) end
        slot = slot + 1
      end
    end
  end
  if type(GetNumQuestLogRewards) == "function" then
    AddItems("reward", GetNumQuestLogRewards(), GetQuestLogRewardInfo)
  end
  if type(GetNumQuestLogChoices) == "function" then
    AddItems("choice", GetNumQuestLogChoices(), GetQuestLogChoiceInfo)
  end
end

local function PaintDetail(frame)
  local wrapW = WIN_W - LIST_W - PAD * 3 - 8
  local sel = 0
  if type(GetQuestLogSelection) == "function" then
    sel = tonumber(GetQuestLogSelection()) or 0
  end
  if sel < 1 then
    frame.detailTitle:SetText("Select a quest")
    frame.detailDesc:SetText("")
    frame.objHeader:SetText("")
    frame.objText:SetText("")
    frame.rewardHeader:SetText("")
    frame.rewardMoney:SetText("")
    PaintItems(frame)
    LayoutDetail(frame)
    return
  end

  local title, level, tag, isHeader, _, complete = GetQuestLogTitle(sel)
  if True(isHeader) or not title then
    frame.detailTitle:SetText(title or "")
    frame.detailDesc:SetText("")
    frame.objHeader:SetText("")
    frame.objText:SetText("")
    frame.rewardHeader:SetText("")
    frame.rewardMoney:SetText("")
    PaintItems(frame)
    LayoutDetail(frame)
    return
  end

  local head = "[" .. tostring(level or 0) .. "] " .. title
  if tag and tag ~= "" then head = head .. " (" .. tag .. ")" end
  if complete == 1 then head = head .. " |cff33ff55(Complete)|r" end
  if complete == -1 then head = head .. " |cffff4040(Failed)|r" end
  frame.detailTitle:SetText(head)
  local r, g, b = QuestLevelColor(level, complete)
  Paint(frame.detailTitle, TITLE_SIZE, r, g, b)

  local desc, objectives = "", ""
  if type(GetQuestLogQuestText) == "function" then
    local ok, d, o = pcall(GetQuestLogQuestText)
    if ok then
      desc = d or ""
      objectives = o or ""
    end
  end
  desc = WrapText(frame.detailDesc, desc, wrapW, TEXT_SIZE)
  frame.detailDesc:SetText(desc)
  PaintWrap(frame.detailDesc, TEXT_SIZE, .92, .9, .82)

  frame.objHeader:SetText("Objectives")
  Paint(frame.objHeader, TEXT_SIZE, 1, .82, .2)

  local lines = objectives or ""
  if type(GetNumQuestLeaderBoards) == "function" and type(GetQuestLogLeaderBoard) == "function" then
    local n = tonumber(GetNumQuestLeaderBoards()) or 0
    local i
    local extra = ""
    for i = 1, n do
      local ok, text, _, done = pcall(GetQuestLogLeaderBoard, i)
      if ok and text and text ~= "" then
        if extra ~= "" then extra = extra .. "\n" end
        if True(done) then
          extra = extra .. "|cff33ff55- " .. text .. "|r"
        else
          extra = extra .. "|cffffffff- " .. text .. "|r"
        end
      end
    end
    if extra ~= "" then
      if lines ~= "" then lines = lines .. "\n\n" .. extra else lines = extra end
    end
  end
  lines = WrapText(frame.objText, lines, wrapW, TEXT_SIZE)
  frame.objText:SetText(lines)
  PaintWrap(frame.objText, TEXT_SIZE, .9, .9, .9)

  frame.rewardHeader:SetText("Rewards")
  Paint(frame.rewardHeader, TEXT_SIZE, 1, .82, .2)

  local money = 0
  if type(GetQuestLogRewardMoney) == "function" then
    money = tonumber(GetQuestLogRewardMoney()) or 0
  end
  if money > 0 then
    local gold = math.floor(money / 10000)
    local silver = math.floor(math.mod(money / 100, 100))
    local copper = math.mod(money, 100)
    frame.rewardMoney:SetText(string.format("|cffffd700%dg|r |cffc7c7cf%ds|r |cffeda55f%dc|r", gold, silver, copper))
  else
    frame.rewardMoney:SetText("")
  end
  Paint(frame.rewardMoney, TEXT_SIZE, 1, 1, 1)

  if type(GetQuestLogRewardSpell) == "function" then
    local ok, _, spellName = pcall(GetQuestLogRewardSpell)
    if ok and spellName and spellName ~= "" then
      frame.rewardHeader:SetText("Rewards  |cff88ccff" .. spellName .. "|r")
    end
  end

  PaintItems(frame)
  LayoutDetail(frame)
end

local function PaintList(frame)
  local entries = 0
  local quests = 0
  if type(GetNumQuestLogEntries) == "function" then
    local ok, a, b = pcall(GetNumQuestLogEntries)
    if ok then
      entries = tonumber(a) or 0
      quests = tonumber(b) or 0
    end
  end
  frame.countText:SetText("Quests  " .. tostring(quests) .. " / 20")
  Paint(frame.countText, 11, .75, .78, .8, "RIGHT", "MIDDLE")

  local sel = 0
  if type(GetQuestLogSelection) == "function" then
    sel = tonumber(GetQuestLogSelection()) or 0
  end

  if entries < 1 then
    frame.detailTitle:SetText("No quests in the log")
    Paint(frame.detailTitle, TITLE_SIZE, 1, .9, .45)
  end

  local i
  for i = 1, MAX_ROWS do
    local btn = frame.rows[i]
    if i > entries then
      btn.index = nil
      btn.isHeader = nil
      if btn.label then btn.label:SetText("") end
      if btn.SetBackdropColor then btn:SetBackdropColor(0, 0, 0, 0) end
    else
      local title, level, tag, isHeader, isCollapsed, complete = GetQuestLogTitle(i)
      btn.index = i
      btn.isHeader = True(isHeader)
      if True(isHeader) then
        local mark = True(isCollapsed) and "+" or "-"
        btn.label:SetText(" " .. mark .. "  " .. (title or ""))
        Paint(btn.label, 12, 1, .82, .25)
      else
        local label = "   [" .. tostring(level or 0) .. "] " .. (title or "")
        if tag and tag ~= "" then label = label .. " (" .. tag .. ")" end
        if complete == 1 then label = label .. " *" end
        local watched
        if type(IsQuestWatched) == "function" then
          local ok, v = pcall(IsQuestWatched, i)
          watched = ok and True(v)
        end
        if watched then label = label .. " +" end
        btn.label:SetText(label)
        local r, g, b = QuestLevelColor(level, complete)
        Paint(btn.label, 11, r, g, b)
      end
      if i == sel and not True(isHeader) then
        if btn.SetBackdropColor then btn:SetBackdropColor(.08, .35, .55, .85) end
      else
        if btn.SetBackdropColor then btn:SetBackdropColor(.04, .05, .06, .4) end
      end
    end
  end
end

function QtUI:RefreshQuestLog()
  local frame = self.questLogFrame
  if not frame then return end
  local sel = 0
  if type(GetQuestLogSelection) == "function" then
    sel = tonumber(GetQuestLogSelection()) or 0
  end
  if sel < 1 and type(GetNumQuestLogEntries) == "function" and type(SelectQuestLogEntry) == "function" then
    local ok, entries = pcall(GetNumQuestLogEntries)
    entries = (ok and tonumber(entries)) or 0
    local i
    for i = 1, entries do
      local title, _, _, isHeader = GetQuestLogTitle(i)
      if title and not True(isHeader) then
        pcall(SelectQuestLogEntry, i)
        break
      end
    end
  end
  PaintList(frame)
  PaintDetail(frame)
end

local function MakeItemButton(parent, i)
  local btn = CreateFrame("Button", "QtUIQuestItem" .. i, parent)
  if btn.EnableMouse then btn:EnableMouse(true) end
  if btn.RegisterForClicks then btn:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
  btn.icon = btn:CreateTexture(nil, "ARTWORK")
  btn.icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -2)
  btn.icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
  btn.count = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
  btn.count:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
  Paint(btn.count, 10, 1, 1, 1)
  btn:SetScript("OnEnter", function()
    if not this.kind or not this.index or not GameTooltip then return end
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    if this.kind == "choice" and GameTooltip.SetQuestLogItem then
      pcall(GameTooltip.SetQuestLogItem, GameTooltip, "choice", this.index)
    elseif GameTooltip.SetQuestLogItem then
      pcall(GameTooltip.SetQuestLogItem, GameTooltip, "reward", this.index)
    end
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", function()
    if GameTooltip then GameTooltip:Hide() end
  end)
  btn:Hide()
  return btn
end

local function ClickRow()
  if not this.index then return end
  if this.isHeader then
    local _, _, _, _, collapsed = GetQuestLogTitle(this.index)
    if True(collapsed) then
      if ExpandQuestHeader then pcall(ExpandQuestHeader, this.index) end
    else
      if CollapseQuestHeader then pcall(CollapseQuestHeader, this.index) end
    end
  elseif ShiftDown() then
    ToggleWatch(this.index)
    if SelectQuestLogEntry then pcall(SelectQuestLogEntry, this.index) end
  else
    if SelectQuestLogEntry then pcall(SelectQuestLogEntry, this.index) end
  end
  QtUI:RefreshQuestLog()
end

local function BuildFrame()
  local frame = CreateFrame("Frame", "QtUIQuestLog", UIParent)
  frame:SetFrameStrata("DIALOG")
  frame:SetFrameLevel(80)
  frame:SetMovable(true)
  frame:SetToplevel(true)
  if frame.SetClampedToScreen then frame:SetClampedToScreen(false) end
  frame:EnableMouse(true)
  frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  frame:SetBackdropColor(.02, .025, .03, .96)
  frame:SetBackdropBorderColor(.18, .24, .28, 1)

  local function SavePos()
    local left, bottom = frame:GetLeft(), frame:GetBottom()
    if left and bottom and QtUIDB then
      if not QtUIDB.positions then QtUIDB.positions = {} end
      QtUIDB.positions.questLog = { x = left, y = bottom }
    end
  end

  -- Drag from the title bar only so bottom buttons keep their clicks.
  frame.dragHandle = CreateFrame("Button", "QtUIQuestLogDrag", frame)
  PlaceBox(frame.dragHandle, frame, 0, WIN_H - TITLE_H, WIN_W, WIN_H)
  frame.dragHandle:EnableMouse(true)
  frame.dragHandle:RegisterForDrag("LeftButton")
  if frame.dragHandle.SetFrameLevel and frame.GetFrameLevel then
    frame.dragHandle:SetFrameLevel(frame:GetFrameLevel() + 5)
  end
  frame.dragHandle:SetScript("OnDragStart", function()
    this:GetParent():StartMoving()
  end)
  frame.dragHandle:SetScript("OnDragStop", function()
    local parent = this:GetParent()
    parent:StopMovingOrSizing()
    SavePos()
  end)

  frame.title = frame:CreateFontString(nil, "OVERLAY")
  PlaceBox(frame.title, frame, PAD, WIN_H - 24, WIN_W - 80, WIN_H - 8)
  frame.title:SetText("Quest Log")
  Paint(frame.title, 13, 1, .9, .45, "LEFT", "MIDDLE")

  frame.countText = frame:CreateFontString(nil, "OVERLAY")
  PlaceBox(frame.countText, frame, WIN_W - LIST_W, WIN_H - 24, WIN_W - 36, WIN_H - 8)
  Paint(frame.countText, 11, .75, .78, .8, "RIGHT", "MIDDLE")

  local close = CreateFrame("Button", "QtUIQuestLogClose", frame)
  close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -10)
  close:SetPoint("BOTTOMLEFT", frame, "TOPRIGHT", -23, -23)
  if close.SetFrameLevel and frame.GetFrameLevel then
    close:SetFrameLevel(frame:GetFrameLevel() + 10)
  end
  if close.SetNormalTexture then close:SetNormalTexture("Interface\\AddOns\\QtUI\\Media\\close_normal") end
  if close.SetPushedTexture then close:SetPushedTexture("Interface\\AddOns\\QtUI\\Media\\close_pushed") end
  close:EnableMouse(true)
  if close.RegisterForClicks then close:RegisterForClicks("LeftButtonUp") end
  close:SetScript("OnClick", function() QtUI:HideQuestLog() end)
  close:SetScript("OnEnter", function()
    if this.GetNormalTexture and this:GetNormalTexture() then
      this:GetNormalTexture():SetVertexColor(.4, 1, .8)
    end
  end)
  close:SetScript("OnLeave", function()
    if this.GetNormalTexture and this:GetNormalTexture() then
      this:GetNormalTexture():SetVertexColor(1, 1, 1)
    end
  end)
  frame.close = close

  local listLeft = WIN_W - LIST_W - PAD
  frame.listHeader = frame:CreateFontString(nil, "OVERLAY")
  PlaceBox(frame.listHeader, frame, listLeft, WIN_H - 44, WIN_W - PAD, WIN_H - 30)
  frame.listHeader:SetText("Quests")
  Paint(frame.listHeader, 12, 1, .82, .2)

  frame.rows = {}
  local i
  for i = 1, MAX_ROWS do
    local btn = CreateFrame("Button", "QtUIQuestRow" .. i, frame)
    local top = WIN_H - 46 - i * ROW_H
    PlaceBox(btn, frame, listLeft, top - ROW_H + 2, WIN_W - PAD, top)
    btn:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    btn:SetBackdropColor(.04, .05, .06, .4)
    if btn.EnableMouse then btn:EnableMouse(true) end
    if btn.RegisterForClicks then btn:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
    if btn.SetFrameLevel and frame.GetFrameLevel then
      btn:SetFrameLevel(frame:GetFrameLevel() + 6)
    end
    btn.label = btn:CreateFontString(nil, "OVERLAY")
    PlaceBox(btn.label, btn, 4, 1, LIST_W - 18, ROW_H - 1)
    Paint(btn.label, 11, 1, 1, 1)
    btn:SetScript("OnMouseUp", function()
      if arg1 == "LeftButton" or arg1 == nil then ClickRow() end
    end)
    frame.rows[i] = btn
  end

  frame.detailPanel = CreateFrame("Frame", "QtUIQuestDetailPanel", frame)
  PlaceBox(frame.detailPanel, frame, PAD, DETAIL_BOTTOM, listLeft - 6, DETAIL_TOP)
  if frame.detailPanel.EnableMouse then frame.detailPanel:EnableMouse(false) end

  frame.detailTitle = frame.detailPanel:CreateFontString(nil, "OVERLAY")
  frame.detailDesc = frame.detailPanel:CreateFontString(nil, "OVERLAY")
  frame.objHeader = frame.detailPanel:CreateFontString(nil, "OVERLAY")
  frame.objText = frame.detailPanel:CreateFontString(nil, "OVERLAY")
  frame.rewardHeader = frame.detailPanel:CreateFontString(nil, "OVERLAY")
  frame.rewardMoney = frame.detailPanel:CreateFontString(nil, "OVERLAY")
  PaintWrap(frame.detailDesc, TEXT_SIZE, .92, .9, .82)
  PaintWrap(frame.objText, TEXT_SIZE, .9, .9, .9)
  Paint(frame.detailTitle, TITLE_SIZE, 1, .9, .45)
  Paint(frame.objHeader, TEXT_SIZE, 1, .82, .2)
  Paint(frame.rewardHeader, TEXT_SIZE, 1, .82, .2)
  Paint(frame.rewardMoney, TEXT_SIZE, 1, 1, 1)

  frame.itemBtns = {}
  for i = 1, MAX_ITEMS do
    frame.itemBtns[i] = MakeItemButton(frame.detailPanel, i)
  end

  local function ClickAbandon()
    if type(SetAbandonQuest) == "function" then pcall(SetAbandonQuest) end
    if type(StaticPopup_Show) == "function" then
      pcall(StaticPopup_Show, "ABANDON_QUEST")
    elseif type(AbandonQuest) == "function" then
      pcall(AbandonQuest)
    end
    QtUI:RefreshQuestLog()
  end

  local function ClickShare()
    if type(QuestLogPushQuest) == "function" then pcall(QuestLogPushQuest) end
  end

  local function ClickTrack()
    local sel = 0
    if type(GetQuestLogSelection) == "function" then
      sel = tonumber(GetQuestLogSelection()) or 0
    end
    ToggleWatch(sel)
    QtUI:RefreshQuestLog()
  end

  local function MakeTextBtn(name, label, left, click)
    local btn = CreateFrame("Button", name, frame)
    PlaceBox(btn, frame, left, BTN_Y, left + BTN_W, BTN_Y + BTN_H)
    if btn.EnableMouse then btn:EnableMouse(true) end
    if btn.RegisterForClicks then btn:RegisterForClicks("LeftButtonUp") end
    if btn.SetFrameLevel and frame.GetFrameLevel then
      btn:SetFrameLevel(frame:GetFrameLevel() + 8)
    end
    btn:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 8, edgeSize = 8,
      insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    btn:SetBackdropColor(.06, .08, .1, .95)
    btn:SetBackdropBorderColor(.25, .32, .36, 1)
    btn.label = btn:CreateFontString(nil, "OVERLAY")
    btn.label:ClearAllPoints()
    btn.label:SetPoint("CENTER", btn, "CENTER", 0, 0)
    btn.label:SetText(label)
    Paint(btn.label, 11, 1, 1, 1, "CENTER", "MIDDLE")
    btn:SetScript("OnMouseUp", function()
      if arg1 == "LeftButton" or arg1 == nil then click() end
    end)
    btn:SetScript("OnEnter", function()
      if this.SetBackdropColor then this:SetBackdropColor(.1, .28, .42, .95) end
    end)
    btn:SetScript("OnLeave", function()
      if this.SetBackdropColor then this:SetBackdropColor(.06, .08, .1, .95) end
    end)
    return btn
  end

  frame.btnAbandon = MakeTextBtn("QtUIQuestAbandon", "Abandon", PAD, ClickAbandon)
  frame.btnShare = MakeTextBtn("QtUIQuestShare", "Share", PAD + BTN_W + 8, ClickShare)
  frame.btnWatch = MakeTextBtn("QtUIQuestWatch", "Track", PAD + (BTN_W + 8) * 2, ClickTrack)

  if UISpecialFrames then table.insert(UISpecialFrames, "QtUIQuestLog") end
  ParkFrame(frame)
  return frame
end

local function HookToggle()
  if nativeToggle then return end
  if type(ToggleQuestLog) == "function" then
    nativeToggle = ToggleQuestLog
    ToggleQuestLog = function()
      if FeatureOn() then
        QtUI:ToggleQuestLog()
      else
        nativeToggle()
      end
    end
  end
  local frame = getglobal("QuestLogFrame")
  if frame then
    if type(frame.GetScript) == "function" then
      nativeOnShow = frame:GetScript("OnShow")
    end
    frame:SetScript("OnShow", function()
      if FeatureOn() then
        ParkNativeQuestLog()
        QtUI:ShowQuestLog()
      elseif nativeOnShow then
        pcall(nativeOnShow)
      end
    end)
  end
end

function QtUI:SetupQuestLog()
  if not self.questLogFrame then
    self.questLogFrame = BuildFrame()
    if self.RegisterMovable then
      self:RegisterMovable("questLog", "Quest Log", self.questLogFrame)
    end
    local events = CreateFrame("Frame", "QtUIQuestLogEvents")
    pcall(events.RegisterEvent, events, "QUEST_LOG_UPDATE")
    pcall(events.RegisterEvent, events, "QUEST_WATCH_UPDATE")
    pcall(events.RegisterEvent, events, "PLAYER_ENTERING_WORLD")
    pcall(events.RegisterEvent, events, "UNIT_QUEST_LOG_CHANGED")
    events:SetScript("OnEvent", function()
      if FeatureOn() and QtUI.questLogFrame and QtUI.questLogFrame.IsShown then
        local ok, vis = pcall(QtUI.questLogFrame.IsShown, QtUI.questLogFrame)
        if ok and True(vis) then QtUI:RefreshQuestLog() end
      end
    end)
  end
  HookToggle()
  if FeatureOn() then
    ParkNativeQuestLog()
  else
    self:RestoreQuestLogArt()
  end
end
