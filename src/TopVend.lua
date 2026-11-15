-- TopVend: marks the quest reward choice that sells for the most gold.
-- Each supported quest UI is a "provider" (see the bottom half of this file).

local SHOW_COIN = true
local SHOW_GLOW = true
local MIN_CHOICES = 2
local GLOW_COLOR = { 1, 0.82, 0 }
local COIN_TEXTURE = "Interface\\MoneyFrame\\UI-GoldIcon"
local GLOW_TEXTURE = "Interface\\Buttons\\UI-ActionButton-Border"

-- While item prices are still loading we rescan on this interval, up to the
-- duration. Once every price is known the rescans stop.
local SCAN_INTERVAL = 0.1
local SCAN_DURATION = 1.5
local MAX_WALK_DEPTH = 5

local GetItemInfo = C_Item.GetItemInfo
local marks = setmetatable({}, { __mode = "k" })

-- Set by every scan: true while a visible choice still has an unknown price.
local waitingForData = false

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
local function ApplyGroup(group)
  local best, visibleCount, allKnown = 0, 0, true
  for i = 1, group.n do
    local entry = group[i]
    if entry.visible then
      visibleCount = visibleCount + 1
      if entry.value == nil then
        allKnown = false
        waitingForData = true
      elseif entry.value > best then
        best = entry.value
      end
    end
  end

  local active = allKnown and visibleCount >= MIN_CHOICES and best > 0
  for i = 1, group.n do
    local entry = group[i]
    SetMarked(entry, active and entry.visible and entry.value == best)
  end
end

-- Scan buffers
--
-- Scans run often, so groups and entries are reused between scans instead of
-- being allocated each time. Providers fill them through scan.BeginGroup and
-- scan.AddEntry and must not keep references to them.

local groups = {}
local groupCount = 0

local scan = {}

function scan.BeginGroup()
  groupCount = groupCount + 1
  local group = groups[groupCount]
  if not group then
    group = { n = 0 }
    groups[groupCount] = group
  end
  group.n = 0
  return group
end

function scan.AddEntry(group, owner, anchor, visible, value)
  local n = group.n + 1
  group.n = n
  local entry = group[n]
  if not entry then
    entry = {}
    group[n] = entry
  end
  entry.owner = owner
  entry.anchor = anchor
  entry.visible = visible
  entry.value = value
end

-- Provider registry
--
-- A provider describes one quest UI:
--   name      string, for debugging
--   isLoaded  function() -> boolean; true once the UI's frames exist
--   hook      function(schedule); attach hooks that call schedule() whenever
--             the UI redraws its rewards
--   collect   function(scan); for each set of choices that compete with each
--             other for the "best" mark, call
--               local group = scan.BeginGroup()
--               scan.AddEntry(group, owner, anchor, visible, value)
--             once per choice, where
--               owner    frame the mark is parented to
--               anchor   frame or region the mark is sized and placed over
--               visible  whether the choice is currently on screen
--               value    total vendor copper (see TopVend.GetStackValue), or
--                        nil while the item is still loading

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
  waitingForData = false
  for _, provider in ipairs(providers) do
    if provider.isLoaded() then
      groupCount = 0
      provider.collect(scan)
      for i = 1, groupCount do
        ApplyGroup(groups[i])
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
  if not waitingForData or GetTime() >= stopAt then
    self:Hide()
  end
end)

Schedule = function()
  stopAt = GetTime() + SCAN_DURATION
  sinceScan = 0
  Refresh()
  -- Always one follow-up pass, in case the UI finishes laying out after its
  -- hook fires; it keeps going only while prices are still loading.
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
  if event == "GET_ITEM_INFO_RECEIVED" then
    -- Fires constantly for unrelated items; only matters if we're waiting.
    if waitingForData then
      Schedule()
    end
    return
  end

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

local BLIZZARD_REWARD_FRAMES = { "QuestInfoRewardsFrame", "MapQuestInfoRewardsFrame" }

