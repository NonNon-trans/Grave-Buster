--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DamageConfig = require(ReplicatedStorage.Shared.DamageConfig)
local RunRules = require(script.Parent.RunRules)

local PlayerHealthService = {}
local started = false
local playerConnections = {}
local deathConnections = {}
local nextZombieDamageAt = {}
local runCoordinator = nil
local PROTECTED_ATTRIBUTE = "RespawnProtected"

local function setProtection(player: Player, character: Model)
	local expiresAt = os.clock() + DamageConfig.RespawnProtectionDuration
	player:SetAttribute(PROTECTED_ATTRIBUTE, true)
	player:SetAttribute("RespawnProtectionUntil", expiresAt)
	task.delay(DamageConfig.RespawnProtectionDuration, function()
		if player.Character == character and player:GetAttribute("RespawnProtectionUntil") == expiresAt then
			player:SetAttribute(PROTECTED_ATTRIBUTE, false)
			player:SetAttribute("RespawnProtectionUntil", 0)
		end
	end)
end

local function configureCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") or player.Character ~= character then
		return
	end
	local oldDeathConnection = deathConnections[player]
	if oldDeathConnection then
		oldDeathConnection:Disconnect()
	end
	player:SetAttribute("MaxHP", DamageConfig.PlayerMaxHP)
	humanoid.MaxHealth = DamageConfig.PlayerMaxHP
	humanoid.Health = DamageConfig.PlayerMaxHP
	nextZombieDamageAt[player] = nil
	setProtection(player, character)
	deathConnections[player] = humanoid.Died:Connect(function()
		if player.Character == character then
			player:SetAttribute(PROTECTED_ATTRIBUTE, false)
			player:SetAttribute("RespawnProtectionUntil", 0)
			runCoordinator.NotifyPlayerUnavailable(player)
		end
	end)
	runCoordinator.NotifyPlayerAvailable(player)
end

local function initializePlayer(player: Player)
	if playerConnections[player] then
		return
	end
	playerConnections[player] = player.CharacterAdded:Connect(function(character)
		task.spawn(configureCharacter, player, character)
	end)
	if player.Character then
		task.spawn(configureCharacter, player, player.Character)
	end
end

function PlayerHealthService.Start(coordinator)
	if started then
		return
	end
	started = true
	runCoordinator = assert(coordinator, "WaveService is required")
	DamageConfig.Validate()
	Players.RespawnTime = DamageConfig.RespawnDelay
	for _, player in Players:GetPlayers() do
		initializePlayer(player)
	end
	Players.PlayerAdded:Connect(initializePlayer)
	Players.PlayerRemoving:Connect(function(player)
		local connection = playerConnections[player]
		if connection then
			connection:Disconnect()
			playerConnections[player] = nil
		end
		local deathConnection = deathConnections[player]
		if deathConnection then
			deathConnection:Disconnect()
			deathConnections[player] = nil
		end
		nextZombieDamageAt[player] = nil
		runCoordinator.NotifyPlayerUnavailable(player)
	end)
end

function PlayerHealthService.EndProtection(player: Player)
	if player:GetAttribute(PROTECTED_ATTRIBUTE) then
		player:SetAttribute(PROTECTED_ATTRIBUTE, false)
		player:SetAttribute("RespawnProtectionUntil", 0)
	end
end

function PlayerHealthService.IsProtected(player: Player): boolean
	if not player:GetAttribute(PROTECTED_ATTRIBUTE) then
		return false
	end
	local expiresAt = player:GetAttribute("RespawnProtectionUntil")
	if type(expiresAt) == "number" and os.clock() >= expiresAt then
		PlayerHealthService.EndProtection(player)
		return false
	end
	return true
end

function PlayerHealthService.DamagePlayer(player: Player, damage: number): boolean
	if player.Parent ~= Players then
		return false
	end
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not humanoid or humanoid.Health <= 0 then
		return false
	end
	local now = os.clock()
	local nextDamageAt = nextZombieDamageAt[player] or 0
	if not RunRules.CanReceiveZombieDamage(now, nextDamageAt, PlayerHealthService.IsProtected(player)) then
		return false
	end
	local afterHP = RunRules.ApplyPlayerDamage(
		humanoid.Health,
		humanoid.MaxHealth,
		damage,
		PlayerHealthService.IsProtected(player)
	)
	if afterHP == nil then
		return false
	end
	local beforeHP = humanoid.Health
	humanoid:TakeDamage(damage)
	if humanoid.Health >= beforeHP then
		return false
	end
	nextZombieDamageAt[player] = now + DamageConfig.PlayerHitInvulnerabilityDuration
	return true
end

return PlayerHealthService
