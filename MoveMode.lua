local MOVE_COLOR = { .05, .8, .62, .28 }
local GRID_STEP = 16
local GRID_MAJOR = 4
local GRID_LINE = 2
local SNAP_DIST = 10

local function SnapSettings()
  local range, left, right, top, bottom = SNAP_DIST, 0, 0, 0, 0
  if QtUI.GetLayout then
    local layout = QtUI:GetLayout()
    if layout then
      if layout.snapRange ~= nil then range = tonumber(layout.snapRange) or range end
      if layout.snapPadLeft ~= nil then left = tonumber(layout.snapPadLeft) or 0 end
      if layout.snapPadRight ~= nil then right = tonumber(layout.snapPadRight) or 0 end
      if layout.snapPadTop ~= nil then top = tonumber(layout.snapPadTop) or 0 end
      if layout.snapPadBottom ~= nil then bottom = tonumber(layout.snapPadBottom) or 0 end
    end
  end
  if range < 2 then range = 2 end
  if range > 40 then range = 40 end
  if left < 0 then left = 0 end
  if right < 0 then right = 0 end
  if top < 0 then top = 0 end
  if bottom < 0 then bottom = 0 end
  return range, left, right, top, bottom
end

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
  if (not width or width < 8) and left and right and right > left then width = right - left end
  -- Emberveil GetTop/GetBottom rewrite Y; only trust them when top is above bottom.
  if (not height or height < 8) and top and bottom and top > bottom then height = top - bottom end
  return width or 0, height or 0
end

local function ShiftDown()
  if type(IsShiftKeyDown) ~= "function" then return nil end
  local ok, held = pcall(IsShiftKeyDown)
  if not ok then return nil end
  return held == true or held == 1 or held == "1"
end

local function PointName(h, v)
  if h == "left" and v == "top" then return "TOPLEFT" end
  if h == "center" and v == "top" then return "TOP" end
  if h == "right" and v == "top" then return "TOPRIGHT" end
  if h == "left" and v == "center" then return "LEFT" end
  if h == "center" and v == "center" then return "CENTER" end
  if h == "right" and v == "center" then return "RIGHT" end
  if h == "left" and v == "bottom" then return "BOTTOMLEFT" end
  if h == "center" and v == "bottom" then return "BOTTOM" end
  if h == "right" and v == "bottom" then return "BOTTOMRIGHT" end
  if h == "left" then return "LEFT" end
  if h == "center" then return "CENTER" end
  if h == "right" then return "RIGHT" end
  if v == "top" then return "TOP" end
  if v == "center" then return "CENTER" end
  if v == "bottom" then return "BOTTOM" end
  return "BOTTOMLEFT"
end

local function EdgeX(left, width, tag)
  if tag == "center" then return left + width / 2 end
  if tag == "right" then return left + width end
  return left
end

local function EdgeY(bottom, height, tag)
  if tag == "center" then return bottom + height / 2 end
  if tag == "top" then return bottom + height end
  return bottom
end

local function FindEntry(key)
  if not QtUI.movableEntries then return nil end
  local _, entry
  for _, entry in ipairs(QtUI.movableEntries) do
    if entry.key == key then return entry end
  end
  return nil
end

local function CollectGuides(skipKey)
  local sw, sh = ScreenSize()
  local _, padL, padR, padT, padB = SnapSettings()
  local guides = {
    { kind = "screen", axis = "x", value = padL, name = "Left", tag = "left" },
    { kind = "screen", axis = "x", value = sw / 2, name = "Center", tag = "center" },
    { kind = "screen", axis = "x", value = sw - padR, name = "Right", tag = "right" },
    { kind = "screen", axis = "y", value = padB, name = "Bottom", tag = "bottom" },
    { kind = "screen", axis = "y", value = sh / 2, name = "Middle", tag = "center" },
    { kind = "screen", axis = "y", value = sh - padT, name = "Top", tag = "top" },
  }
  if QtUI.movableEntries then
    local _, entry
    for _, entry in ipairs(QtUI.movableEntries) do
      if entry.key ~= skipKey and entry.frame then
        local l = entry.frame.GetLeft and entry.frame:GetLeft()
        local b = entry.frame.GetBottom and entry.frame:GetBottom()
        local w, h = FrameSize(entry.frame)
        if l and b and w > 0 and h > 0 then
          local box = { l = l, b = b, r = l + w, t = b + h }
          table.insert(guides, { kind = "frame", key = entry.key, label = entry.label, axis = "x", value = l - padR, name = "Left", tag = "left", box = box })
          table.insert(guides, { kind = "frame", key = entry.key, label = entry.label, axis = "x", value = l + w / 2, name = "Center", tag = "center", box = box })
          table.insert(guides, { kind = "frame", key = entry.key, label = entry.label, axis = "x", value = l + w + padL, name = "Right", tag = "right", box = box })
          table.insert(guides, { kind = "frame", key = entry.key, label = entry.label, axis = "y", value = b - padT, name = "Bottom", tag = "bottom", box = box })
          table.insert(guides, { kind = "frame", key = entry.key, label = entry.label, axis = "y", value = b + h / 2, name = "Middle", tag = "center", box = box })
          table.insert(guides, { kind = "frame", key = entry.key, label = entry.label, axis = "y", value = b + h + padB, name = "Top", tag = "top", box = box })
        end
      end
    end
  end
  return guides
