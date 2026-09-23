--!strict

local DamageRules = {}

export type HealthState = {
	Lifecycle: string,
	CurrentHP: number,
	MaxHP: number,
}

export type Result = {
	Damage: number,
	CurrentHP: number,
	MaxHP: number,
	Lethal: boolean,
}

function DamageRules.Apply(state: HealthState, damage: number): Result?
	if state.Lifecycle ~= "ACTIVE"
		or type(damage) ~= "number"
		or damage ~= damage
		or damage <= 0
		or damage == math.huge
		or state.CurrentHP <= 0
		or state.MaxHP <= 0 then
		return nil
	end

	local appliedDamage = math.floor(damage)
	if appliedDamage <= 0 then
		return nil
	end
	state.CurrentHP = math.max(state.CurrentHP - appliedDamage, 0)
	local lethal = state.CurrentHP <= 0
	if lethal then
		state.CurrentHP = 0
		state.Lifecycle = "DEFEATED"
	end
	return {
		Damage = appliedDamage,
		CurrentHP = state.CurrentHP,
		MaxHP = state.MaxHP,
		Lethal = lethal,
	}
end

return DamageRules
