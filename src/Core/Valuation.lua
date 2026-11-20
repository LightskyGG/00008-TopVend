local _, ns = ...

local GetItemInfo = C_Item.GetItemInfo

-- Returns nil while item data is still loading, so an incomplete set of
-- prices can never produce a wrong "best" pick.
function ns.GetStackValue(link, count)
	if not link then
		return nil
	end
	local sellPrice = select(11, GetItemInfo(link))
	if not sellPrice then
		return nil
	end
	return sellPrice * (count or 1)
end
