--!nonstrict

local ActiveZombieRegistry = {}
ActiveZombieRegistry.__index = ActiveZombieRegistry

function ActiveZombieRegistry.new()
	return setmetatable({ entries = {}, count = 0 }, ActiveZombieRegistry)
end

function ActiveZombieRegistry:Add(model, entry)
	assert(self.entries[model] == nil, "Zombie already active")
	self.entries[model] = entry
	self.count += 1
end

function ActiveZombieRegistry:Get(model)
	return self.entries[model]
end

function ActiveZombieRegistry:Contains(model): boolean
	return self.entries[model] ~= nil
end

function ActiveZombieRegistry:Release(model)
	local entry = self.entries[model]
	if entry == nil then
		return nil
	end
	self.entries[model] = nil
	self.count -= 1
	return entry
end

function ActiveZombieRegistry:Count(): number
	return self.count
end

function ActiveZombieRegistry:CountForWave(wave: number): number
	local count = 0
	for _, entry in self:Entries() do
		if entry.SpawnWave == wave and entry.Lifecycle == "ACTIVE" then
			count += 1
		end
	end
	return count
end

function ActiveZombieRegistry:Entries()
	return self.entries
end

function ActiveZombieRegistry:Clear()
	self.entries = {}
	self.count = 0
end

return ActiveZombieRegistry
