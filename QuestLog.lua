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
local LIST_NAME_SIZE = 9
local BTN_W = 78
local BTN_H = 22
local BTN_Y = 8
local TITLE_H = 26
local REWARD_H = 78
local REWARD_BOTTOM = 36
local REWARD_TOP = REWARD_BOTTOM + REWARD_H
local TEXT_BOTTOM = REWARD_TOP + 6
local TEXT_TOP = WIN_H - 52
local TEXT_H = TEXT_TOP - TEXT_BOTTOM
local SCROLL_W = 12
local VIEW_LINES = math.floor((TEXT_H - 8) / (TEXT_SIZE + 3))
if VIEW_LINES < 4 then VIEW_LINES = 4 end
local REWARD_VIEW = 4
local LIST_TOP = WIN_H - 46
local LIST_BOTTOM = 40
local LIST_H = LIST_TOP - LIST_BOTTOM

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
  -- Emberveil: SetJustifyV accepts TOP/CENTER/BOTTOM. MIDDLE is ignored.
  if justifyV == "MIDDLE" then justifyV = "CENTER" end
  if fs.SetJustifyV then fs:SetJustifyV(justifyV or "TOP") end
end

local function WheelOn(frame)
  if frame and frame.EnableMouseWheel then
    pcall(frame.EnableMouseWheel, frame, true)
  end
end

-- Emberveil GetQuestLogTitle uses 0/false for unset flags, not nil (pfQuest).
local function Flag(v)
  if v == 0 or v == false then return nil end
  return v
end

local function ReadQuestTitle(index)
  local title, level, tag, isHeader, isCollapsed, complete = GetQuestLogTitle(index)
  return title, level, tag, Flag(isHeader), Flag(isCollapsed), Flag(complete)
end

local function PaintWrap(fs, size, r, g, b)
  Paint(fs, size, r, g, b, "LEFT", "TOP")
  -- Manual newlines already wrap. Extra engine wrap overflows the next block.
  if fs.SetNonSpaceWrap then pcall(fs.SetNonSpaceWrap, fs, false) end
  if fs.SetWordWrap then pcall(fs.SetWordWrap, fs, false) end
end

local function ShiftDown()
  if type(IsShiftKeyDown) ~= "function" then return false end
  local ok, held = pcall(IsShiftKeyDown)
  return ok and True(held)
end

local function UnitHasQuest(index, unit)
  if type(IsUnitOnQuest) ~= "function" then return false end
  local ok, on = pcall(IsUnitOnQuest, index, unit)
  return ok and True(on)
end

local function PartyQuestCount(index)
  index = tonumber(index) or 0
  if index < 1 then return 0 end
  local n = 0
  local seen = {}
  local function AddUnit(unit)
    if type(UnitIsUnit) == "function" then
      local okSame, same = pcall(UnitIsUnit, unit, "player")
      if okSame and True(same) then return end
    end
    if not UnitHasQuest(index, unit) then return end
    local name
    if type(UnitName) == "function" then name = UnitName(unit) end
    if type(name) == "string" and name ~= "" then
      local key = string.lower(name)
      if seen[key] then return end
      seen[key] = true
    end
    n = n + 1
  end
  local i
  for i = 1, 4 do AddUnit("party" .. i) end
  local raid = 0
  if type(GetNumRaidMembers) == "function" then
    raid = tonumber(GetNumRaidMembers()) or 0
  end
  if raid > 0 then
    for i = 1, raid do AddUnit("raid" .. i) end
  end
  return n
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

-- GetStringWidth on Emberveil often returns the region width, not the string.
-- Wrap by visible character count so height matches what is actually drawn.
local function WrapText(fs, text, wrapW, size)
  if not text or text == "" then return "" end
  text = string.gsub(text, "|n", "\n")
  text = string.gsub(text, "\r\n", "\n")
  text = string.gsub(text, "\r", "\n")
  wrapW = wrapW or 200
  size = size or TEXT_SIZE
  local charW = size * 0.55
  if charW < 5 then charW = 5 end
  local maxChars = math.floor(wrapW / charW)
  if maxChars < 12 then maxChars = 12 end

  local function WrapPara(para)
    if para == "" then return "" end
    if VisibleLen(para) <= maxChars then return para end
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
        if VisibleLen(test) > maxChars and line ~= "" then
          if out ~= "" then out = out .. "\n" end
          out = out .. line
          line = word
          while VisibleLen(line) > maxChars and string.len(line) > 1 do
            local cut = maxChars
            if cut >= string.len(line) then cut = string.len(line) - 1 end
            local piece = string.sub(line, 1, cut)
            while VisibleLen(piece) > maxChars and cut > 1 do
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

