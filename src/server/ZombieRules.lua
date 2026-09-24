--!strict

local ZombieRules = {}

function ZombieRules.ResolveSpawnHP(
	requestedMaxHP: number?,
	defaultMaxHP: number,
	serviceReady: boolean,
	activeCount: number,
	activeCap: number
): (number?, boolean, string?)
	local isTestSpawn = requestedMaxHP ~= nil
	if not serviceReady then
		return nil, isTestSpawn, "NOT_READY"
	end
	if activeCount >= activeCap then
		return nil, isTestSpawn, "ACTIVE_CAP"
	end
	local maxHP = if isTestSpawn then requestedMaxHP else defaultMaxHP
	if type(maxHP) ~= "number" or maxHP ~= maxHP or maxHP % 1 ~= 0 or maxHP < 1 or maxHP > 1000 then
		return nil, isTestSpawn, "INVALID_HP"
	end
	return maxHP, isTestSpawn, nil
end

function ZombieRules.GetValidRoot(player: Player?, playersService: Players): BasePart?
	if not player or player.Parent ~= playersService then
		return nil
	end
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil
	end
	return root
end

function ZombieRules.FindNearestPlayer(
	players: { Player },
	playersService: Players,
	origin: Vector3
): (Player?, BasePart?)
	local nearestPlayer: Player? = nil
	local nearestRoot: BasePart? = nil
	local nearestDistanceSquared = math.huge
	for _, player in players do
		local root = ZombieRules.GetValidRoot(player, playersService)
		if root then
			local delta = root.Position - origin
			local distanceSquared = delta.X * delta.X + delta.Y * delta.Y + delta.Z * delta.Z
			if distanceSquared < nearestDistanceSquared then
				nearestDistanceSquared = distanceSquared
				nearestPlayer = player
				nearestRoot = root
			end
		end
	end
	return nearestPlayer, nearestRoot
end

return ZombieRules
