-- Show the currently equipped item next to item tooltips (pfUI eqcompare).

local function FeatureOn()
  if not QtUI.GetLayout then return true end
  local layout = QtUI:GetLayout()
  local value = layout and layout.eqCompare
  return value ~= false and value ~= 0 and value ~= "0"
end

local SLOT_ROWS

local function BuildSlotRows()
  if SLOT_ROWS then return SLOT_ROWS end
  SLOT_ROWS = {}
  local function Add(token, slot, other)
    local label = getglobal(token)
    if label then
      table.insert(SLOT_ROWS, { label = label, slot = slot, other = other })
    end
  end
  Add("INVTYPE_2HWEAPON", "MainHandSlot")
  Add("INVTYPE_BODY", "ShirtSlot")
  Add("INVTYPE_CHEST", "ChestSlot")
  Add("INVTYPE_CLOAK", "BackSlot")
  Add("INVTYPE_FEET", "FeetSlot")
  Add("INVTYPE_FINGER", "Finger0Slot", "Finger1Slot")
  Add("INVTYPE_HAND", "HandsSlot")
  Add("INVTYPE_HEAD", "HeadSlot")
  Add("INVTYPE_HOLDABLE", "SecondaryHandSlot")
  Add("INVTYPE_LEGS", "LegsSlot")
  Add("INVTYPE_NECK", "NeckSlot")
  Add("INVTYPE_RANGED", "RangedSlot")
  Add("INVTYPE_RANGEDRIGHT", "RangedSlot")
  Add("INVTYPE_RELIC", "RangedSlot")
  Add("INVTYPE_ROBE", "ChestSlot")
  Add("INVTYPE_SHIELD", "SecondaryHandSlot")
  Add("INVTYPE_SHOULDER", "ShoulderSlot")
  Add("INVTYPE_TABARD", "TabardSlot")
  Add("INVTYPE_TRINKET", "Trinket0Slot", "Trinket1Slot")
  Add("INVTYPE_WAIST", "WaistSlot")
  Add("INVTYPE_WEAPON", "MainHandSlot", "SecondaryHandSlot")
  Add("INVTYPE_WEAPONMAINHAND", "MainHandSlot")
  Add("INVTYPE_WEAPONOFFHAND", "SecondaryHandSlot")
  Add("INVTYPE_WRIST", "WristSlot")
  Add("INVTYPE_WAND", "RangedSlot")
  Add("INVTYPE_GUN", "RangedSlot")
  Add("INVTYPE_CROSSBOW", "RangedSlot")
  Add("INVTYPE_THROWN", "RangedSlot")
  return SLOT_ROWS
end

local function HideCompare()
  if ShoppingTooltip1 then
    if ShoppingTooltip1.Hide then pcall(ShoppingTooltip1.Hide, ShoppingTooltip1) end
    if ShoppingTooltip1.ClearLines then pcall(ShoppingTooltip1.ClearLines, ShoppingTooltip1) end
  end
  if ShoppingTooltip2 then
    if ShoppingTooltip2.Hide then pcall(ShoppingTooltip2.Hide, ShoppingTooltip2) end
    if ShoppingTooltip2.ClearLines then pcall(ShoppingTooltip2.ClearLines, ShoppingTooltip2) end
  end
end

local function ShowEquipped(tooltip, slotName, compareTip, anchor)
  if not tooltip or not slotName or not compareTip then return nil end
  if type(GetInventorySlotInfo) ~= "function" or type(compareTip.SetInventoryItem) ~= "function" then
    return nil
  end
  local slotID = GetInventorySlotInfo(slotName)
  if not slotID then return nil end
  if type(GetInventoryItemLink) == "function" then
    local link = GetInventoryItemLink("player", slotID)
    if not link then return nil end
  end
  compareTip:SetOwner(tooltip, "ANCHOR_NONE")
  compareTip:ClearAllPoints()
  if anchor == "right" then
    compareTip:SetPoint("BOTTOMLEFT", tooltip, "BOTTOMRIGHT", 4, 0)
  else
    compareTip:SetPoint("BOTTOMRIGHT", tooltip, "BOTTOMLEFT", -4, 0)
  end
  compareTip:SetInventoryItem("player", slotID)
  compareTip:Show()
  return true
end

local function OnTooltipShow()
  if not FeatureOn() then
    HideCompare()
    return
  end
  if not GameTooltip or not GameTooltip.IsVisible or not GameTooltip:IsVisible() then return end
  local rows = BuildSlotRows()
  local lines = GameTooltip.NumLines and GameTooltip:NumLines() or 0
  local i
  for i = 2, lines do
    local fontString = getglobal("GameTooltipTextLeft" .. i)
    local text = fontString and fontString:GetText()
    if text then
      local n
      for n = 1, table.getn(rows) do
        if text == rows[n].label then
          local cursor = 0
          if type(GetCursorPosition) == "function" then
            cursor = GetCursorPosition() or 0
          end
          local scale = 1
          if UIParent.GetEffectiveScale then
            scale = UIParent:GetEffectiveScale() or 1
          end
          if scale == 0 then scale = 1 end
          local screen = (UIParent.GetWidth and UIParent:GetWidth()) or 1024
          local side = "left"
          if (cursor / scale) < (screen / 2) then side = "right" end
          local shown = ShowEquipped(GameTooltip, rows[n].slot, ShoppingTooltip1, side)
          if shown and rows[n].other and ShoppingTooltip2 then
            local otherSide = side
            ShoppingTooltip2:SetOwner(GameTooltip, "ANCHOR_NONE")
            ShoppingTooltip2:ClearAllPoints()
            if side == "right" then
              ShoppingTooltip2:SetPoint("BOTTOMLEFT", ShoppingTooltip1, "BOTTOMRIGHT", 4, 0)
            else
              ShoppingTooltip2:SetPoint("BOTTOMRIGHT", ShoppingTooltip1, "BOTTOMLEFT", -4, 0)
            end
            local otherID = GetInventorySlotInfo(rows[n].other)
            if otherID and GetInventoryItemLink("player", otherID) then
              ShoppingTooltip2:SetInventoryItem("player", otherID)
              ShoppingTooltip2:Show()
            end
          end
          return
        end
      end
    end
  end
  HideCompare()
end

function QtUI:SetupEqCompare()
  if self.eqCompareReady then return end
  self.eqCompareReady = true
  if not GameTooltip then return end
  local watch = CreateFrame("Frame", "QtUIEqCompare", GameTooltip)
  watch:SetScript("OnShow", OnTooltipShow)
  watch:SetScript("OnHide", HideCompare)
end
