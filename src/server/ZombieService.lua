--!strict

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HordeConfig = require(ReplicatedStorage.Shared.HordeConfig)
local DamageConfig = require(ReplicatedStorage.Shared.DamageConfig)
local ActiveZombieRegistry = require(script.Parent.ActiveZombieRegistry)
local DamageRules = require(script.Parent.DamageRules)
local ZombieRules = require(script.Parent.ZombieRules)

type JointSet = {
	RightShoulder: Motor6D,
	LeftShoulder: Motor6D,
	RightHip: Motor6D,
	LeftHip: Motor6D,
}

type ZombieEntry = {
	Humanoid: Humanoid,
	Root: BasePart,
	Joints: JointSet,
	NextTargetRefresh: number,
	TargetPlayer: Player?,
	ApproachOffset: Vector3,
	AnimationPhase: number,
	MaxHP: number,
	CurrentHP: number,
	Lifecycle: string,
}

local ZombieService = {}
local ZOMBIE_CONTAINER_NAME = "Zombies"
local COLLISION_GROUP = "Zombie"
local SPAWN_EDGE = 76
local SPAWN_LANES = { -60, -44, -28, -12, 12, 28, 44, 60 }
local APPROACH_SLOTS_PER_RING = 14

local registry = ActiveZombieRegistry.new()
local container: Folder? = nil
local spawnCursor = 0
local running = false

