--!strict

local HordeConfig = {
	InitialDelay = 3,
	Intermission = 0,
	SpawnInterval = 0.65,
	CapPollInterval = 0.2,
	ClearPollInterval = 0.1,
	MaxAliveZombies = 80,
	ZombieWalkSpeed = 8,
	AIUpdateInterval = 0.25,
	TargetRefreshInterval = 0.75,
	NoTargetPollInterval = 0.5,
	ApproachRadius = 5.5,
	StopDistance = 2.5,
}

local WAVE_BALANCE = table.freeze({
	table.freeze({ ZombieHP = 10, ZombieDamage = 10, TotalSpawn = 15 }),
	table.freeze({ ZombieHP = 12, ZombieDamage = 10, TotalSpawn = 20 }),
	table.freeze({ ZombieHP = 15, ZombieDamage = 10, TotalSpawn = 25 }),
	table.freeze({ ZombieHP = 18, ZombieDamage = 11, TotalSpawn = 30 }),
	table.freeze({ ZombieHP = 22, ZombieDamage = 11, TotalSpawn = 35 }),
	table.freeze({ ZombieHP = 26, ZombieDamage = 12, TotalSpawn = 40 }),
	table.freeze({ ZombieHP = 30, ZombieDamage = 12, TotalSpawn = 45 }),
	table.freeze({ ZombieHP = 35, ZombieDamage = 13, TotalSpawn = 50 }),
	table.freeze({ ZombieHP = 40, ZombieDamage = 14, TotalSpawn = 55 }),
	table.freeze({ ZombieHP = 50, ZombieDamage = 15, TotalSpawn = 60 }),
})

local function validateWave(wave: number)
	assert(type(wave) == "number" and wave >= 1 and wave % 1 == 0, "Wave number must be a positive integer")
end

function HordeConfig.GetZombieHP(wave: number): number
	validateWave(wave)
	local fixed = WAVE_BALANCE[wave]
	if fixed then
		return fixed.ZombieHP
	end
	return math.round(50 * 1.10 ^ (wave - 10))
end

function HordeConfig.GetZombieDamage(wave: number): number
	validateWave(wave)
	local fixed = WAVE_BALANCE[wave]
	if fixed then
		return fixed.ZombieDamage
	end
	return 15 + math.floor((wave - 10) / 3)
end

function HordeConfig.GetTotalSpawn(wave: number): number
	validateWave(wave)
	local fixed = WAVE_BALANCE[wave]
	if fixed then
		return fixed.TotalSpawn
	end
	return 60 + (wave - 10) * 5
end

function HordeConfig.CanSpawn(activeCount: number): boolean
	return activeCount < HordeConfig.MaxAliveZombies
end

return table.freeze(HordeConfig)
