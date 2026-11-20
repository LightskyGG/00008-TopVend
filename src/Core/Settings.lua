local addonName, ns = ...

local settingsCategory

function ns.InitSettings()
	local category = Settings.RegisterVerticalLayoutCategory(addonName)

	local showCoinSetting = Settings.RegisterAddOnSetting(
		category,
		"TOPVEND_SHOW_COIN",
		"showCoin",
		ns.config,
		Settings.VarType.Boolean,
		"Show Coin",
		ns.Defaults.showCoin
	)
	Settings.CreateCheckbox(category, showCoinSetting, "Mark the best reward with a coin.")

	local showGlowSetting = Settings.RegisterAddOnSetting(
		category,
		"TOPVEND_SHOW_GLOW",
		"showGlow",
		ns.config,
		Settings.VarType.Boolean,
		"Show Glow",
		ns.Defaults.showGlow
	)
	Settings.CreateCheckbox(category, showGlowSetting, "Add a pulsing glow to the best reward.")

	Settings.RegisterAddOnCategory(category)
	settingsCategory = category
end

function TopVend_AddonCompartmentCallback()
	if settingsCategory then
		Settings.OpenToCategory(settingsCategory:GetID())
	end
end