end

local function RangeGap(a1, a2, b1, b2)
  if a2 < b1 then return b1 - a2 end
  if b2 < a1 then return a1 - b2 end
  return 0
end

local function SnapDrag(left, bottom, width, height, skipKey)
  if not ShiftDown() then return left, bottom, nil end
  local range = SnapSettings()
  local guides = CollectGuides(skipKey)
  local ourX = { { tag = "left", pos = left }, { tag = "center", pos = left + width / 2 }, { tag = "right", pos = left + width } }
  local ourY = { { tag = "bottom", pos = bottom }, { tag = "center", pos = bottom + height / 2 }, { tag = "top", pos = bottom + height } }
  local ourL, ourR, ourB, ourT = left, left + width, bottom, bottom + height
  local bestX, bestXd, bestY, bestYd
  bestXd = range + 1
  bestYd = range + 1
  local g, e
  for _, g in ipairs(guides) do
    if g.kind == "frame" and g.box then
      if g.axis == "x" then
        if RangeGap(ourB, ourT, g.box.b, g.box.t) > range then
          g = nil
        end
      else
        if RangeGap(ourL, ourR, g.box.l, g.box.r) > range then
          g = nil
        end
      end
    end
    if g and g.axis == "x" then
      for _, e in ipairs(ourX) do
        local d = math.abs(e.pos - g.value)
        if d < bestXd then
          bestXd = d
          bestX = { guide = g, edge = e.tag, delta = g.value - e.pos }
        end
      end
    elseif g then
      for _, e in ipairs(ourY) do
        local d = math.abs(e.pos - g.value)
        if d < bestYd then
          bestYd = d
          bestY = { guide = g, edge = e.tag, delta = g.value - e.pos }
        end
      end
    end
  end
  local snap
  if bestX and bestXd <= range then
    left = left + bestX.delta
    snap = snap or {}
    snap.sh = bestX.edge
    snap.gh = bestX.guide.tag
    snap.hKind = bestX.guide.kind
    snap.hKey = bestX.guide.key
    snap.hName = bestX.guide.label or ("Screen " .. bestX.guide.name)
  end
  if bestY and bestYd <= range then
    bottom = bottom + bestY.delta
    snap = snap or {}
    snap.sv = bestY.edge
    snap.gv = bestY.guide.tag
    snap.vKind = bestY.guide.kind
    snap.vKey = bestY.guide.key
    snap.vName = bestY.guide.label or ("Screen " .. bestY.guide.name)
  end
  return left, bottom, snap
end

local function SnapLabel(snap)
  if not snap then return "Free" end
  local parts = {}
  if snap.hName then table.insert(parts, snap.hName) end
  if snap.vName and snap.vName ~= snap.hName then table.insert(parts, snap.vName) end
  if table.getn(parts) < 1 then return "Free" end
  local out = parts[1]
  if parts[2] then out = out .. " + " .. parts[2] end
  return out
end

local function BuildSaved(left, bottom, width, height, snap)
  local sw, sh = ScreenSize()
  local saved = { x = left, y = bottom }
  if not snap then return saved end
  local ourH = snap.sh or "left"
  local guideH = snap.gh or "left"
  local ourV = snap.sv or "bottom"
  local guideV = snap.gv or "bottom"
  local relL, relB, relW, relH = 0, 0, sw, sh
  local toKey = snap.hKey or snap.vKey
  if toKey then
    local other = FindEntry(toKey)
    if other and other.frame then
      relL = other.frame:GetLeft() or 0
      relB = other.frame:GetBottom() or 0
      relW, relH = FrameSize(other.frame)
      saved.to = toKey
    end
  end
  saved.sh = ourH
  saved.gh = guideH
  saved.sv = ourV
  saved.gv = guideV
  saved.w = width
  saved.h = height
  saved.sw, saved.shScreen = ScreenSize()
  saved.ox = EdgeX(left, width, ourH) - EdgeX(relL, relW, guideH)
  saved.oy = EdgeY(bottom, height, ourV) - EdgeY(relB, relH, guideV)
  return saved
end

