--!strict

local ProgressionSessionStore = {}
ProgressionSessionStore.__index = ProgressionSessionStore

function ProgressionSessionStore.new(createState)
	return setmetatable({ Sessions = {}, HighestBonusedWave = {}, CreateState = createState }, ProgressionSessionStore)
end

function ProgressionSessionStore:GetOrCreate(player: Player)
	local state = self.Sessions[player]
	if not state then
		state = self.CreateState()
		self.Sessions[player] = state
		self.HighestBonusedWave[player] = 0
	end
	return state
end

function ProgressionSessionStore:ClaimWaveBonus(player: Player, wave: number): boolean
	self:GetOrCreate(player)
	local highestWave = self.HighestBonusedWave[player]
	if wave <= highestWave then
		return false
	end
	self.HighestBonusedWave[player] = wave
	return true
end

function ProgressionSessionStore:Get(player: Player)
	return self.Sessions[player]
end

function ProgressionSessionStore:Remove(player: Player)
	self.Sessions[player] = nil
	self.HighestBonusedWave[player] = nil
end

return ProgressionSessionStore