-- The world map's panel knows which quest it is showing; other log panels
-- (like the popup detail frame) go through QuestInfo.
local function GetQuestLogQuestID(frameName)
  if frameName == "MapQuestInfoRewardsFrame" and QuestMapFrame_GetDetailQuestID then
    return QuestMapFrame_GetDetailQuestID()
  end
  return QuestInfo_GetQuestID and QuestInfo_GetQuestID()
end

local function AddBlizzardChoice(group, button, isQuestLog, questID)
  local link
  if isQuestLog then
    link = GetQuestLogItemLink and GetQuestLogItemLink("choice", button:GetID(), questID)
  else
    link = GetQuestItemLink("choice", button:GetID())
  end

  -- The stack count is only exposed through the button's count text.
  local count = 1
  if button.Count and button.Count:IsShown() then
    count = tonumber(button.Count:GetText()) or 1
  end

  scan.AddEntry(group, button, button.Icon, button:IsVisible(), GetStackValue(link, count))
end

RegisterProvider({
  name = "Blizzard",

  isLoaded = function()
    return QuestInfo_Display ~= nil
  end,

  -- Every Blizzard quest panel (NPC dialog, world map log, popup detail)
  -- renders through QuestInfo_Display. Hooking it works for all of them,
  -- including the quest log, which fires no quest event when opened.
  hook = function(schedule)
    hooksecurefunc("QuestInfo_Display", schedule)
  end,

  collect = function()
    for _, frameName in ipairs(BLIZZARD_REWARD_FRAMES) do
      local rewards = _G[frameName]
      if rewards and rewards:IsVisible() then
        -- The world map's quest log panel reads from the log, not the NPC dialog.
        local isQuestLog = frameName == "MapQuestInfoRewardsFrame" or (QuestInfoFrame and QuestInfoFrame.questLog)
        local questID = isQuestLog and GetQuestLogQuestID(frameName) or nil
        local group = scan.BeginGroup()
        for i = 1, rewards:GetNumChildren() do
          local button = select(i, rewards:GetChildren())
          if button.type == "choice" and button.objectType == "item" and button.Icon then
            AddBlizzardChoice(group, button, isQuestLog, questID)
          end
        end
      end
    end
  end,
})

-- Provider: Lorewalker

local LOREWALKER_REWARD_GROUPS = { "QuestItemChoiceRewards", "QuestItemRewards" }
local lorewalkerButtons = {}
local lorewalkerButtonCount = 0

-- Lorewalker pools its reward buttons inside nested list frames, so we find
-- them by the fields it sets on every reward button instead of by path.
local function FindLorewalkerButtons(frame, depth)
  for i = 1, frame:GetNumChildren() do
    local child = select(i, frame:GetChildren())
    if child.rewardButtonType ~= nil and child.Item then
      lorewalkerButtonCount = lorewalkerButtonCount + 1
      lorewalkerButtons[lorewalkerButtonCount] = child
    elseif depth < MAX_WALK_DEPTH then
      FindLorewalkerButtons(child, depth + 1)
    end
  end
end

local itemLinks = setmetatable({}, {
  __index = function(links, itemID)
    local link = "item:" .. itemID
    links[itemID] = link
    return link
  end,
})

local function GetLorewalkerValue(button)
  local info = button.rewardInfo
  if not info then
    return nil
  end
  if info.uk_poolElementType == "Currency" then
    return 0
  end
  local link = button.rewardItemLink or (info.rewardID and itemLinks[info.rewardID])
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
    local questFrame = LWDialogFrame.QuestFrame
    if not (questFrame and LWDialogFrame:IsVisible()) then
      return
    end

    for _, groupName in ipairs(LOREWALKER_REWARD_GROUPS) do
      local list = questFrame[groupName]
      if list then
        lorewalkerButtonCount = 0
        FindLorewalkerButtons(list, 1)

        local group = scan.BeginGroup()
        for i = 1, lorewalkerButtonCount do
          local button = lorewalkerButtons[i]
          scan.AddEntry(group, button.Item, button.Item, button:IsVisible(), GetLorewalkerValue(button))
        end
      end
    end
  end,
})
