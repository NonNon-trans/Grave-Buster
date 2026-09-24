--!strict

local DamageRules = require("../src/server/DamageRules")
local WeaponConfig = require("../src/shared/WeaponConfig")
local DamageConfig = require("../src/shared/DamageConfig")
local KillCounter = require("../src/server/KillCounter")
local ActiveZombieRegistry = require("../src/server/ActiveZombieRegistry")

assert(WeaponConfig.Validate())
assert(DamageConfig.Validate())
assert(DamageConfig.PlayerMaxHP == 100)

local function hit(currentHP: number, maxHP: number, weapon: string)
	local state = { Lifecycle = "ACTIVE", CurrentHP = currentHP, MaxHP = maxHP }
	local attackDamage = assert(WeaponConfig.Get(weapon)).BaseDamage
	return state, DamageRules.Apply(state, attackDamage)
end

local hp10Bat, batLethal = hit(10, 10, "BASEBALL_BAT")
assert(batLethal and batLethal.Lethal and hp10Bat.Lifecycle == "DEFEATED")
assert(batLethal.AfterHP == 0 and batLethal.ActualHPLoss == 10)
assert(batLethal.AttackDamage == 10)

local hp10Pan, panLethal = hit(10, 10, "FRYING_PAN")
assert(panLethal and panLethal.Lethal and hp10Pan.CurrentHP == 0)
assert(panLethal.BeforeHP == 10 and panLethal.AfterHP == 0)
assert(panLethal.ActualHPLoss == 10 and panLethal.AttackDamage == 15)

local hp10Hammer, hammerLethal = hit(10, 10, "GIANT_HAMMER")
assert(hammerLethal and hammerLethal.Lethal and hp10Hammer.CurrentHP == 0)
assert(hammerLethal.AttackDamage == 25 and hammerLethal.ActualHPLoss == 10)

local hp15, batNonlethal = hit(15, 15, "BASEBALL_BAT")
assert(batNonlethal and not batNonlethal.Lethal)
assert(batNonlethal.AfterHP == 5 and batNonlethal.AttackDamage == 10)
assert(batNonlethal.ActualHPLoss == 10 and hp15.Lifecycle == "ACTIVE")
local followupLethal = DamageRules.Apply(hp15, 10)
assert(followupLethal and followupLethal.Lethal and followupLethal.AttackDamage == 10)
assert(hp15.Lifecycle == "DEFEATED" and hp15.CurrentHP == 0)
assert(DamageRules.Apply(hp15, 10) == nil) -- lethal transition is single-use

local hp5Thunder, thunderLethal = hit(5, 10, "THUNDER_ROD")
assert(thunderLethal and thunderLethal.Lethal and hp5Thunder.CurrentHP == 0)
assert(thunderLethal.AttackDamage == 30 and thunderLethal.ActualHPLoss == 5)

local killCounter = KillCounter.new()
local player = {}
assert(killCounter:Ensure(player) == 0)
if batNonlethal.Lethal then killCounter:Add(player, 1) end
assert(killCounter:Get(player) == 0)
if followupLethal.Lethal then killCounter:Add(player, 1) end
assert(killCounter:Get(player) == 1)
if DamageRules.Apply(hp15, 10) then killCounter:Add(player, 1) end
assert(killCounter:Get(player) == 1)

local overkillState = { Lifecycle = "ACTIVE", CurrentHP = 10, MaxHP = 10 }
local overkillZombie = {}
local registry = ActiveZombieRegistry.new()
registry:Add(overkillZombie, overkillState)
local overkillReleaseCount = 0
local overkillLethalFeedbackCount = 0
local function applyOverkillOnce()
	local result = DamageRules.Apply(overkillState, 15)
	if result and result.Lethal then
		local released = registry:Release(overkillZombie)
		if released then
			overkillReleaseCount += 1
			killCounter:Add(player, 1)
			overkillLethalFeedbackCount += 1
		end
	end
	return result
end
local overkillResult = applyOverkillOnce()
assert(overkillResult and overkillResult.AttackDamage == 15 and overkillResult.ActualHPLoss == 10)
assert(applyOverkillOnce() == nil)
assert(killCounter:Get(player) == 2)
assert(overkillReleaseCount == 1 and overkillLethalFeedbackCount == 1)

local first, second = { Lifecycle = "ACTIVE", CurrentHP = 15, MaxHP = 15 },
	{ Lifecycle = "ACTIVE", CurrentHP = 25, MaxHP = 25 }
local firstResult = DamageRules.Apply(first, 10)
local secondResult = DamageRules.Apply(second, 10)
assert(firstResult and firstResult.AfterHP == 5 and not firstResult.Lethal)
assert(secondResult and secondResult.AfterHP == 15 and not secondResult.Lethal)
assert(first.Lifecycle == "ACTIVE" and second.Lifecycle == "ACTIVE")

assert(DamageRules.Apply({ Lifecycle = "ACTIVE", CurrentHP = 10, MaxHP = 10 }, 0) == nil)
assert(DamageRules.Apply({ Lifecycle = "RELEASED", CurrentHP = 10, MaxHP = 10 }, 10) == nil)

print("PASS DamageRules: lethal/non-lethal damage, kill gating, idempotence, and independent targets")
