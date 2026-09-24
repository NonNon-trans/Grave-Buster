--!strict

local WeaponConfig = require("../src/shared/WeaponConfig")

assert(WeaponConfig.Validate())
assert(#WeaponConfig.Order == 5)
assert(WeaponConfig.DefaultWeapon == WeaponConfig.Order[1])
local expectedDamage = { 10, 15, 25, 18, 30 }
for index, name in WeaponConfig.Order do
	assert(WeaponConfig.IsValid(name))
	local config = assert(WeaponConfig.Get(name))
	assert(config.MaxTargets >= 2)
	assert(config.BaseDamage == expectedDamage[index])
	assert(type(config.IconGlyph) == "string" and #config.IconGlyph > 0)
end
assert(not WeaponConfig.IsValid("NOT_A_WEAPON"))
assert(not WeaponConfig.IsValid(42))

print("PASS WeaponConfig: weapon identity preserved and v0.2 base damage is authoritative")
