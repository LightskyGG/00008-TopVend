local _, ns = ...

local constants = ns.Constants
local Refresh = ns.Refresh
local TryHooks = ns.TryHooks

local sinceScan, stopAt = 0, 0

local driver = CreateFrame("Frame")
driver:Hide()
driver:SetScript("OnUpdate", function(self, elapsed)
	sinceScan = sinceScan + elapsed
	if sinceScan < constants.scanInterval then
		return
	end
	sinceScan = 0
	Refresh()
	if not ns.waitingForData or GetTime() >= stopAt then
		self:Hide()
	end
end)

local function Schedule()
	stopAt = GetTime() + constants.scanDuration
	sinceScan = 0
	Refresh()
	-- One follow-up pass always runs, in case the UI finishes laying out after
	-- its hook fires. It continues only while prices are still loading.
	driver:Show()
end

ns.Schedule = Schedule

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("QUEST_DETAIL")
events:RegisterEvent("QUEST_PROGRESS")
events:RegisterEvent("QUEST_COMPLETE")
events:RegisterEvent("QUEST_ITEM_UPDATE")
events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
events:SetScript("OnEvent", function(_, event)
	if event == "GET_ITEM_INFO_RECEIVED" then
		-- Fires constantly for unrelated items; only matters while waiting.
		if ns.waitingForData then
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
