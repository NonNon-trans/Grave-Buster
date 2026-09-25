--!strict

local ProgressionRules = require("../src/server/ProgressionRules")
local DamageRules = require("../src/server/DamageRules")
local WeaponConfig = require("../src/shared/WeaponConfig")
local ActiveZombieRegistry = require("../src/server/ActiveZombieRegistry")

assert(ProgressionRules.RequiredXP(1) == 100)
assert(ProgressionRules.RequiredXP(2) == 150)
assert(ProgressionRules.RequiredXP(3) == 200)
assert(ProgressionRules.RequiredXP(4) == 250)
assert(ProgressionRules.RequiredXP(5) == 300)
assert(ProgressionRules.RequiredXP(6) == 350)

assert(ProgressionRules.FinalAttackDamage(10, 1) == 10)
assert(ProgressionRules.FinalAttackDamage(10, 2) == 11)
assert(ProgressionRules.FinalAttackDamage(10, 3) == 11)
assert(ProgressionRules.FinalAttackDamage(25, 5) == 30)
assert(ProgressionRules.FinalAttackDamage(15, 2) == 16)

assert(ProgressionRules.ZombieXPReward(1) == 5)
assert(ProgressionRules.ZombieXPReward(2) == 6)
assert(ProgressionRules.ZombieXPReward(3) == 6)
assert(ProgressionRules.ZombieXPReward(4) == 7)
assert(ProgressionRules.ZombieXPReward(10) == 10)
assert(ProgressionRules.ZombieCoinReward(1) == 1)
assert(ProgressionRules.ZombieCoinReward(2) == 1)
assert(ProgressionRules.ZombieCoinReward(3) == 2)
assert(ProgressionRules.ZombieCoinReward(6) == 3)
assert(ProgressionRules.ZombieCoinReward(9) == 4)
assert(ProgressionRules.ZombieCoinReward(12) == 5)
assert(ProgressionRules.WaveClearBonus(1) == 10)
assert(ProgressionRules.WaveClearBonus(5) == 50)

local overflow = { Level = 1, XP = 90 }
local overflowAward = ProgressionRules.AwardXP(overflow, 30)
assert(overflowAward.Level == 2 and overflowAward.XP == 20)
assert(overflowAward.RequiredXP == 150 and overflowAward.LevelsGained == 1)

local multiple = ProgressionRules.NewState()
local multiAward = ProgressionRules.AwardXP(multiple, 1123)
assert(multiAward.OldLevel == 1 and multiAward.Level == 6)
assert(multiAward.XP == 123 and multiAward.RequiredXP == 350)
assert(multiAward.LevelsGained == 5 and multiAward.DamageIncreasePercent == 25)

local nonlethal = ProgressionRules.NewState()
local noDefeatAward = ProgressionRules.AwardZombieDefeats(nonlethal, 1, 0)
assert(noDefeatAward.XPGranted == 0 and nonlethal.Level == 1 and nonlethal.XP == 0)

local lethalProgression = ProgressionRules.NewState()
local zombieHealth = { Lifecycle = "ACTIVE", CurrentHP = 15, MaxHP = 15 }
local zombie = {}
local registry = ActiveZombieRegistry.new()
registry:Add(zombie, zombieHealth)
local killRewardCount = 0
local lethalFeedbackCount = 0
local function applyHit(damage: number)
	local hit = DamageRules.Apply(zombieHealth, damage)
	if hit and hit.Lethal then
		local released = registry:Release(zombie)
		if released then
			ProgressionRules.AwardZombieDefeatsByWave(lethalProgression, { [1] = 1 })
			killRewardCount += 1
			lethalFeedbackCount += 1
		end
	end
	return hit
end
local firstHit = applyHit(10)
assert(firstHit and not firstHit.Lethal and lethalProgression.XP == 0 and lethalProgression.Coins == 0)
local secondHit = applyHit(10)
assert(secondHit and secondHit.Lethal and lethalProgression.XP == 5 and lethalProgression.Coins == 1)
assert(applyHit(10) == nil)
assert(registry:Release(zombie) == nil)
assert(killRewardCount == 1 and lethalFeedbackCount == 1 and lethalProgression.Coins == 1)

local multiTargetProgression = ProgressionRules.NewState()
local multiTargetReward = ProgressionRules.AwardZombieDefeats(multiTargetProgression, 4, 3)
assert(multiTargetReward.XPGranted == 21 and multiTargetProgression.XP == 21)
assert(multiTargetReward.CoinsGranted == 6 and multiTargetProgression.Coins == 6)

local waveOwnedRewards = ProgressionRules.NewState()
local ownershipReward = ProgressionRules.AwardZombieDefeatsByWave(waveOwnedRewards, {
	[1] = 1,
	[2] = 2,
})
assert(ownershipReward.XPGranted == 17, "XP uses each defeated Zombie's immutable spawn wave")
assert(ownershipReward.CoinsGranted == 3 and waveOwnedRewards.Coins == 3)

local waveOneClear = ProgressionRules.NewState()
local waveOneKills = ProgressionRules.AwardZombieDefeatsByWave(waveOneClear, { [1] = 15 })
local waveOneBonus = ProgressionRules.AwardWaveClearBonus(waveOneClear, 1)
assert(waveOneKills.CoinsGranted == 15 and waveOneBonus == 10 and waveOneClear.Coins == 25)
local waveFiveClear = ProgressionRules.NewState()
assert(ProgressionRules.AwardWaveClearBonus(waveFiveClear, 5) == 50)
assert(waveFiveClear.Coins == 50)

local nextAttackState = { Level = 1, XP = 95, Coins = 0 }
assert(ProgressionRules.FinalAttackDamage(10, nextAttackState.Level) == 10)
ProgressionRules.AwardZombieDefeats(nextAttackState, 1, 1)
assert(nextAttackState.Level == 2)
assert(ProgressionRules.FinalAttackDamage(10, nextAttackState.Level) == 11)

local levelFiveHammer = ProgressionRules.FinalAttackDamage(
	assert(WeaponConfig.Get("GIANT_HAMMER")).BaseDamage,
	5
)
local overkill = DamageRules.Apply(
	{ Lifecycle = "ACTIVE", CurrentHP = 10, MaxHP = 10 },
	levelFiveHammer
)
assert(overkill and overkill.Lethal and overkill.AfterHP == 0)
assert(overkill.AttackDamage == 30 and overkill.ActualHPLoss == 10)

print("PASS ProgressionRules: XP thresholds/overflow/rewards, wave-owned rewards, level damage, lethal gating, and overkill")
