local BAG_COLUMNS = 10
local SLOT_SIZE = 36
local SLOT_WELL = "Interface\\AddOns\\QtUI\\Media\\HDActionBarBtn"

local function ApplySlotWell(button, pad)
  if not button then return end
  pad = pad or 2
  if not button.well then
    button.well = button:CreateTexture(nil, "BACKGROUND")
  end
  button.well:ClearAllPoints()
  button.well:SetPoint("TOPLEFT", button, "TOPLEFT", -pad, pad)
  button.well:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", pad, -pad)
  button.well:SetTexture(SLOT_WELL)
  if button.well.Show then pcall(button.well.Show, button.well) end
  if button.SetBackdrop then pcall(button.SetBackdrop, button, nil) end
end

local function TintSlotWell(button, r, g, b, a)
  if button and button.well and button.well.SetVertexColor then
    button.well:SetVertexColor(r or 1, g or 1, b or 1, a or 1)
  end
end
local SLOT_GAP = 3
local WINDOW_PADDING = 12
local ShowKeyring

local function FormatMoney(copper)
  copper = copper or 0
  local gold = math.floor(copper / 10000)
  local silver = math.floor(math.mod(copper / 100, 100))
  local remainder = math.mod(copper, 100)
  return string.format("|cffffd700%dg|r  |cffc7c7cf%ds|r  |cffeda55f%dc|r", gold, silver, remainder)
end

local function IsTruthy(value)
  return value == true or value == 1 or value == "1"
end

local function GetVendorSellPrice(link)
  if not link then return nil end

  -- Some custom clients append sellPrice to GetItemInfo. Prefer that when it
  -- is present, then fall back to QtUI's Vanilla database.
  local _, _, _, _, _, _, _, _, _, _, apiSellPrice = GetItemInfo(link)
  if apiSellPrice and tonumber(apiSellPrice) then return tonumber(apiSellPrice) end

  local _, _, itemID = string.find(link, "item:(%d+)")
  itemID = tonumber(itemID)
  local value = itemID and QtUI.vendorPrices and QtUI.vendorPrices[itemID]
  if not value then return nil end

  local _, _, sell = string.find(value, "^(%d+),")
  return tonumber(sell)
end

local function AutoSellGreyItems()
  local soldItems = 0
  local soldStacks = 0
  local totalValue = 0
  local bag, slot

  for bag = 0, 4 do
    local slots = GetContainerNumSlots(bag) or 0
    for slot = 1, slots do
      local _, count, locked = GetContainerItemInfo(bag, slot)
      local link = GetContainerItemLink(bag, slot)
      if link and not IsTruthy(locked) then
        local _, _, quality = GetItemInfo(link)
        if quality == 0 then
          local sellPrice = GetVendorSellPrice(link)
          if sellPrice and sellPrice > 0 then
            count = count or 1
            UseContainerItem(bag, slot)
            soldItems = soldItems + count
            soldStacks = soldStacks + 1
            totalValue = totalValue + (sellPrice * count)
          end
        end
      end
    end
  end

  if soldStacks > 0 and DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00QtUI|r: Sold " .. soldItems ..
      " grey item" .. (soldItems == 1 and "" or "s") .. " for " .. FormatMoney(totalValue) .. ".")
  end
end

function QtUI:SetupAutoSell()
  if self.autoSellFrame then return end
  local frame = CreateFrame("Frame", "QtUIAutoSellEvents")
  frame:RegisterEvent("MERCHANT_SHOW")
  frame:SetScript("OnEvent", AutoSellGreyItems)
  self.autoSellFrame = frame
end

local function IsModifierDown(fn)
  if type(fn) ~= "function" then return nil end
  return IsTruthy(fn())
end

local function StyleSplitButton(button, width, height)
  button:SetWidth(width)
  button:SetHeight(height)
  button:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 9,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  button:SetBackdropColor(.035, .05, .06, .96)
  button:SetBackdropBorderColor(.25, .34, .36, 1)
  button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  button.text:SetPoint("CENTER", button, "CENTER", 0, 0)
  button.text:SetJustifyH("CENTER")
  button.text:SetTextColor(1, .9, .48)
  button:SetScript("OnEnter", function()
    this:SetBackdropColor(.08, .4, .64, .95)
    this:SetBackdropBorderColor(.25, .72, 1, 1)
  end)
  button:SetScript("OnLeave", function()
    this:SetBackdropColor(.035, .05, .06, .96)
    this:SetBackdropBorderColor(.25, .34, .36, 1)
  end)
