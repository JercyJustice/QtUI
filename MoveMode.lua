local MOVE_COLOR = { .05, .8, .62, .28 }
local GRID_STEP = 16
local GRID_MAJOR = 4
local GRID_LINE = 2

local function KindForOffset(offset)
  if offset == 0 then return "axis" end
  local steps = math.floor((math.abs(offset) / GRID_STEP) + 0.5)
  if math.mod(steps, GRID_MAJOR) == 0 then return "major" end
  return "minor"
end

local function ColorForKind(kind)
  if kind == "axis" then return .3, 1, .85, .55 end
  if kind == "major" then return .22, .78, .7, .32 end
  return 1, 1, 1, .14
end

local function AddGridLine(grid, vertical, offset, width, height)
  local tex = grid:CreateTexture(nil, "ARTWORK")
  tex:SetTexture("Interface\\Buttons\\WHITE8X8")
  local r, g, b, a = ColorForKind(KindForOffset(offset))
  tex:SetVertexColor(r, g, b, a)
  -- Corner anchors so Emberveil actually stretches both axes. A 1px
  -- SetWidth line is often discarded and never shows vertically.
  if vertical then
    tex:SetPoint("TOPLEFT", grid, "CENTER", offset, height / 2)
    tex:SetPoint("BOTTOMRIGHT", grid, "CENTER", offset + GRID_LINE, -(height / 2))
  else
    tex:SetPoint("TOPLEFT", grid, "CENTER", -(width / 2), offset + GRID_LINE)
    tex:SetPoint("BOTTOMRIGHT", grid, "CENTER", width / 2, offset)
  end
end

local function BuildMoveGrid(grid)
  local width = (UIParent.GetWidth and UIParent:GetWidth()) or 1024
  local height = (UIParent.GetHeight and UIParent:GetHeight()) or 768
  if width < 200 then width = 1024 end
  if height < 200 then height = 768 end

  local x = 0
  local count = 0
  while x <= (width / 2) + 1 and count < 160 do
    AddGridLine(grid, true, x, width, height)
    if x > 0 then AddGridLine(grid, true, -x, width, height) end
    x = x + GRID_STEP
    count = count + 1
  end

  local y = 0
  count = 0
  while y <= (height / 2) + 1 and count < 160 do
    AddGridLine(grid, false, y, width, height)
    if y > 0 then AddGridLine(grid, false, -y, width, height) end
    y = y + GRID_STEP
    count = count + 1
  end
end

local function EnsureMoveGrid()
  if QtUI.moveGrid then return QtUI.moveGrid end
  local grid = CreateFrame("Frame", "QtUIMoveGrid", UIParent)
  grid:SetAllPoints(UIParent)
  grid:SetFrameStrata("LOW")
  grid:SetFrameLevel(0)
  if grid.EnableMouse then grid:EnableMouse(false) end

  grid.dim = grid:CreateTexture(nil, "BACKGROUND")
  grid.dim:SetAllPoints()
  grid.dim:SetTexture("Interface\\Buttons\\WHITE8X8")
  grid.dim:SetVertexColor(0, 0, 0, .18)

  BuildMoveGrid(grid)
  grid:Hide()
  QtUI.moveGrid = grid
  return grid
end

local function EnsureMoveCatcher()
  if QtUI.moveCatcher then return QtUI.moveCatcher end
  local catcher = CreateFrame("Frame", "QtUIMoveCatcher", UIParent)
  catcher:SetWidth(1)
  catcher:SetHeight(1)
  catcher:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  catcher:Hide()
  catcher:SetScript("OnHide", function()
    if QtUI.moveMode then
      QtUI:EndMoveMode(QtUI.moveFromSettings)
    end
  end)
  if UISpecialFrames then table.insert(UISpecialFrames, "QtUIMoveCatcher") end
  QtUI.moveCatcher = catcher
  return catcher
end