local function SplitLines(text)
  local t = {}
  local n = 0
  if not text or text == "" then return t end
  local start = 1
  while true do
    local nl = string.find(text, "\n", start, 1)
    n = n + 1
    if not nl then
      t[n] = string.sub(text, start)
      break
    end
    t[n] = string.sub(text, start, nl - 1)
    start = nl + 1
  end
  return t
end

local function WheelDelta(a, b)
  local delta = tonumber(arg1)
  if (not delta or delta == 0) and type(b) == "number" then delta = b end
  if (not delta or delta == 0) and type(a) == "number" then delta = a end
  return tonumber(delta) or 0
end

local function QuestLevelColor(level, complete)
  if complete == -1 then return 1, .25, .25 end
  if complete == 1 or complete == true then return .2, 1, .35 end
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

local function PlaceThumb(thumb, track, off, maxOff, view, total, trackH)
  if not thumb or not track then return end
  if maxOff < 1 or total < 1 then
    PlaceBox(thumb, track, 2, 2, SCROLL_W - 2, trackH - 2)
    if thumb.SetBackdropColor then thumb:SetBackdropColor(.16, .2, .22, .5) end
    return
  end
  if thumb.SetBackdropColor then thumb:SetBackdropColor(.38, .55, .62, 1) end
  local th = math.floor(trackH * view / total)
  if th < 16 then th = 16 end
  if th > trackH - 4 then th = trackH - 4 end
  local travel = trackH - th - 4
  if travel < 0 then travel = 0 end
  local y = math.floor(travel - (off / maxOff) * travel)
  PlaceBox(thumb, track, 2, y, SCROLL_W - 2, y + th)
end

local function JumpScroll(track, total, view)
  if not track then return 0 end
  local top = track:GetTop()
  local bottom = track:GetBottom()
  if not top or not bottom or top <= bottom then return 0 end
  local scale = 1
  if track.GetEffectiveScale then scale = track:GetEffectiveScale() or 1 end
  local _, cy = GetCursorPosition()
  cy = (cy or 0) / scale
  local frac = (top - cy) / (top - bottom)
  if frac < 0 then frac = 0 end
  if frac > 1 then frac = 1 end
  local maxOff = (tonumber(total) or 0) - (tonumber(view) or 1)
  if maxOff < 0 then maxOff = 0 end
  return math.floor(frac * maxOff + 0.5)
end

local function ApplyTextScroll(frame)
  if not frame or not frame.bodyText then return end
  local lines = frame.textLines or {}
  local total = table.getn(lines)
  local view = VIEW_LINES
  local maxOff = total - view
  if maxOff < 0 then maxOff = 0 end
  local off = tonumber(frame.textScroll) or 0
  if off < 0 then off = 0 end
  if off > maxOff then off = maxOff end
  frame.textScroll = off

  local slice = ""
  local i
  for i = 1, view do
    local line = lines[off + i]
    if not line then break end
    if slice ~= "" then slice = slice .. "\n" end
    slice = slice .. line
  end
  frame.bodyText:SetText(slice)
  PaintWrap(frame.bodyText, TEXT_SIZE, .92, .9, .82)
  PlaceThumb(frame.scrollThumb, frame.scrollTrack, off, maxOff, view, total, TEXT_H)
end

local function ScrollText(frame, delta)
  if not frame then return end
  delta = tonumber(delta) or 0
  if delta == 0 then return end
  if delta > 0 then delta = 1 else delta = -1 end
  frame.textScroll = (tonumber(frame.textScroll) or 0) - delta
  ApplyTextScroll(frame)
end

local function ApplyListThumb(frame)
  if not frame then return end
  local total = tonumber(frame.listCount) or 0
  local maxOff = total - MAX_ROWS
  if maxOff < 0 then maxOff = 0 end
  local off = tonumber(frame.listScroll) or 0
  PlaceThumb(frame.listThumb, frame.listTrack, off, maxOff, MAX_ROWS, total, LIST_H)
end

