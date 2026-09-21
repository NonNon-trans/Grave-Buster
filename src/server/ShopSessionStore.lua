--!strict

local ShopSessionStore = {}
ShopSessionStore.__index = ShopSessionStore

function ShopSessionStore.new(createSession)
	return setmetatable({ sessions = {}, createSession = createSession }, ShopSessionStore)
end

function ShopSessionStore:GetOrCreate(player)
	local session = self.sessions[player]
	if not session then
		session = self.createSession()
		self.sessions[player] = session
	end
	return session
end

function ShopSessionStore:Get(player)
	return self.sessions[player]
end

function ShopSessionStore:Remove(player)
	self.sessions[player] = nil
end

function ShopSessionStore:Clear()
	table.clear(self.sessions)
end

return ShopSessionStore
