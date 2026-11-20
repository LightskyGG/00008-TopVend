local _, ns = ...

local constants = ns.Constants
local SetMarked = ns.SetMarked

local providers = {}
local groups = {}
local groupCount = 0

-- True after a scan while a visible choice still has an unknown price.
ns.waitingForData = false

-- Scans run often, so groups and entries are reused instead of reallocated.
-- Providers must not keep references to them.
local scan = {}
ns.scan = scan

function scan.BeginGroup()
	groupCount = groupCount + 1
	local group = groups[groupCount]
	if not group then
		group = { count = 0 }
		groups[groupCount] = group
	end
	group.count = 0
	return group
end

function scan.AddEntry(group, owner, anchor, visible, value)
	local index = group.count + 1
	group.count = index
	local entry = group[index]
	if not entry then
		entry = {}
		group[index] = entry
	end
	entry.owner = owner
	entry.anchor = anchor
	entry.visible = visible
	entry.value = value
end

-- Hidden entries are included so stale marks on pooled buttons get cleared.
local function ApplyGroup(group)
	local bestValue, visibleCount, allKnown = 0, 0, true
	for i = 1, group.count do
		local entry = group[i]
		if entry.visible then
			visibleCount = visibleCount + 1
			if entry.value == nil then
				allKnown = false
				ns.waitingForData = true
			elseif entry.value > bestValue then
				bestValue = entry.value
			end
		end
	end

	local isActive = allKnown and visibleCount >= constants.minChoices and bestValue > 0
	for i = 1, group.count do
		local entry = group[i]
		SetMarked(entry, isActive and entry.visible and entry.value == bestValue)
	end
end

local function TryHooks()
	for _, provider in ipairs(providers) do
		if not provider.hooked and provider.isLoaded() then
			provider.hook(ns.Schedule)
			provider.hooked = true
		end
	end
end

function ns.RegisterProvider(provider)
	providers[#providers + 1] = provider
	TryHooks()
end

ns.TryHooks = TryHooks

function ns.Refresh()
	ns.waitingForData = false
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
