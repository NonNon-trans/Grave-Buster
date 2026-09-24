--!strict

local ZombieRules = require("../src/server/ZombieRules")

local hp15, isTest, spawnError = ZombieRules.ResolveSpawnHP(15, 10, true, 2, 28)
assert(hp15 == 15 and isTest and spawnError == nil)
local defaultHP, isWaveSpawn = ZombieRules.ResolveSpawnHP(nil, 10, true, 2, 28)
assert(defaultHP == 10 and not isWaveSpawn)
assert(select(1, ZombieRules.ResolveSpawnHP(15, 10, true, 28, 28)) == nil)
assert(select(3, ZombieRules.ResolveSpawnHP(15, 10, true, 28, 28)) == "ACTIVE_CAP")
assert(select(1, ZombieRules.ResolveSpawnHP(15, 10, false, 0, 28)) == nil)
assert(select(3, ZombieRules.ResolveSpawnHP(15, 10, false, 0, 28)) == "NOT_READY")
assert(select(1, ZombieRules.ResolveSpawnHP(1.5, 10, true, 0, 28)) == nil)

local vectorMetatable = {}
vectorMetatable.__index = vectorMetatable
vectorMetatable.__sub = function(left, right)
	return setmetatable({ X = left.X - right.X, Y = left.Y - right.Y, Z = left.Z - right.Z }, vectorMetatable)
end

local function vector(x, y, z)
	return setmetatable({ X = x, Y = y, Z = z }, vectorMetatable)
end

local playersService = {}

local function makePlayer(position, health)
	local humanoid = { Health = health }
	local root = {
		Position = position,
		IsA = function(_, className)
			return className == "BasePart"
		end,
	}
	local character = {
		FindFirstChildOfClass = function(_, className)
			return if className == "Humanoid" then humanoid else nil
		end,
		FindFirstChild = function(_, name)
			return if name == "HumanoidRootPart" then root else nil
		end,
	}
	return { Parent = playersService, Character = character }, humanoid, root
end

local nearPlayer, nearHumanoid, nearRoot = makePlayer(vector(10, 0, 0), 100)
local farPlayer = makePlayer(vector(30, 0, 0), 100)
local deadPlayer = makePlayer(vector(2, 0, 0), 0)

local selectedPlayer, selectedRoot = ZombieRules.FindNearestPlayer(
	{ farPlayer, deadPlayer, nearPlayer }, playersService, vector(0, 0, 0)
)
assert(selectedPlayer == nearPlayer and selectedRoot == nearRoot)

nearHumanoid.Health = 0
assert(ZombieRules.GetValidRoot(nearPlayer, playersService) == nil)
nearHumanoid.Health = 100
nearPlayer.Character = nil
assert(ZombieRules.GetValidRoot(nearPlayer, playersService) == nil)
nearPlayer.Parent = nil
assert(ZombieRules.GetValidRoot(nearPlayer, playersService) == nil)

print("PASS ZombieRules: nearest living target and death/reset/leave invalidation")