local function ScrollList(frame, delta)
  if not frame then return end
  delta = tonumber(delta) or 0
  if delta == 0 then return end
  if delta > 0 then delta = 1 else delta = -1 end
  frame.listScroll = (tonumber(frame.listScroll) or 0) - delta
  if QtUI.RefreshQuestLog then QtUI:RefreshQuestLog() end
end

local function ApplyRewardScroll(frame)
  local panel = frame.rewardPanel
  if not panel then return end
  local w = WIN_W - LIST_W - PAD * 3 - SCROLL_W
  PlaceBox(frame.rewardHeader, panel, 6, REWARD_H - 20, w - 6, REWARD_H - 4)
  PlaceBox(frame.rewardMoney, panel, 6, REWARD_H - 38, w - 6, REWARD_H - 22)

  local items = 0
  local i
  for i = 1, MAX_ITEMS do
    if frame.itemBtns[i] and frame.itemBtns[i].kind then
      items = items + 1
    end
  end
  frame.rewardCount = items
  local view = REWARD_VIEW
  local maxOff = items - view
  if maxOff < 0 then maxOff = 0 end
  local off = tonumber(frame.rewardScroll) or 0
  if off < 0 then off = 0 end
  if off > maxOff then off = maxOff end
  frame.rewardScroll = off

  for i = 1, MAX_ITEMS do
    local btn = frame.itemBtns[i]
    local vis = i - off
    if i <= items and vis >= 1 and vis <= view then
      local left = 6 + (vis - 1) * 36
      PlaceBox(btn, panel, left, 4, left + 34, 38)
      if btn.Show then pcall(btn.Show, btn) end
    else
      PlaceBox(btn, panel, 4, REWARD_H + 20, 38, REWARD_H + 54)
      if btn.Hide then pcall(btn.Hide, btn) end
    end
  end
  PlaceThumb(frame.rewardThumb, frame.rewardTrack, off, maxOff, view, items, REWARD_H)
end

local function ScrollRewards(frame, delta)
  if not frame then return end
  delta = tonumber(delta) or 0
  if delta == 0 then return end
  if delta > 0 then delta = 1 else delta = -1 end
  frame.rewardScroll = (tonumber(frame.rewardScroll) or 0) - delta
  ApplyRewardScroll(frame)
end

local function LayoutRewards(frame)
  ApplyRewardScroll(frame)
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

local function SetBody(frame, text)
  frame.textLines = SplitLines(text or "")
  ApplyTextScroll(frame)
end

