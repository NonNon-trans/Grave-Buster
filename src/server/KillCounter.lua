--!strict

local KillCounter = {}
KillCounter.__index = KillCounter

function KillCounter.new()
	return setmetatable({ counts = {} }, KillCounter)
end

function KillCounter:Ensure(player): number
	local count = self.counts[player]
	if count == nil then
		count = 0
		self.counts[player] = count
	end
	return count
end

function KillCounter:Add(player, amount: number): number
	assert(amount >= 0 and amount % 1 == 0, "Kill increment must be a non-negative integer")
	local count = self:Ensure(player) + amount
	self.counts[player] = count
	return count
end

function KillCounter:Get(player): number?
	return self.counts[player]
end

function KillCounter:Remove(player)
	self.counts[player] = nil
end

return KillCounter
