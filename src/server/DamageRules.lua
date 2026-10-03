--!strict

local DamageRules = {}

export type HealthState = {
	Lifecycle: string,
	CurrentHP: number,
	MaxHP: number,
}

export type Result = {
	AttackDamage: number,
	ActualHPLoss: number,
	BeforeHP: number,
	AfterHP: number,
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
	local beforeHP = state.CurrentHP
	local afterHP = math.max(0, beforeHP - appliedDamage)
	local actualHPLoss = beforeHP - afterHP
	state.CurrentHP = afterHP
	local lethal = afterHP <= 0
	if lethal then
		state.CurrentHP = 0
		state.Lifecycle = "DEFEATED"
	end
	return {
		AttackDamage = appliedDamage,
		ActualHPLoss = actualHPLoss,
		BeforeHP = beforeHP,
		AfterHP = afterHP,
		MaxHP = state.MaxHP,
		Lethal = lethal,
	}
end

return DamageRules
