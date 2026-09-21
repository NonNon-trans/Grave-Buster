--!strict

local HordeConfig = require("../src/shared/HordeConfig")

local expectedCounts = { 6, 9, 12, 15, 18, 21, 24, 24, 24 }
for wave, expected in expectedCounts do
	assert(HordeConfig.GetWaveSpawnCount(wave) == expected, `Unexpected count for wave {wave}`)
end

assert(HordeConfig.CanSpawn(HordeConfig.ActiveZombieCap - 1))
assert(not HordeConfig.CanSpawn(HordeConfig.ActiveZombieCap))
local configAny = HordeConfig :: any
assert(configAny.ZombieLifetime == nil, "ACTIVE zombies must not expire with time")
assert(configAny.IsExpired == nil, "Temporary GB-002 lifetime helper must be removed")

print("PASS HordeConfig: increasing waves, active cap, and persistent ACTIVE zombies")
