--!strict

local HordeConfig = require("../src/shared/HordeConfig")

local expectedCounts = { 6, 9, 12, 15, 18, 21, 24, 24, 24 }
for wave, expected in expectedCounts do
	assert(HordeConfig.GetWaveSpawnCount(wave) == expected, `Unexpected count for wave {wave}`)
end

assert(HordeConfig.CanSpawn(HordeConfig.ActiveZombieCap - 1))
assert(not HordeConfig.CanSpawn(HordeConfig.ActiveZombieCap))
assert(not HordeConfig.IsExpired(10, 10 + HordeConfig.ZombieLifetime - 0.01))
assert(HordeConfig.IsExpired(10, 10 + HordeConfig.ZombieLifetime))

print("PASS HordeConfig: increasing waves, active cap, and lifetime boundary")
