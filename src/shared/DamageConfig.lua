--!strict

local DamageConfig = {
	PlayerMaxHP = 100,
	ZombieAttackInterval = 1.0,
	ZombieAttackRange = 5.5,
	RespawnDelay = 2.5,
	RespawnProtectionDuration = 2,
	ZombieHealthBarLifetime = 1.5,
	DamageNumberLifetime = 0.8,
}

function DamageConfig.Validate(): boolean
	assert(DamageConfig.PlayerMaxHP == 100)
	assert(DamageConfig.ZombieAttackInterval == 1.0)
	assert(DamageConfig.ZombieAttackRange > 0)
	assert(DamageConfig.RespawnDelay >= 2 and DamageConfig.RespawnDelay <= 3)
	assert(DamageConfig.RespawnProtectionDuration == 2)
	assert(DamageConfig.ZombieHealthBarLifetime == 1.5)
	assert(DamageConfig.DamageNumberLifetime >= 0.5 and DamageConfig.DamageNumberLifetime <= 1.5)
	return true
end

return table.freeze(DamageConfig)