-- Emberveil GetBottom() often returns a top-down Y. If we snapped to the
-- screen bottom but stored a value in the upper half, flip it.
local function SanitizeSaved(saved, width, height)
  if type(saved) ~= "table" then return saved end
  local sw, sh = ScreenSize()
  local h = height or saved.h or 0
  if saved.gv == "bottom" and saved.y and saved.y > sh * .55 then
    saved.y = sh - saved.y - h
    if saved.y < 0 then saved.y = 0 end
    saved.oy = saved.y
  end
  return saved
end

-- Emberveil ignores CENTER/BOTTOM/TOP anchors. Resolve snap to pixels,
-- then pin BOTTOMLEFT + TOPRIGHT like every other QtUI frame.
local function PlaceSaved(frame, saved)
  if not frame or type(saved) ~= "table" then return end
  local width, height = FrameSize(frame)
  if (not width or width < 8) and saved.w then width = saved.w end
  if (not height or height < 8) and saved.h then height = saved.h end
  SanitizeSaved(saved, width, height)
  local sw, sh = ScreenSize()
  local screenChanged = saved.sw and saved.shScreen
    and (math.abs(saved.sw - sw) > 16 or math.abs(saved.shScreen - sh) > 16)
  local left, bottom
  -- Prefer the pixels we wrote while dragging. Emberveil GetBottom() is not
  -- trustworthy (pfUI: GetTop/GetScreenHeight rewrites Y). Only recompute
  -- from snap when the resolution actually changed.
  if screenChanged and (saved.gh or saved.gv) and not saved.to then
    local guideX = EdgeX(0, sw, saved.gh or "left")
    local guideY = EdgeY(0, sh, saved.gv or "bottom")
    local ox = saved.ox or 0
    local oy = saved.oy or 0
    local ourH = saved.sh or "left"
    local ourV = saved.sv or "bottom"
    if ourH == "right" then
      left = guideX + ox - width
    elseif ourH == "center" then
      left = guideX + ox - width / 2
    else
      left = guideX + ox
    end
    if ourV == "top" then
      bottom = guideY + oy - height
    elseif ourV == "center" then
      bottom = guideY + oy - height / 2
    else
      bottom = guideY + oy
    end
  elseif saved.x and saved.y then
    left, bottom = saved.x, saved.y
  else
    return
  end
  left, bottom = ClampToScreen(left, bottom, width, height)
  frame:ClearAllPoints()
  frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
  if width > 1 and height > 1 then
    frame:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", left + width, bottom + height)
  end
end

local function EnsureSnapLines()
  if QtUI.snapLines then return QtUI.snapLines end
  local lines = CreateFrame("Frame", "QtUISnapLines", UIParent)
  lines:SetAllPoints(UIParent)
  lines:SetFrameStrata("FULLSCREEN")
  lines:SetFrameLevel(90)
  if lines.EnableMouse then lines:EnableMouse(false) end
  lines.v = lines:CreateTexture(nil, "OVERLAY")
  lines.v:SetTexture("Interface\\Buttons\\WHITE8X8")
  lines.v:SetVertexColor(.2, 1, .85, .7)
  lines.h = lines:CreateTexture(nil, "OVERLAY")
  lines.h:SetTexture("Interface\\Buttons\\WHITE8X8")
  lines.h:SetVertexColor(.2, 1, .85, .7)
  lines:Hide()
  QtUI.snapLines = lines
  return lines
end

local function HideSnapLines()
  if not QtUI.snapLines then return end
  QtUI.snapLines.v:ClearAllPoints()
  QtUI.snapLines.v:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -4000, 4000)
  QtUI.snapLines.h:ClearAllPoints()
  QtUI.snapLines.h:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -4000, 4000)
  if QtUI.snapLines.Hide then pcall(QtUI.snapLines.Hide, QtUI.snapLines) end
end

local function ShowSnapLines(left, bottom, width, height, snap)
  local lines = EnsureSnapLines()
  if not snap then
    HideSnapLines()
    return
  end
  local sw, sh = ScreenSize()
  if lines.Show then pcall(lines.Show, lines) end
  if snap.sh then
    local x = EdgeX(left, width, snap.sh)
    lines.v:ClearAllPoints()
    lines.v:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, 0)
    lines.v:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", x + 2, sh)
  else
    lines.v:ClearAllPoints()
    lines.v:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -4000, 4000)
  end
  if snap.sv then
    local y = EdgeY(bottom, height, snap.sv)
    lines.h:ClearAllPoints()
    lines.h:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 0, y)
    lines.h:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", sw, y + 2)
  else
    lines.h:ClearAllPoints()
    lines.h:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -4000, 4000)
  end
end

local selectedOverlay
local nudgeHold

local SELECT_COLOR = { .22, .16, .04, .4 }

local function PlaceBtn(btn, parent, left, bottom, width, height)
  btn:ClearAllPoints()
  btn:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", left, bottom)
  btn:SetPoint("TOPRIGHT", parent, "BOTTOMLEFT", left + width, bottom + height)
  if btn.SetWidth then
    btn:SetWidth(width + 1)
    if btn.SetHeight then btn:SetHeight(height + 1) end
    btn:SetWidth(width)
    if btn.SetHeight then btn:SetHeight(height) end
  end
