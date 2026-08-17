local MOVE_COLOR = { .05, .8, .62, .28 }

local function ReanchorOverlay(overlay)
  local target = overlay.entry.frame
  overlay:ClearAllPoints()
  overlay:SetPoint("TOPLEFT", target, "TOPLEFT", 0, 0)
  overlay:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 0, 0)
end

local function SaveOverlayPosition(overlay)
  local left, bottom = overlay:GetLeft(), overlay:GetBottom()
  if not left or not bottom then return end

  local entry = overlay.entry
  local target = entry.frame
  PotatoUIDB.positions[entry.key] = { x = left, y = bottom }
  target:ClearAllPoints()
  target:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
  ReanchorOverlay(overlay)
end

local function CreateMoveOverlay(entry, index)
  local overlay = CreateFrame("Button", "PotatoUIMoveOverlay" .. index, UIParent)
  overlay.entry = entry
  overlay:SetFrameStrata("TOOLTIP")
  overlay:SetFrameLevel(100)
  overlay:SetMovable(true)
  overlay:SetClampedToScreen(true)
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
    local width, height = this:GetWidth(), this:GetHeight()
    if not left or not bottom then return end
    this:ClearAllPoints()
    this:SetWidth(width)
    this:SetHeight(height)
    this:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
    this:StartMoving()
  end)
  overlay:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
    SaveOverlayPosition(this)
  end)
  overlay:SetScript("OnClick", function()
    if arg1 == "RightButton" then PotatoUI:ResetMovable(entry.key) end
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

function PotatoUI:RegisterMovable(key, label, frame)
  if not frame then return end
  if not self.movableEntries then self.movableEntries = {} end

  local entry = { key = key, label = label, frame = frame }
  local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
  entry.default = {
    point = point,
    relativeTo = relativeTo or UIParent,
    relativePoint = relativePoint or point,
    x = x or 0,
    y = y or 0,
  }
  local saved = PotatoUIDB.positions and PotatoUIDB.positions[key]
  if saved and saved.x and saved.y then
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", saved.x, saved.y)
  end

  frame:SetClampedToScreen(true)
  table.insert(self.movableEntries, entry)
  entry.overlay = CreateMoveOverlay(entry, table.getn(self.movableEntries))
end

function PotatoUI:ResetMovable(key)
  if not self.movableEntries then return end
  local _, entry
  for _, entry in ipairs(self.movableEntries) do
    if entry.key == key then
      PotatoUIDB.positions[key] = nil
      if key == "bags" then
        PotatoUIDB.bagX = nil
        PotatoUIDB.bagY = nil
        entry.default = {
          point = "BOTTOMRIGHT", relativeTo = UIParent,
          relativePoint = "BOTTOMRIGHT", x = -18, y = 220,
        }
      end
      if entry.default then
        entry.frame:ClearAllPoints()
        entry.frame:SetPoint(entry.default.point, entry.default.relativeTo,
          entry.default.relativePoint, entry.default.x, entry.default.y)
      end
      ReanchorOverlay(entry.overlay)
      return
    end
  end
end

function PotatoUI:SetMoveMode(enabled)
  self.moveMode = enabled and true or nil
  if not self.movableEntries then return end
  local _, entry
  for _, entry in ipairs(self.movableEntries) do
    if self.moveMode then
      ReanchorOverlay(entry.overlay)
      entry.overlay:Show()
    else
      entry.overlay:Hide()
    end
  end
end

function PotatoUI:ToggleMoveMode()
  self:SetMoveMode(not self.moveMode)
  if self.moveMode then
    self:Print("Move mode unlocked. Drag the green fields; right-click resets one. Type /pui move again to lock.")
  else
    self:Print("Move mode locked. Positions saved.")
  end
end

function PotatoUI:SetupMoveMode()
  if self.moveModeReady then return end
  self.moveModeReady = true
  if not PotatoUIDB.positions then PotatoUIDB.positions = {} end

  self:RegisterMovable("player", "Player", self.playerFrame)
  self:RegisterMovable("combo", "Combo Points", self.comboFrame)
  self:RegisterMovable("target", "Target", self.targetFrame)
  self:RegisterMovable("cast", "Cast Bar", self.castBar)
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
  self:RegisterMovable("bags", "Bags", self.bagFrame)
  self:RegisterMovable("data", "Gold / Time / FPS", self.dataBar)
end
