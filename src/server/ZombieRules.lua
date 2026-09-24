--!strict

local ZombieRules = {}

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
