--!strict

local HordeConfig = require("../src/shared/HordeConfig")

local expected = {
	{ 10, 10, 15 },
	{ 12, 10, 20 },
	{ 15, 10, 25 },
	{ 18, 11, 30 },
	{ 22, 11, 35 },
	{ 26, 12, 40 },
	{ 30, 12, 45 },
	{ 35, 13, 50 },
	{ 40, 14, 55 },
	{ 50, 15, 60 },
}

for wave, row in expected do
	assert(HordeConfig.GetZombieHP(wave) == row[1], `Unexpected HP at wave {wave}`)
	assert(HordeConfig.GetZombieDamage(wave) == row[2], `Unexpected damage at wave {wave}`)
	assert(HordeConfig.GetTotalSpawn(wave) == row[3], `Unexpected quota at wave {wave}`)
end

assert(HordeConfig.GetZombieHP(11) == 55)
assert(HordeConfig.GetZombieDamage(11) == 15)
assert(HordeConfig.GetTotalSpawn(11) == 65)
assert(HordeConfig.GetZombieHP(13) == 67)
assert(HordeConfig.GetZombieDamage(13) == 16)
assert(HordeConfig.GetTotalSpawn(13) == 75)
assert(HordeConfig.GetZombieHP(20) == 130)
assert(HordeConfig.GetZombieDamage(20) == 18)
assert(HordeConfig.GetTotalSpawn(20) == 110)
assert(HordeConfig.GetZombieHP(100) % 1 == 0, "Scaled HP must be an integer")

assert(HordeConfig.Intermission == 0)
assert(HordeConfig.MaxAliveZombies == 80)
assert(HordeConfig.CanSpawn(HordeConfig.MaxAliveZombies - 1))
assert(not HordeConfig.CanSpawn(HordeConfig.MaxAliveZombies))
assert(HordeConfig.SpawnInterval == 0.65, "Existing spawn pacing should be preserved")
assert((HordeConfig :: any).ZombieLifetime == nil, "ACTIVE zombies must not expire with time")

print("PASS HordeConfig: fixed/scaled HP, damage, quota, integer HP, cap, and zero intermission")
