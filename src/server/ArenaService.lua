--!strict

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local ArenaService = {}

-- Studs. Keep the central 160 x 160 clear; decorations sit outside it.
local FLOOR_SIZE = 208
local GRAVE_ROWS = { 84, 92 }
local GRAVE_SPACING = 8
-- Match the innermost grave row; never leave a walkable strip behind it.
local BOUNDARY_OFFSET = GRAVE_ROWS[1]
local BOUNDARY_THICKNESS = 1.2 -- Same depth as the grave stones.
local BOUNDARY_HEIGHT = 40
local ARENA_NAME = "GraveyardArena"

local function createPart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.Concrete
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanTouch = false
	part.Parent = parent
	return part
end

local function createGrave(parent: Instance, index: number, position: Vector3, yaw: number)
	local variant = index % 5
	local height = if variant == 1 then 6 else 4.5
	local width = if variant == 0 then 1.2 else 3
	local tilt = if variant == 2 then math.rad(8) else 0
	local shade = 118 + (index % 4) * 8
	local color = Color3.fromRGB(shade, shade + 3, shade - 2)
	local frame = CFrame.new(position) * CFrame.Angles(0, yaw, tilt)
	local stone = createPart(parent, string.format("Grave%03d", index),
		Vector3.new(width, height, 1.2), frame * CFrame.new(0, height / 2, 0), color)
	-- Decoration does not block movement or provide steps over the boundary.
	stone.CanCollide = false
	stone.CanQuery = false
	if variant == 0 then
		local crossbar = createPart(parent, string.format("Crossbar%03d", index),
			Vector3.new(3.5, 1, 1.2), frame * CFrame.new(0, height * 0.7, 0), color)
		crossbar.CanCollide = false
		crossbar.CanQuery = false
	end
end

function ArenaService.Build(): Model
	-- Build without yielding, before Bootstrap waits for shared modules.
	-- Parenting only after construction makes floor and spawns available together.
	local arena = Instance.new("Model")
	arena.Name = ARENA_NAME
	local floor = createPart(arena, "Ground", Vector3.new(FLOOR_SIZE, 2, FLOOR_SIZE),
		CFrame.new(0, -1, 0), Color3.fromRGB(133, 105, 73))
	floor.Material = Enum.Material.Ground

	local graves = Instance.new("Folder")
	graves.Name = "Graves"
	graves.Parent = arena
	local graveIndex = 0
	for _, extent in GRAVE_ROWS do
		for side = 0, 3 do
			local rotation = CFrame.Angles(0, math.rad(side * 90), 0)
			for offset = -extent + GRAVE_SPACING / 2, extent - GRAVE_SPACING / 2, GRAVE_SPACING do
				graveIndex += 1
				local position = rotation:PointToWorldSpace(Vector3.new(offset, 0, -extent))
				createGrave(graves, graveIndex, position, math.rad(side * 90))
			end
		end
	end

	local boundaries = Instance.new("Folder")
	boundaries.Name = "Boundaries"
	boundaries.Parent = arena
	for side = 0, 3 do
		local rotation = CFrame.Angles(0, math.rad(side * 90), 0)
		local wall = createPart(boundaries, "Boundary" .. side,
			Vector3.new(BOUNDARY_OFFSET * 2 + BOUNDARY_THICKNESS, BOUNDARY_HEIGHT, BOUNDARY_THICKNESS),
			rotation * CFrame.new(0, BOUNDARY_HEIGHT / 2 - 1, -BOUNDARY_OFFSET), Color3.new(1, 1, 1))
		wall.Transparency = 1
		wall.CastShadow = false
		wall.CanCollide = true
	end

	local spawns = Instance.new("Folder")
	spawns.Name = "Spawns"
	spawns.Parent = arena
	for _, x in { -10, 10 } do
		for _, z in { -10, 10 } do
			local spawn = Instance.new("SpawnLocation")
			spawn.Name = string.format("Spawn_%d_%d", x, z)
			spawn.Size = Vector3.new(8, 1, 8)
			spawn.Position = Vector3.new(x, -0.5, z)
			spawn.Anchored = true
			spawn.Transparency = 1
			spawn.CanCollide = false
			spawn.CanTouch = false
			spawn.CanQuery = false
			spawn.CastShadow = false
			spawn.Neutral = true
			spawn.Enabled = true
			spawn.Duration = 0
			spawn.AllowTeamChangeOnTouch = false
			spawn.Parent = spawns
		end
	end

	Lighting.ClockTime = 14
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromRGB(130, 130, 125)
	Lighting.OutdoorAmbient = Color3.fromRGB(165, 165, 155)
	Lighting.GlobalShadows = true
	Lighting.ExposureCompensation = 0
	-- Distance fog only; do not combine with an Atmosphere instance.
	Lighting.FogColor = Color3.fromRGB(190, 198, 184)
	-- The grave rows are only 84 / 92 studs from center: fog must start before them.
	Lighting.FogStart = 50
	Lighting.FogEnd = 260

	local previous = Workspace:FindFirstChild(ARENA_NAME)
	if previous then
		previous:Destroy()
	end
	arena.Parent = Workspace
	return arena
end

return ArenaService
