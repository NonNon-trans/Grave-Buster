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

local playerANextDamageAt = 0
local playerBNextDamageAt = 0
assert(RunRules.CanReceiveZombieDamage(10, playerANextDamageAt, false), "First zombie hit damages Player A")
playerANextDamageAt = 12
assert(not RunRules.CanReceiveZombieDamage(10.5, playerANextDamageAt, false), "Another zombie is blocked during hit invulnerability")
assert(not RunRules.CanReceiveZombieDamage(11.99, playerANextDamageAt, false), "Hit invulnerability lasts the full two seconds")
assert(RunRules.CanReceiveZombieDamage(12, playerANextDamageAt, false), "Damage resumes when two seconds elapse")
assert(not RunRules.CanReceiveZombieDamage(11.5, playerANextDamageAt, false), "Blocked hits do not move the original expiry")
assert(not RunRules.CanReceiveZombieDamage(10.5, playerANextDamageAt, false), "Player attacks do not alter the hit timer")
assert(not RunRules.CanReceiveZombieDamage(12, 0, true), "Respawn Protection independently blocks damage")
assert(RunRules.CanReceiveZombieDamage(10.5, playerBNextDamageAt, false), "Player A's hit timer does not affect Player B")
playerBNextDamageAt = 12.5
assert(not RunRules.CanReceiveZombieDamage(11, playerBNextDamageAt, false), "Player B has an independent hit timer")
assert(RunRules.CanReceiveZombieDamage(12, playerANextDamageAt, false), "Player B's hit timer does not affect Player A")

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

print("PASS RunRules: wave damage, attack intervals, independent hit invulnerability, protection, run reset, and BestWave")
