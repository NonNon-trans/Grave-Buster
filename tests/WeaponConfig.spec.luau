--!strict

local WeaponConfig = require("../src/shared/WeaponConfig")

assert(WeaponConfig.Validate())
assert(#WeaponConfig.Order == 5)
assert(WeaponConfig.DefaultWeapon == WeaponConfig.Order[1])
for _, name in WeaponConfig.Order do
	assert(WeaponConfig.IsValid(name))
	local config = assert(WeaponConfig.Get(name))
	assert(config.MaxTargets >= 2)
	assert(type(config.IconGlyph) == "string" and #config.IconGlyph > 0)
end
assert(not WeaponConfig.IsValid("NOT_A_WEAPON"))
assert(not WeaponConfig.IsValid(42))

print("PASS WeaponConfig: five distinct, bounded, multi-target weapon definitions")
