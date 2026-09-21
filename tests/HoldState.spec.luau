--!strict

local HoldState = require("../src/client/HoldState")

local state = HoldState.new()
local first = state:Begin()
assert(first and state:IsCurrent(first))
assert(state:Begin() == nil, "Duplicate hold loop must be rejected")
state:Stop()
assert(not state:IsCurrent(first), "Release/reset/switch must invalidate the old loop")
local second = state:Begin()
assert(second and second ~= first and state:IsCurrent(second))
state:Stop()

print("PASS HoldState: start, duplicate rejection, immediate stop, and restart")
