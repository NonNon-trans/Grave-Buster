--!strict

local HordeConfig = require("../src/shared/HordeConfig")

local now = HordeConfig.InitialDelay
local activeSpawnTimes: { number } = {}
local peakActive = 0
local cleanupCount = 0
local previousScheduledCount = 0

local function cleanupExpired()
	local retained = {}
	for _, spawnedAt in activeSpawnTimes do
		if HordeConfig.IsExpired(spawnedAt, now) then
			cleanupCount += 1
		else
			table.insert(retained, spawnedAt)
		end
	end
	activeSpawnTimes = retained
end

for wave = 1, 12 do
	local scheduledCount = HordeConfig.GetWaveSpawnCount(wave)
	assert(scheduledCount >= previousScheduledCount)
	previousScheduledCount = scheduledCount
	for _ = 1, scheduledCount do
		cleanupExpired()
		if HordeConfig.CanSpawn(#activeSpawnTimes) then
			table.insert(activeSpawnTimes, now)
		end
		peakActive = math.max(peakActive, #activeSpawnTimes)
		assert(#activeSpawnTimes <= HordeConfig.ActiveZombieCap)
		now += HordeConfig.SpawnInterval
	end
	now += HordeConfig.Intermission
end

cleanupExpired()
assert(peakActive == HordeConfig.ActiveZombieCap)
assert(cleanupCount > 0, "Lifetime cleanup should recycle old zombies during a long session")

print("PASS HordeSimulation: wave growth, cap enforcement, and lifetime recycling")
