--!nonstrict

local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WeaponConfig = require(ReplicatedStorage.Shared.WeaponConfig)
local FeedbackConfig = require(ReplicatedStorage.Shared.FeedbackConfig)
local CombatRules = require(script.Parent.CombatRules)
local DamageConfig = require(ReplicatedStorage.Shared.DamageConfig)
local KillCounter = require(script.Parent.KillCounter)

local CombatService = {}
local REMOTE_FOLDER_NAME = "CombatRemotes"
local ATTACK_REMOTE_NAME = "AttackRequest"
local EQUIP_REMOTE_NAME = "EquipRequest"
local FEEDBACK_REMOTE_NAME = "CombatFeedback"
local DAMAGE_REMOTE_NAME = "ZombieDamageFeedback"
local DEFEATED_GROUP = "DefeatedZombie"
local KILL_ATTRIBUTE = "SessionKills"

local started = false
local zombieService = nil
local shopService = nil
local progressionService = nil
local playerHealthService = nil
local lastAttackAt = {}
local progressionReadyConnections = {}
local killCounter = KillCounter.new()
local feedbackRemote = nil
local damageRemote = nil

local function ensureRemote(folder: Folder, name: string): RemoteEvent
	local existing = folder:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = folder
	return remote
end

local function ensureRemotes(): (RemoteEvent, RemoteEvent, RemoteEvent, RemoteEvent)
	local folder = ReplicatedStorage:FindFirstChild(REMOTE_FOLDER_NAME)
	if folder and not folder:IsA("Folder") then
		folder:Destroy()
		folder = nil
	end
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = REMOTE_FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end
	return ensureRemote(folder, ATTACK_REMOTE_NAME),
		ensureRemote(folder, EQUIP_REMOTE_NAME),
		ensureRemote(folder, FEEDBACK_REMOTE_NAME),
		ensureRemote(folder, DAMAGE_REMOTE_NAME)
end

local function getCharacterRoot(player: Player): (Model?, BasePart?)
	local character = player.Character
	if not character or character.Parent ~= Workspace then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil, nil
	end
	return character, root
end

local function getZombieModel(part: BasePart, container: Folder): Model?
	local current = part.Parent
	while current and current ~= container do
		if current:IsA("Model") and current.Parent == container then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function makeOverlapParams(container: Folder): OverlapParams
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { container }
	params.MaxParts = 200
	return params
end

local function collectModels(parts: { BasePart }, container: Folder): { Model }
	local models = {}
	local seen = {}
	for _, part in parts do
		local model = getZombieModel(part, container)
		if model and not seen[model] and zombieService.IsActive(model) then
			seen[model] = true
			table.insert(models, model)
		end
	end
	return models
end

local function sortByDistance(models: { Model }, origin: Vector3)
	table.sort(models, function(a, b)
		local aRoot = zombieService.GetRoot(a)
		local bRoot = zombieService.GetRoot(b)
		local aDistance = if aRoot then (aRoot.Position - origin).Magnitude else math.huge
		local bDistance = if bRoot then (bRoot.Position - origin).Magnitude else math.huge
		return aDistance < bDistance
	end)
end

local function queryForwardBox(root: BasePart, config, container: Folder): { Model }
	local center = root.CFrame * CFrame.new(0, 0, -(config.Range * 0.5 + 2))
	local parts = Workspace:GetPartBoundsInBox(
		center,
		Vector3.new(config.Width, config.Height, config.Range),
		makeOverlapParams(container)
	)
	local models = collectModels(parts, container)
	if config.Shape == "Cone" then
		local filtered = {}
		for _, model in models do
			local targetRoot = zombieService.GetRoot(model)
			if targetRoot then
				local delta = targetRoot.Position - root.Position
				local horizontal = Vector3.new(delta.X, 0, delta.Z)
				if horizontal.Magnitude > 0
					and horizontal.Unit:Dot(root.CFrame.LookVector) >= config.MinForwardDot then
					table.insert(filtered, model)
				end
			end
		end
		models = filtered
	end
	sortByDistance(models, root.Position)
	return models
end

local function queryRadius(root: BasePart, config, container: Folder): { Model }
	local center = root.Position + root.CFrame.LookVector * 3
	local parts = Workspace:GetPartBoundsInRadius(center, config.Width * 0.5, makeOverlapParams(container))
	local models = collectModels(parts, container)
	sortByDistance(models, root.Position)
	return models
