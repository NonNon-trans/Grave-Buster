--!nonstrict

local GuiService = game:GetService("GuiService")
local Rules = require(script.Parent:WaitForChild("ProgressionFeedbackRules"))

local HudLayout = {}

-- GetInsetArea rectangles use CoreUISafeInsets coordinates. TopbarSafeInsets
-- tracks unoccupied CoreUI space; DeviceSafeInsets accounts for screen cutouts.
-- https://create.roblox.com/docs/reference/engine/classes/GuiService#GetInsetArea
function HudLayout.Read()
	local core = GuiService:GetInsetArea(Enum.ScreenInsets.CoreUISafeInsets)
	local top = GuiService:GetInsetArea(Enum.ScreenInsets.TopbarSafeInsets)
	local device = GuiService:GetInsetArea(Enum.ScreenInsets.DeviceSafeInsets)
	return Rules.Layout(core.Width, core.Height, {
		X = top.Min.X - core.Min.X, Y = top.Min.Y - core.Min.Y,
		Width = top.Width, Height = top.Height,
	}, {
		X = device.Min.X - core.Min.X, Y = device.Min.Y - core.Min.Y,
		Width = device.Width, Height = device.Height,
	})
end

function HudLayout.Watch(scope, gui, callback)
	local function refresh() callback(HudLayout.Read()) end
	scope:Connect(GuiService:GetPropertyChangedSignal("TopbarInset"), refresh)
	scope:Connect(gui:GetPropertyChangedSignal("AbsoluteSize"), refresh)
	scope:Connect(gui:GetPropertyChangedSignal("AbsolutePosition"), refresh)
	refresh()
	-- The first safe rectangles may arrive after parenting; no polling loop.
	scope:Delay("InitialLayout", 0, refresh)
end

return HudLayout
