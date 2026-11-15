local SHOW_COIN = true
local SHOW_GLOW = true
local MIN_CHOICES = 2
local GLOW_COLOR = { 1, 0.82, 0 }
local COIN_TEXTURE = "Interface\\MoneyFrame\\UI-GoldIcon"
local GLOW_TEXTURE = "Interface\\Buttons\\UI-ActionButton-Border"

-- Item data and custom quest UIs can finish populating after the event that
-- triggered us, so we rescan briefly instead of trusting a single pass.
local SCAN_INTERVAL = 0.1
local SCAN_DURATION = 1.5
local MAX_WALK_DEPTH = 5

local GetItemInfo = C_Item.GetItemInfo
local marks = setmetatable({}, { __mode = "k" })

-- Rendering

local function GetMark(owner, anchor)
  local mark = marks[owner]
  if mark then
    return mark
  end

  mark = CreateFrame("Frame", nil, owner)
  mark:SetAllPoints(anchor)
  mark:SetFrameLevel(owner:GetFrameLevel() + 10)

  mark.glow = mark:CreateTexture(nil, "OVERLAY")
  mark.glow:SetTexture(GLOW_TEXTURE)
  mark.glow:SetBlendMode("ADD")
  mark.glow:SetVertexColor(unpack(GLOW_COLOR))
  mark.glow:SetPoint("CENTER")

  mark.coin = mark:CreateTexture(nil, "OVERLAY", nil, 2)
  mark.coin:SetTexture(COIN_TEXTURE)
  mark.coin:SetPoint("CENTER", mark, "TOPRIGHT", -2, -2)

  mark.pulse = mark.glow:CreateAnimationGroup()
  mark.pulse:SetLooping("BOUNCE")
  local fade = mark.pulse:CreateAnimation("Alpha")
  fade:SetFromAlpha(1)
  fade:SetToAlpha(0.45)
  fade:SetDuration(0.8)
  fade:SetSmoothing("IN_OUT")

  marks[owner] = mark
  return mark
end

local function SetMarked(entry, on)
  if not on then
    local mark = marks[entry.owner]
    if mark then
      mark.pulse:Stop()
      mark:Hide()
    end
    return
  end

  local mark = GetMark(entry.owner, entry.anchor)
  local size = entry.anchor:GetWidth()
  if not size or size < 1 then
    size = 30
  end

  mark.glow:SetSize(size * 1.8, size * 1.8)
  mark.glow:SetShown(SHOW_GLOW)
  mark.coin:SetSize(math.max(10, size * 0.45), math.max(10, size * 0.45))
  mark.coin:SetShown(SHOW_COIN)
  mark:Show()
  if SHOW_GLOW and not mark.pulse:IsPlaying() then
    mark.pulse:Play()
  end
end

-- Valuation

-- Returns nil while item data is still loading so an incomplete set of
-- prices can never produce a wrong "best" pick.
local function GetStackValue(link, count)
  if not link then
    return nil
  end
  local sellPrice = select(11, GetItemInfo(link))
  if not sellPrice then
    return nil
  end
  return sellPrice * (count or 1)
end

-- Marks the most valuable visible entry (or entries, on a tie) of one group
-- of choices. Hidden entries are included so stale marks on pooled buttons
-- get cleared.
local function ApplyGroup(entries)
  local best, visibleCount, allKnown = 0, 0, true
  for _, entry in ipairs(entries) do
    if entry.visible then
      visibleCount = visibleCount + 1
      if entry.value == nil then
        allKnown = false
      elseif entry.value > best then
        best = entry.value
      end
    end
  end

  local active = allKnown and visibleCount >= MIN_CHOICES and best > 0
  for _, entry in ipairs(entries) do
    SetMarked(entry, active and entry.visible and entry.value == best)
  end
end

-- Provider registry
--
-- A provider describes one quest UI:
--   name      string, for debugging
--   isLoaded  function() -> boolean; true once the UI's frames exist
--   hook      function(schedule); attach hooks that call schedule() whenever
--             the UI redraws its rewards
--   collect   function() -> array of groups; each group is an array of
--             entries { owner, anchor, visible, value } that compete with
--             each other for the "best" mark
--               owner    frame the mark is parented to
--               anchor   frame or region the mark is sized and placed over
--               visible  whether the choice is currently on screen
--               value    total vendor copper (see TopVend.GetStackValue)

local providers = {}
local Schedule

local function TryHooks()
  for _, provider in ipairs(providers) do
    if not provider.hooked and provider.isLoaded() then
      provider.hook(Schedule)
      provider.hooked = true
    end
  end
end

