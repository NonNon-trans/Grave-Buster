--!strict

local ProgressionRules = require("../src/server/ProgressionRules")
local ProgressionSessionStore = require("../src/server/ProgressionSessionStore")

local store = ProgressionSessionStore.new(ProgressionRules.NewState)
local player = {}
local secondPlayer = {}
local initial = store:GetOrCreate(player)
assert(initial.Level == 1 and initial.XP == 0)
local independent = store:GetOrCreate(secondPlayer)
ProgressionRules.AwardXP(independent, 40)
ProgressionRules.AwardXP(initial, 90)
ProgressionRules.AwardXP(initial, 30)

local simulatedCharacter = {}
local afterCharacterRespawn = store:GetOrCreate(player)
assert(simulatedCharacter ~= nil)
assert(afterCharacterRespawn == initial)
assert(afterCharacterRespawn.Level == 2 and afterCharacterRespawn.XP == 20)
assert(store:GetOrCreate(secondPlayer).Level == 1 and store:GetOrCreate(secondPlayer).XP == 40)

store:Remove(player)
local rejoined = store:GetOrCreate(player)
assert(rejoined.Level == 1 and rejoined.XP == 0)
assert(store:GetOrCreate(secondPlayer).XP == 40)

print("PASS ProgressionSessionStore: character respawn retains session state; leave clears it")