end

local function OpenQtStackSplit(button, count)
  if QtUI.splitFrame and not QtUI.splitFrame.layoutV2 then
    QtUI.splitFrame:Hide()
    QtUI.splitFrame = nil
  end

  local frame = QtUI.splitFrame
  if not frame then
    frame = CreateFrame("Frame", "QtUIStackSplit", UIParent)
    frame.layoutV2 = true
    frame:SetWidth(176)
    frame:SetHeight(108)
    frame:SetFrameStrata("TOOLTIP")
    frame:SetFrameLevel(200)
    frame:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 8, edgeSize = 12,
      insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(.012, .018, .024, .97)
    frame:SetBackdropBorderColor(.4, .52, .54, 1)
    frame:EnableMouse(true)

    frame.label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.label:SetPoint("TOP", frame, "TOP", 0, -12)
    frame.label:SetText("|cffffcc00Split stack|r")

    frame.minus = CreateFrame("Button", nil, frame)
    StyleSplitButton(frame.minus, 28, 24)
    frame.minus:SetPoint("TOP", frame, "TOP", -40, -38)
    frame.minus.text:SetText("-")
    frame.minus:SetScript("OnClick", function()
      local split = QtUI.splitFrame.split - 1
      if split < 1 then split = 1 end
      QtUI.splitFrame.split = split
      QtUI.splitFrame.value:SetText(split)
    end)

    frame.value = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.value:SetPoint("TOP", frame, "TOP", 0, -40)
    frame.value:SetWidth(36)
    frame.value:SetJustifyH("CENTER")
    frame.value:SetTextColor(1, 1, 1)

    frame.plus = CreateFrame("Button", nil, frame)
    StyleSplitButton(frame.plus, 28, 24)
    frame.plus:SetPoint("TOP", frame, "TOP", 40, -38)
    frame.plus.text:SetText("+")
    frame.plus:SetScript("OnClick", function()
      local split = QtUI.splitFrame.split + 1
      local maxStack = QtUI.splitFrame.maxStack or 1
      if split > maxStack - 1 then split = maxStack - 1 end
      if split < 1 then split = 1 end
      QtUI.splitFrame.split = split
      QtUI.splitFrame.value:SetText(split)
    end)

    frame.ok = CreateFrame("Button", nil, frame)
    StyleSplitButton(frame.ok, 68, 24)
    frame.ok:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 12)
    frame.ok.text:SetText("OK")
    frame.ok:SetScript("OnClick", function()
      local owner = QtUI.splitFrame.owner
      local split = QtUI.splitFrame.split
      QtUI.splitFrame:Hide()
      if owner and owner.bag and owner.slot and type(SplitContainerItem) == "function" then
        SplitContainerItem(owner.bag, owner.slot, split)
      end
    end)

    frame.cancel = CreateFrame("Button", nil, frame)
    StyleSplitButton(frame.cancel, 68, 24)
    frame.cancel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 12)
    frame.cancel.text:SetText("Cancel")
    frame.cancel:SetScript("OnClick", function()
      QtUI.splitFrame:Hide()
    end)

    QtUI.splitFrame = frame
  end

  frame.owner = button
  frame.maxStack = count
  frame.split = 1
  frame.value:SetText("1")
  frame:SetParent(UIParent)
  frame:SetFrameStrata("TOOLTIP")
  frame:SetFrameLevel(200)
  frame:ClearAllPoints()
  frame:SetPoint("BOTTOM", button, "TOP", 0, 10)
  frame:Show()
  if frame.Raise then frame:Raise() end
end

local function GetEquipLoc(link)
  if not link or type(GetItemInfo) ~= "function" then return nil end
  local _, _, _, _, _, _, g, h, i = GetItemInfo(link)
  if type(h) == "string" and string.find(h, "INVTYPE_", 1, 1) then return h end
  if type(i) == "string" and string.find(i, "INVTYPE_", 1, 1) then return i end
  if type(g) == "string" and string.find(g, "INVTYPE_", 1, 1) then return g end
  return nil
end

local function CursorHasBagItem()
  if type(CursorHasItem) ~= "function" then return nil end
  local ok, value = pcall(CursorHasItem)
  return ok and IsTruthy(value)
end

