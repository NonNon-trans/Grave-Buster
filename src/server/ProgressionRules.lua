--!strict

local ProgressionRules = {}

export type State = {
	Level: number,
	XP: number,
	Coins: number,
	BestWave: number,
	OwnedWeapons: { string },
	EquippedWeapon: string,
}

export type AwardResult = {
	OldLevel: number,
	Level: number,
	XP: number,
	RequiredXP: number,
	XPGranted: number,
	LevelsGained: number,
	DamageIncreasePercent: number,
	CoinsGranted: number,
}

local INITIAL_LEVEL = 1
local INITIAL_XP = 0
local BASE_REQUIRED_XP = 100
local REQUIRED_XP_PER_LEVEL = 50
local BASE_ZOMBIE_XP = 5
local XP_WAVE_DIVISOR = 2
local DAMAGE_INCREASE_PER_LEVEL = 0.05
local INITIAL_COINS = 0

function ProgressionRules.NewState(): State
	return {
		Level = INITIAL_LEVEL,
		XP = INITIAL_XP,
		Coins = INITIAL_COINS,
		BestWave = 1,
		OwnedWeapons = { "BASEBALL_BAT" },
		EquippedWeapon = "BASEBALL_BAT",
	}
end

function ProgressionRules.RequiredXP(level: number): number
	assert(type(level) == "number" and level >= INITIAL_LEVEL and level % 1 == 0)
	return BASE_REQUIRED_XP + (level - 1) * REQUIRED_XP_PER_LEVEL
end

function ProgressionRules.DamageMultiplier(level: number): number
	assert(type(level) == "number" and level >= INITIAL_LEVEL and level % 1 == 0)
	return 1 + DAMAGE_INCREASE_PER_LEVEL * (level - 1)
end

function ProgressionRules.FinalAttackDamage(baseDamage: number, level: number): number
	assert(type(baseDamage) == "number" and baseDamage > 0)
	return math.round(baseDamage * ProgressionRules.DamageMultiplier(level))
end

function ProgressionRules.ZombieXPReward(wave: number): number
	local safeWave = math.max(1, math.floor(wave))
	return BASE_ZOMBIE_XP + math.floor(safeWave / XP_WAVE_DIVISOR)
end

function ProgressionRules.ZombieCoinReward(wave: number): number
	local safeWave = math.max(1, math.floor(wave))
	return 1 + math.floor(safeWave / 3)
end

function ProgressionRules.WaveClearBonus(wave: number): number
	assert(type(wave) == "number" and wave >= 1 and wave % 1 == 0)
	return wave * 10
end

function ProgressionRules.TrySpendCoins(state: State, amount: number): boolean
	if type(amount) ~= "number" or amount < 0 or amount % 1 ~= 0 or state.Coins < amount then
		return false
	end
	state.Coins -= amount
	return true
end

function ProgressionRules.AwardXP(state: State, xpAmount: number): AwardResult
	assert(type(xpAmount) == "number" and xpAmount >= 0 and xpAmount % 1 == 0)
	local oldLevel = state.Level
	state.XP += xpAmount
	while state.XP >= ProgressionRules.RequiredXP(state.Level) do
		state.XP -= ProgressionRules.RequiredXP(state.Level)
		state.Level += 1
	end
	local levelsGained = state.Level - oldLevel
	return {
		OldLevel = oldLevel,
		Level = state.Level,
		XP = state.XP,
		RequiredXP = ProgressionRules.RequiredXP(state.Level),
		XPGranted = xpAmount,
		LevelsGained = levelsGained,
		DamageIncreasePercent = levelsGained * DAMAGE_INCREASE_PER_LEVEL * 100,
		CoinsGranted = 0,
	}
end

function ProgressionRules.AwardZombieDefeats(state: State, wave: number, defeatCount: number): AwardResult
	assert(type(defeatCount) == "number" and defeatCount >= 0 and defeatCount % 1 == 0)
	return ProgressionRules.AwardZombieDefeatsByWave(state, { [wave] = defeatCount })
end

function ProgressionRules.AwardZombieDefeatsByWave(
	state: State,
	defeatsByWave: { [number]: number }
): AwardResult
	local totalXP = 0
	local totalCoins = 0
	for wave, defeatCount in defeatsByWave do
		assert(type(wave) == "number" and wave >= 1 and wave % 1 == 0)
		assert(type(defeatCount) == "number" and defeatCount >= 0 and defeatCount % 1 == 0)
		totalXP += ProgressionRules.ZombieXPReward(wave) * defeatCount
		totalCoins += ProgressionRules.ZombieCoinReward(wave) * defeatCount
	end
	local result = ProgressionRules.AwardXP(state, totalXP)
	state.Coins += totalCoins
	result.CoinsGranted = totalCoins
	return result
end

function ProgressionRules.AwardWaveClearBonus(state: State, wave: number): number
	local amount = ProgressionRules.WaveClearBonus(wave)
	state.Coins += amount
	return amount
end

return ProgressionRules