local function HookEscapeToEndMove()
  if QtUI.hookedToggleGameMenu then return end
  QtUI.hookedToggleGameMenu = true
  local original = ToggleGameMenu
  ToggleGameMenu = function()
    if QtUI.moveMode then
      QtUI:EndMoveMode(QtUI.moveFromSettings)
      return
    end
    if QtUI.justEndedMove then
      QtUI.justEndedMove = nil
      return
    end
    if type(original) == "function" then original() end
  end
  if type(CloseSpecialWindows) == "function" then
    local originalClose = CloseSpecialWindows
    CloseSpecialWindows = function()
      if QtUI.moveMode then
        QtUI:EndMoveMode(QtUI.moveFromSettings)
        return 1
      end
      return originalClose()
    end
  end
end

local function ReanchorOverlay(overlay)
  local target = overlay.entry.frame
  overlay:ClearAllPoints()
  overlay:SetPoint("TOPLEFT", target, "TOPLEFT", 0, 0)
  overlay:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 0, 0)
end

local function UIScale()
  if UIParent.GetEffectiveScale then
    local scale = UIParent:GetEffectiveScale()
    if scale and scale > 0 then return scale end
  end
  if UIParent.GetScale then
    local scale = UIParent:GetScale()
    if scale and scale > 0 then return scale end
  end
  return 1
end

local function ScreenSize()
  local width = (UIParent.GetWidth and UIParent:GetWidth()) or 1024
  local height = (UIParent.GetHeight and UIParent:GetHeight()) or 768
  if width < 200 then width = 1024 end
  if height < 200 then height = 768 end
  return width, height
end

local function ClampToScreen(left, bottom, width, height)
  local screenW, screenH = ScreenSize()
  if not left or not bottom then return left, bottom end
  width = width or 0
  height = height or 0
  if width > screenW then width = screenW end
  if height > screenH then height = screenH end
  if left < 0 then left = 0 end
  if bottom < 0 then bottom = 0 end
  if left + width > screenW then left = screenW - width end
  if bottom + height > screenH then bottom = screenH - height end
  return left, bottom
end

local function PlaceFrame(frame, left, bottom)
  if not frame then return end
  frame:ClearAllPoints()
  frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
end

local function FrameSize(frame)
  if not frame then return 0, 0 end
  local width = frame.GetWidth and frame:GetWidth() or 0
  local height = frame.GetHeight and frame:GetHeight() or 0
  local left = frame.GetLeft and frame:GetLeft()
  local right = frame.GetRight and frame:GetRight()
  local top = frame.GetTop and frame:GetTop()
  local bottom = frame.GetBottom and frame:GetBottom()
  if (not width or width < 8) and left and right then width = right - left end
  if (not height or height < 8) and top and bottom then height = top - bottom end
  return width or 0, height or 0
end

-- Emberveil often drops SetWidth after ClearAllPoints. Keep a hit box with
-- a second corner so OnDragStop / mouse-up still land on the overlay.
local function PlaceSized(frame, left, bottom, width, height)
  if not frame then return end
  width = width or 0
  height = height or 0
  frame:ClearAllPoints()
  frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
  if width > 1 and height > 1 then
    frame:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", left + width, bottom + height)
    if frame.SetWidth then
      frame:SetWidth(width + 1)
      if frame.SetHeight then frame:SetHeight(height + 1) end
      frame:SetWidth(width)
      if frame.SetHeight then frame:SetHeight(height) end
    end
  end
end

local function MouseLeftDown()
  if type(IsMouseButtonDown) ~= "function" then return true end
  local ok, held = pcall(IsMouseButtonDown, "LeftButton")
  if not ok then return true end
  return held == true or held == 1 or held == "1"
end

local function SaveOverlayPosition(overlay)
  local left, bottom = overlay:GetLeft(), overlay:GetBottom()
  if not left or not bottom then return end
  local width, height = FrameSize(overlay)
  left, bottom = ClampToScreen(left, bottom, width, height)

  local entry = overlay.entry
  local target = entry.frame
  QtUIDB.positions[entry.key] = { x = left, y = bottom }
  PlaceFrame(target, left, bottom)
  PlaceSized(overlay, left, bottom, width, height)
end