end

local function OverlayPixels(overlay)
  if not overlay then return nil, nil end
  local left = overlay.lastLeft
  local bottom = overlay.lastBottom
  local key = overlay.entry and overlay.entry.key
  local saved = key and QtUIDB.positions and QtUIDB.positions[key]
  if saved then
    if left == nil then left = saved.x end
    if bottom == nil then bottom = saved.y end
  end
  if left == nil and overlay.GetLeft then left = overlay:GetLeft() end
  if bottom == nil then
    local _, sh = ScreenSize()
    local _, height = FrameSize(overlay)
    local rawB = overlay.GetBottom and overlay:GetBottom()
    local rawT = overlay.GetTop and overlay:GetTop()
    if rawB and rawT and rawT > rawB then
      bottom = rawB
    elseif rawB and rawT and rawB > rawT then
      bottom = sh - rawB
    elseif rawB then
      if height and rawB > sh * .55 then
        local flipped = sh - rawB - height
        if flipped >= 0 then
          bottom = flipped
        else
          bottom = rawB
        end
      else
        bottom = rawB
      end
    end
  end
  return left, bottom
end

local function PaintOverlay(overlay)
  if not overlay or not overlay.SetBackdropColor then return end
  if selectedOverlay == overlay then
    overlay:SetBackdropColor(SELECT_COLOR[1], SELECT_COLOR[2], SELECT_COLOR[3], SELECT_COLOR[4])
    if overlay.SetBackdropBorderColor then
      overlay:SetBackdropBorderColor(1, .82, .18, 1)
    end
  else
    overlay:SetBackdropColor(MOVE_COLOR[1], MOVE_COLOR[2], MOVE_COLOR[3], MOVE_COLOR[4])
    if overlay.SetBackdropBorderColor then
      overlay:SetBackdropBorderColor(.1, 1, .78, .95)
    end
  end
end

local function PlaceMoveInfo(info)
  info:ClearAllPoints()
  info:SetPoint("TOPLEFT", UIParent, "TOP", -150, -16)
  info:SetPoint("BOTTOMRIGHT", UIParent, "TOP", 150, -294)
end

local PlaceSized, RefreshMoveInfo, MouseLeftHeld

local function NudgeStep()
  if ShiftDown() then return 10 end
  return 1
end

local function StopNudgeHold()
  nudgeHold = nil
  if QtUI.moveInfo then QtUI.moveInfo:SetScript("OnUpdate", nil) end
end

local function SelectOverlay(overlay)
  local prev = selectedOverlay
  selectedOverlay = overlay
  if prev and prev ~= overlay then PaintOverlay(prev) end
  if overlay then
    local left, bottom = OverlayPixels(overlay)
    if left ~= nil then overlay.lastLeft = left end
    if bottom ~= nil then overlay.lastBottom = bottom end
    PaintOverlay(overlay)
  end
end

local function NudgeSelected(dx, dy)
  local overlay = selectedOverlay
  if not overlay or not overlay.entry or overlay.dragging then return end
  local step = NudgeStep()
  dx = (dx or 0) * step
  dy = (dy or 0) * step
  if dx == 0 and dy == 0 then return end
  local width, height = FrameSize(overlay)
  if (width < 8 or height < 8) and overlay.entry.frame then
    local fw, fh = FrameSize(overlay.entry.frame)
    if width < 8 then width = fw end
    if height < 8 then height = fh end
  end
  local saved = QtUIDB.positions and QtUIDB.positions[overlay.entry.key]
  if saved then
    if width < 8 and saved.w then width = saved.w end
    if height < 8 and saved.h then height = saved.h end
  end
  local left, bottom = OverlayPixels(overlay)
  if left == nil or bottom == nil then return end
  left = left + dx
  bottom = bottom + dy
  left, bottom = ClampToScreen(left, bottom, width, height)
  overlay.lastLeft = left
  overlay.lastBottom = bottom
  overlay.snap = nil
  PlaceSized(overlay, left, bottom, width, height)
  if overlay.entry.frame then
    PlaceFrame(overlay.entry.frame, left, bottom)
  end
  if not QtUIDB.positions then QtUIDB.positions = {} end
  QtUIDB.positions[overlay.entry.key] = BuildSaved(left, bottom, width, height, nil)
  RefreshMoveInfo(overlay)
end