-- Slot-to-slot in the backpack goes through PickupContainerItem, which is
-- what Emberveil uses for the item-move sound. UseContainerItem is silent.
local function EquipFromBag(bag, slot)
  if type(PickupContainerItem) ~= "function" then
    UseContainerItem(bag, slot)
    return
  end
  PickupContainerItem(bag, slot)
  if CursorHasBagItem() and type(AutoEquipCursorItem) == "function" then
    pcall(AutoEquipCursorItem)
    if CursorHasBagItem() then
      PickupContainerItem(bag, slot)
    end
    return
  end
  if CursorHasBagItem() then
    PickupContainerItem(bag, slot)
  end
  UseContainerItem(bag, slot)
end

local function HandleItemClick()
  local bag, slot = this.bag, this.slot
  local link = GetContainerItemLink(bag, slot)
  local _, count, locked = GetContainerItemInfo(bag, slot)
  count = tonumber(count) or 1

  if IsModifierDown(IsShiftKeyDown) then
    if link and ChatFrameEditBox and ChatFrameEditBox:IsVisible() then
      ChatFrameEditBox:Insert(link)
      return
    end
    if link and count > 1 and not IsTruthy(locked) then
      this.SplitStack = function(button, split)
        if type(SplitContainerItem) == "function" then
          SplitContainerItem(button.bag, button.slot, split)
        end
      end
      OpenQtStackSplit(this, count)
      return
    end
  end

  if IsModifierDown(IsControlKeyDown) and link and type(DressUpItemLink) == "function" then
    DressUpItemLink(link)
    return
  end

  if arg1 == "RightButton" then
    local loc = GetEquipLoc(link)
    local atMerchant = MerchantFrame and MerchantFrame.IsShown and MerchantFrame:IsShown()
    if loc and loc ~= "INVTYPE_BAG" and loc ~= "INVTYPE_AMMO" and loc ~= "INVTYPE_QUIVER" and not atMerchant then
      EquipFromBag(bag, slot)
    else
      UseContainerItem(bag, slot)
    end
  else
    PickupContainerItem(bag, slot)
  end
end

local function CreateItemButton(parent, index)
  local button = CreateFrame("Button", "QtUIBagItem" .. index, parent)
  button:SetWidth(SLOT_SIZE)
  button:SetHeight(SLOT_SIZE)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:RegisterForDrag("LeftButton")
  ApplySlotWell(button, 2)

  button.icon = button:CreateTexture(nil, "ARTWORK")
  button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 4, -4)
  button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -4, 4)
  button.icon:SetTexCoord(.07, .93, .07, .93)

  button.bagHighlight = button:CreateTexture(nil, "OVERLAY")
  button.bagHighlight:SetAllPoints(button)
  button.bagHighlight:SetTexture("Interface\\Buttons\\WHITE8X8")
  button.bagHighlight:SetVertexColor(1, .78, .08, .32)
  if button.bagHighlight.SetBlendMode then button.bagHighlight:SetBlendMode("ADD") end
  button.bagHighlight:Hide()

  button.count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
  button.count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)
  button.count:SetJustifyH("RIGHT")

  button:SetScript("OnClick", HandleItemClick)
  button:SetScript("OnDragStart", function()
    PickupContainerItem(this.bag, this.slot)
  end)
  button:SetScript("OnReceiveDrag", function()
    PickupContainerItem(this.bag, this.slot)
  end)
  button:SetScript("OnEnter", function()
    local link = GetContainerItemLink(this.bag, this.slot)
    if link then
      GameTooltip:SetOwner(this, "ANCHOR_LEFT")
      GameTooltip:SetBagItem(this.bag, this.slot)
      local sellPrice = GetVendorSellPrice(link)
      if sellPrice then
        local _, count = GetContainerItemInfo(this.bag, this.slot)
        count = tonumber(count) or 1
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Sell value: " .. FormatMoney(sellPrice), 1, 1, 1)
        if count > 1 then
          GameTooltip:AddLine("Stack value: " .. FormatMoney(sellPrice * count), .75, .85, 1)
        end
      end
      GameTooltip:Show()
    end
  end)
  button:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return button
end

local function HighlightBagSlots(bag, show)
  local frame = QtUI.bagFrame
  if not frame then return end
  for _, button in ipairs(frame.items) do
    if button.bag == bag and button:IsShown() then
      if show then button.bagHighlight:Show() else button.bagHighlight:Hide() end
    else
      button.bagHighlight:Hide()
    end
  end
end

local function BagInventorySlot(bag)
  if type(ContainerIDToInventoryID) == "function" then
    return ContainerIDToInventoryID(bag)
  end
  return 19 + bag
end