local function createPart(
	model: Model,
	name: string,
	size: Vector3,
	color: Color3,
	canCollide: boolean,
	transparency: number?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = false
	part.CanCollide = canCollide
	part.CanTouch = false
	part.CanQuery = true
	part.Massless = name ~= "HumanoidRootPart"
	part.Transparency = transparency or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CollisionGroup = COLLISION_GROUP
	part.Parent = model
	return part
end

local function createMotor(
	parent: BasePart,
	name: string,
	part0: BasePart,
	part1: BasePart,
	c0: CFrame,
	c1: CFrame
): Motor6D
	local motor = Instance.new("Motor6D")
	motor.Name = name
	motor.Part0 = part0
	motor.Part1 = part1
	motor.C0 = c0
	motor.C1 = c1
	motor.Parent = parent
	return motor
end

local function createZombieModel(index: number): (Model, Humanoid, BasePart, JointSet)
	local model = Instance.new("Model")
	model.Name = string.format("Zombie%03d", index)

	local skin = Color3.fromRGB(93, 143, 82)
	local shirt = Color3.fromRGB(76, 55, 66)
	local pants = Color3.fromRGB(50, 55, 58)
	local root = createPart(model, "HumanoidRootPart", Vector3.new(2, 2, 1), Color3.new(0, 0, 0), false, 1)
	local torso = createPart(model, "Torso", Vector3.new(2, 2, 1), shirt, true)
	local head = createPart(model, "Head", Vector3.new(2, 1, 1), skin, false)
	local rightArm = createPart(model, "Right Arm", Vector3.new(1, 2, 1), skin, false)
	local leftArm = createPart(model, "Left Arm", Vector3.new(1, 2, 1), skin, false)
	local rightLeg = createPart(model, "Right Leg", Vector3.new(1, 2, 1), pants, false)
	local leftLeg = createPart(model, "Left Leg", Vector3.new(1, 2, 1), pants, false)

	createMotor(root, "RootJoint", root, torso, CFrame.new(), CFrame.new())
	createMotor(torso, "Neck", torso, head, CFrame.new(0, 1, 0), CFrame.new(0, -0.5, 0))
	local rightShoulder = createMotor(torso, "Right Shoulder", torso, rightArm,
		CFrame.new(1, 0.5, 0), CFrame.new(-0.5, 0.5, 0))
	local leftShoulder = createMotor(torso, "Left Shoulder", torso, leftArm,
		CFrame.new(-1, 0.5, 0), CFrame.new(0.5, 0.5, 0))
	local rightHip = createMotor(torso, "Right Hip", torso, rightLeg,
		CFrame.new(0.5, -1, 0), CFrame.new(0, 1, 0))
	local leftHip = createMotor(torso, "Left Hip", torso, leftLeg,
		CFrame.new(-0.5, -1, 0), CFrame.new(0, 1, 0))

	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "Humanoid"
	humanoid.MaxHealth = 1
	humanoid.Health = 1
	humanoid.WalkSpeed = HordeConfig.ZombieWalkSpeed
	humanoid.AutoRotate = true
	humanoid.BreakJointsOnDeath = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.Parent = model

	model.PrimaryPart = root
	return model, humanoid, root, {
		RightShoulder = rightShoulder,
		LeftShoulder = leftShoulder,
		RightHip = rightHip,
		LeftHip = leftHip,
	}
end

local function getSpawnPosition(index: number): Vector3
	local laneCount = #SPAWN_LANES
	local zeroBased = (index - 1) % (laneCount * 4)
	local side = math.floor(zeroBased / laneCount)
	local lane = SPAWN_LANES[zeroBased % laneCount + 1]
	if side == 0 then
		return Vector3.new(lane, 3, -SPAWN_EDGE)
	elseif side == 1 then
		return Vector3.new(SPAWN_EDGE, 3, lane)
	elseif side == 2 then
		return Vector3.new(-lane, 3, SPAWN_EDGE)
	end
	return Vector3.new(-SPAWN_EDGE, 3, -lane)
end

local function stopAnimation(entry: ZombieEntry)
	entry.Joints.RightShoulder.C0 = CFrame.new(1, 0.5, 0)
	entry.Joints.LeftShoulder.C0 = CFrame.new(-1, 0.5, 0)
	entry.Joints.RightHip.C0 = CFrame.new(0.5, -1, 0)
	entry.Joints.LeftHip.C0 = CFrame.new(-0.5, -1, 0)
end

local function updateAnimation(entry: ZombieEntry, now: number, moving: boolean)
	if not moving then
		stopAnimation(entry)
		return
	end
	local swing = math.sin(now * 7 + entry.AnimationPhase) * 0.45
	entry.Joints.RightShoulder.C0 = CFrame.new(1, 0.5, 0) * CFrame.Angles(swing, 0, 0)
	entry.Joints.LeftShoulder.C0 = CFrame.new(-1, 0.5, 0) * CFrame.Angles(-swing, 0, 0)
	entry.Joints.RightHip.C0 = CFrame.new(0.5, -1, 0) * CFrame.Angles(-swing, 0, 0)
	entry.Joints.LeftHip.C0 = CFrame.new(-0.5, -1, 0) * CFrame.Angles(swing, 0, 0)
end

local function releaseZombie(model: Model): boolean
	local entry = registry:Release(model)
	if not entry then
		return false
	end
	entry.Humanoid:Move(Vector3.zero)
	stopAnimation(entry)
	return true
end

local function removeZombie(model: Model)
	releaseZombie(model)
	model:Destroy()
end

local function updateZombie(model: Model, entry: ZombieEntry, now: number)
	if model.Parent ~= container or entry.Humanoid.Health <= 0 or entry.Root.Position.Y < -20 then
		removeZombie(model)
		return
	end

	local targetRoot = ZombieRules.GetValidRoot(entry.TargetPlayer, Players)
	if now >= entry.NextTargetRefresh or not targetRoot then
		entry.TargetPlayer, targetRoot = ZombieRules.FindNearestPlayer(
			Players:GetPlayers(), Players, entry.Root.Position
		)
		entry.NextTargetRefresh = now + HordeConfig.TargetRefreshInterval
	end

	if not targetRoot then
		entry.Humanoid:Move(Vector3.zero)
		updateAnimation(entry, now, false)
		return
	end

	local destination = targetRoot.Position + entry.ApproachOffset
	local delta = destination - entry.Root.Position
	local horizontalDistance = Vector3.new(delta.X, 0, delta.Z).Magnitude
	if horizontalDistance <= HordeConfig.StopDistance then
		entry.Humanoid:Move(Vector3.zero)
		updateAnimation(entry, now, false)
	else
		entry.Humanoid:MoveTo(destination)
		updateAnimation(entry, now, true)
	end
end

local function updateLoop()
	while running do
		local now = os.clock()
		for model, entry in registry:Entries() do
			updateZombie(model, entry, now)
		end
		task.wait(HordeConfig.AIUpdateInterval)
	end
end

function ZombieService.Start()
	if running then
		return
	end
	running = true
	if not PhysicsService:IsCollisionGroupRegistered(COLLISION_GROUP) then
		PhysicsService:RegisterCollisionGroup(COLLISION_GROUP)
	end
	PhysicsService:CollisionGroupSetCollidable(COLLISION_GROUP, COLLISION_GROUP, false)

	local previous = Workspace:FindFirstChild(ZOMBIE_CONTAINER_NAME)
	if previous then
		previous:Destroy()
	end
	registry:Clear()
	spawnCursor = 0
	local newContainer = Instance.new("Folder")
	newContainer.Name = ZOMBIE_CONTAINER_NAME
	newContainer.Parent = Workspace
	container = newContainer
	task.spawn(updateLoop)
end

function ZombieService.Spawn(requestedMaxHP: number?): Model?
	local maxHP, testSpawn, rejection = ZombieRules.ResolveSpawnHP(
		requestedMaxHP,
		DamageConfig.DefaultZombieHP,
		running and container ~= nil,
		registry:Count(),
		HordeConfig.ActiveZombieCap
	)
	if not maxHP then
		if testSpawn then
			local reason = if rejection == "ACTIVE_CAP"
				then string.format("active cap reached (%d/%d)", registry:Count(), HordeConfig.ActiveZombieCap)
				elseif rejection == "NOT_READY" then "ZombieService is not ready"
				else string.format("invalid MaxHP %s", tostring(requestedMaxHP))
			warn(string.format("[GB021 HP TEST] Spawn rejected: %s", reason))
		end
		return nil
	end
	spawnCursor += 1
	local position = getSpawnPosition(spawnCursor)
	local model, humanoid, root, joints = createZombieModel(spawnCursor)
	model:SetAttribute("ZombieState", "ACTIVE")
	model:SetAttribute("GB021HPTest", testSpawn)
	model:SetAttribute("MaxHP", maxHP)
	model:SetAttribute("CurrentHP", maxHP)
	humanoid.MaxHealth = maxHP
	humanoid.Health = maxHP
	model:PivotTo(CFrame.lookAt(position, Vector3.new(0, position.Y, 0)))
	model.Parent = container
	root:SetNetworkOwner(nil)
	if testSpawn then
		local marker = Instance.new("BillboardGui")
		marker.Name = "GB021HPTestMarker"
		marker.Adornee = model:FindFirstChild("Head") or root
		marker.Size = UDim2.fromOffset(106, 24)
		marker.StudsOffsetWorldSpace = Vector3.new(0, 4.1, 0)
		marker.AlwaysOnTop = true
		marker.MaxDistance = 180
		marker.Parent = model
		local label = Instance.new("TextLabel")
		label.Name = "MarkerText"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = Color3.fromRGB(118, 47, 28)
		label.BackgroundTransparency = 0.1
		label.BorderSizePixel = 0
		label.Font = Enum.Font.GothamBold
		label.Text = string.format("TEST HP %d", maxHP)
		label.TextColor3 = Color3.fromRGB(255, 242, 220)
		label.TextScaled = true
		label.Parent = marker
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = label
	end

	local approachSlot = (spawnCursor - 1) % HordeConfig.ActiveZombieCap
	local approachRing = math.floor(approachSlot / APPROACH_SLOTS_PER_RING)
	local ringSlot = approachSlot % APPROACH_SLOTS_PER_RING
	local angle = (ringSlot + approachRing * 0.5) / APPROACH_SLOTS_PER_RING * math.pi * 2
	local approachRadius = HordeConfig.ApproachRadius + approachRing * 2.5
	registry:Add(model, {
		Humanoid = humanoid,
		Root = root,
		Joints = joints,
		NextTargetRefresh = 0,
		TargetPlayer = nil,
		ApproachOffset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * approachRadius,
		AnimationPhase = spawnCursor * 0.7,
		MaxHP = maxHP,
		CurrentHP = maxHP,
		Lifecycle = "ACTIVE",
	})
	if testSpawn then
		print(string.format(
			"[GB021 HP TEST] SPAWN id=%s maxHP=%d currentHP=%d lifecycle=ACTIVE humanoid=%d/%d",
			model.Name, maxHP, maxHP, humanoid.Health, humanoid.MaxHealth
		))
	end
	return model
end

function ZombieService.HasValidTarget(): boolean
	local player = ZombieRules.FindNearestPlayer(Players:GetPlayers(), Players, Vector3.zero)
	return player ~= nil
end

function ZombieService.GetActiveCount(): number
	return registry:Count()
end

function ZombieService.IsActive(model: Model): boolean
	local entry = registry:Get(model)
	return entry ~= nil and entry.Lifecycle == "ACTIVE"
end

-- Damage and lethal lifecycle transition are synchronous and server-owned.
function ZombieService.ApplyDamage(model: Model, damage: number)
	local entry = registry:Get(model)
	if not entry then
		return nil
	end
	local result = DamageRules.Apply(entry, damage)
	if not result then
		return nil
	end
	model:SetAttribute("CurrentHP", result.CurrentHP)
	local humanoid = entry.Humanoid
	if humanoid.Parent and humanoid.Health > 0 then
		humanoid.Health = result.CurrentHP
	end
	if result.Lethal then
		model:SetAttribute("ZombieState", "DEFEATED")
	end
	return result
end

function ZombieService.GetRoot(model: Model): BasePart?
	local entry = registry:Get(model)
	return if entry then entry.Root else nil
end

function ZombieService.GetContainer(): Folder?
	return container
end

-- Combat calls this before a physics launch to stop AI ownership without
-- destroying the rig. CombatService then owns final cleanup.
function ZombieService.Release(model: Model): boolean
	return releaseZombie(model)
end

return ZombieService
