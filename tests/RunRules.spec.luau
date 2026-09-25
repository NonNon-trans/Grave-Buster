--!strict

local DamageConfig = require("../src/shared/DamageConfig")
local HordeConfig = require("../src/shared/HordeConfig")
local RunRules = require("../src/server/RunRules")

assert(DamageConfig.ZombieAttackInterval == 1.0)
for wave = 1, 13 do
	local zombieDamage = HordeConfig.GetZombieDamage(wave)
	assert(zombieDamage > 0)
end
assert(HordeConfig.GetZombieDamage(1) == 10)
assert(HordeConfig.GetZombieDamage(6) == 12)
assert(HordeConfig.GetZombieDamage(13) == 16)

assert(RunRules.CanZombieAttack(0, 10, true))
assert(not RunRules.CanZombieAttack(10, 9.99, true), "One zombie cannot attack more often than its interval")
assert(RunRules.CanZombieAttack(10, 10, true))
assert(not RunRules.CanZombieAttack(0, 10, false))

assert(RunRules.ApplyPlayerDamage(100, 100, 10, true) == nil, "Respawn protection blocks damage")
assert(RunRules.ApplyPlayerDamage(100, 100, 10, false) == 90)
assert(RunRules.ApplyPlayerDamage(5, 100, 10, false) == 0)
assert(RunRules.ApplyPlayerDamage(0, 100, 10, false) == nil)

assert(not RunRules.ShouldResetRun(1, false), "One dead player does not reset a multiplayer run with survivors")
assert(RunRules.ShouldResetRun(0, false), "Solo death resets the run")
assert(not RunRules.ShouldResetRun(0, true), "Death/reset duplicates cannot start a second reset")

local progression = { BestWave = 0 }
assert(RunRules.RecordBestWave(progression, 1))
assert(RunRules.RecordBestWave(progression, 12))
assert(not RunRules.RecordBestWave(progression, 1), "BestWave cannot decrease after run reset")
assert(not RunRules.RecordBestWave(progression, 12))
assert(RunRules.RecordBestWave(progression, 13))
assert(progression.BestWave == 13)

print("PASS RunRules: wave damage, per-zombie attack interval, protection, solo/multiplayer reset, and BestWave")
