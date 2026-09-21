--!strict

local ZombieRules = require("../src/server/ZombieRules")

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