local function StartNudgeHold(dx, dy)
  StopNudgeHold()
  NudgeSelected(dx, dy)
  nudgeHold = { dx = dx, dy = dy, elapsed = 0, repeating = nil }
  if not QtUI.moveInfo then return end
  QtUI.moveInfo:SetScript("OnUpdate", function()
    if not nudgeHold then return end
    if MouseLeftHeld() == false then
      StopNudgeHold()
      return
    end
    nudgeHold.elapsed = nudgeHold.elapsed + (arg1 or 0)
    local delay = .32
    if nudgeHold.repeating then delay = .07 end
    if nudgeHold.elapsed >= delay then
      nudgeHold.elapsed = 0
      nudgeHold.repeating = true
      NudgeSelected(nudgeHold.dx, nudgeHold.dy)
    end
  end)
end

local function MakeNudgeButton(info, name, label, dx, dy)
  local btn = CreateFrame("Button", name, info)
  if btn.EnableMouse then btn:EnableMouse(true) end
  btn:RegisterForClicks("LeftButtonUp")
  btn:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  btn:SetBackdropColor(.04, .05, .06, .95)
  btn:SetBackdropBorderColor(.2, .7, .62, 1)
  btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  btn.text:SetPoint("CENTER", btn, "CENTER", 0, 0)
  btn.text:SetText(label)
  btn:SetScript("OnMouseDown", function()
    if arg1 == "LeftButton" then StartNudgeHold(dx, dy) end
  end)
  btn:SetScript("OnMouseUp", function()
    StopNudgeHold()
  end)
  btn:SetScript("OnEnter", function()
    this:SetBackdropColor(.08, .4, .64, .95)
    if GameTooltip then
      GameTooltip:SetOwner(this, "ANCHOR_TOP")
      GameTooltip:SetText("Nudge selected")
      GameTooltip:AddLine("1 pixel. Hold Shift for 10px. Hold to repeat.", .8, .9, .85)
      GameTooltip:Show()
    end
  end)
  btn:SetScript("OnLeave", function()
    this:SetBackdropColor(.04, .05, .06, .95)
    if GameTooltip then GameTooltip:Hide() end
  end)
  return btn
end

local function EnsureNudgePad(info)
  if info.SetFrameStrata then info:SetFrameStrata("TOOLTIP") end
  if info.SetFrameLevel then info:SetFrameLevel(250) end
  if info.EnableMouse then info:EnableMouse(true) end
  if info.body then
    info.body:ClearAllPoints()
    info.body:SetPoint("TOPLEFT", info, "TOPLEFT", 10, -48)
    info.body:SetPoint("BOTTOMRIGHT", info, "BOTTOMRIGHT", -10, 112)
  end
  if info.hint then
    info.hint:SetText("Click a frame to select. Escape locks.")
  end
  if not info.nudgeLabel then
    info.nudgeLabel = info:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    info.nudgeLabel:SetJustifyH("CENTER")
  end
  info.nudgeLabel:ClearAllPoints()
  info.nudgeLabel:SetPoint("BOTTOMLEFT", info, "BOTTOMLEFT", 10, 100)
  info.nudgeLabel:SetPoint("BOTTOMRIGHT", info, "BOTTOMLEFT", 290, 114)
  info.nudgeLabel:SetText("Nudge selected  (Shift = 10px)")
  if not info.nudgeUp then
    info.nudgeUp = MakeNudgeButton(info, "QtUIMoveNudgeUp", "^", 0, 1)
    info.nudgeDown = MakeNudgeButton(info, "QtUIMoveNudgeDown", "v", 0, -1)
    info.nudgeLeft = MakeNudgeButton(info, "QtUIMoveNudgeLeft", "<", -1, 0)
    info.nudgeRight = MakeNudgeButton(info, "QtUIMoveNudgeRight", ">", 1, 0)
  end
  PlaceBtn(info.nudgeDown, info, 130, 10, 40, 26)
  PlaceBtn(info.nudgeLeft, info, 86, 40, 40, 26)
  PlaceBtn(info.nudgeRight, info, 174, 40, 40, 26)
  PlaceBtn(info.nudgeUp, info, 130, 70, 40, 26)
  if not info.nudgeHooked then
    info.nudgeHooked = true
    info:SetScript("OnMouseUp", function()
      StopNudgeHold()
      if QtUI.StopOverlayDrag then QtUI.StopOverlayDrag() end
    end)
  end
end

