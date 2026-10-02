--!strict

local Rules = require("../src/client/WeaponSwitcherRules")

local order = { "BAT", "PAN", "HAMMER", "BLOWER", "ROD" }
local owned = Rules.OrderOwned({ "ROD", "BAT", "HAMMER", "PAN", "PAN", "UNKNOWN" }, order)
assert(#owned == 4 and owned[1] == "BAT" and owned[2] == "PAN" and owned[3] == "HAMMER" and owned[4] == "ROD",
	"Only owned weapons should appear, deduplicated in canonical weapon order")
assert(Rules.ResolveCurrent(owned, "PAN", "BAT") == "PAN")
assert(Rules.ResolveCurrent(owned, "REMOVED", "BAT") == "BAT")
assert(Rules.ResolveCurrent({ "PAN" }, "REMOVED", "BAT") == "PAN")

assert(Rules.ArrowStep(1, 1, 5) == 2, "Next arrow advances exactly one weapon")
assert(Rules.ArrowStep(2, -1, 5) == 1, "Previous arrow advances exactly one weapon")
assert(Rules.ArrowStep(1, -1, 5) == 1, "Left boundary clamps without wrapping")
assert(Rules.ArrowStep(5, 1, 5) == 5, "Right boundary clamps without wrapping")
assert(Rules.ArrowStep(1, 1, 1) == 1, "Single-owned list remains stable")

assert(Rules.PositionForDrag(3, -100, 200, 5) == 3.5, "Drag preview follows horizontal pointer movement")
local draggedPosition = Rules.PositionForDrag(3, 10, 200, 5)
assert(math.abs(draggedPosition - 2.95) < 0.0001, "A small pointer move produces a fractional scroll position")
local dragStartCanvasOffset = Rules.CanvasOffset(3, 200, 5)
assert(math.abs(Rules.CanvasOffset(draggedPosition, 200, 5) - dragStartCanvasOffset + 10) < 0.0001,
	"A ten-pixel pointer movement produces an equal and opposite CanvasPosition movement")
assert(Rules.CanvasOffset(3.5, 200, 5) == 500, "Fractional scroll places two items around the fixed selection area")
assert(Rules.CanvasOffset(-4, 200, 5) == 0 and Rules.CanvasOffset(20, 200, 5) == 800,
	"CanvasPosition is clamped to the first and last owned item")
assert(Rules.PointInside(10, 20, 100, 80, 60, 50))
assert(not Rules.PointInside(10, 20, 100, 80, 111, 50),
	"Gesture capture is restricted to the picker center hit area")
assert(Rules.SnapIndex(3.49, 5) == 3 and Rules.SnapIndex(3.5, 5) == 4,
	"Release snaps to the nearest weapon position")
assert(Rules.SnapIndex(0.2, 5) == 1 and Rules.SnapIndex(5.8, 5) == 5, "Drag snap clamps at both boundaries")

local tuning = Rules.Tuning
assert(tuning.SnapDuration == 0.24, "Center snap duration remains unchanged")
assert(Rules.FlickTravel(650, 200) == 0, "Old weak flick below 700 px/s no longer triggers inertia")
local weakTravel = Rules.FlickTravel(750, 200)
local mediumTravel = Rules.FlickTravel(1200, 200)
local strongTravel = Rules.FlickTravel(1800, 200)
local maximumTravel = Rules.FlickTravel(3000, 200)
assert(math.abs(weakTravel - 0.75) < 0.001 and Rules.SnapIndex(2 + weakTravel, 5) == 3,
	"Weak flick should travel about one weapon")
assert(mediumTravel >= 1 and mediumTravel <= 2, "Normal flick should travel one to two weapons")
assert(strongTravel >= 2 and strongTravel <= 3, "Strong flick should travel two to three weapons")
assert(maximumTravel == 3, "Strongest flick travel is capped at three weapons")
for _, width in { 100, 150, 200 } do
	assert(Rules.SnapIndex(2 + Rules.FlickTravel(700, width), 5) == 3, "Threshold flick snaps about one weapon onward")
	local ordinaryStep = Rules.SnapIndex(2 + Rules.FlickTravel(1000, width), 5) - 2
	assert(ordinaryStep >= 1 and ordinaryStep <= 2,
		"Ordinary flick remains controllable across picker widths")
	assert(Rules.FlickTravel(3000, width) == 3, "Maximum travel remains capped across picker widths")