local function StopOverlayDrag(overlay)
  if not overlay or not overlay.dragging then return end
  overlay.dragging = nil
  overlay:SetScript("OnUpdate", nil)
  SaveOverlayPosition(overlay)
end

local function DragOverlay()
  if not this.dragging then return end
  if not MouseLeftDown() then
    StopOverlayDrag(this)
    return
  end
  local scale = UIScale()
  local cursorX, cursorY = GetCursorPosition()
  cursorX = (cursorX or 0) / scale
  cursorY = (cursorY or 0) / scale
  local width = this.dragW or 0
  local height = this.dragH or 0
  local left = cursorX - (this.dragX or 0)
  local bottom = cursorY - (this.dragY or 0)
  left, bottom = ClampToScreen(left, bottom, width, height)
  PlaceSized(this, left, bottom, width, height)
  if this.entry and this.entry.frame then
    PlaceFrame(this.entry.frame, left, bottom)
  end
end

local function CreateMoveOverlay(entry, index)
  local overlay = CreateFrame("Button", "QtUIMoveOverlay" .. index, UIParent)
  overlay.entry = entry
  overlay:SetFrameStrata("TOOLTIP")
  overlay:SetFrameLevel(100)
  overlay:SetMovable(true)
  -- Emberveil's clamp keeps a fat inset, so bars never sit on the screen edge.
  if overlay.SetClampedToScreen then overlay:SetClampedToScreen(false) end
  overlay:EnableMouse(true)
  overlay:RegisterForDrag("LeftButton")
  overlay:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 8,
    edgeSize = 10,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  overlay:SetBackdropColor(MOVE_COLOR[1], MOVE_COLOR[2], MOVE_COLOR[3], MOVE_COLOR[4])
  overlay:SetBackdropBorderColor(.1, 1, .78, .95)

  overlay.label = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  overlay.label:SetPoint("CENTER", overlay, "CENTER", 0, 0)
  overlay.label:SetText("|cffffff33" .. entry.label .. "|r")

  overlay:SetScript("OnDragStart", function()
    local left, bottom = this:GetLeft(), this:GetBottom()
    local width, height = FrameSize(this)
    if not left or not bottom then return end
    this.dragW = width
    this.dragH = height
    PlaceSized(this, left, bottom, width, height)
    local scale = UIScale()
    local cursorX, cursorY = GetCursorPosition()
    cursorX = (cursorX or 0) / scale
    cursorY = (cursorY or 0) / scale
    this.dragX = cursorX - left
    this.dragY = cursorY - bottom
    this.dragging = true
    this:SetScript("OnUpdate", DragOverlay)
  end)
  overlay:SetScript("OnDragStop", function()
    StopOverlayDrag(this)
  end)
  overlay:SetScript("OnMouseUp", function()
    StopOverlayDrag(this)
  end)
  overlay:SetScript("OnClick", function()
    if arg1 == "RightButton" then QtUI:ResetMovable(entry.key) end
  end)
  overlay:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  overlay:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_TOP")
    GameTooltip:SetText(entry.label)
    GameTooltip:AddLine("Drag to reposition.", 1, 1, 1)
    GameTooltip:AddLine("Right-click to restore its default position.", .8, .8, .8)
    GameTooltip:Show()
  end)
  overlay:SetScript("OnLeave", function() GameTooltip:Hide() end)
  ReanchorOverlay(overlay)
  overlay:Hide()
  return overlay
end

