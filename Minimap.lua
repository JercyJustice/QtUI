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
  "MinimapCloseButton",
  "MiniMapCloseButton",
  "MinimapToggleButton",
}

local function UpdateZoneName()
  if not PotatoUI.minimapZone then return end
  local zone = ""
  if type(GetMinimapZoneText) == "function" then zone = GetMinimapZoneText() or "" end
  if zone == "" and type(GetZoneText) == "function" then zone = GetZoneText() or "" end
  PotatoUI.minimapZone:SetText(zone)
end

local function HandleMouseWheel()
  if not Minimap.GetZoom or not Minimap.SetZoom then return end
  local zoom = Minimap:GetZoom() or 0
  if (arg1 or 0) > 0 then zoom = math.min(5, zoom + 1) else zoom = math.max(0, zoom - 1) end
  Minimap:SetZoom(zoom)
end

function PotatoUI:SetupMinimap()
  if not Minimap then return end

  for _, name in ipairs(hiddenDecorations) do
    self:HideFrame(getglobal(name))
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
  Minimap:EnableMouseWheel(true)
  Minimap:SetScript("OnMouseWheel", HandleMouseWheel)

  local zone = (MinimapCluster or UIParent):CreateFontString("PotatoUIMinimapZone", "OVERLAY", "GameFontNormalSmall")
  zone:SetPoint("BOTTOM", Minimap, "TOP", 0, 2)
  zone:SetWidth(MAP_SIZE)
  zone:SetJustifyH("CENTER")
  zone:SetTextColor(1, .82, .2)
  if zone.SetShadowOffset then zone:SetShadowOffset(1, -1) end
  if zone.SetShadowColor then zone:SetShadowColor(0, 0, 0, 1) end
  self.minimapZone = zone

  local events = CreateFrame("Frame", "PotatoUIMinimapEvents")
  events:RegisterEvent("MINIMAP_ZONE_CHANGED")
  events:RegisterEvent("ZONE_CHANGED")
  events:RegisterEvent("ZONE_CHANGED_INDOORS")
  events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
  events:SetScript("OnEvent", UpdateZoneName)

  UpdateZoneName()
end