local function UpdateEquippedBagButton(button)
  local bag = button.bag
  local slots = GetContainerNumSlots(bag) or 0
  local texture
  if bag == 0 then
    texture = "Interface\\Buttons\\Button-Backpack-Up"
  elseif bag == -2 then
    texture = "Interface\\Icons\\INV_Misc_Key_03"
  else
    texture = GetInventoryItemTexture("player", button.inventorySlot)
  end

  button.icon:SetTexture(texture or "Interface\\Buttons\\Button-Backpack-Up")
  if texture then
    button.icon:SetVertexColor(1, 1, 1, 1)
  else
    button.icon:SetVertexColor(.3, .3, .3, .7)
  end
  if bag == -2 then
    button.slots:SetText("")
  else
    button.slots:SetText(slots)
  end
  if bag == -2 then
    if ShowKeyring() then
      TintSlotWell(button, 1, .72, .18, 1)
      button.icon:SetVertexColor(1, 1, 1, 1)
    else
      TintSlotWell(button, .4, .4, .4, 1)
      button.icon:SetVertexColor(.45, .45, .45, .8)
    end
  end
end

local function HasKeyringItem()
  if type(HasKey) ~= "function" then return true end
  local ok, has = pcall(HasKey)
  if not ok then return true end
  return has == true or has == 1 or has == "1"
end

function ShowKeyring()
  if not QtUI.GetLayout then return HasKeyringItem() end
  local layout = QtUI:GetLayout()
  if not layout then return HasKeyringItem() end
  local value = layout.bagShowKeys
  if value == false or value == 0 or value == "0" then return nil end
  return HasKeyringItem()
end

local function ShowKeyButton()
  if not QtUI.GetLayout then return true end
  local layout = QtUI:GetLayout()
  if not layout then return true end
  local value = layout.bagShowKeys
  if value == false or value == 0 or value == "0" then return nil end
  return true
end

local function ContainerSlots(bag)
  if bag == -2 then
    local n = tonumber(GetContainerNumSlots(-2)) or 0
    if n > 0 then return n end
    local last = 0
    local i
    for i = 1, 32 do
      local ok, link = pcall(GetContainerItemLink, -2, i)
      if ok and link and link ~= "" then last = i end
    end
    if last > 0 then
      last = math.ceil(last / 4) * 4
      if last < 4 then last = 4 end
      return last
    end
    return 0
  end
  return tonumber(GetContainerNumSlots(bag)) or 0
end

local function PlaceKeyButton(frame)
  local button = frame and frame.keyButton
  if not button then return end
  if ShowKeyButton() then
    button:ClearAllPoints()
    button:SetPoint("BOTTOMLEFT", frame.bagMenuButton, "BOTTOMRIGHT", 3, 0)
    if button.EnableMouse then button:EnableMouse(true) end
    if button.Show then pcall(button.Show, button) end
  else
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -4000, 4000)
    if button.EnableMouse then button:EnableMouse(false) end
    if button.Hide then pcall(button.Hide, button) end
  end
end

local function BagOrder()
  if ShowKeyring() then return { 0, 1, 2, 3, 4, -2 } end
  return { 0, 1, 2, 3, 4 }
end

local function HandleEquippedBagClick()
  if this.bag == -2 then
    local layout = QtUI.GetLayout and QtUI:GetLayout()
    if layout then
      layout.bagShowKeys = not ShowKeyring()
    end
    if type(ToggleKeyRing) == "function" and ShowKeyring() then
      pcall(ToggleKeyRing)
    end
    if QtUI.UpdateBags then QtUI:UpdateBags() end
    return
  end
  if this.bag == 0 then return end

  local hasCursorItem = type(CursorHasItem) == "function" and IsTruthy(CursorHasItem())
  if hasCursorItem and type(PutItemInBag) == "function" then
    PutItemInBag(this.inventorySlot)
  elseif type(PickupBagFromSlot) == "function" then
    PickupBagFromSlot(this.inventorySlot)
  elseif type(PickupInventoryItem) == "function" then
    PickupInventoryItem(this.inventorySlot)
  end
end

