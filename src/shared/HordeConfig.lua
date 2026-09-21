--!strict

local HordeConfig = {
	InitialDelay = 3,
	Intermission = 2.5,
	SpawnInterval = 0.65,
	BaseWaveCount = 6,
	WaveCountIncrement = 3,
	MaxWaveCount = 24,
	ActiveZombieCap = 28,
	ZombieLifetime = 30,
	ZombieWalkSpeed = 8,
	AIUpdateInterval = 0.25,
	TargetRefreshInterval = 0.75,
	NoTargetPollInterval = 0.5,
	ApproachRadius = 5.5,
	StopDistance = 2.5,
}

function HordeConfig.GetWaveSpawnCount(wave: number): number
	assert(wave >= 1, "Wave number must be at least 1")
	return math.min(
		HordeConfig.BaseWaveCount + (wave - 1) * HordeConfig.WaveCountIncrement,
		HordeConfig.MaxWaveCount
	)
end

function HordeConfig.CanSpawn(activeCount: number): boolean
	return activeCount < HordeConfig.ActiveZombieCap
end

function HordeConfig.IsExpired(spawnedAt: number, now: number): boolean
	return now - spawnedAt >= HordeConfig.ZombieLifetime
end

return table.freeze(HordeConfig)