local function PaintDetail(frame)
  local wrapW = WIN_W - LIST_W - PAD * 3 - SCROLL_W - 16
  local sel = 0
  if type(GetQuestLogSelection) == "function" then
    sel = tonumber(GetQuestLogSelection()) or 0
  end
  if frame.paintSel ~= sel then
    frame.paintSel = sel
    frame.textScroll = 0
    frame.rewardScroll = 0
  end
  if sel < 1 then
    frame.detailTitle:SetText("Select a quest")
    Paint(frame.detailTitle, TITLE_SIZE, 1, .9, .45)
    SetBody(frame, "")
    frame.rewardHeader:SetText("Rewards")
    frame.rewardMoney:SetText("")
    Paint(frame.rewardHeader, TEXT_SIZE, 1, .82, .2)
    PaintItems(frame)
    LayoutRewards(frame)
    return
  end

  local title, level, tag, isHeader, _, complete = ReadQuestTitle(sel)
  if True(isHeader) or not title then
    frame.detailTitle:SetText(title or "")
    Paint(frame.detailTitle, TITLE_SIZE, 1, .82, .25)
    SetBody(frame, "")
    frame.rewardHeader:SetText("Rewards")
    frame.rewardMoney:SetText("")
    Paint(frame.rewardHeader, TEXT_SIZE, 1, .82, .2)
    PaintItems(frame)
    LayoutRewards(frame)
    return
  end

  local head = "[" .. tostring(level or 0) .. "] " .. title
  if tag and tag ~= "" then head = head .. " (" .. tag .. ")" end
  if complete == 1 or complete == true then head = head .. " |cff33ff55(Complete)|r" end
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
  desc = WrapText(frame.bodyText, desc, wrapW, TEXT_SIZE)

  local obj = objectives or ""
  if type(GetNumQuestLeaderBoards) == "function" and type(GetQuestLogLeaderBoard) == "function" then
    local n = tonumber(GetNumQuestLeaderBoards(sel)) or 0
    local i
    local extra = ""
    for i = 1, n do
      local ok, text, _, done = pcall(GetQuestLogLeaderBoard, i, sel)
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
      if obj ~= "" then obj = obj .. "\n\n" .. extra else obj = extra end
    end
  end
  obj = WrapText(frame.bodyText, obj, wrapW, TEXT_SIZE)

  local body = desc
  if obj ~= "" then
    if body ~= "" then body = body .. "\n\n" end
    body = body .. "|cffffd133Objectives|r\n" .. obj
  end
  SetBody(frame, body)

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
  LayoutRewards(frame)
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

  local maxList = entries - MAX_ROWS
  if maxList < 0 then maxList = 0 end
  local listOff = tonumber(frame.listScroll) or 0
  if listOff < 0 then listOff = 0 end
  if listOff > maxList then listOff = maxList end
  frame.listScroll = listOff

  local i
  for i = 1, MAX_ROWS do
    local btn = frame.rows[i]
    local idx = listOff + i
    if idx > entries then
      btn.index = nil
      btn.isHeader = nil
      if btn.label then btn.label:SetText("") end
      if btn.partyCount then btn.partyCount:SetText("") end
      if btn.SetBackdropColor then btn:SetBackdropColor(0, 0, 0, 0) end
    else
      local title, level, tag, isHeader, isCollapsed, complete = ReadQuestTitle(idx)
      btn.index = idx
      btn.isHeader = True(isHeader)
      if True(isHeader) then
        local mark = True(isCollapsed) and "+" or "-"
        btn.label:SetText(" " .. mark .. "  " .. (title or ""))
        Paint(btn.label, 12, 1, .82, .25)
        if btn.partyCount then btn.partyCount:SetText("") end
      else
        local label = "   [" .. tostring(level or 0) .. "] " .. (title or "")
        if tag and tag ~= "" then label = label .. " (" .. tag .. ")" end
        if complete == 1 or complete == true then label = label .. " [x]" end
        local watched
        if type(IsQuestWatched) == "function" then
          local ok, v = pcall(IsQuestWatched, idx)
          watched = ok and True(v)
        end
        if watched then label = label .. " +" end
        btn.label:SetText(label)
        local r, g, b = QuestLevelColor(level, complete)
        Paint(btn.label, LIST_NAME_SIZE, r, g, b)
        if btn.partyCount then
          local pn = PartyQuestCount(idx)
          if pn > 0 then
            btn.partyCount:SetText("(" .. tostring(pn) .. ")")
            Paint(btn.partyCount, LIST_NAME_SIZE, .85, .9, .95, "RIGHT", "CENTER")
          else
            btn.partyCount:SetText("")
          end
        end
      end
      if idx == sel and not True(isHeader) then
        if btn.SetBackdropColor then btn:SetBackdropColor(.08, .35, .55, .85) end
      else
        if btn.SetBackdropColor then btn:SetBackdropColor(.04, .05, .06, .4) end
      end
    end
  end
  frame.listCount = entries
  ApplyListThumb(frame)
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
      local title, _, _, isHeader = ReadQuestTitle(i)
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
  if btn.SetFrameLevel and parent and parent.GetFrameLevel then
    btn:SetFrameLevel((parent:GetFrameLevel() or 4) + 4)
  end
  WheelOn(btn)
  btn:SetScript("OnMouseWheel", function(a, b)
    local parent = QtUI.questLogFrame
    ScrollRewards(parent, WheelDelta(a, b))
  end)
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
    local _, _, _, _, collapsed = ReadQuestTitle(this.index)
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
  PlaceBox(frame.listHeader, frame, listLeft, WIN_H - 44, WIN_W - PAD - SCROLL_W - 4, WIN_H - 30)
  frame.listHeader:SetText("Quests")
  Paint(frame.listHeader, 12, 1, .82, .2)

  frame.listTrack = CreateFrame("Button", "QtUIQuestListScroll", frame)
  PlaceBox(frame.listTrack, frame, WIN_W - PAD - SCROLL_W, LIST_BOTTOM, WIN_W - PAD, LIST_TOP)
  frame.listTrack:EnableMouse(true)
  WheelOn(frame.listTrack)
  if frame.listTrack.SetFrameLevel and frame.GetFrameLevel then
    frame.listTrack:SetFrameLevel(frame:GetFrameLevel() + 6)
  end
  frame.listTrack:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    insets = { left = 0, right = 0, top = 0, bottom = 0 },
  })
  frame.listTrack:SetBackdropColor(.08, .1, .12, .95)
  frame.listTrack:SetScript("OnMouseWheel", function(a, b)
    ScrollList(frame, WheelDelta(a, b))
  end)
  frame.listTrack:SetScript("OnMouseUp", function()
    frame.listScroll = JumpScroll(this, frame.listCount or 0, MAX_ROWS)
    if QtUI.RefreshQuestLog then QtUI:RefreshQuestLog() end
  end)
  frame.listThumb = CreateFrame("Frame", "QtUIQuestListThumb", frame.listTrack)
  frame.listThumb:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    insets = { left = 0, right = 0, top = 0, bottom = 0 },
  })
  frame.listThumb:SetBackdropColor(.38, .55, .62, 1)
  PlaceBox(frame.listThumb, frame.listTrack, 2, LIST_H - 40, SCROLL_W - 2, LIST_H - 4)

  frame.rows = {}
  local i
  for i = 1, MAX_ROWS do
    local btn = CreateFrame("Button", "QtUIQuestRow" .. i, frame)
    local top = LIST_TOP - i * ROW_H
    PlaceBox(btn, frame, listLeft, top - ROW_H + 2, WIN_W - PAD - SCROLL_W - 4, top)
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
    PlaceBox(btn.label, btn, 4, 1, LIST_W - SCROLL_W - 36, ROW_H - 1)
    Paint(btn.label, LIST_NAME_SIZE, 1, 1, 1)
    btn.partyCount = btn:CreateFontString(nil, "OVERLAY")
    btn.partyCount:ClearAllPoints()
    btn.partyCount:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
    Paint(btn.partyCount, 11, .85, .9, .95, "RIGHT", "CENTER")
    btn:SetScript("OnMouseUp", function()
      if arg1 == "LeftButton" or arg1 == nil then ClickRow() end
    end)
    WheelOn(btn)
    btn:SetScript("OnMouseWheel", function(a, b)
      ScrollList(frame, WheelDelta(a, b))
    end)
    frame.rows[i] = btn
  end

  frame.detailTitle = frame:CreateFontString(nil, "OVERLAY")
  PlaceBox(frame.detailTitle, frame, PAD, TEXT_TOP, listLeft - 6, WIN_H - 32)
  Paint(frame.detailTitle, TITLE_SIZE, 1, .9, .45, "LEFT", "MIDDLE")

  frame.textPanel = CreateFrame("Button", "QtUIQuestTextPanel", frame)
  PlaceBox(frame.textPanel, frame, PAD, TEXT_BOTTOM, listLeft - SCROLL_W - 10, TEXT_TOP - 2)
  frame.textPanel:EnableMouse(true)
  WheelOn(frame.textPanel)
  if frame.textPanel.SetFrameLevel and frame.GetFrameLevel then
    frame.textPanel:SetFrameLevel(frame:GetFrameLevel() + 4)
  end
  frame.textPanel:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    insets = { left = 0, right = 0, top = 0, bottom = 0 },
  })
  frame.textPanel:SetBackdropColor(.03, .04, .05, .55)
  frame.textPanel:SetScript("OnMouseWheel", function(a, b)
    ScrollText(frame, WheelDelta(a, b))
  end)

  frame.bodyText = frame.textPanel:CreateFontString(nil, "OVERLAY")
  PlaceBox(frame.bodyText, frame.textPanel, 4, 4, (listLeft - SCROLL_W - 10) - PAD - 4, TEXT_H - 6)
  PaintWrap(frame.bodyText, TEXT_SIZE, .92, .9, .82)

  frame.scrollTrack = CreateFrame("Button", "QtUIQuestTextScroll", frame)
  PlaceBox(frame.scrollTrack, frame, listLeft - SCROLL_W - 8, TEXT_BOTTOM, listLeft - 8, TEXT_TOP - 2)
  frame.scrollTrack:EnableMouse(true)
  WheelOn(frame.scrollTrack)
  if frame.scrollTrack.SetFrameLevel and frame.GetFrameLevel then
    frame.scrollTrack:SetFrameLevel(frame:GetFrameLevel() + 6)
  end
  frame.scrollTrack:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    insets = { left = 0, right = 0, top = 0, bottom = 0 },
  })
  frame.scrollTrack:SetBackdropColor(.08, .1, .12, .95)
  frame.scrollTrack:SetScript("OnMouseWheel", function(a, b)
    ScrollText(frame, WheelDelta(a, b))
  end)
  frame.scrollTrack:SetScript("OnMouseUp", function()
    frame.textScroll = JumpScroll(this, table.getn(frame.textLines or {}), VIEW_LINES)
    ApplyTextScroll(frame)
  end)

  frame.scrollThumb = CreateFrame("Frame", "QtUIQuestTextThumb", frame.scrollTrack)
  frame.scrollThumb:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    insets = { left = 0, right = 0, top = 0, bottom = 0 },
  })
  frame.scrollThumb:SetBackdropColor(.38, .55, .62, 1)
  PlaceBox(frame.scrollThumb, frame.scrollTrack, 2, TEXT_H - 40, SCROLL_W - 2, TEXT_H - 4)

  frame.rewardPanel = CreateFrame("Button", "QtUIQuestRewardPanel", frame)
  PlaceBox(frame.rewardPanel, frame, PAD, REWARD_BOTTOM, listLeft - SCROLL_W - 10, REWARD_TOP)
  frame.rewardPanel:EnableMouse(true)
  WheelOn(frame.rewardPanel)
  if frame.rewardPanel.SetFrameLevel and frame.GetFrameLevel then
    frame.rewardPanel:SetFrameLevel(frame:GetFrameLevel() + 4)
  end
  frame.rewardPanel:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  frame.rewardPanel:SetBackdropColor(.035, .045, .05, .92)
  frame.rewardPanel:SetBackdropBorderColor(.22, .3, .34, 1)
  frame.rewardPanel:SetScript("OnMouseWheel", function(a, b)
    ScrollRewards(frame, WheelDelta(a, b))
  end)

  frame.rewardTrack = CreateFrame("Button", "QtUIQuestRewardScroll", frame)
  PlaceBox(frame.rewardTrack, frame, listLeft - SCROLL_W - 8, REWARD_BOTTOM, listLeft - 8, REWARD_TOP)
  frame.rewardTrack:EnableMouse(true)
  WheelOn(frame.rewardTrack)
  if frame.rewardTrack.SetFrameLevel and frame.GetFrameLevel then
    frame.rewardTrack:SetFrameLevel(frame:GetFrameLevel() + 6)
  end
  frame.rewardTrack:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    insets = { left = 0, right = 0, top = 0, bottom = 0 },
  })
  frame.rewardTrack:SetBackdropColor(.08, .1, .12, .95)
  frame.rewardTrack:SetScript("OnMouseWheel", function(a, b)
    ScrollRewards(frame, WheelDelta(a, b))
  end)
  frame.rewardTrack:SetScript("OnMouseUp", function()
    frame.rewardScroll = JumpScroll(this, frame.rewardCount or 0, REWARD_VIEW)
    ApplyRewardScroll(frame)
  end)

  frame.rewardThumb = CreateFrame("Frame", "QtUIQuestRewardThumb", frame.rewardTrack)
  frame.rewardThumb:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    insets = { left = 0, right = 0, top = 0, bottom = 0 },
  })
  frame.rewardThumb:SetBackdropColor(.38, .55, .62, 1)
  PlaceBox(frame.rewardThumb, frame.rewardTrack, 2, 2, SCROLL_W - 2, REWARD_H - 2)

  frame.rewardHeader = frame.rewardPanel:CreateFontString(nil, "OVERLAY")
  frame.rewardMoney = frame.rewardPanel:CreateFontString(nil, "OVERLAY")
  Paint(frame.rewardHeader, TEXT_SIZE, 1, .82, .2)
  Paint(frame.rewardMoney, TEXT_SIZE, 1, 1, 1)
  frame.rewardHeader:SetText("Rewards")

  frame.itemBtns = {}
  for i = 1, MAX_ITEMS do
    frame.itemBtns[i] = MakeItemButton(frame.rewardPanel, i)
  end
  frame.textLines = {}
  frame.textScroll = 0
  frame.rewardScroll = 0
  frame.listScroll = 0

  local function HideAbandonConfirm()
    if frame.abandonConfirm then ParkFrame(frame.abandonConfirm) end
  end

  local function DoAbandon()
    HideAbandonConfirm()
    local sel = 0
    if type(GetQuestLogSelection) == "function" then
      sel = tonumber(GetQuestLogSelection()) or 0
    end
    if sel > 0 and type(SelectQuestLogEntry) == "function" then
      pcall(SelectQuestLogEntry, sel)
    end
    if type(SetAbandonQuest) == "function" then pcall(SetAbandonQuest) end
    if type(AbandonQuest) == "function" then pcall(AbandonQuest) end
    QtUI:RefreshQuestLog()
  end

  local function ShowAbandonConfirm()
    local sel = 0
    if type(GetQuestLogSelection) == "function" then
      sel = tonumber(GetQuestLogSelection()) or 0
    end
    if sel < 1 then return end
    if type(SelectQuestLogEntry) == "function" then pcall(SelectQuestLogEntry, sel) end
    if type(SetAbandonQuest) == "function" then pcall(SetAbandonQuest) end
    local name
    if type(GetAbandonQuestName) == "function" then
      local ok, n = pcall(GetAbandonQuestName)
      if ok then name = n end
    end
    if (not name or name == "") and type(GetQuestLogTitle) == "function" then
      local title = GetQuestLogTitle(sel)
      name = title
    end
    if not name or name == "" then return end
    local box = frame.abandonConfirm
    if box and box.label then
      box.label:SetText("Abandon  " .. name .. "?")
      Paint(box.label, 12, 1, .9, .45, "CENTER", "MIDDLE")
    end
    if box then
      PlaceBox(box, frame, PAD, BTN_Y, WIN_W - LIST_W - PAD - 4, BTN_Y + BTN_H + 28)
      if box.EnableMouse then box:EnableMouse(true) end
      if box.Show then pcall(box.Show, box) end
      if box.Raise then pcall(box.Raise, box) end
    end
  end

  local function ClickAbandon()
    ShowAbandonConfirm()
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

  local confirm = CreateFrame("Frame", "QtUIQuestAbandonConfirm", frame)
  if confirm.SetFrameLevel and frame.GetFrameLevel then
    confirm:SetFrameLevel(frame:GetFrameLevel() + 20)
  end
  confirm:EnableMouse(true)
  confirm:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  confirm:SetBackdropColor(.04, .05, .06, .98)
  confirm:SetBackdropBorderColor(.4, .28, .2, 1)
  confirm.label = confirm:CreateFontString(nil, "OVERLAY")
  PlaceBox(confirm.label, confirm, 8, 28, 250, 50)
  Paint(confirm.label, 12, 1, .9, .45, "LEFT", "MIDDLE")

  local function MakeConfirmBtn(name, label, left, click)
    local btn = CreateFrame("Button", name, confirm)
    PlaceBox(btn, confirm, left, 6, left + 70, 26)
    if btn.EnableMouse then btn:EnableMouse(true) end
    if btn.RegisterForClicks then btn:RegisterForClicks("LeftButtonUp") end
    if btn.SetFrameLevel and confirm.GetFrameLevel then
      btn:SetFrameLevel(confirm:GetFrameLevel() + 2)
    end
    btn:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 8, edgeSize = 8,
      insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    btn:SetBackdropColor(.08, .1, .12, .95)
    btn:SetBackdropBorderColor(.3, .38, .4, 1)
    btn.label = btn:CreateFontString(nil, "OVERLAY")
    btn.label:ClearAllPoints()
    btn.label:SetPoint("CENTER", btn, "CENTER", 0, 0)
    btn.label:SetText(label)
    Paint(btn.label, 11, 1, 1, 1, "CENTER", "MIDDLE")
    btn:SetScript("OnMouseUp", function()
      if arg1 == "LeftButton" or arg1 == nil then click() end
    end)
    return btn
  end
  MakeConfirmBtn("QtUIQuestAbandonYes", "Yes", 8, DoAbandon)
  MakeConfirmBtn("QtUIQuestAbandonNo", "No", 86, HideAbandonConfirm)
  frame.abandonConfirm = confirm
  ParkFrame(confirm)

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
    pcall(events.RegisterEvent, events, "PARTY_MEMBERS_CHANGED")
    pcall(events.RegisterEvent, events, "RAID_ROSTER_UPDATE")
    pcall(events.RegisterEvent, events, "PARTY_MEMBER_ENABLE")
    pcall(events.RegisterEvent, events, "PARTY_MEMBER_DISABLE")
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