local function EnsureMoveInfo()
  if QtUI.moveInfo then
    PlaceMoveInfo(QtUI.moveInfo)
    EnsureNudgePad(QtUI.moveInfo)
    return QtUI.moveInfo
  end
  local info = CreateFrame("Frame", "QtUIMoveInfo", UIParent)
  info:SetFrameStrata("TOOLTIP")
  info:SetFrameLevel(250)
  PlaceMoveInfo(info)
  info:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  info:SetBackdropColor(.015, .018, .022, .94)
  info:SetBackdropBorderColor(.2, .7, .62, 1)
  if info.EnableMouse then info:EnableMouse(true) end
  info.title = info:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  info.title:SetPoint("TOPLEFT", info, "TOPLEFT", 10, -10)
  info.title:SetText("|cff33ffccINFO|r")
  info.hint = info:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  info.hint:SetPoint("TOPLEFT", info, "TOPLEFT", 10, -28)
  info.hint:SetPoint("TOPRIGHT", info, "TOPRIGHT", -10, -28)
  info.hint:SetJustifyH("LEFT")
  info.hint:SetText("Click a frame to select. Escape locks.")
  info.body = info:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  info.body:SetPoint("TOPLEFT", info, "TOPLEFT", 10, -48)
  info.body:SetPoint("BOTTOMRIGHT", info, "BOTTOMRIGHT", -10, 112)
  info.body:SetJustifyH("LEFT")
  if info.body.SetJustifyV then info.body:SetJustifyV("TOP") end
  EnsureNudgePad(info)
  info:Hide()
  QtUI.moveInfo = info
  return info
end

function RefreshMoveInfo(dragOverlay)
  local info = EnsureMoveInfo()
  if not QtUI.moveMode then
    if info.Hide then pcall(info.Hide, info) end
    return
  end
  if info.Show then pcall(info.Show, info) end
  local shown = dragOverlay or selectedOverlay
  local lines = "Click a frame, then use the arrows."
  if shown and shown.entry then
    local left, bottom = OverlayPixels(shown)
    left = left or 0
    bottom = bottom or 0
    local snap = shown.snap
    lines = "|cffffd24d" .. shown.entry.label .. "|r"
      .. "\n" .. math.floor(left + .5) .. ", " .. math.floor(bottom + .5)
      .. "\nSnap: " .. SnapLabel(snap)
      .. "\nArrows move 1px. Shift+arrow = 10px."
    if shown.dragging and not ShiftDown() then
      lines = lines .. "\n(Shift not held)"
    end
  elseif QtUI.movableEntries then
    local _, entry
    local n = 0
    for _, entry in ipairs(QtUI.movableEntries) do
      if n >= 6 then
        lines = lines .. "\n..."
        break
      end
      local saved = QtUIDB.positions and QtUIDB.positions[entry.key]
      local extra = "free"
      if saved and (saved.sh or saved.sv) then
        extra = SnapLabel({
          hName = saved.to and (entry.label) or (saved.gh and ("Screen " .. saved.gh)),
          vName = saved.gv and ("Screen " .. saved.gv),
        })
      end
      local x = saved and saved.x
      local y = saved and saved.y
      if x and y then
        lines = lines .. "\n" .. entry.label .. "  " .. math.floor(x + .5) .. "," .. math.floor(y + .5) .. "  " .. extra
        n = n + 1
      end
    end
  end
  info.body:SetText(lines)
end

-- Emberveil often drops SetWidth after ClearAllPoints. Keep a hit box with
-- a second corner so OnDragStop / mouse-up still land on the overlay.
function PlaceSized(frame, left, bottom, width, height)
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

local activeDrag
local dragNeedCatch

function MouseLeftHeld()
  if type(IsMouseButtonDown) ~= "function" then return nil end
  local ok, held = pcall(IsMouseButtonDown, "LeftButton")
  if not ok then return nil end
  if held == true or held == 1 or held == "1" then return true end
  return false
end

-- pfUI unlock: Emberveil often skips OnDragStop unless the cursor is still
-- over the overlay. A fullscreen catcher gets the mouse-up everywhere.
local function EnsureDropCatch()
  if QtUI.moveDropCatch then return QtUI.moveDropCatch end
  local catch = CreateFrame("Button", "QtUIMoveDropCatch", UIParent)
  catch:Hide()
  catch:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
  catch:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
  catch:SetFrameStrata("TOOLTIP")
  catch:SetFrameLevel(90)
  catch:EnableMouse(true)
  catch:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  catch:SetScript("OnMouseUp", function()
    if QtUI.StopOverlayDrag then QtUI.StopOverlayDrag() end
  end)
  catch:SetScript("OnClick", function()
    if QtUI.StopOverlayDrag then QtUI.StopOverlayDrag() end
  end)
  QtUI.moveDropCatch = catch
  return catch
end

local function SaveOverlayPosition(overlay)
  local left = overlay.lastLeft or overlay:GetLeft()
  local bottom = overlay.lastBottom or overlay:GetBottom()
  if not left or not bottom then return end
  local width, height = FrameSize(overlay)
  left, bottom = ClampToScreen(left, bottom, width, height)
  local snap = overlay.snap
  if not ShiftDown() then snap = nil end

  local entry = overlay.entry
  local target = entry.frame
  QtUIDB.positions[entry.key] = BuildSaved(left, bottom, width, height, snap)
  if snap then
    PlaceSaved(target, QtUIDB.positions[entry.key])
  else
    PlaceFrame(target, left, bottom)
  end
  PlaceSized(overlay, left, bottom, width, height)
  HideSnapLines()
  overlay.snap = nil
  SelectOverlay(overlay)
  RefreshMoveInfo(overlay)
