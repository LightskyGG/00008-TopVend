local _, ns = ...

local constants = ns.Constants
local marks = setmetatable({}, { __mode = "k" })

local function GetMark(owner, anchor)
	local mark = marks[owner]
	if mark then
		return mark
	end

	mark = CreateFrame("Frame", nil, owner)
	mark:SetAllPoints(anchor)
	mark:SetFrameLevel(owner:GetFrameLevel() + 10)

	mark.glow = mark:CreateTexture(nil, "OVERLAY")
	mark.glow:SetTexture(constants.glowTexture)
	mark.glow:SetBlendMode("ADD")
	mark.glow:SetVertexColor(unpack(constants.glowColor))
	mark.glow:SetPoint("CENTER")

	mark.coin = mark:CreateTexture(nil, "OVERLAY", nil, 2)
	mark.coin:SetTexture(constants.coinTexture)
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

function ns.SetMarked(entry, on)
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
	mark.glow:SetShown(ns.config.showGlow)
	mark.coin:SetSize(math.max(10, size * 0.45), math.max(10, size * 0.45))
	mark.coin:SetShown(ns.config.showCoin)
	mark:Show()
	if ns.config.showGlow and not mark.pulse:IsPlaying() then
		mark.pulse:Play()
	end
end
