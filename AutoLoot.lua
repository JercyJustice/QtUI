local function IsShiftHeld()
  local value = IsShiftKeyDown()
  return value == true or value == 1 or value == "1"
end

local function LootEverything()
  local count = GetNumLootItems() or 0
  local slot
  for slot = count, 1, -1 do
    LootSlot(slot)
  end
end

function PotatoUI:SetupAutoLoot()
  if self.autoLootFrame then return end

  local frame = CreateFrame("Frame", "PotatoUIAutoLootEvents")
  frame.elapsed = 0
  frame.remaining = 0

  frame:RegisterEvent("LOOT_OPENED")
  frame:RegisterEvent("LOOT_CLOSED")
  frame:RegisterEvent("LOOT_SLOT_CLEARED")
  frame:RegisterEvent("SPELLCAST_START")

  frame:SetScript("OnEvent", function()
    if event == "SPELLCAST_START" then
      -- Mining, herbalism and skinning open their loot only after a cast.
      -- Remember whether Shift requested manual looting even if it is released
      -- before the node's LOOT_OPENED event arrives.
      this.shiftCastRemaining = IsShiftHeld() and 10 or 0
    elseif event == "LOOT_OPENED" then
      local manualLoot = IsShiftHeld() or (this.shiftCastRemaining or 0) > 0
      this.shiftCastRemaining = 0
      if not manualLoot then
        this.active = true
        this.elapsed = 0
        this.remaining = 1.25
        LootEverything()
      else
        this.active = nil
        this.remaining = 0
      end
    elseif event == "LOOT_SLOT_CLEARED" then
      if this.active then LootEverything() end
    elseif event == "LOOT_CLOSED" then
      this.active = nil
      this.remaining = 0
    end
  end)

  -- A short retry period handles gathering nodes whose loot becomes available
  -- one frame after LOOT_OPENED on Emberveil.
  frame:SetScript("OnUpdate", function()
    if (this.shiftCastRemaining or 0) > 0 then
      this.shiftCastRemaining = this.shiftCastRemaining - arg1
      if this.shiftCastRemaining < 0 then this.shiftCastRemaining = 0 end
    end

    if not this.active then return end
    this.elapsed = this.elapsed + arg1
    this.remaining = this.remaining - arg1
    if this.remaining <= 0 then
      this.active = nil
      return
    end
    if this.elapsed >= .1 then
      this.elapsed = 0
      LootEverything()
    end
  end)

  self.autoLootFrame = frame
end
