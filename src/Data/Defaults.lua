local _, ns = ...

ns.Defaults = {
	showCoin = true,
	showGlow = true,
}

ns.Constants = {
	minChoices = 2,
	glowColor = { 1, 0.82, 0 },
	coinTexture = "Interface\\MoneyFrame\\UI-GoldIcon",
	glowTexture = "Interface\\Buttons\\UI-ActionButton-Border",

	-- While item prices are loading, rescans run on this interval (seconds)
	-- until the duration (seconds) passes or every price is known.
	scanInterval = 0.1,
	scanDuration = 1.5,

	maxWalkDepth = 5,
}
