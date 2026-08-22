local MAP_SIZE = 148

local hiddenDecorations = {
  "MinimapBorder",
  "MinimapBorderTop",
  "MinimapBackdrop",
  "MinimapZoomIn",
  "MinimapZoomOut",
  "MinimapNorthTag",
  "MiniMapWorldMapButton",
  "GameTimeFrame",
  "MinimapZoneTextButton",
  "MinimapZoneText",
  "MiniMapZoneText",
  "MinimapCloseButton",
  "MiniMapCloseButton",
  "MinimapToggleButton",
}

local nativeLayout
local skinApplied

local function SnapFrame(frame)
  if not frame then return nil end
  local snap = {}
  if frame.GetWidth then snap.width = frame:GetWidth() end
  if frame.GetHeight then snap.height = frame:GetHeight() end
  if frame.GetLeft then snap.left = frame:GetLeft() end
  if frame.GetBottom then snap.bottom = frame:GetBottom() end
  if frame.GetAlpha then snap.alpha = frame:GetAlpha() end
  if frame.GetScript then
    snap.onShow = frame:GetScript("OnShow")
    snap.onMouseWheel = frame:GetScript("OnMouseWheel")
  end
  return snap
end

local function CaptureNative()
  if nativeLayout then return end
  nativeLayout = {
    cluster = SnapFrame(MinimapCluster),
    map = SnapFrame(Minimap),
    deco = {},
  }
  local i
  for i = 1, table.getn(hiddenDecorations) do
    local name = hiddenDecorations[i]
    nativeLayout.deco[name] = SnapFrame(getglobal(name))
  end
end

local function PlaceAbsolute(frame, snap)
  if not frame or not snap then return end
  local left, bottom, width, height = snap.left, snap.bottom, snap.width, snap.height
  if width and frame.SetWidth then frame:SetWidth(width) end
  if height and frame.SetHeight then frame:SetHeight(height) end
  if not left or not bottom or not width or not height then return end
  if not frame.ClearAllPoints or not frame.SetPoint then return end
  frame:ClearAllPoints()
  frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
  frame:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", left + width, bottom + height)
end

local function ParkWidget(widget)
  if not widget then return end
  if widget.EnableMouse then pcall(widget.EnableMouse, widget, false) end
  if widget.EnableMouseWheel then pcall(widget.EnableMouseWheel, widget, 0) end
  if widget.ClearAllPoints and widget.SetPoint then
    widget:ClearAllPoints()
    widget:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -4000, 4000)
  end
  if widget.Hide then pcall(widget.Hide, widget) end
end

local function UpdateZoneName()
  if not QtUI.minimapZone then return end
  local zone = ""
  if type(GetMinimapZoneText) == "function" then zone = GetMinimapZoneText() or "" end
  if zone == "" and type(GetZoneText) == "function" then zone = GetZoneText() or "" end
  QtUI.minimapZone:SetText(zone)
end

local function UpdateMinimapCoords()
  if not QtUI.minimapCoords then return end
  local x, y
  if type(GetPlayerMapPosition) == "function" then
    local ok, px, py = pcall(GetPlayerMapPosition, "player")
    if ok then
      x, y = px, py
    end
  end
  x = tonumber(x) or 0
  y = tonumber(y) or 0
  if x == 0 and y == 0 then
    QtUI.minimapCoords:SetText("--")
  else
    QtUI.minimapCoords:SetText(string.format("%.1f, %.1f", x * 100, y * 100))
  end
end

local function HandleMouseWheel()
  local delta = tonumber(arg1) or 0
  if delta == 0 then return end

  -- Prefer the native handlers so Emberveil can keep its indoor/outdoor zoom
  -- state in sync. Some client builds omit them, so retain a direct fallback.
  if delta > 0 and type(Minimap_ZoomIn) == "function" then
    Minimap_ZoomIn()
    return
  elseif delta < 0 and type(Minimap_ZoomOut) == "function" then
    Minimap_ZoomOut()
    return
  end

  local minimap = Minimap
  if not minimap or not minimap.GetZoom or not minimap.SetZoom then return end
  local zoom = tonumber(minimap:GetZoom()) or 0
  if delta > 0 then zoom = math.min(5, zoom + 1) else zoom = math.max(0, zoom - 1) end
  minimap:SetZoom(zoom)
end