end
assert(Rules.FlickTravel(tuning.FlickVelocityThreshold - 1, 200) == 0, "Sub-threshold motion has no inertia")
assert(Rules.ProjectFlick(4.8, -3000, 200, 5, 3) == 5, "Flick respects right boundary")
assert(Rules.ProjectFlick(1.2, 3000, 200, 5, 3) == 1, "Flick respects left boundary")
assert(Rules.ProjectFlick(3, -3000, 200, 20, 3) <= 3 + tuning.MaximumFlickTravel,
	"Flick travel is capped relative to gesture start")
local maxSnap = Rules.FlickSnapIndex(7.8, 2.8, 20)
assert(maxSnap == 5 and maxSnap - 2.8 <= tuning.MaximumFlickTravel,
	"Final integer snap cannot exceed maximum travel after rounding")

local drag = Rules.DragState.new()
local touch = {}
assert(drag:Begin(touch, 200, 100, 1, 3))
assert(not drag:Begin({}, 200, 100, 1.01, 3), "A second pointer cannot replace an active gesture")
local updated, preview = drag:Update(touch, 100, 104, 1.1, 200, 5)
assert(updated and preview == 3.5)
local handled, _, velocity = drag:Finish(touch)
assert(handled and velocity < 0, "Drag state captures signed release velocity")
assert(not select(1, drag:Finish(touch)), "One pointer release can only finish once")

assert(drag:Begin(touch, 0, 0, 2, 2))
drag:Cancel()
assert(not select(1, drag:Finish(touch)), "Cancelled touch cannot commit a selection")

local commitGate = Rules.SnapCommitGate.new()
local token = commitGate:Begin(4)
assert(commitGate:Commit(token) == 4, "Snap completion commits its final selection")
assert(commitGate:Commit(token) == nil, "Repeated completion cannot equip twice")
local staleToken = commitGate:Begin(2)
commitGate:Cancel()
assert(commitGate:Commit(staleToken) == nil, "Interrupted snap cannot commit stale selection")

local visibility = Rules.VisibilityState.new()
assert(visibility:GetMode() == "Idle")
assert(Rules.GroupTransparencyForMode(visibility:GetMode()) == 0.5,
	"Idle picker visibility is visibly reduced as one composited group")
visibility:Activate()
assert(visibility:GetMode() == "Active")
assert(Rules.GroupTransparencyForMode(visibility:GetMode()) == 0,
	"Interaction restores full group visibility immediately")
local staleGeneration = visibility:ScheduleIdle()
assert(visibility:GetMode() == "Hold")
assert(Rules.GroupTransparencyForMode(visibility:GetMode()) == 0,
	"Picker stays fully visible through the post-interaction hold")
visibility:Activate()
assert(not visibility:BeginFade(staleGeneration), "New touch cancels a pending fade")
local generation = visibility:ScheduleIdle()
assert(visibility:BeginFade(generation) and visibility:GetMode() == "Fade")
assert(Rules.GroupTransparencyForMode(visibility:GetMode()) == 0.5,
	"Fade targets the idle group transparency after the hold interval")
assert(visibility:CompleteFade(generation) and visibility:GetMode() == "Idle")
assert(Rules.GroupTransparencyForMode(visibility:GetMode()) == 0.5)

print("PASS WeaponSwitcherRules: owned ordering, exact arrows, continuous pixel drag, flick/inertia, snap, boundaries, one-shot equip commit, and group opacity lifecycle")

-- Real card centers, viewport resizing, and both end padding boundaries.
for _, width in { 138, 234, 288 } do
	for _, count in { 1, 2, 5 } do
		local g = Rules.CenterGeometry(width, count)
		assert(g.EndPadding > 0)
		for index = 1, count do
			local canvas = Rules.CanvasOffset(index, g.SlotWidth, count)
			assert(math.abs(Rules.ItemCenter(index, g) - canvas - width / 2) < 0.00001,
				"Each visual card center aligns with the viewport center at snap")
			assert(Rules.NearestCenter(canvas, g, count) == index)
		end
		assert(math.abs(g.CanvasWidth - width - Rules.CanvasOffset(count, g.SlotWidth, count)) < 0.00001,
			"Last card can reach center without hitting the canvas boundary early")
		if count >= 2 then
			assert(Rules.NearestCenter(g.SlotWidth * 0.49, g, count) == 1)
			assert(Rules.NearestCenter(g.SlotWidth * 0.51, g, count) == 2)
			local before = Rules.ItemCenter(2, g) - g.SlotWidth * 0.49
			local after = Rules.ItemCenter(2, g) - (g.SlotWidth * 0.49 + 10)
			assert(math.abs(before - after - 10) < 0.00001, "Visual centers move continuously in pixels")
		end
	end
end
assert(Rules.NearestCenter(0, Rules.CenterGeometry(200, 0), 0) == nil)
print("PASS center alignment: nearest visual center, responsive viewport, symmetric padding, continuous movement")
