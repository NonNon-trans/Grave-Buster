--!strict

local CombatRules = {}

function CombatRules.CanAttack(lastAttackAt: number?, now: number, interval: number): boolean
	return lastAttackAt == nil or now - lastAttackAt >= interval
end

function CombatRules.Deduplicate<T>(items: { T }): { T }
	local seen: { [T]: boolean } = {}
	local result = {}
	for _, item in items do
		if not seen[item] then
			seen[item] = true
			table.insert(result, item)
		end
	end
	return result
end

return CombatRules
