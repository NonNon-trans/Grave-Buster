--!strict

local DamageRules = require("../src/server/DamageRules")
local WeaponConfig = require("../src/shared/WeaponConfig")
local DamageConfig = require("../src/shared/DamageConfig")
local KillCounter = require("../src/server/KillCounter")

assert(WeaponConfig.Validate())
assert(DamageConfig.Validate())
assert(DamageConfig.PlayerMaxHP == 100)

local function hit(currentHP: number, maxHP: number, weapon: string)
	local state = { Lifecycle = "ACTIVE", CurrentHP = currentHP, MaxHP = maxHP }
	local damage = assert(WeaponConfig.Get(weapon)).BaseDamage
	return state, DamageRules.Apply(state, damage)
end

local hp10, batLethal = hit(10, 10, "BASEBALL_BAT")
assert(batLethal and batLethal.Lethal and hp10.Lifecycle == "DEFEATED")
assert(batLethal.CurrentHP == 0 and batLethal.Damage == 10)

local hp15, batNonlethal = hit(15, 15, "BASEBALL_BAT")
assert(batNonlethal and not batNonlethal.Lethal)
assert(batNonlethal.CurrentHP == 5 and hp15.Lifecycle == "ACTIVE")
local followupLethal = DamageRules.Apply(hp15, 10)
assert(followupLethal and followupLethal.Lethal and followupLethal.Damage == 10)
assert(hp15.Lifecycle == "DEFEATED" and hp15.CurrentHP == 0)
assert(DamageRules.Apply(hp15, 10) == nil) -- lethal transition is single-use

local _, panLethal = hit(15, 15, "FRYING_PAN")
assert(panLethal and panLethal.Lethal and panLethal.Damage == 15)

local killCounter = KillCounter.new()
local player = {}
assert(killCounter:Ensure(player) == 0)
if batNonlethal.Lethal then killCounter:Add(player, 1) end
assert(killCounter:Get(player) == 0)
if followupLethal.Lethal then killCounter:Add(player, 1) end
assert(killCounter:Get(player) == 1)
if DamageRules.Apply(hp15, 10) then killCounter:Add(player, 1) end
assert(killCounter:Get(player) == 1)

local first, second = { Lifecycle = "ACTIVE", CurrentHP = 15, MaxHP = 15 },
	{ Lifecycle = "ACTIVE", CurrentHP = 25, MaxHP = 25 }
local firstResult = DamageRules.Apply(first, 10)
local secondResult = DamageRules.Apply(second, 10)
assert(firstResult and firstResult.CurrentHP == 5 and not firstResult.Lethal)
assert(secondResult and secondResult.CurrentHP == 15 and not secondResult.Lethal)
assert(first.Lifecycle == "ACTIVE" and second.Lifecycle == "ACTIVE")

assert(DamageRules.Apply({ Lifecycle = "ACTIVE", CurrentHP = 10, MaxHP = 10 }, 0) == nil)
assert(DamageRules.Apply({ Lifecycle = "RELEASED", CurrentHP = 10, MaxHP = 10 }, 10) == nil)

print("PASS DamageRules: lethal/non-lethal damage, kill gating, idempotence, and independent targets")
