--!strict

local CombatRules = require("../src/server/CombatRules")

assert(CombatRules.CanAttack(nil, 10, 0.34))
assert(not CombatRules.CanAttack(10, 10.339, 0.34))
assert(CombatRules.CanAttack(10, 10.341, 0.34))

local zombieA = {}
local zombieB = {}
local candidates = CombatRules.Deduplicate({ zombieA, zombieA, zombieB, zombieA, zombieB })
assert(#candidates == 2)
assert(candidates[1] == zombieA and candidates[2] == zombieB)

print("PASS CombatRules: authoritative cooldown boundary and candidate deduplication")
