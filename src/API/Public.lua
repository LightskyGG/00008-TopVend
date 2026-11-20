local _, ns = ...

-- Lets other addons register their own quest UI. A provider is a table with:
--   name      string, for debugging
--   isLoaded  function() -> boolean; true once the UI's frames exist
--   hook      function(schedule); attach hooks that call schedule() whenever
--             the UI redraws its rewards
--   collect   function(scan); for each set of choices that compete for the
--             "best" mark, call scan.BeginGroup(), then once per choice:
--               scan.AddEntry(group, owner, anchor, visible, value)
--             owner    frame the mark is parented to
--             anchor   frame or region the mark is sized and placed over
--             visible  whether the choice is currently on screen
--             value    total vendor copper (see GetStackValue), or nil while
--                      the item is still loading
TopVend = {
	RegisterProvider = ns.RegisterProvider,
	GetStackValue = ns.GetStackValue,
}
