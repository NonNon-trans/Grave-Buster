--!strict

local ProgressionRules = require("../src/server/ProgressionRules")
local ProgressionSessionStore = require("../src/server/ProgressionSessionStore")

local store = ProgressionSessionStore.new(ProgressionRules.NewState)
local player = {}
local secondPlayer = {}
local initial = store:GetOrCreate(player)
assert(initial.Level == 1 and initial.XP == 0 and initial.Coins == 0 and initial.BestWave == 0)
assert(store:ClaimWaveBonus(player, 1))
local waveOneBonus = ProgressionRules.AwardWaveClearBonus(initial, 1)
assert(waveOneBonus == 10 and initial.Coins == 10)
assert(not store:ClaimWaveBonus(player, 1), "Wave clear bonus may only be claimed once per session")
assert(store:ClaimWaveBonus(player, 2))
assert(not store:ClaimWaveBonus(player, 1), "A stale clear notification cannot replay an earlier wave bonus")
assert(initial.Coins == 10, "Duplicate wave-clear notification must not double award")
local independent = store:GetOrCreate(secondPlayer)
ProgressionRules.AwardXP(independent, 40)
ProgressionRules.AwardXP(initial, 90)
ProgressionRules.AwardXP(initial, 30)
initial.Coins = 37
initial.BestWave = 12

local simulatedCharacter = {}
local afterCharacterRespawn = store:GetOrCreate(player)
assert(simulatedCharacter ~= nil)
assert(afterCharacterRespawn == initial)
assert(afterCharacterRespawn.Level == 2 and afterCharacterRespawn.XP == 20
	and afterCharacterRespawn.Coins == 37 and afterCharacterRespawn.BestWave == 12)
assert(store:GetOrCreate(secondPlayer).Level == 1 and store:GetOrCreate(secondPlayer).XP == 40)

store:Remove(player)
assert(store:ClaimWaveBonus(player, 1), "A rejoined session starts a fresh bonus ledger")
local rejoined = store:GetOrCreate(player)
assert(rejoined.Level == 1 and rejoined.XP == 0 and rejoined.Coins == 0 and rejoined.BestWave == 0)
assert(store:GetOrCreate(secondPlayer).XP == 40)

print("PASS ProgressionSessionStore: character respawn retains session state; leave clears it")