function QtUI:RegisterMovable(key, label, frame, alwaysShow)
  if not frame then return end
  if not self.movableEntries then self.movableEntries = {} end

  local _, existing
  for _, existing in ipairs(self.movableEntries) do
    if existing.key == key then
      existing.frame = frame
      existing.label = label
      existing.alwaysShow = alwaysShow
      if existing.overlay then
        existing.overlay.entry = existing
        if existing.overlay.label then
          existing.overlay.label:SetText("|cffffff33" .. label .. "|r")
        end
        ReanchorOverlay(existing.overlay)
      end
      local saved = QtUIDB.positions and QtUIDB.positions[key]
      if saved and saved.x and saved.y then
        local width, height = FrameSize(frame)
        local left, bottom = ClampToScreen(saved.x, saved.y, width, height)
        PlaceFrame(frame, left, bottom)
      end
      return
    end
  end

  local entry = { key = key, label = label, frame = frame, alwaysShow = alwaysShow }
  local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
  entry.default = {
    point = point,
    relativeTo = relativeTo or UIParent,
    relativePoint = relativePoint or point,
    x = x or 0,
    y = y or 0,
  }
  local saved = QtUIDB.positions and QtUIDB.positions[key]
  if saved and saved.x and saved.y then
    local width = frame.GetWidth and frame:GetWidth() or 0
    local height = frame.GetHeight and frame:GetHeight() or 0
    local left, bottom = ClampToScreen(saved.x, saved.y, width, height)
    PlaceFrame(frame, left, bottom)
  end

  if frame.SetClampedToScreen then frame:SetClampedToScreen(false) end
  table.insert(self.movableEntries, entry)
  entry.overlay = CreateMoveOverlay(entry, table.getn(self.movableEntries))
end

function QtUI:ResetMovable(key)
  if not self.movableEntries then return end
  local _, entry
  for _, entry in ipairs(self.movableEntries) do
    if entry.key == key then
      QtUIDB.positions[key] = nil
      if key == "bags" then
        QtUIDB.bagX = nil
        QtUIDB.bagY = nil
        entry.default = {
          point = "BOTTOMRIGHT", relativeTo = UIParent,
          relativePoint = "BOTTOMRIGHT", x = -18, y = 220,
        }
      end
      if key == "cast" and QtUI.PlaceCastBar then
        QtUI:PlaceCastBar()
      elseif entry.default then
        entry.frame:ClearAllPoints()
        entry.frame:SetPoint(entry.default.point, entry.default.relativeTo,
          entry.default.relativePoint, entry.default.x, entry.default.y)
      end
      ReanchorOverlay(entry.overlay)
      return
    end
  end
end

function QtUI:SetMoveMode(enabled)
  self.moveMode = enabled and true or nil
  EnsureMoveCatcher()
  EnsureMoveGrid()
  HookEscapeToEndMove()

  if self.movableEntries then
    local _, entry
    for _, entry in ipairs(self.movableEntries) do
      if entry.overlay then StopOverlayDrag(entry.overlay) end
      local shown = self.moveMode and entry.frame
      if shown and not entry.alwaysShow then
        local ok, isShown = pcall(entry.frame.IsShown, entry.frame)
        shown = ok and (isShown == true or isShown == 1 or isShown == "1")
      end
      if shown then
        if entry.alwaysShow and entry.frame.Show then pcall(entry.frame.Show, entry.frame) end
        ReanchorOverlay(entry.overlay)
        entry.overlay:Show()
      else
        entry.overlay:Hide()
        if entry.key == "cast" and entry.frame and not entry.frame.casting and not entry.frame.channeling then
          if entry.frame.Hide then pcall(entry.frame.Hide, entry.frame) end
        end
      end
    end
  end

  if self.moveMode then
    if self.moveGrid then self.moveGrid:Show() end
    if self.moveCatcher then self.moveCatcher:Show() end
  else
    if self.moveGrid then self.moveGrid:Hide() end
    if self.moveCatcher then self.moveCatcher:Hide() end
  end
end

function QtUI:EndMoveMode(reopenSettings)
  if not self.moveMode then return end
  local reopen = reopenSettings
  self.moveFromSettings = nil
  self.justEndedMove = true
  self:SetMoveMode(false)
  self:Print("Move mode locked. Positions saved.")
  if reopen and self.ToggleSettings then
    if not self.settingsFrame or not self.settingsFrame:IsShown() then
      self:ToggleSettings()
    end
  end
end

function QtUI:ToggleMoveMode()
  if self.moveMode then
    self:EndMoveMode(self.moveFromSettings)
    return
  end
  self:SetMoveMode(true)
  self:Print("Move mode unlocked. Drag the green fields; right-click resets one. Escape locks.")
end