local function CreateEquippedBagButton(parent, bag)
  local button = CreateFrame("Button", "QtUIEquippedBag" .. bag, parent)
  button:SetWidth(36)
  button:SetHeight(36)
  button.bag = bag
  button.inventorySlot = bag > 0 and BagInventorySlot(bag) or nil
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:RegisterForDrag("LeftButton")
  ApplySlotWell(button, 2)

  button.icon = button:CreateTexture(nil, "ARTWORK")
  button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 4, -4)
  button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -4, 4)
  button.icon:SetTexCoord(.07, .93, .07, .93)

  button.slots = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
  button.slots:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)

  button:SetScript("OnClick", HandleEquippedBagClick)
  button:SetScript("OnDragStart", HandleEquippedBagClick)
  button:SetScript("OnReceiveDrag", function()
    if this.bag > 0 and type(PutItemInBag) == "function" then
      PutItemInBag(this.inventorySlot)
    end
  end)
  button:SetScript("OnEnter", function()
    HighlightBagSlots(this.bag, true)
    GameTooltip:SetOwner(this, "ANCHOR_TOP")
    if this.bag == -2 then
      GameTooltip:SetText("Keyring")
      GameTooltip:AddLine("Shown while you have keys. Click to include them in this window.", .8, .8, .8, 1)
    elseif this.bag == 0 then
      GameTooltip:SetText("Backpack")
      GameTooltip:AddLine("The backpack is fixed and cannot be replaced.", .75, .75, .75, 1)
    elseif GetInventoryItemLink("player", this.inventorySlot) then
      GameTooltip:SetInventoryItem("player", this.inventorySlot)
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine("Drag or click to pick up this bag.", .8, .8, .8, 1)
      GameTooltip:AddLine("Drop another bag here to replace it.", .8, .8, .8, 1)
    else
      GameTooltip:SetText("Empty Bag Slot")
      GameTooltip:AddLine("Drop a bag here to equip it.", .8, .8, .8, 1)
    end
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function()
    HighlightBagSlots(this.bag, false)
    GameTooltip:Hide()
  end)

  UpdateEquippedBagButton(button)
  return button
end

local function UpdateSlot(button, bag, slot, isKeySlot)
  local texture, count, locked = GetContainerItemInfo(bag, slot)
  local link = GetContainerItemLink(bag, slot)
  button.bag = bag
  button.slot = slot
  button.isKeySlot = isKeySlot

  if texture then
    button.icon:SetTexture(texture)
    button.icon:Show()
    if IsTruthy(locked) then
      button.icon:SetVertexColor(.45, .45, .45, 1)
    else
      button.icon:SetVertexColor(1, 1, 1, 1)
    end
  else
    button.icon:SetTexture(nil)
    button.icon:Hide()
  end

  if count and count > 1 then
    button.count:SetText(count)
  else
    button.count:SetText("")
  end

  if QtUI.SetCooldownText and type(GetContainerItemCooldown) == "function" then
    local start, duration, enable = GetContainerItemCooldown(bag, slot)
    QtUI:SetCooldownText(button, start, duration, enable, 12)
  end

  local quality
  if link then
    local _, _, itemQuality = GetItemInfo(link)
    quality = itemQuality
  end
  if isKeySlot then
    TintSlotWell(button, 1, .72, .18, 1)
  elseif quality and quality > 1 and type(GetItemQualityColor) == "function" then
    local r, g, b = GetItemQualityColor(quality)
    TintSlotWell(button, r or 1, g or 1, b or 1, 1)
  else
    TintSlotWell(button, 1, 1, 1, 1)
  end

  button:Show()
end

local function BagLayoutSignature()
  local signature = ""
  local bagOrder = BagOrder()
  for _, bag in ipairs(bagOrder) do
    signature = signature .. bag .. ":" .. ContainerSlots(bag) .. ";"
  end
  return signature
end

local function UpdateMoneyText(frame)
  if frame and frame.money then frame.money:SetText(FormatMoney(GetMoney())) end
end

local function UpdateSpaceText(frame)
  local free, total = 0, 0
  local bagOrder = BagOrder()
  for _, bag in ipairs(bagOrder) do
    local slots = ContainerSlots(bag)
    total = total + slots
    for slot = 1, slots do
      if not GetContainerItemLink(bag, slot) then free = free + 1 end
    end
  end
  if frame.space then
    frame.space:SetText(free .. " / " .. total)
  end
end

local function UpdateEquippedBags(frame)
  PlaceKeyButton(frame)
  if frame.equippedBags then
    for _, button in ipairs(frame.equippedBags) do UpdateEquippedBagButton(button) end
  end
end

local function UpdateOneBag(frame, bag)
  if not frame.itemByLocation then return end
  local slots = ContainerSlots(bag)
  for slot = 1, slots do
    local button = frame.itemByLocation[bag .. ":" .. slot]
    if button then UpdateSlot(button, bag, slot, bag == -2) end
  end
end

local function UpdateOneSlot(frame, bag, slot)
  if not frame.itemByLocation then return end
  local button = frame.itemByLocation[bag .. ":" .. slot]
  if button then UpdateSlot(button, bag, slot, bag == -2) end
