--!strict

local KillCounter = require("../src/server/KillCounter")

local counter = KillCounter.new()
local player = {}
assert(counter:Ensure(player) == 0)
assert(counter:Add(player, 1) == 1)
assert(counter:Add(player, 5) == 6, "Multi-kill must add every released zombie")
assert(counter:Ensure(player) == 6, "Character reset must not reset the player session")

counter:Remove(player)
assert(counter:Get(player) == nil)
assert(counter:Ensure(player) == 0, "Rejoin-equivalent session must start at zero")

print("PASS KillCounter: authority, multi-kill, reset persistence, and rejoin initialization")
