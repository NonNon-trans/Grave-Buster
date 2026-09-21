--!strict

local HordeConfig = require("../src/shared/HordeConfig")

local active = 0
local peakActive = 0
local defeated = 0
local spawned = 0
local previousScheduledCount = 0

for wave = 1, 12 do
	local scheduledCount = HordeConfig.GetWaveSpawnCount(wave)
	assert(scheduledCount >= previousScheduledCount)
	previousScheduledCount = scheduledCount
	for _ = 1, scheduledCount do
		if HordeConfig.CanSpawn(active) then
			active += 1
			spawned += 1
		end
		peakActive = math.max(peakActive, active)
		assert(active <= HordeConfig.ActiveZombieCap)
	end
	if wave >= 4 then
		local releaseCount = math.min(active, 5)
		active -= releaseCount
		defeated += releaseCount
	end
end

assert(peakActive == HordeConfig.ActiveZombieCap)
assert(defeated > 0)
assert(spawned > HordeConfig.ActiveZombieCap, "Released cap slots should accept replacement zombies")

print("PASS HordeSimulation: wave growth, persistent pressure, cap enforcement, and defeat recycling")