end

function QtUI:UpdateBags()
  local frame = self.bagFrame
  if not frame then return end

  local layout = QtUI.GetLayout and QtUI:GetLayout()
  local slotSize = (layout and layout.bagSlotSize) or SLOT_SIZE
  local columns = (layout and layout.bagColumns) or BAG_COLUMNS
  if slotSize < 24 then slotSize = 24 end
  if columns < 6 then columns = 6 end

  local position = 1
  local free = 0
  local total = 0
  local bagOrder = BagOrder()
  local keySlots = 0
  frame.itemByLocation = {}
  for _, bag in ipairs(bagOrder) do
    local slots = ContainerSlots(bag)
    local slot
    for slot = 1, slots do
      local button = frame.items[position]
      if not button then
        button = CreateItemButton(frame, position)
        frame.items[position] = button
      end
      button:SetWidth(slotSize)
      button:SetHeight(slotSize)

      local column = math.mod(position - 1, columns)
      local row = math.floor((position - 1) / columns)
      button:ClearAllPoints()
      button:SetPoint("TOPLEFT", frame, "TOPLEFT",
        WINDOW_PADDING + column * (slotSize + SLOT_GAP),
        -28 - row * (slotSize + SLOT_GAP))
      UpdateSlot(button, bag, slot, bag == -2)
      frame.itemByLocation[bag .. ":" .. slot] = button

      total = total + 1
      if bag == -2 then keySlots = keySlots + 1 end
      if not GetContainerItemLink(bag, slot) then free = free + 1 end
      position = position + 1
    end
  end

  local index
  for index = position, table.getn(frame.items) do
    frame.items[index]:Hide()
  end

  local rows = math.max(1, math.floor((total + columns - 1) / columns))
  local windowWidth = WINDOW_PADDING * 2 + columns * slotSize + (columns - 1) * SLOT_GAP
  local windowHeight = 62 + rows * (slotSize + SLOT_GAP)
  frame:SetWidth(windowWidth)
  frame:SetHeight(windowHeight)
  frame.layoutSignature = BagLayoutSignature()
  UpdateSpaceText(frame)
  UpdateMoneyText(frame)
  UpdateEquippedBags(frame)
end

function QtUI:OpenBags()
  if not self.bagFrame then return end
  pcall(self.UpdateBags, self)
  if self.bagFrame.Show then pcall(self.bagFrame.Show, self.bagFrame) end
end

function QtUI:CloseBags()
  if self.bagFrame then
    if self.bagFrame.bagMenu then self.bagFrame.bagMenu:Hide() end
    self.bagFrame:Hide()
  end
  if self.splitFrame then self.splitFrame:Hide() end
  if StackSplitFrame and StackSplitFrame.Hide then StackSplitFrame:Hide() end
end

function QtUI:ToggleBags()
  if not self.bagFrame then return end
  if self.bagFrame:IsShown() then self:CloseBags() else self:OpenBags() end
end

