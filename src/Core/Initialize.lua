local addonName, ns = ...

local function InitializeConfig()
	TOPVEND_CONFIG = TOPVEND_CONFIG or {}
	for key, value in pairs(ns.Defaults) do
		if TOPVEND_CONFIG[key] == nil then
			TOPVEND_CONFIG[key] = value
		end
	end
	ns.config = TOPVEND_CONFIG
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, loadedAddon)
	if loadedAddon ~= addonName then return end
	self:UnregisterEvent(event)

	InitializeConfig()
	ns.InitSettings()
end)