function QtUI:SetupMoveMode()
  if self.moveModeReady then return end
  self.moveModeReady = true
  if not QtUIDB.positions then QtUIDB.positions = {} end
  HookEscapeToEndMove()

  self:RegisterMovable("player", "Player", self.playerFrame)
  self:RegisterMovable("combo", "Combo Points", self.comboFrame)
  if self.meterFrames and table.getn(self.meterFrames) > 0 then
    local i
    for i = 1, table.getn(self.meterFrames) do
      local frame = self.meterFrames[i]
      local id = frame.meterId or i
      local key = "damageMeter"
      if tonumber(id) ~= 1 then key = "damageMeter" .. tostring(id) end
      self:RegisterMovable(key, "Damage Meter " .. tostring(id), frame)
    end
  else
    self:RegisterMovable("damageMeter", "Damage Meter", self.meterFrame)
  end
  self:RegisterMovable("target", "Target", self.targetFrame)
  self:RegisterMovable("targettarget", "Target of Target", self.targetTargetFrame)
  self:RegisterMovable("cast", "Cast Bar", self.castBar, true)
  self:RegisterMovable("actions", "Main Action Bar", self.actionPanel)
  self:RegisterMovable("extraActions", "Extra Action Bar", self.extraActionPanel)
  self:RegisterMovable("experience", "Experience Bar", self.xpBar)
  self:RegisterMovable("utilityActions", "Bottom-Right Action Bar", self.utilityActionPanel)
  self:RegisterMovable("sideRight", "Right Side Bar", self.sideRightPanel)
  self:RegisterMovable("sideLeft", "Left Side Bar", self.sideLeftPanel)
  self:RegisterMovable("auxiliary", "Stance / Pet Bar", self.auxiliaryPanel)
  self:RegisterMovable("party", "Party Frames", self.partyAnchor)
  self:RegisterMovable("playerPet", "Player Pet", self.playerPetFrame)
  self:RegisterMovable("minimap", "Minimap", MinimapCluster or Minimap)
  self:RegisterMovable("minimapIcon", "Minimap Icon", self.settingsButton)
  self:RegisterMovable("bags", "Bags", self.bagFrame)
  self:RegisterMovable("data", "Gold / Time / FPS", self.dataBar)
  self:SetupQuestTimerMove()
end

function QtUI:RestoreQuestTimerPosition()
  local frame = getglobal("QuestTimerFrame")
  if not frame then return end
  local saved = QtUIDB.positions and QtUIDB.positions.questTimers
  if saved and saved.x and saved.y then
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", saved.x, saved.y)
  end
end

function QtUI:SetupQuestTimerMove()
  if self.questTimerRegistered then return end
  local frame = getglobal("QuestTimerFrame")
  if not frame then
    if self.questTimerWait then return end
    local wait = CreateFrame("Frame", "QtUIQuestTimerWait")
    self.questTimerWait = wait
    wait.elapsed = 0
    wait:SetScript("OnUpdate", function()
      this.elapsed = this.elapsed + (arg1 or 0)
      if getglobal("QuestTimerFrame") then
        this:SetScript("OnUpdate", nil)
        QtUI:SetupQuestTimerMove()
        if QtUI.moveMode then QtUI:SetMoveMode(true) end
      elseif this.elapsed > 8 then
        this:SetScript("OnUpdate", nil)
      end
    end)
    return
  end
  self.questTimerRegistered = true
  self:RegisterMovable("questTimers", "Quest Timers", frame)
  self:RestoreQuestTimerPosition()
  if frame.HookScript then
    pcall(frame.HookScript, frame, "OnShow", function()
      QtUI:RestoreQuestTimerPosition()
    end)
  else
    local original = frame.GetScript and frame:GetScript("OnShow")
    frame:SetScript("OnShow", function()
      if original then original() end
      QtUI:RestoreQuestTimerPosition()
    end)
  end
  if type(QuestTimerFrame_Update) == "function" then
    local originalUpdate = QuestTimerFrame_Update
    QuestTimerFrame_Update = function()
      originalUpdate()
      QtUI:RestoreQuestTimerPosition()
    end
  end
end