function QtUI:SetupBags()
  local frame = self:CreatePanel("QtUIBagFrame", UIParent, 8)
  frame:SetFrameStrata("HIGH")
  if QtUIDB.bagX and QtUIDB.bagY then
    frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", QtUIDB.bagX, QtUIDB.bagY)
  else
    frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -18, 220)
  end
  frame:SetBackdropColor(.025, .035, .045, .92)
  frame:SetBackdropBorderColor(.18, .24, .28, 1)
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function() this:StartMoving() end)
  frame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  frame.items = {}

  -- Item buttons consume mouse input, so provide a full-width header handle
  -- that always starts movement and stores its final screen position.
  frame.dragHandle = CreateFrame("Button", "QtUIBagDragHandle", frame)
  frame.dragHandle:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  frame.dragHandle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  frame.dragHandle:SetHeight(26)
  frame.dragHandle:SetFrameLevel(frame:GetFrameLevel() + 5)
  frame.dragHandle:RegisterForDrag("LeftButton")
  frame.dragHandle:SetScript("OnDragStart", function()
    this:GetParent():StartMoving()
  end)
  frame.dragHandle:SetScript("OnDragStop", function()
    local parent = this:GetParent()
    parent:StopMovingOrSizing()
    local left, bottom = parent:GetLeft(), parent:GetBottom()
    if left and bottom then
      QtUIDB.bagX = left
      QtUIDB.bagY = bottom
      if QtUIDB.positions then
        QtUIDB.positions.bags = { x = left, y = bottom }
      end
      parent:ClearAllPoints()
      parent:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
    end
  end)

  frame.space = frame.dragHandle:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.space:SetPoint("LEFT", frame.dragHandle, "LEFT", 10, -12)
  frame.space:SetPoint("RIGHT", frame.dragHandle, "RIGHT", -22, -12)
  frame.space:SetJustifyH("LEFT")

  frame.close = CreateFrame("Button", "QtUIBagClose", frame)
  frame.close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -10)
  frame.close:SetPoint("BOTTOMLEFT", frame, "TOPRIGHT", -23, -23)
  frame.close:SetFrameLevel(frame:GetFrameLevel() + 10)
  if frame.close.SetNormalTexture then
    frame.close:SetNormalTexture("Interface\\AddOns\\QtUI\\Media\\close_normal")
  end
  if frame.close.SetPushedTexture then
    frame.close:SetPushedTexture("Interface\\AddOns\\QtUI\\Media\\close_pushed")
  end
  frame.close:EnableMouse(true)
  frame.close:RegisterForClicks("LeftButtonUp")
  frame.close:SetScript("OnClick", function() QtUI:CloseBags() end)
  frame.close:SetScript("OnEnter", function()
    if this.GetNormalTexture and this:GetNormalTexture() then
      this:GetNormalTexture():SetVertexColor(.4, 1, .8)
    end
  end)
  frame.close:SetScript("OnLeave", function()
    if this.GetNormalTexture and this:GetNormalTexture() then
      this:GetNormalTexture():SetVertexColor(1, 1, 1)
    end
  end)

  frame.money = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  frame.money:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -13, 12)
  frame.money:SetJustifyH("RIGHT")

  -- Bag-management button and popover.
  frame.bagMenuButton = CreateFrame("Button", "QtUIBagMenuButton", frame)
  frame.bagMenuButton:SetWidth(22)
  frame.bagMenuButton:SetHeight(22)
  frame.bagMenuButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 11, 6)
  frame.bagMenuButton:SetFrameLevel(frame:GetFrameLevel() + 6)
  ApplySlotWell(frame.bagMenuButton, 2)
  frame.bagMenuButton.icon = frame.bagMenuButton:CreateTexture(nil, "ARTWORK")
  frame.bagMenuButton.icon:SetPoint("TOPLEFT", frame.bagMenuButton, "TOPLEFT", 3, -3)
  frame.bagMenuButton.icon:SetPoint("BOTTOMRIGHT", frame.bagMenuButton, "BOTTOMRIGHT", -3, 3)
  frame.bagMenuButton.icon:SetTexture("Interface\\Buttons\\Button-Backpack-Up")

  frame.bagMenu = self:CreatePanel("QtUIBagMenu", frame, frame:GetFrameLevel() + 8)
  frame.bagMenu:SetFrameStrata("DIALOG")
  frame.bagMenu:SetWidth(212)
  frame.bagMenu:SetHeight(62)
  frame.bagMenu:SetPoint("BOTTOMLEFT", frame.bagMenuButton, "TOPLEFT", 0, 4)
  frame.bagMenu:SetBackdropColor(.015, .02, .025, .94)
  frame.bagMenu:SetBackdropBorderColor(.28, .34, .36, 1)
  frame.bagMenu.title = frame.bagMenu:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  frame.bagMenu.title:SetPoint("TOP", frame.bagMenu, "TOP", 0, -6)
  frame.bagMenu.title:SetText("Equipped Bags")
  frame.bagMenu:Hide()

  frame.equippedBags = {}
  local bagIndex
  for bagIndex = 0, 4 do
    local bagButton = CreateEquippedBagButton(frame.bagMenu, bagIndex)
    bagButton:SetPoint("BOTTOMLEFT", frame.bagMenu, "BOTTOMLEFT", 7 + bagIndex * 40, 6)
    frame.equippedBags[bagIndex + 1] = bagButton
  end

  frame.keyButton = CreateEquippedBagButton(frame, -2)
  frame.keyButton:SetWidth(22)
  frame.keyButton:SetHeight(22)
  frame.keyButton:SetPoint("BOTTOMLEFT", frame.bagMenuButton, "BOTTOMRIGHT", 3, 0)
  if frame.keyButton.icon then
    frame.keyButton.icon:ClearAllPoints()
    frame.keyButton.icon:SetPoint("TOPLEFT", frame.keyButton, "TOPLEFT", 3, -3)
    frame.keyButton.icon:SetPoint("BOTTOMRIGHT", frame.keyButton, "BOTTOMRIGHT", -3, 3)
  end
  frame.keyButton:SetFrameLevel(frame:GetFrameLevel() + 6)
  frame.equippedBags[6] = frame.keyButton

  frame.bagMenuButton:SetScript("OnClick", function()
    local menu = this:GetParent().bagMenu
    if menu:IsShown() then menu:Hide() else
      QtUI:UpdateBags()
      menu:Show()
    end
  end)
  frame.bagMenuButton:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_TOP")
    GameTooltip:SetText("Manage Bags")
    GameTooltip:AddLine("View, replace or unequip carried bags.", .8, .8, .8, 1)
    GameTooltip:Show()
  end)
  frame.bagMenuButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

  frame:Hide()
  self.bagFrame = frame

  -- Replace every standard backpack entry point with the combined window.
  ToggleBackpack = function() QtUI:ToggleBags() end
  OpenBackpack = function() QtUI:OpenBags() end
  CloseBackpack = function() QtUI:CloseBags() end
  OpenAllBags = function() QtUI:OpenBags() end
  CloseAllBags = function() QtUI:CloseBags() end
  ToggleBag = function() QtUI:ToggleBags() end

  local bagsOk, bagsErr = pcall(function() QtUI:UpdateBags() end)
  if bagsOk then
    local i
    for i = 1, 13 do self:HideFrame(getglobal("ContainerFrame" .. i)) end
  else
    self:Print("Bags failed to build: " .. tostring(bagsErr))
  end

  local events = CreateFrame("Frame", "QtUIBagEvents")
  events:RegisterEvent("BAG_UPDATE")
  events:RegisterEvent("ITEM_LOCK_CHANGED")
  events:RegisterEvent("PLAYER_MONEY")
  events:RegisterEvent("MERCHANT_SHOW")
  events.dirtyBags = {}
  events.dirtySlots = {}
  events.elapsed = 0

  local function FlushBagEvents()
    local frame = QtUI.bagFrame
    if not frame or not frame:IsShown() then
      events.dirtyBags = {}
      events.dirtySlots = {}
      return
    end

    -- Equipping a different-sized bag is the only normal operation that
    -- requires recreating anchors and rebuilding the location lookup.
    local hasBagChanges = next(events.dirtyBags)
    if frame.layoutSignature ~= BagLayoutSignature() then
      QtUI:UpdateBags()
    else
      for bag in pairs(events.dirtyBags) do UpdateOneBag(frame, bag) end
      for key, location in pairs(events.dirtySlots) do
        if not events.dirtyBags[location.bag] then
          UpdateOneSlot(frame, location.bag, location.slot)
        end
      end
      -- Lock changes only affect the dimmed state of one icon. Occupancy and
      -- equipped-bag information can only change with BAG_UPDATE.
      if hasBagChanges then
        UpdateSpaceText(frame)
        UpdateEquippedBags(frame)
      end
    end
    events.dirtyBags = {}
    events.dirtySlots = {}
  end

  local function ProcessPendingBagEvents()
    this.elapsed = this.elapsed + (arg1 or 0)
    if this.elapsed < .08 then return end
    this.elapsed = 0
    this:SetScript("OnUpdate", nil)
    FlushBagEvents()
  end

  events:SetScript("OnEvent", function()
    if event == "MERCHANT_SHOW" then
      QtUI:OpenBags()
    elseif event == "PLAYER_MONEY" then
      if QtUI.bagFrame and QtUI.bagFrame:IsShown() then
        UpdateMoneyText(QtUI.bagFrame)
      end
    elseif event == "BAG_UPDATE" then
      local bag = tonumber(arg1)
      if bag then
        events.dirtyBags[bag] = true
      else
        -- Emberveil builds do not always provide Blizzard's event arguments.
        events.dirtyBags[0] = true
        events.dirtyBags[1] = true
        events.dirtyBags[2] = true
        events.dirtyBags[3] = true
        events.dirtyBags[4] = true
        events.dirtyBags[-2] = true
      end
    elseif event == "ITEM_LOCK_CHANGED" then
      local bag, slot = tonumber(arg1), tonumber(arg2)
      if bag and slot then
        events.dirtySlots[bag .. ":" .. slot] = { bag = bag, slot = slot }
      elseif bag then
        events.dirtyBags[bag] = true
      end
    end
    if next(events.dirtyBags) or next(events.dirtySlots) then
      events:SetScript("OnUpdate", ProcessPendingBagEvents)
    end
  end)
end