local function ForwardMinimapScript(handler)
  if not handler then return end
  local previousThis = this
  this = Minimap
  pcall(handler)
  this = previousThis
end

local function MinimapSkinOn()
  if QtUI.IsFeatureEnabled then return QtUI:IsFeatureEnabled("minimap") end
  return true
end

local function EnsureChrome()
  if QtUI.minimapInput then return end

  local nativeMouseDown = Minimap:GetScript("OnMouseDown")
  local nativeMouseUp = Minimap:GetScript("OnMouseUp")
  local nativeClick = Minimap:GetScript("OnClick")
  local input = CreateFrame("Button", "QtUIMinimapInput", Minimap)
  input:SetAllPoints(Minimap)
  if input.SetFrameLevel then input:SetFrameLevel(Minimap:GetFrameLevel() or 1) end
  input:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  input:SetScript("OnMouseWheel", HandleMouseWheel)
  input:SetScript("OnMouseDown", function() ForwardMinimapScript(nativeMouseDown) end)
  input:SetScript("OnMouseUp", function() ForwardMinimapScript(nativeMouseUp) end)
  input:SetScript("OnClick", function() ForwardMinimapScript(nativeClick) end)
  QtUI.minimapInput = input

  local zone = (MinimapCluster or UIParent):CreateFontString("QtUIMinimapZone", "OVERLAY", "GameFontNormalSmall")
  zone:SetJustifyH("CENTER")
  zone:SetTextColor(1, .82, .2)
  if QtUI.ApplyFont then QtUI:ApplyFont(zone, 12, 1, .82, .2) end
  if zone.SetShadowOffset then zone:SetShadowOffset(1, -1) end
  if zone.SetShadowColor then zone:SetShadowColor(0, 0, 0, 1) end
  QtUI.minimapZone = zone

  local coords = (MinimapCluster or UIParent):CreateFontString("QtUIMinimapCoords", "OVERLAY", "GameFontNormalSmall")
  coords:SetJustifyH("CENTER")
  coords:SetTextColor(1, 1, 1)
  if QtUI.ApplyFont then
    QtUI:ApplyFont(coords, 11, 1, 1, 1)
  elseif coords.SetFont then
    local font = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    coords:SetFont(font, 11, "OUTLINE")
  end
  if coords.SetShadowOffset then coords:SetShadowOffset(1, -1) end
  if coords.SetShadowColor then coords:SetShadowColor(0, 0, 0, 1) end
  QtUI.minimapCoords = coords

  local coordTicker = CreateFrame("Frame", "QtUIMinimapCoordTicker")
  coordTicker.elapsed = 0
  coordTicker:SetScript("OnUpdate", function()
    if not MinimapSkinOn() then return end
    this.elapsed = this.elapsed + (arg1 or 0)
    if this.elapsed < .5 then return end
    this.elapsed = 0
    UpdateMinimapCoords()
  end)
  QtUI.minimapCoordTicker = coordTicker

  local events = CreateFrame("Frame", "QtUIMinimapEvents")
  events:RegisterEvent("MINIMAP_ZONE_CHANGED")
  events:RegisterEvent("ZONE_CHANGED")
  events:RegisterEvent("ZONE_CHANGED_INDOORS")
  events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
  events:SetScript("OnEvent", function()
    if not MinimapSkinOn() then return end
    UpdateZoneName()
    UpdateMinimapCoords()
  end)
  QtUI.minimapEvents = events
end

