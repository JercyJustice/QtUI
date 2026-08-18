local function IsShiftHeld()
  local value = IsShiftKeyDown()
  return value == true or value == 1 or value == "1"
end

local function LootEverything()
  local count = tonumber(GetNumLootItems()) or 0
  local slot
  for slot = count, 1, -1 do
    -- One temporarily unavailable slot should not prevent the remaining loot
    -- from being collected on Emberveil's asynchronous loot bridge.
    pcall(LootSlot, slot)
  end
end

function QtUI:SetupAutoLoot()
  if self.autoLootFrame then return end

  local frame = CreateFrame("Frame", "QtUIAutoLootEvents")
  frame.elapsed = 0
  frame.remaining = 0

  local function LootTicker()
    if not this.active then
      this:SetScript("OnUpdate", nil)
      return
    end
    this.elapsed = this.elapsed + arg1
    this.remaining = this.remaining - arg1
    if this.remaining <= 0 then
      this.active = nil
      this:SetScript("OnUpdate", nil)
      return
    end
    if this.elapsed >= .1 then
      this.elapsed = 0
      LootEverything()
    end
  end

  frame:RegisterEvent("LOOT_OPENED")
  frame:RegisterEvent("LOOT_CLOSED")
  frame:RegisterEvent("LOOT_SLOT_CLEARED")

  frame:SetScript("OnEvent", function()
    if event == "LOOT_OPENED" then
      -- Shift is sampled only when the corpse, container or gathering loot
      -- actually opens. A Shift-modified spell cast must not suppress a later,
      -- unrelated loot window.
      if not IsShiftHeld() then
        this.active = true
        this.elapsed = 0
        this.remaining = 2
        LootEverything()
        this:SetScript("OnUpdate", LootTicker)
      else
        this.active = nil
        this.remaining = 0
        this:SetScript("OnUpdate", nil)
      end
    elseif event == "LOOT_SLOT_CLEARED" then
      if this.active then LootEverything() end
    elseif event == "LOOT_CLOSED" then
      this.active = nil
      this.remaining = 0
      this:SetScript("OnUpdate", nil)
    end
  end)

  self.autoLootFrame = frame
end
