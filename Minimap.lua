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

local function UpdateZoneName()
  if not QtUI.minimapZone then return end
  local zone = ""
  if type(GetMinimapZoneText) == "function" then zone = GetMinimapZoneText() or "" end
  if zone == "" and type(GetZoneText) == "function" then zone = GetZoneText() or "" end
  QtUI.minimapZone:SetText(zone)
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

function QtUI:SetupMinimap()
  if not Minimap then return end

  for _, name in ipairs(hiddenDecorations) do
    self:HideFrame(getglobal(name))
  end
  -- Emberveil ships MinimapZoneText with the placeholder "BLAH!".
  local nativeZone = getglobal("MinimapZoneText") or getglobal("MiniMapZoneText")
  if nativeZone then
    if nativeZone.SetText then pcall(nativeZone.SetText, nativeZone, "") end
    if nativeZone.SetAlpha then pcall(nativeZone.SetAlpha, nativeZone, 0) end
    if nativeZone.ClearAllPoints and nativeZone.SetPoint then
      pcall(function()
        nativeZone:ClearAllPoints()
        nativeZone:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -4000, 4000)
      end)
    end
  end

  -- Retain the native circular render that works in Emberveil, but strip all
  -- of Blizzard's surrounding artwork and controls.
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

  -- Emberveil renders the minimap but does not consistently include that
  -- special render frame in UI mouse hit testing. A regular transparent button
  -- reliably captures the wheel before it reaches the third-person camera.
  local nativeMouseDown = Minimap:GetScript("OnMouseDown")
  local nativeMouseUp = Minimap:GetScript("OnMouseUp")
  local nativeClick = Minimap:GetScript("OnClick")
  local input = CreateFrame("Button", "QtUIMinimapInput", MinimapCluster or UIParent)
  input:SetAllPoints(Minimap)
  input:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 5)
  input:EnableMouse(true)
  input:EnableMouseWheel(1)
  input:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  input:SetScript("OnMouseWheel", HandleMouseWheel)
  input:SetScript("OnMouseDown", function() ForwardMinimapScript(nativeMouseDown) end)
  input:SetScript("OnMouseUp", function() ForwardMinimapScript(nativeMouseUp) end)
  input:SetScript("OnClick", function() ForwardMinimapScript(nativeClick) end)
  self.minimapInput = input

  local zone = (MinimapCluster or UIParent):CreateFontString("QtUIMinimapZone", "OVERLAY", "GameFontNormalSmall")
  zone:SetPoint("BOTTOM", Minimap, "TOP", 0, 2)
  zone:SetWidth(MAP_SIZE)
  zone:SetJustifyH("CENTER")
  zone:SetTextColor(1, .82, .2)
  if zone.SetShadowOffset then zone:SetShadowOffset(1, -1) end
  if zone.SetShadowColor then zone:SetShadowColor(0, 0, 0, 1) end
  self.minimapZone = zone

  local events = CreateFrame("Frame", "QtUIMinimapEvents")
  events:RegisterEvent("MINIMAP_ZONE_CHANGED")
  events:RegisterEvent("ZONE_CHANGED")
  events:RegisterEvent("ZONE_CHANGED_INDOORS")
  events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
  events:SetScript("OnEvent", UpdateZoneName)

  UpdateZoneName()
end
