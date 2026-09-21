--!nonstrict

local TweenService = game:GetService("TweenService")

local WeaponPresenter = {}
local visual = nil
local grip = nil
local swingGeneration = 0

local function part(name, size, color, material)
	local value = Instance.new("Part")
	value.Name = name
	value.Size = size
	value.Color = color
	value.Material = material or Enum.Material.SmoothPlastic
	value.CanCollide = false
	value.CanTouch = false
	value.CanQuery = false
	value.Massless = true
	value.CastShadow = false
	return value
end

local function addDecoration(model: Model, handle: BasePart, decoration: BasePart, offset: CFrame)
	decoration.CFrame = handle.CFrame * offset
	decoration.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = decoration
	weld.Parent = decoration
end

local function createVisual(weaponName: string): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "EquippedWeaponVisual"
	local handle = part("Handle", Vector3.new(0.35, 3.2, 0.35), Color3.fromRGB(92, 57, 35))
	handle.Parent = model

	if weaponName == "BASEBALL_BAT" then
		handle.Size = Vector3.new(0.48, 4.1, 0.48)
		handle.Color = Color3.fromRGB(171, 116, 64)
		local barrel = part("Barrel", Vector3.new(0.72, 2.3, 0.72), Color3.fromRGB(207, 154, 88), Enum.Material.Wood)
		addDecoration(model, handle, barrel, CFrame.new(0, 1.45, 0))
	elseif weaponName == "FRYING_PAN" then
		handle.Size = Vector3.new(0.35, 3.3, 0.35)
		handle.Color = Color3.fromRGB(45, 45, 48)
		local pan = part("Pan", Vector3.new(2.4, 0.42, 2.4), Color3.fromRGB(75, 76, 80), Enum.Material.Metal)
		pan.Shape = Enum.PartType.Cylinder
		addDecoration(model, handle, pan, CFrame.new(0, 2, 0) * CFrame.Angles(0, 0, math.rad(90)))
	elseif weaponName == "GIANT_HAMMER" then
		handle.Size = Vector3.new(0.48, 4.2, 0.48)
		local head = part("HammerHead", Vector3.new(3.3, 1.45, 1.45), Color3.fromRGB(82, 87, 92), Enum.Material.Metal)
		addDecoration(model, handle, head, CFrame.new(0, 2.05, 0))
	elseif weaponName == "BLOWER" then
		handle.Size = Vector3.new(0.5, 2.4, 0.5)
		handle.Color = Color3.fromRGB(48, 52, 55)
		local body = part("BlowerBody", Vector3.new(1.25, 1.25, 2.3), Color3.fromRGB(58, 112, 74))
		addDecoration(model, handle, body, CFrame.new(0, 1, -0.65))
		local nozzle = part("Nozzle", Vector3.new(1.65, 1.65, 1.4), Color3.fromRGB(39, 43, 45), Enum.Material.Metal)
		addDecoration(model, handle, nozzle, CFrame.new(0, 1, -2.25))
	else
		handle.Size = Vector3.new(0.38, 4.3, 0.38)
		handle.Color = Color3.fromRGB(50, 62, 74)
		local core = part("ThunderCore", Vector3.new(1.05, 1.05, 1.05), Color3.fromRGB(95, 220, 255), Enum.Material.Neon)
		core.Shape = Enum.PartType.Ball
		addDecoration(model, handle, core, CFrame.new(0, 2.25, 0))
	end
	model.PrimaryPart = handle
	return model, handle
end

function WeaponPresenter.Detach()
	swingGeneration += 1
	if grip then
		grip:Destroy()
		grip = nil
	end
	if visual then
		visual:Destroy()
		visual = nil
	end
end

function WeaponPresenter.Equip(character: Model, weaponName: string)
	WeaponPresenter.Detach()
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if not hand or not hand:IsA("BasePart") then
		return
	end
	local newVisual, handle = createVisual(weaponName)
	newVisual.Parent = character
	handle.CFrame = hand.CFrame
	local motor = Instance.new("Motor6D")
	motor.Name = "GraveBusterWeaponGrip"
	motor.Part0 = hand
	motor.Part1 = handle
	motor.C0 = CFrame.new(0, -0.85, -0.15) * CFrame.Angles(0, 0, math.rad(90))
	motor.Parent = hand
	visual = newVisual
	grip = motor
end

function WeaponPresenter.PlayAttack(weaponName: string, interval: number)
	if not grip then
		return
	end
	swingGeneration += 1
	local generation = swingGeneration
	local motor = grip
	local angle = if weaponName == "GIANT_HAMMER" then -125 else -95
	local outward = TweenService:Create(
		motor,
		TweenInfo.new(math.min(interval * 0.3, 0.13), Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Transform = CFrame.Angles(math.rad(angle), 0, math.rad(-20)) }
	)
	outward:Play()
	task.delay(math.min(interval * 0.32, 0.14), function()
		if generation ~= swingGeneration or grip ~= motor then
			return
		end
		TweenService:Create(
			motor,
			TweenInfo.new(math.min(interval * 0.42, 0.16), Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Transform = CFrame.new() }
		):Play()
	end)
end

return WeaponPresenter