end

local function queryChain(root: BasePart, config, container: Folder): { Model }
	local initial = queryForwardBox(root, config, container)
	if #initial == 0 then
		return {}
	end
	local selected = { initial[1] }
	local seen = { [initial[1]] = true }
	local current = initial[1]
	while #selected < config.MaxTargets do
		local currentRoot = zombieService.GetRoot(current)
		if not currentRoot then
			break
		end
		local nearby = collectModels(
			Workspace:GetPartBoundsInRadius(currentRoot.Position, config.ChainRadius, makeOverlapParams(container)),
			container
		)
		sortByDistance(nearby, currentRoot.Position)
		local nextModel = nil
		for _, model in nearby do
			if not seen[model] then
				nextModel = model
				break
			end
		end
		if not nextModel then
			break
		end
		seen[nextModel] = true
		table.insert(selected, nextModel)
		current = nextModel
	end
	return selected
end

local function queryTargets(root: BasePart, config): { Model }
	local container = zombieService.GetContainer()
	if not container then
		return {}
	end
	if config.Shape == "Radius" then
		return queryRadius(root, config, container)
	elseif config.Shape == "Chain" then
		return queryChain(root, config, container)
	end
	return queryForwardBox(root, config, container)
end

local function getHorizontalDirection(weaponName: string, playerRoot: BasePart, targetRoot: BasePart): Vector3
	local forward = Vector3.new(playerRoot.CFrame.LookVector.X, 0, playerRoot.CFrame.LookVector.Z).Unit
	local delta = targetRoot.Position - playerRoot.Position
	local outward = Vector3.new(delta.X, 0, delta.Z)
	if outward.Magnitude < 0.01 then
		outward = forward
	else
		outward = outward.Unit
	end
	if weaponName == "FRYING_PAN" then
		local side = if delta:Dot(playerRoot.CFrame.RightVector) >= 0 then 1 else -1
		return (forward * 0.35 + playerRoot.CFrame.RightVector * side).Unit
	elseif weaponName == "GIANT_HAMMER" or weaponName == "BLOWER" or weaponName == "THUNDER_ROD" then
		return outward
	end
	return forward
end

local function defeatZombie(model: Model, playerRoot: BasePart, weaponName: string, config)
	local targetRoot = zombieService.GetRoot(model)
	if not zombieService.Release(model) then
		return nil, false
	end
	model:SetAttribute("ZombieState", "DEFEATED")
	if not targetRoot or not targetRoot.Parent then
		Debris:AddItem(model, config.PresentationLifetime)
		return nil, true
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:Move(Vector3.zero)
		humanoid.AutoRotate = false
		humanoid.PlatformStand = true
		humanoid.Health = 0
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CollisionGroup = DEFEATED_GROUP
		end
	end

	local horizontal = getHorizontalDirection(weaponName, playerRoot, targetRoot)
	local desiredVelocity = horizontal * config.HorizontalKnockback + Vector3.yAxis * config.VerticalKnockback
	if desiredVelocity.Magnitude > 115 then
		desiredVelocity = desiredVelocity.Unit * 115
	end
	targetRoot:SetNetworkOwner(nil)
	targetRoot:ApplyImpulse((desiredVelocity - targetRoot.AssemblyLinearVelocity) * targetRoot.AssemblyMass)
	targetRoot:ApplyAngularImpulse(Vector3.new(config.Spin, config.Spin * 0.5, -config.Spin) * targetRoot.AssemblyMass)
	Debris:AddItem(model, config.PresentationLifetime)
	return targetRoot, true
end

