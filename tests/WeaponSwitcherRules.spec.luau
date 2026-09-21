--!strict

local Rules = require("../src/client/WeaponSwitcherRules")

local owned = { "BAT", "PAN", "HAMMER", "BLOWER", "ROD" }
assert(Rules.Step(owned, "BAT", 1) == "PAN")
assert(Rules.Step(owned, "BAT", -1) == "ROD", "Previous must wrap first to last")
assert(Rules.Step(owned, "ROD", 1) == "BAT", "Next must wrap last to first")
assert(Rules.Step({ "BAT" }, "BAT", 1) == "BAT", "Single-owned list must remain stable")
assert(Rules.ResolveCurrent(owned, "PAN", "BAT") == "PAN")
assert(Rules.ResolveCurrent(owned, "REMOVED", "BAT") == "BAT")
assert(Rules.ResolveCurrent({ "PAN" }, "REMOVED", "BAT") == "PAN")

local threshold = 48
assert(Rules.GetSwipeDirection(-threshold, 4, threshold) == 1, "Swipe left selects next")
assert(Rules.GetSwipeDirection(threshold, 4, threshold) == -1, "Swipe right selects previous")
assert(Rules.GetSwipeDirection(47, 0, threshold) == 0, "Small drag must not switch")
assert(Rules.GetSwipeDirection(60, 55, threshold) == 0, "Mostly vertical drag must not switch")

local drag = Rules.DragState.new()
local touch = {}
assert(drag:Begin(touch, 100, 100))
assert(not drag:Begin({}, 100, 100), "A second touch cannot replace an active gesture")
assert(drag:Update(touch, 40, 104))
local handled, direction = drag:Finish(touch, threshold)
assert(handled and direction == 1)
local handledAgain, secondDirection = drag:Finish(touch, threshold)
assert(not handledAgain and secondDirection == 0, "One swipe can produce only one switch")

assert(drag:Begin(touch, 0, 0))
drag:Cancel()
assert(not select(1, drag:Finish(touch, threshold)), "Cancelled touch cannot switch")

local visibility = Rules.VisibilityState.new()
assert(visibility:GetMode() == "Idle")
visibility:Activate()
assert(visibility:GetMode() == "Active")
local staleGeneration = visibility:ScheduleIdle()
assert(visibility:GetMode() == "Hold")
visibility:Activate()
assert(not visibility:BeginFade(staleGeneration), "New touch must cancel a pending fade")
local generation = visibility:ScheduleIdle()
assert(visibility:BeginFade(generation) and visibility:GetMode() == "Fade")
assert(visibility:CompleteFade(generation) and visibility:GetMode() == "Idle")

print("PASS WeaponSwitcherRules: ownership fallback, wrap, swipe, one-shot drag, and fade cancellation")
