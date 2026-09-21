--!strict

local WeaponConfig = {}

WeaponConfig.DefaultWeapon = "BASEBALL_BAT"
WeaponConfig.Order = { "BASEBALL_BAT", "FRYING_PAN", "GIANT_HAMMER", "BLOWER", "THUNDER_ROD" }

WeaponConfig.Weapons = {
	BASEBALL_BAT = {
		DisplayName = "BASEBALL BAT", IconGlyph = "BAT", Interval = 0.34, Shape = "Box", Range = 10, Width = 8, Height = 7,
		MaxTargets = 6, HorizontalKnockback = 68, VerticalKnockback = 30, Spin = 7,
		PresentationLifetime = 2.0,
	},
	FRYING_PAN = {
		DisplayName = "FRYING PAN", IconGlyph = "PAN", Interval = 0.38, Shape = "Box", Range = 9, Width = 13, Height = 7,
		MaxTargets = 8, HorizontalKnockback = 60, VerticalKnockback = 24, Spin = 12,
		PresentationLifetime = 2.0,
	},
	GIANT_HAMMER = {
		DisplayName = "GIANT HAMMER", IconGlyph = "HAM", Interval = 0.55, Shape = "Radius", Range = 9, Width = 15, Height = 8,
		MaxTargets = 10, HorizontalKnockback = 74, VerticalKnockback = 48, Spin = 8,
		PresentationLifetime = 2.4,
	},
	BLOWER = {
		DisplayName = "BLOWER", IconGlyph = "WND", Interval = 0.28, Shape = "Cone", Range = 17, Width = 16, Height = 8,
		MaxTargets = 12, HorizontalKnockback = 80, VerticalKnockback = 18, Spin = 4,
		PresentationLifetime = 1.8, MinForwardDot = 0.45,
	},
	THUNDER_ROD = {
		DisplayName = "THUNDER ROD", IconGlyph = "ZAP", Interval = 0.42, Shape = "Chain", Range = 11, Width = 8, Height = 8,
		MaxTargets = 8, HorizontalKnockback = 62, VerticalKnockback = 34, Spin = 9,
		PresentationLifetime = 2.1, ChainRadius = 11,
	},
}

function WeaponConfig.Get(name: unknown)
	if type(name) ~= "string" then
		return nil
	end
	return WeaponConfig.Weapons[name]
end

function WeaponConfig.IsValid(name: unknown): boolean
	return WeaponConfig.Get(name) ~= nil
end

function WeaponConfig.Validate(): boolean
	for _, name in WeaponConfig.Order do
		local weapon = WeaponConfig.Weapons[name]
		assert(weapon, `Missing weapon config: {name}`)
		assert(weapon.Interval >= 0.2 and weapon.Interval <= 0.8)
		assert(weapon.Range > 0 and weapon.Width > 0 and weapon.Height > 0)
		assert(weapon.MaxTargets >= 2 and weapon.MaxTargets <= 12)
		assert(weapon.HorizontalKnockback > 0 and weapon.HorizontalKnockback <= 100)
		assert(weapon.VerticalKnockback >= 0 and weapon.VerticalKnockback <= 60)
		assert(weapon.PresentationLifetime >= 1 and weapon.PresentationLifetime <= 3)
	end
	return true
end

return table.freeze(WeaponConfig)
