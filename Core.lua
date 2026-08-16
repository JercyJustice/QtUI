PotatoUI = CreateFrame("Frame", "PotatoUIEventFrame", UIParent)
PotatoUI.version = "0.8.9"
PotatoUI.media = {
  statusbar = "Interface\\TargetingFrame\\UI-StatusBar",
}

local function Print(message)
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00PotatoUI|r: " .. message)
  end
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
  if PotatoUIDB.scale == nil then PotatoUIDB.scale = 1 end
end

function PotatoUI:ApplyScale()
  local scale = PotatoUIDB.scale or 1
  if self.actionPanel then self.actionPanel:SetScale(scale) end
  if self.playerFrame then self.playerFrame:SetScale(scale) end
  if self.targetFrame then self.targetFrame:SetScale(scale) end
end

function PotatoUI:Initialize()
  if self.initialized then return end
  self.initialized = true
  self:EnsureDB()

  if self.SetupActionBars then self:SetupActionBars() end
  if self.SetupUnitFrames then self:SetupUnitFrames() end
  if self.SetupCastBar then self:SetupCastBar() end
  if self.SetupPartyFrames then self:SetupPartyFrames() end
  if self.SetupBags then self:SetupBags() end
  if self.SetupMinimap then self:SetupMinimap() end
  if self.SetupWorldMap then self:SetupWorldMap() end
  if self.SetupAutoLoot then self:SetupAutoLoot() end
  if self.SetupDataText then self:SetupDataText() end
  self:ApplyScale()

  SLASH_POTATOUI1 = "/potatoui"
  SLASH_POTATOUI2 = "/pui"
  SlashCmdList["POTATOUI"] = function(message)
    local command = string.lower(message or "")
    local _, _, scale = string.find(command, "^scale%s+(%d+%.?%d*)$")

    if scale then
      scale = tonumber(scale)
      if scale and scale >= .7 and scale <= 1.3 then
        PotatoUIDB.scale = scale
        PotatoUI:ApplyScale()
        Print("Scale set to " .. scale .. ".")
      else
        Print("Scale must be between 0.7 and 1.3.")
      end
    elseif command == "reset" then
      PotatoUIDB = { scale = 1 }
      ReloadUI()
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
    else
      Print("Loaded v" .. PotatoUI.version .. ". Commands: /pui bags, /pui reload, /pui scale 0.7-1.3, /pui reset")
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
