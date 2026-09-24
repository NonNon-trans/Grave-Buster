--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DamageConfig = require(ReplicatedStorage.Shared.DamageConfig)

local PlayerHealthService = {}
local started = false
local connections = {}

local function configureCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") or player.Character ~= character then
		return
	end
	player:SetAttribute("MaxHP", DamageConfig.PlayerMaxHP)
	humanoid.MaxHealth = DamageConfig.PlayerMaxHP
	humanoid.Health = DamageConfig.PlayerMaxHP
end

function PlayerHealthService.Start()
	if started then
		return
	end
	started = true
	DamageConfig.Validate()
	local function initialize(player: Player)
		if connections[player] then
			return
		end
		connections[player] = player.CharacterAdded:Connect(function(character)
			task.spawn(configureCharacter, player, character)
		end)
		if player.Character then
			task.spawn(configureCharacter, player, player.Character)
		end
	end
	for _, player in Players:GetPlayers() do
		initialize(player)
	end
	Players.PlayerAdded:Connect(initialize)
	Players.PlayerRemoving:Connect(function(player)
		local connection = connections[player]
		if connection then
			connection:Disconnect()
			connections[player] = nil
		end
	end)
end

return PlayerHealthService