end

local function StopOverlayDrag(overlay)
  overlay = overlay or activeDrag
  if overlay and overlay.dragArmed then
    overlay.dragArmed = nil
    if not overlay.dragging then
      overlay:SetScript("OnUpdate", nil)
      return
    end
  end
  if not overlay or not overlay.dragging then return end
  overlay.dragging = nil
  overlay:SetScript("OnUpdate", nil)
  activeDrag = nil
  dragNeedCatch = nil
  if QtUI.moveDropCatch then
    QtUI.moveDropCatch:SetScript("OnUpdate", nil)
    if QtUI.moveDropCatch.Hide then pcall(QtUI.moveDropCatch.Hide, QtUI.moveDropCatch) end
  end
  SaveOverlayPosition(overlay)
end
QtUI.StopOverlayDrag = function()
  StopOverlayDrag(activeDrag)
end

local function DragOverlay()
  local overlay = activeDrag or this
  if not overlay or not overlay.dragging then return end
  if dragNeedCatch then
    dragNeedCatch = nil
    local catch = EnsureDropCatch()
    if catch.Show then pcall(catch.Show, catch) end
    catch:SetScript("OnUpdate", DragOverlay)
  end
  local scale = UIScale()
  local cursorX, cursorY = GetCursorPosition()
  cursorX = (cursorX or 0) / scale
  cursorY = (cursorY or 0) / scale
  local movedX = cursorX - (overlay.dragCursorX or cursorX)
  local movedY = cursorY - (overlay.dragCursorY or cursorY)
  if (movedX > 2 or movedX < -2 or movedY > 2 or movedY < -2) and MouseLeftHeld() == false then
    StopOverlayDrag(overlay)
    return
  end
  local width = overlay.dragW or 0
  local height = overlay.dragH or 0
  local left = cursorX - (overlay.dragX or 0)
  local bottom = cursorY - (overlay.dragY or 0)
  local snap
  left, bottom, snap = SnapDrag(left, bottom, width, height, overlay.entry and overlay.entry.key)
  left, bottom = ClampToScreen(left, bottom, width, height)
  overlay.snap = snap
  overlay.lastLeft = left
  overlay.lastBottom = bottom
  PlaceSized(overlay, left, bottom, width, height)
  if overlay.entry and overlay.entry.frame then
    PlaceFrame(overlay.entry.frame, left, bottom)
  end
  ShowSnapLines(left, bottom, width, height, snap)
  RefreshMoveInfo(overlay)
end

local function BeginOverlayDrag(overlay)
  if not overlay or overlay.dragging then return end
  overlay.dragArmed = nil
  local left, bottom = OverlayPixels(overlay)
  if left == nil then left = overlay.GetLeft and overlay:GetLeft() end
  if bottom == nil then bottom = overlay.lastBottom end
  local width, height = FrameSize(overlay)
  if not left or not bottom then return end
  overlay.dragW = width
  overlay.dragH = height
  PlaceSized(overlay, left, bottom, width, height)
  local scale = UIScale()
  local cursorX, cursorY = GetCursorPosition()
  cursorX = (cursorX or 0) / scale
  cursorY = (cursorY or 0) / scale
  overlay.dragX = cursorX - left
  overlay.dragY = cursorY - bottom
  overlay.dragCursorX = cursorX
  overlay.dragCursorY = cursorY
  overlay.lastLeft = left
  overlay.lastBottom = bottom
  overlay.dragging = true
  activeDrag = overlay
  dragNeedCatch = true
  overlay:SetScript("OnUpdate", DragOverlay)
end

