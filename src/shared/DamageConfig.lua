--!strict

local DamageConfig = {
	PlayerMaxHP = 100,
	DefaultZombieHP = 10,
	ZombieHealthBarLifetime = 1.5,
	DamageNumberLifetime = 0.8,
}

function DamageConfig.Validate(): boolean
	assert(DamageConfig.PlayerMaxHP == 100)
	assert(DamageConfig.DefaultZombieHP > 0)
	assert(DamageConfig.ZombieHealthBarLifetime == 1.5)
	assert(DamageConfig.DamageNumberLifetime >= 0.5 and DamageConfig.DamageNumberLifetime <= 1.5)
	return true
end

return table.freeze(DamageConfig)
