PotatoUI = CreateFrame("Frame", "PotatoUIEventFrame", UIParent)
PotatoUI.version = "0.10.3"
PotatoUI.media = {
  statusbar = "Interface\\TargetingFrame\\UI-StatusBar",
}

local function Print(message)
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00PotatoUI|r: " .. message)
  end
end

function PotatoUI:Print(message)
  Print(message)
end

function PotatoUI:CreatePanel(name, parent, level)
  local panel = CreateFrame("Frame", name, parent or UIParent)
  panel:SetFrameStrata("BACKGROUND")
  panel:SetFrameLevel(level or 1)
  panel:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 8,
    edgeSize = 12,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  panel:SetBackdropColor(.025, .035, .045, .92)
  panel:SetBackdropBorderColor(.18, .24, .28, 1)
  return panel
end

function PotatoUI:HideFrame(frame)
  if not frame then return end
  frame:Hide()
  if type(frame.SetScript) == "function" then
    frame:SetScript("OnShow", function() this:Hide() end)
  end
end

function PotatoUI:EnsureDB()
  if not PotatoUIDB then PotatoUIDB = {} end
  -- Discard values saved by versions that offered UI scaling. Emberveil does
  -- not apply frame transforms consistently, so PotatoUI now uses fixed sizes.
  PotatoUIDB.scale = nil
  if self.EnsureFeatureDefaults then self:EnsureFeatureDefaults() end
end

function PotatoUI:Initialize()
  if self.initialized then return end
  self.initialized = true
  self:EnsureDB()

  if self:IsFeatureEnabled("actionBars") and self.SetupActionBars then self:SetupActionBars() end
  if self:IsFeatureEnabled("experienceBar") and self.SetupXPBar then self:SetupXPBar() end
  if self:IsFeatureEnabled("unitFrames") and self.SetupUnitFrames then self:SetupUnitFrames() end
  if self:IsFeatureEnabled("castBar") and self.SetupCastBar then self:SetupCastBar() end
  if self:IsFeatureEnabled("partyFrames") and self.SetupPartyFrames then self:SetupPartyFrames() end
  if self:IsFeatureEnabled("bags") and self.SetupBags then self:SetupBags() end
  if self:IsFeatureEnabled("minimap") and self.SetupMinimap then self:SetupMinimap() end
  if self:IsFeatureEnabled("mapReveal") and self.SetupWorldMap then self:SetupWorldMap() end
  if self:IsFeatureEnabled("autoLoot") and self.SetupAutoLoot then self:SetupAutoLoot() end
  if self:IsFeatureEnabled("autoSell") and self.SetupAutoSell then self:SetupAutoSell() end
  if self:IsFeatureEnabled("dataText") and self.SetupDataText then self:SetupDataText() end
  if self.SetupSettingsButton then self:SetupSettingsButton() end
  if self.SetupMoveMode then self:SetupMoveMode() end

  SLASH_POTATOUI1 = "/potatoui"
  SLASH_POTATOUI2 = "/pui"
  SlashCmdList["POTATOUI"] = function(message)
    local command = string.lower(message or "")
    command = string.gsub(command, "^%s+", "")
    command = string.gsub(command, "%s+$", "")
    if command == "reset" then
      PotatoUIDB = { positions = {} }
      if type(ReloadUI) == "function" then
        ReloadUI()
      elseif type(ConsoleExec) == "function" then
        ConsoleExec("reloadui")
      else
        Print("Settings reset. Restart Emberveil to apply the default layout.")
      end
    elseif command == "reload" then
      if type(ReloadUI) == "function" then
        ReloadUI()
      elseif type(ConsoleExec) == "function" then
        ConsoleExec("reloadui")
      else
        Print("This Emberveil build does not expose a UI reload function; restart the client instead.")
      end
    elseif command == "bags" then
      PotatoUI:ToggleBags()
    elseif command == "move" then
      PotatoUI:ToggleMoveMode()
    elseif command == "settings" or command == "config" then
      PotatoUI:ToggleSettings()
    else
      Print("Loaded v" .. PotatoUI.version .. ". Commands: /pui settings, /pui move, /pui bags, /pui reload, /pui reset")
    end
  end

  Print("Loaded. Type /pui for commands.")
end

PotatoUI:SetScript("OnEvent", function()
  if event == "ADDON_LOADED" and arg1 == "PotatoUI" then
    PotatoUI:EnsureDB()
  elseif event == "PLAYER_ENTERING_WORLD" then
    PotatoUI:Initialize()
  end
end)
PotatoUI:RegisterEvent("ADDON_LOADED")
PotatoUI:RegisterEvent("PLAYER_ENTERING_WORLD")