local function ArmOverlaySelect(overlay)
  if not overlay then return end
  SelectOverlay(overlay)
  RefreshMoveInfo(overlay)
  if overlay.dragging then return end
  local scale = UIScale()
  local cursorX, cursorY = GetCursorPosition()
  overlay.armCursorX = (cursorX or 0) / scale
  overlay.armCursorY = (cursorY or 0) / scale
  overlay.dragArmed = true
  overlay:SetScript("OnUpdate", function()
    if not this or not this.dragArmed then
      if this then this:SetScript("OnUpdate", nil) end
      return
    end
    if MouseLeftHeld() == false then
      this.dragArmed = nil
      this:SetScript("OnUpdate", nil)
      return
    end
    local scale = UIScale()
    local cursorX, cursorY = GetCursorPosition()
    cursorX = (cursorX or 0) / scale
    cursorY = (cursorY or 0) / scale
    local movedX = cursorX - (this.armCursorX or cursorX)
    local movedY = cursorY - (this.armCursorY or cursorY)
    if movedX > 2 or movedX < -2 or movedY > 2 or movedY < -2 then
      this.dragArmed = nil
      BeginOverlayDrag(this)
    end
  end)
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

  overlay:SetScript("OnMouseDown", function()
    if arg1 == "LeftButton" then ArmOverlaySelect(this) end
  end)
  overlay:SetScript("OnDragStart", function()
    BeginOverlayDrag(this)
  end)
  overlay:SetScript("OnDragStop", function()
    StopOverlayDrag(this)
  end)
  overlay:SetScript("OnMouseUp", function()
    if this.dragArmed and not this.dragging then
      this.dragArmed = nil
      this:SetScript("OnUpdate", nil)
      return
    end
    if arg1 == "LeftButton" or this.dragging then StopOverlayDrag(this) end
  end)
  overlay:SetScript("OnClick", function()
    if arg1 == "RightButton" then QtUI:ResetMovable(entry.key) end
  end)
  overlay:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  overlay:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_TOP")
    GameTooltip:SetText(entry.label)
    GameTooltip:AddLine("Click to select, then nudge from the INFO window.", 1, 1, 1)
    GameTooltip:AddLine("Drag to reposition. Hold Shift to snap.", .7, .95, .9)
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
      if saved then PlaceSaved(frame, saved) end
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
  if saved then PlaceSaved(frame, saved) end

  if frame.SetClampedToScreen then frame:SetClampedToScreen(false) end
  table.insert(self.movableEntries, entry)
  entry.overlay = CreateMoveOverlay(entry, table.getn(self.movableEntries))
end

function QtUI:ApplySavedPositions()
  if not QtUIDB.positions then return end
  if self.movableEntries then
    local pass
    for pass = 1, 2 do
      local _, entry
      for _, entry in ipairs(self.movableEntries) do
        local saved = QtUIDB.positions[entry.key]
        if saved and entry.frame then
          local needsOther = saved.to
          if (pass == 1 and not needsOther) or (pass == 2 and needsOther) then
            PlaceSaved(entry.frame, saved)
            if entry.overlay then ReanchorOverlay(entry.overlay) end
          end
        end
      end
    end
  end
  if self.PlaceCastBar then self:PlaceCastBar() end
  if self.RestoreQuestTimerPosition then self:RestoreQuestTimerPosition() end
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
      if entry.overlay then
        entry.overlay.lastLeft = nil
        entry.overlay.lastBottom = nil
        ReanchorOverlay(entry.overlay)
        if selectedOverlay == entry.overlay then
          SelectOverlay(entry.overlay)
          RefreshMoveInfo(entry.overlay)
        end
      end
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
    EnsureMoveInfo()
    if selectedOverlay then PaintOverlay(selectedOverlay) end
    RefreshMoveInfo(selectedOverlay)
  else
    StopNudgeHold()
    if selectedOverlay then
      local prev = selectedOverlay
      selectedOverlay = nil
      PaintOverlay(prev)
    end
    if self.moveGrid then self.moveGrid:Hide() end
    if self.moveCatcher then self.moveCatcher:Hide() end
    HideSnapLines()
    if self.moveDropCatch then
      self.moveDropCatch:SetScript("OnUpdate", nil)
      if self.moveDropCatch.Hide then pcall(self.moveDropCatch.Hide, self.moveDropCatch) end
    end
    if self.moveInfo and self.moveInfo.Hide then pcall(self.moveInfo.Hide, self.moveInfo) end
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
  self:Print("Anchor mode on. Click a frame, then nudge with the INFO arrows. Shift snaps / 10px. Escape locks.")
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
  if self.playerFrame then
    if self.playerFrame.buffs then
      self:RegisterMovable("playerBuffs", "Player Buffs", self.playerFrame.buffs)
    end
    if self.playerFrame.debuffs then
      self:RegisterMovable("playerDebuffs", "Player Debuffs", self.playerFrame.debuffs)
    end
  end
  if self.targetFrame then
    if self.targetFrame.buffs then
      self:RegisterMovable("targetBuffs", "Target Buffs", self.targetFrame.buffs)
    end
    if self.targetFrame.debuffs then
      self:RegisterMovable("targetDebuffs", "Target Debuffs", self.targetFrame.debuffs)
    end
  end
  if self.leftChatPanel then
    self:RegisterMovable("chat", "Chat", self.leftChatPanel)
  elseif ChatFrame1 then
    self:RegisterMovable("chat", "Chat", ChatFrame1)
  end
  if self.rightChatPanel then
    self:RegisterMovable("chatSocial", "Chat (Social)", self.rightChatPanel)
  elseif ChatFrame2 then
    self:RegisterMovable("chatSocial", "Chat (Social)", ChatFrame2)
  end
  self:SetupQuestTimerMove()
end

function QtUI:RestoreQuestTimerPosition()
  local frame = getglobal("QuestTimerFrame")
  if not frame then return end
  local saved = QtUIDB.positions and QtUIDB.positions.questTimers
  if saved then PlaceSaved(frame, saved) end
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