local function RegisterProvider(provider)
  providers[#providers + 1] = provider
  TryHooks()
end

local function Refresh()
  for _, provider in ipairs(providers) do
    if provider.isLoaded() then
      for _, group in ipairs(provider.collect()) do
        ApplyGroup(group)
      end
    end
  end
end

-- Scheduling

local driver = CreateFrame("Frame")
local sinceScan, stopAt = 0, 0
driver:Hide()
driver:SetScript("OnUpdate", function(self, dt)
  sinceScan = sinceScan + dt
  if sinceScan < SCAN_INTERVAL then
    return
  end
  sinceScan = 0
  Refresh()
  if GetTime() >= stopAt then
    self:Hide()
  end
end)

Schedule = function()
  stopAt = GetTime() + SCAN_DURATION
  Refresh()
  driver:Show()
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("QUEST_DETAIL")
events:RegisterEvent("QUEST_PROGRESS")
events:RegisterEvent("QUEST_COMPLETE")
events:RegisterEvent("QUEST_ITEM_UPDATE")
events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
events:SetScript("OnEvent", function(_, event)
  -- Custom UIs may create their frames after we load, so retry hooking.
  TryHooks()
  if event ~= "PLAYER_LOGIN" then
    Schedule()
  end
end)

-- Public API, so other addons can register their own quest UI without
-- editing this file.
TopVend = {
  RegisterProvider = RegisterProvider,
  GetStackValue = GetStackValue,
}

-- Provider: Blizzard default UI

RegisterProvider({
  name = "Blizzard",

  isLoaded = function()
    return QuestInfo_ShowRewards ~= nil
  end,

  hook = function(schedule)
    hooksecurefunc("QuestInfo_ShowRewards", schedule)
  end,

  collect = function()
    local groups = {}

    for _, frameName in ipairs({ "QuestInfoRewardsFrame", "MapQuestInfoRewardsFrame" }) do
      local rewards = _G[frameName]
      if rewards and rewards:IsVisible() then
        -- The world map's quest log panel reads from the log, not the NPC dialog.
        local isQuestLog = frameName == "MapQuestInfoRewardsFrame" or (QuestInfoFrame and QuestInfoFrame.questLog)
        local entries = {}
        for _, button in ipairs({ rewards:GetChildren() }) do
          if button.type == "choice" and button.objectType == "item" and button.Icon then
            local link
            if isQuestLog then
              local questID = QuestInfo_GetQuestID and QuestInfo_GetQuestID()
              link = GetQuestLogItemLink and GetQuestLogItemLink("choice", button:GetID(), questID)
            else
              link = GetQuestItemLink("choice", button:GetID())
            end

            -- The stack count is only exposed through the button's count text.
            local count = 1
            if button.Count and button.Count:IsShown() then
              count = tonumber(button.Count:GetText()) or 1
            end

            entries[#entries + 1] = {
              owner = button,
              anchor = button.Icon,
              visible = button:IsVisible(),
              value = GetStackValue(link, count),
            }
          end
        end
        groups[#groups + 1] = entries
      end
    end

    return groups
  end,
})

-- Provider: Lorewalker

-- Lorewalker pools its reward buttons inside nested list frames, so we find
-- them by the fields it sets on every reward button instead of by path.
local function FindLorewalkerButtons(frame, found, depth)
  for _, child in ipairs({ frame:GetChildren() }) do
    if child.rewardButtonType ~= nil and child.Item then
      found[#found + 1] = child
    elseif depth < MAX_WALK_DEPTH then
      FindLorewalkerButtons(child, found, depth + 1)
    end
  end
end

local function GetLorewalkerValue(button)
  local info = button.rewardInfo
  if not info then
    return nil
  end
  if info.uk_poolElementType == "Currency" then
    return 0
  end
  local link = button.rewardItemLink or (info.rewardID and ("item:" .. info.rewardID))
  return GetStackValue(link, info.count)
end

RegisterProvider({
  name = "Lorewalker",

  isLoaded = function()
    return LWDialogFrame ~= nil and LWDialogFrame.UpdateQuestRewards ~= nil
  end,

  hook = function(schedule)
    hooksecurefunc(LWDialogFrame, "UpdateQuestRewards", schedule)
  end,

  collect = function()
    local groups = {}
    local questFrame = LWDialogFrame.QuestFrame
    if not (questFrame and LWDialogFrame:IsVisible()) then
      return groups
    end

    for _, groupName in ipairs({ "QuestItemChoiceRewards", "QuestItemRewards" }) do
      local group = questFrame[groupName]
      if group then
        local buttons = {}
        FindLorewalkerButtons(group, buttons, 1)

        local entries = {}
        for _, button in ipairs(buttons) do
          entries[#entries + 1] = {
            owner = button.Item,
            anchor = button.Item,
            visible = button:IsVisible(),
            value = GetLorewalkerValue(button),
          }
        end
        groups[#groups + 1] = entries
      end
    end

    return groups
  end,
})