local function ApplyMinimapSkin()
  EnsureChrome()

  local i
  for i = 1, table.getn(hiddenDecorations) do
    ParkWidget(getglobal(hiddenDecorations[i]))
  end

  local nativeZone = getglobal("MinimapZoneText") or getglobal("MiniMapZoneText")
  if nativeZone then
    if nativeZone.SetText then pcall(nativeZone.SetText, nativeZone, "") end
    if nativeZone.SetAlpha then pcall(nativeZone.SetAlpha, nativeZone, 0) end
    ParkWidget(nativeZone)
  end

  if Minimap.SetMaskTexture then Minimap:SetMaskTexture("Textures\\MinimapMask") end

  if MinimapCluster then
    MinimapCluster:ClearAllPoints()
    MinimapCluster:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -16, -28)
    MinimapCluster:SetWidth(MAP_SIZE)
    MinimapCluster:SetHeight(MAP_SIZE + 18)
  end

  Minimap:ClearAllPoints()
  Minimap:SetPoint("TOP", MinimapCluster or UIParent, "TOP", 0, -14)
  Minimap:SetWidth(MAP_SIZE)
  Minimap:SetHeight(MAP_SIZE)
  Minimap:EnableMouse(true)
  Minimap:EnableMouseWheel(1)
  Minimap:SetScript("OnMouseWheel", HandleMouseWheel)

  local input = QtUI.minimapInput
  if input then
    input:ClearAllPoints()
    input:SetAllPoints(Minimap)
    if input.SetFrameLevel then input:SetFrameLevel(Minimap:GetFrameLevel() or 1) end
    input:EnableMouse(true)
    input:EnableMouseWheel(1)
    if input.Show then pcall(input.Show, input) end
  end

  local zone = QtUI.minimapZone
  if zone then
    zone:ClearAllPoints()
    zone:SetPoint("BOTTOM", Minimap, "TOP", 0, 2)
    zone:SetWidth(MAP_SIZE)
    if zone.Show then pcall(zone.Show, zone) end
  end

  local coords = QtUI.minimapCoords
  if coords then
    coords:ClearAllPoints()
    coords:SetPoint("BOTTOM", Minimap, "BOTTOM", 0, 4)
    coords:SetWidth(MAP_SIZE)
    if coords.Show then pcall(coords.Show, coords) end
  end

  UpdateZoneName()
  UpdateMinimapCoords()
  skinApplied = 1
end

function QtUI:RestoreMinimap()
  if not Minimap then return end

  ParkWidget(self.minimapInput)
  if self.minimapZone then
    self.minimapZone:SetText("")
    ParkWidget(self.minimapZone)
  end
  if self.minimapCoords then
    self.minimapCoords:SetText("")
    ParkWidget(self.minimapCoords)
  end

  local snap = nativeLayout
  if snap and snap.cluster then
    PlaceAbsolute(MinimapCluster, snap.cluster)
  elseif MinimapCluster then
    MinimapCluster:ClearAllPoints()
    MinimapCluster:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, 0)
    MinimapCluster:SetWidth(192)
    MinimapCluster:SetHeight(192)
  end

  if snap and snap.map then
    PlaceAbsolute(Minimap, snap.map)
    if snap.map.onMouseWheel then
      Minimap:SetScript("OnMouseWheel", snap.map.onMouseWheel)
    else
      Minimap:SetScript("OnMouseWheel", nil)
    end
  else
    Minimap:ClearAllPoints()
    Minimap:SetPoint("CENTER", MinimapCluster or UIParent, "TOPRIGHT", -76, -82)
    Minimap:SetWidth(140)
    Minimap:SetHeight(140)
    Minimap:SetScript("OnMouseWheel", nil)
  end
  if Minimap.SetMaskTexture then Minimap:SetMaskTexture("Textures\\MinimapMask") end
  Minimap:EnableMouse(true)

  local i
  for i = 1, table.getn(hiddenDecorations) do
    local name = hiddenDecorations[i]
    local frame = getglobal(name)
    if frame then
      local deco = snap and snap.deco and snap.deco[name]
      if frame.SetScript then pcall(frame.SetScript, frame, "OnShow", deco and deco.onShow or nil) end
      if deco then PlaceAbsolute(frame, deco) end
      if deco and deco.alpha and frame.SetAlpha then pcall(frame.SetAlpha, frame, deco.alpha) end
      if frame.Show then pcall(frame.Show, frame) end
    end
  end

  local nativeZone = getglobal("MinimapZoneText") or getglobal("MiniMapZoneText")
  if nativeZone then
    if nativeZone.SetAlpha then pcall(nativeZone.SetAlpha, nativeZone, 1) end
    if nativeZone.SetText and type(GetMinimapZoneText) == "function" then
      pcall(nativeZone.SetText, nativeZone, GetMinimapZoneText() or "")
    end
    if nativeZone.Show then pcall(nativeZone.Show, nativeZone) end
  end

  skinApplied = nil
end

function QtUI:SetupMinimap()
  if not Minimap then return end
  CaptureNative()
  if not MinimapSkinOn() then
    if skinApplied then self:RestoreMinimap() end
    return
  end
  ApplyMinimapSkin()
end
