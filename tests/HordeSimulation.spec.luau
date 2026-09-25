--!strict

local HordeConfig = require("../src/shared/HordeConfig")
local WaveRules = require("../src/server/WaveRules")

local wave20 = WaveRules.New(20, HordeConfig.GetTotalSpawn(20))
local active = 0
local totalSpawned = 0
local defeated = 0
local activePeak = 0

while wave20.Spawned < wave20.TotalQuota do
	if WaveRules.CanSpawn(wave20, active, HordeConfig.MaxAliveZombies) then
		assert(WaveRules.RecordSpawn(wave20))
		active += 1
		totalSpawned += 1
		activePeak = math.max(activePeak, active)
		assert(active <= HordeConfig.MaxAliveZombies)
	else
		local released = math.min(10, active)
		assert(released > 0, "A full cap must contain active zombies that can release slots")
		active -= released
		defeated += released
	end
end

assert(wave20.Spawned == 110 and totalSpawned == 110, "Cap pressure must preserve the full quota")
assert(activePeak == 80 and defeated == 30)
assert(not WaveRules.TryMarkCleared(wave20, active), "ACTIVE zombies block wave clear")

local quotaIncomplete = WaveRules.New(1, 15)
for _ = 1, 14 do
	assert(WaveRules.RecordSpawn(quotaIncomplete))
end
assert(not WaveRules.TryMarkCleared(quotaIncomplete, 0), "Unspawned quota blocks wave clear")

active = 0
assert(WaveRules.TryMarkCleared(wave20, 0), "Complete quota and zero active should clear")
assert(not WaveRules.TryMarkCleared(wave20, 0), "Wave clear may fire only once")
local nextWave = WaveRules.New(21, HordeConfig.GetTotalSpawn(21))
assert(WaveRules.CanSpawn(nextWave, 0, HordeConfig.MaxAliveZombies))
assert(WaveRules.RecordSpawn(nextWave), "Next wave starts without intermission")
assert(not WaveRules.TryMarkCleared(nextWave, 1), "New wave activity does not count as old-wave clear")

print("PASS HordeSimulation: retained quota at cap, replacement spawns, wave ownership, clear gating, and once-only transition")
