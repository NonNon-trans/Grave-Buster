--!strict

local ProgressionSessionStore = {}
ProgressionSessionStore.__index = ProgressionSessionStore

function ProgressionSessionStore.new(createState)
	return setmetatable({ Sessions = {}, CreateState = createState }, ProgressionSessionStore)
end

function ProgressionSessionStore:GetOrCreate(player: Player)
	local state = self.Sessions[player]
	if not state then
		state = self.CreateState()
		self.Sessions[player] = state
	end
	return state
end

function ProgressionSessionStore:Get(player: Player)
	return self.Sessions[player]
end

function ProgressionSessionStore:Remove(player: Player)
	self.Sessions[player] = nil
end

return ProgressionSessionStore