local function performAttack(player: Player)
	if not progressionService.IsReady(player) then
		return
	end
	local weaponName = player:GetAttribute("EquippedWeapon")
	local config = WeaponConfig.Get(weaponName)
	if not config or not shopService.IsOwned(player, weaponName) then
		return
	end
	local _, root = getCharacterRoot(player)
	if not root then
		return
	end
	local now = os.clock()
	if not CombatRules.CanAttack(lastAttackAt[player], now, config.Interval) then
		return
	end
	lastAttackAt[player] = now
	playerHealthService.EndProtection(player)
	local attackDamage = progressionService.ResolveFinalAttackDamage(player, config.BaseDamage)

	local targets = queryTargets(root, config)
	local feedbackRoots = {}
	local damageResults = {}
	local effectLimit = FeedbackConfig.GetEffectCount(config.MaxTargets)
	local defeatCount = 0
	local defeatsByWave = {}
	for index = 1, math.min(#targets, config.MaxTargets) do
		local model = targets[index]
		local result = zombieService.ApplyDamage(model, attackDamage)
		if result then
			table.insert(damageResults, {
				Model = model,
				AttackDamage = result.AttackDamage,
				CurrentHP = result.AfterHP,
				MaxHP = result.MaxHP,
				Lethal = result.Lethal,
			})
			if result.Lethal then
				local spawnWave = zombieService.GetSpawnWave(model)
				local defeatedRoot, released = defeatZombie(model, root, weaponName, config)
				if released then
					defeatCount += 1
					if spawnWave then
						defeatsByWave[spawnWave] = (defeatsByWave[spawnWave] or 0) + 1
					end
					if defeatedRoot and #feedbackRoots < effectLimit then
						table.insert(feedbackRoots, defeatedRoot)
					end
				end
			end
		end
	end
	if #damageResults > 0 then
		damageRemote:FireAllClients(damageResults)
	end
	if defeatCount > 0 then
		local kills = killCounter:Add(player, defeatCount)
		player:SetAttribute(KILL_ATTRIBUTE, kills)
		progressionService.AwardZombieDefeats(player, defeatsByWave)
		feedbackRemote:FireClient(player, weaponName, feedbackRoots)
	end
end

function CombatService.Start(service, ownershipService, playerProgressionService, healthService)
	if started then
		return
	end
	started = true
	zombieService = service
	shopService = ownershipService
	progressionService = playerProgressionService
	playerHealthService = healthService
	WeaponConfig.Validate()
	FeedbackConfig.Validate()

	if not PhysicsService:IsCollisionGroupRegistered(DEFEATED_GROUP) then
		PhysicsService:RegisterCollisionGroup(DEFEATED_GROUP)
	end
	PhysicsService:CollisionGroupSetCollidable(DEFEATED_GROUP, DEFEATED_GROUP, false)
	PhysicsService:CollisionGroupSetCollidable(DEFEATED_GROUP, "Zombie", false)

	local attackRemote, equipRemote, combatFeedbackRemote, zombieDamageRemote = ensureRemotes()
	feedbackRemote = combatFeedbackRemote
	damageRemote = zombieDamageRemote
	local function initializePlayer(player: Player)
		if not progressionService.IsReady(player) then
			return
		end
		player:SetAttribute(KILL_ATTRIBUTE, killCounter:Ensure(player))
		local equipped = player:GetAttribute("EquippedWeapon")
		if not WeaponConfig.IsValid(equipped) or not shopService.IsOwned(player, equipped) then
			progressionService.SetEquippedWeapon(player, WeaponConfig.DefaultWeapon)
		end
	end
	local function bindPlayer(player: Player)
		if progressionReadyConnections[player] then
			return
		end
		initializePlayer(player)
		progressionReadyConnections[player] = player:GetAttributeChangedSignal("ProgressionReady"):Connect(function()
			initializePlayer(player)
		end)
	end
	for _, player in Players:GetPlayers() do
		bindPlayer(player)
	end
	Players.PlayerAdded:Connect(bindPlayer)
	DamageConfig.Validate()
	Players.PlayerRemoving:Connect(function(player)
		lastAttackAt[player] = nil
		killCounter:Remove(player)
		local connection = progressionReadyConnections[player]
		if connection then
			connection:Disconnect()
			progressionReadyConnections[player] = nil
		end
	end)
	attackRemote.OnServerEvent:Connect(function(player, ...)
		if select("#", ...) == 0 then
			performAttack(player)
		end
	end)
	equipRemote.OnServerEvent:Connect(function(player, requestedWeapon, ...)
		if progressionService.IsReady(player)
			and select("#", ...) == 0
			and type(requestedWeapon) == "string"
			and WeaponConfig.IsValid(requestedWeapon)
			and shopService.IsOwned(player, requestedWeapon) then
			progressionService.SetEquippedWeapon(player, requestedWeapon)
		end
	end)
end

return CombatService
