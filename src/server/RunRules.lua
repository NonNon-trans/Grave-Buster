--!strict

local RunRules = {}

function RunRules.CanZombieAttack(nextAttackAt: number, now: number, targetAlive: boolean): boolean
	return targetAlive and now >= nextAttackAt
end

function RunRules.CanReceiveZombieDamage(now: number, nextDamageAt: number, respawnProtected: boolean): boolean
	return not respawnProtected and now >= nextDamageAt
end

function RunRules.ApplyPlayerDamage(currentHP: number, maxHP: number, damage: number, protected: boolean): number?
	if protected or currentHP <= 0 or damage <= 0 then
		return nil
	end
	return math.max(0, math.min(maxHP, currentHP) - math.floor(damage))
end

function RunRules.ShouldResetRun(livingPlayerCount: number, resetInProgress: boolean): boolean
	return livingPlayerCount == 0 and not resetInProgress
end

function RunRules.RecordBestWave(state, wave: number): boolean
	assert(type(wave) == "number" and wave >= 1 and wave % 1 == 0)
	if wave <= state.BestWave then
		return false
	end
	state.BestWave = wave
	return true
end

return RunRules
