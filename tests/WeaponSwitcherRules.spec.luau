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
assert(math.abs(Rules.PixelOffset(3, draggedPosition, 200) - 10) < 0.0001,
	"The card follows the pointer delta continuously in pixels")
assert(Rules.PixelOffset(4, 3.5, 200) == 100, "Fractional preview renders between weapon slots")
assert(Rules.PointInside(10, 20, 100, 80, 60, 50))
assert(not Rules.PointInside(10, 20, 100, 80, 111, 50),
	"Gesture capture is restricted to the picker center hit area")
assert(Rules.SnapIndex(3.49, 5) == 3 and Rules.SnapIndex(3.5, 5) == 4,
	"Release snaps to the nearest weapon position")
assert(Rules.SnapIndex(0.2, 5) == 1 and Rules.SnapIndex(5.8, 5) == 5, "Drag snap clamps at both boundaries")

local tuning = Rules.Tuning
local weakTravel = Rules.FlickTravel(650, 200)
local mediumTravel = Rules.FlickTravel(1200, 200)
local strongTravel = Rules.FlickTravel(1800, 200)
local maximumTravel = Rules.FlickTravel(3000, 200)
assert(math.abs(weakTravel - 0.85) < 0.001 and Rules.SnapIndex(2 + weakTravel, 5) == 3,
	"Weak flick should travel about one weapon")
assert(mediumTravel == 2, "Medium flick should travel about two weapons")
assert(strongTravel >= 4 and strongTravel <= 5, "Strong flick should travel four to five weapons")
assert(maximumTravel == tuning.MaximumFlickTravel, "Flick distance is capped")
assert(Rules.FlickTravel(tuning.FlickVelocityThreshold - 1, 200) == 0, "Sub-threshold motion has no inertia")
assert(Rules.ProjectFlick(4.8, -3000, 200, 5, 3) == 5, "Flick respects right boundary")
assert(Rules.ProjectFlick(1.2, 3000, 200, 5, 3) == 1, "Flick respects left boundary")
assert(Rules.ProjectFlick(3, -3000, 200, 20, 3) <= 3 + tuning.MaximumFlickTravel,
	"Flick travel is capped relative to gesture start")
local maxSnap = Rules.FlickSnapIndex(7.8, 2.8, 20)
assert(maxSnap == 7 and maxSnap - 2.8 <= tuning.MaximumFlickTravel,
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
assert(Rules.GroupTransparencyForMode(visibility:GetMode()) == 0,
	"Fade interpolates toward idle only after the hold interval")
assert(visibility:CompleteFade(generation) and visibility:GetMode() == "Idle")
assert(Rules.GroupTransparencyForMode(visibility:GetMode()) == 0.5)

print("PASS WeaponSwitcherRules: owned ordering, exact arrows, continuous pixel drag, flick/inertia, snap, boundaries, one-shot equip commit, and group opacity lifecycle")
