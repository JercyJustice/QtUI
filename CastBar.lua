local function StopCast(frame)
  frame.casting = nil
  frame.channeling = nil
  frame:SetScript("OnUpdate", nil)
  frame:Hide()
end

local function UpdateCast(frame, elapsed)
  frame.elapsed = frame.elapsed + elapsed
  local remaining = frame.duration - frame.elapsed
  if remaining < 0 then remaining = 0 end

  if frame.channeling then
    frame:SetValue(remaining)
  else
    frame:SetValue(math.min(frame.elapsed, frame.duration))
  end
  frame.time:SetText(string.format("%.1f", remaining))

  if remaining <= 0 then StopCast(frame) end
end

local function StartCast(frame, spellName, durationMS, channeling)
  local duration = (tonumber(durationMS) or 0) / 1000
  if duration <= 0 then duration = .1 end

  frame.duration = duration
  frame.elapsed = 0
  frame.casting = not channeling
  frame.channeling = channeling
  frame:SetMinMaxValues(0, duration)
  frame:SetValue(channeling and duration or 0)
  frame.spell:SetText(spellName or "Casting")
  frame.time:SetText(string.format("%.1f", duration))
  if channeling then
    frame:SetStatusBarColor(.48, .34, .82)
  else
    frame:SetStatusBarColor(.88, .58, .16)
  end
  frame:SetScript("OnUpdate", function()
    UpdateCast(this, arg1 or 0)
  end)
  frame:Show()
end

function QtUI:SetupCastBar()
  if self.castBar or not self.playerFrame then return end

  -- The original bar is positioned for Blizzard's unit frames and otherwise
  -- appears underneath QtUI's replacements.
  self:HideFrame(CastingBarFrame)

  local bar = CreateFrame("StatusBar", "QtUICastBar", self.playerFrame)
  bar:SetWidth(260)
  bar:SetHeight(14)
  bar:SetPoint("TOP", self.playerFrame, "BOTTOM", 0, -3)
  bar:SetFrameStrata("MEDIUM")
  bar:SetFrameLevel(self.playerFrame:GetFrameLevel() + 3)
  bar:SetStatusBarTexture(self.media.statusbar)
  bar:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 8,
    edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  bar:SetBackdropColor(.025, .03, .04, .9)
  bar:SetBackdropBorderColor(.18, .24, .28, 1)

  bar.background = bar:CreateTexture(nil, "BACKGROUND")
  bar.background:SetAllPoints(bar)
  bar.background:SetTexture(self.media.statusbar)
  bar.background:SetVertexColor(.035, .04, .055, .95)

  bar.spell = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  bar.spell:SetPoint("LEFT", bar, "LEFT", 6, 0)
  bar.spell:SetJustifyH("LEFT")

  bar.time = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  bar.time:SetPoint("RIGHT", bar, "RIGHT", -6, 0)
  bar.time:SetJustifyH("RIGHT")
  bar:Hide()

  local events = CreateFrame("Frame", "QtUICastEvents")
  events:RegisterEvent("SPELLCAST_START")
  events:RegisterEvent("SPELLCAST_STOP")
  events:RegisterEvent("SPELLCAST_FAILED")
  events:RegisterEvent("SPELLCAST_INTERRUPTED")
  pcall(events.RegisterEvent, events, "SPELLCAST_DELAYED")
  pcall(events.RegisterEvent, events, "SPELLCAST_CHANNEL_START")
  pcall(events.RegisterEvent, events, "SPELLCAST_CHANNEL_UPDATE")
  pcall(events.RegisterEvent, events, "SPELLCAST_CHANNEL_STOP")
  events:SetScript("OnEvent", function()
    if event == "SPELLCAST_START" then
      StartCast(bar, arg1, arg2, nil)
    elseif event == "SPELLCAST_CHANNEL_START" then
      -- Original clients send duration first; tolerate name-first variants.
      if tonumber(arg1) then
        StartCast(bar, arg2, arg1, true)
      else
        StartCast(bar, arg1, arg2, true)
      end
    elseif event == "SPELLCAST_DELAYED" and bar.casting then
      bar.duration = bar.duration + ((tonumber(arg1) or 0) / 1000)
      bar:SetMinMaxValues(0, bar.duration)
    elseif event == "SPELLCAST_CHANNEL_UPDATE" and bar.channeling then
      local remaining = (tonumber(arg1) or 0) / 1000
      if remaining > 0 then bar.elapsed = math.max(0, bar.duration - remaining) end
    elseif event == "SPELLCAST_STOP" and bar.casting then
      StopCast(bar)
    elseif event == "SPELLCAST_CHANNEL_STOP" and bar.channeling then
      StopCast(bar)
    elseif event == "SPELLCAST_FAILED" or event == "SPELLCAST_INTERRUPTED" then
      StopCast(bar)
    end
  end)

  self.castBar = bar
  self.castEvents = events
end
