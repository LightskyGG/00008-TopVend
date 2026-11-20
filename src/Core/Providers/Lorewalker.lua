local _, ns = ...

local constants = ns.Constants
local scan = ns.scan
local GetStackValue = ns.GetStackValue

local rewardGroupNames = { "QuestItemChoiceRewards", "QuestItemRewards" }
local rewardButtons = {}
local rewardButtonCount = 0

-- Lorewalker pools its reward buttons inside nested list frames, so they are
-- found by the fields it sets on every reward button instead of by path.
local function FindRewardButtons(frame, depth)
	for i = 1, frame:GetNumChildren() do
		local child = select(i, frame:GetChildren())
		if child.rewardButtonType ~= nil and child.Item then
			rewardButtonCount = rewardButtonCount + 1
			rewardButtons[rewardButtonCount] = child
		elseif depth < constants.maxWalkDepth then
			FindRewardButtons(child, depth + 1)
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

local function GetRewardValue(button)
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

ns.RegisterProvider({
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

		for _, groupName in ipairs(rewardGroupNames) do
			local list = questFrame[groupName]
			if list then
				rewardButtonCount = 0
				FindRewardButtons(list, 1)

				local group = scan.BeginGroup()
				for i = 1, rewardButtonCount do
					local button = rewardButtons[i]
					scan.AddEntry(group, button.Item, button.Item, button:IsVisible(), GetRewardValue(button))
				end
			end
		end
	end,
})
