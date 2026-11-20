local _, ns = ...

local scan = ns.scan
local GetStackValue = ns.GetStackValue

local rewardFrameNames = { "QuestInfoRewardsFrame", "MapQuestInfoRewardsFrame" }

-- The world map's panel knows which quest it is showing; other log panels
-- (like the popup detail frame) go through QuestInfo.
local function GetQuestLogQuestID(frameName)
	if frameName == "MapQuestInfoRewardsFrame" and QuestMapFrame_GetDetailQuestID then
		return QuestMapFrame_GetDetailQuestID()
	end
	return QuestInfo_GetQuestID and QuestInfo_GetQuestID()
end

local function AddChoice(group, button, isQuestLog, questID)
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

ns.RegisterProvider({
	name = "Blizzard",

	isLoaded = function()
		return QuestInfo_Display ~= nil
	end,

	-- Every Blizzard quest panel (NPC dialog, world map log, popup detail)
	-- renders through QuestInfo_Display. Hooking it covers all of them,
	-- including the quest log, which fires no quest event when opened.
	hook = function(schedule)
		hooksecurefunc("QuestInfo_Display", schedule)
	end,

	collect = function()
		for _, frameName in ipairs(rewardFrameNames) do
			local rewards = _G[frameName]
			if rewards and rewards:IsVisible() then
				-- The world map's quest log panel reads from the log, not the NPC dialog.
				local isQuestLog = frameName == "MapQuestInfoRewardsFrame" or (QuestInfoFrame and QuestInfoFrame.questLog)
				local questID = isQuestLog and GetQuestLogQuestID(frameName) or nil
				local group = scan.BeginGroup()
				for i = 1, rewards:GetNumChildren() do
					local button = select(i, rewards:GetChildren())
					if button.type == "choice" and button.objectType == "item" and button.Icon then
						AddChoice(group, button, isQuestLog, questID)
					end
				end
			end
		end
	end,
})
