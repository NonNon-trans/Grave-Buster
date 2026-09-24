--!nonstrict

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local FeedbackConfig = require(ReplicatedStorage.Shared.FeedbackConfig)
local DamageConfig = require(ReplicatedStorage.Shared.DamageConfig)

local CombatFeedbackController = {}
local GUI_NAME = "GraveBusterFeedbackGui"
local KILL_ATTRIBUTE = "SessionKills"
local started = false
local healthBars = {}

local COLORS = {
	BASEBALL_BAT = Color3.fromRGB(255, 224, 154),
	FRYING_PAN = Color3.fromRGB(255, 242, 196),
	GIANT_HAMMER = Color3.fromRGB(255, 178, 112),
	BLOWER = Color3.fromRGB(174, 232, 236),
	THUNDER_ROD = Color3.fromRGB(190, 174, 255),
}

local function createKnockbackTrail(root, color)
	if not root or not root:IsA("BasePart") or not root.Parent then
		return
	end
	local upper = Instance.new("Attachment")
	upper.Name = "FeedbackTrailUpper"
	upper.Position = Vector3.new(0, 0.7, 0)
	upper.Parent = root
	local lower = Instance.new("Attachment")
	lower.Name = "FeedbackTrailLower"
	lower.Position = Vector3.new(0, -0.7, 0)
	lower.Parent = root
	local trail = Instance.new("Trail")
	trail.Name = "KnockbackTrail"
	trail.Attachment0 = upper
	trail.Attachment1 = lower
	trail.Color = ColorSequence.new(color)
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.WidthScale = NumberSequence.new(0.42, 0)
	trail.Lifetime = 0.1
	trail.LightEmission = 0.45
	trail.MaxLength = 14
	trail.Parent = root
	Debris:AddItem(trail, FeedbackConfig.TrailLifetime)
	Debris:AddItem(upper, FeedbackConfig.TrailLifetime)
	Debris:AddItem(lower, FeedbackConfig.TrailLifetime)
end

local function createDamageNumber(root: BasePart, damage: number, color: Color3)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZombieDamageNumber"
	billboard.Adornee = root
	billboard.Size = UDim2.fromOffset(74, 34)
	billboard.StudsOffsetWorldSpace = Vector3.new(math.random(-8, 8) / 10, 2.5, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 120
	billboard.Parent = root
	local label = Instance.new("TextLabel")
	label.Name = "Damage"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.Text = tostring(damage)
	label.TextColor3 = color
	label.TextScaled = true
	label.TextStrokeColor3 = Color3.fromRGB(20, 20, 20)
	label.TextStrokeTransparency = 0.25
	label.Parent = billboard
	TweenService:Create(billboard, TweenInfo.new(DamageConfig.DamageNumberLifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffsetWorldSpace = billboard.StudsOffsetWorldSpace + Vector3.new(0, 1.5, 0),
	}):Play()
	TweenService:Create(label, TweenInfo.new(DamageConfig.DamageNumberLifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	Debris:AddItem(billboard, DamageConfig.DamageNumberLifetime)
end

local function removeHealthBar(model: Model)
	local state = healthBars[model]
	if state then
		state.Gui:Destroy()
		healthBars[model] = nil
	end
end

local function showHealthBar(model: Model, root: BasePart, currentHP: number, maxHP: number)
	local state = healthBars[model]
	if not state or not state.Gui.Parent then
		local gui = Instance.new("BillboardGui")
		gui.Name = "ZombieHealthBar"
		gui.Adornee = root
		gui.Size = UDim2.fromOffset(76, 10)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 3.25, 0)
		gui.AlwaysOnTop = true
		gui.MaxDistance = 100
		gui.Parent = root
		local background = Instance.new("Frame")
		background.Name = "Background"
		background.Size = UDim2.fromScale(1, 1)
		background.BackgroundColor3 = Color3.fromRGB(28, 30, 29)
		background.BorderSizePixel = 0
		background.ClipsDescendants = true
		background.Parent = gui
		local backgroundCorner = Instance.new("UICorner")
		backgroundCorner.CornerRadius = UDim.new(0.5, 0)
		backgroundCorner.Parent = background
		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.Size = UDim2.fromScale(1, 1)
		fill.BackgroundColor3 = Color3.fromRGB(111, 196, 105)
		fill.BorderSizePixel = 0
		fill.Parent = background
		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(0.5, 0)
		fillCorner.Parent = fill
		state = { Gui = gui, Fill = fill, Generation = 0 }
		healthBars[model] = state
	end
	state.Generation += 1
	state.Fill.Size = UDim2.fromScale(math.clamp(currentHP / maxHP, 0, 1), 1)
	local generation = state.Generation
	task.delay(DamageConfig.ZombieHealthBarLifetime, function()
		local latest = healthBars[model]
		if latest == state and latest.Generation == generation then
			removeHealthBar(model)
		end
	end)
end

local function presentDamageResults(results)
	if type(results) ~= "table" then
		return
	end
	local count = math.min(#results, 12)
	for index = 1, count do
		local result = results[index]
		if type(result) == "table"
			and typeof(result.Model) == "Instance"
			and result.Model:IsA("Model")
			and type(result.AttackDamage) == "number"
			and type(result.CurrentHP) == "number"
			and type(result.MaxHP) == "number"
			and result.MaxHP > 0 then
			local model = result.Model
			local root = model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") and root:IsDescendantOf(workspace) then
				createDamageNumber(root, result.AttackDamage, Color3.fromRGB(255, 239, 179))
				if result.Lethal == true or result.CurrentHP <= 0 then
					removeHealthBar(model)
				else
					showHealthBar(model, root, result.CurrentHP, result.MaxHP)
				end
			end
		end
	end
end

function CombatFeedbackController.Start()
	if started then
		return
	end
	started = true
	FeedbackConfig.Validate()

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local previous = playerGui:FindFirstChild(GUI_NAME)
	if previous then
		previous:Destroy()
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = GUI_NAME
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.ClipToDeviceSafeArea = true
	gui.DisplayOrder = 2
	gui.Parent = playerGui

	local kills = Instance.new("TextLabel")
	kills.Name = "KillCounter"
	kills.Position = UDim2.fromOffset(18, 16)
	kills.Size = UDim2.fromOffset(116, 36)
	kills.BackgroundColor3 = Color3.fromRGB(30, 32, 30)
	kills.BackgroundTransparency = 0.35
	kills.BorderSizePixel = 0
	kills.Font = Enum.Font.GothamBold
	kills.TextColor3 = Color3.fromRGB(235, 235, 228)
	kills.TextSize = 18
	kills.TextStrokeColor3 = Color3.fromRGB(20, 20, 20)
	kills.TextStrokeTransparency = 0.55
	kills.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = kills

	local function updateKills()
		local count = player:GetAttribute(KILL_ATTRIBUTE)
		kills.Text = string.format("KILLS %d", if type(count) == "number" then count else 0)
	end
	player:GetAttributeChangedSignal(KILL_ATTRIBUTE):Connect(updateKills)
	updateKills()

	local feedbackRemote = ReplicatedStorage:WaitForChild("CombatRemotes"):WaitForChild("CombatFeedback")
	feedbackRemote.OnClientEvent:Connect(function(weaponName, roots)
		if type(weaponName) ~= "string" or type(roots) ~= "table" then
			return
		end
		local color = COLORS[weaponName] or Color3.fromRGB(245, 245, 235)
		local effectCount = math.min(#roots, FeedbackConfig.MaxEffectsPerAttack)
		for index = 1, effectCount do
			createKnockbackTrail(roots[index], color)
		end
	end)
	local damageRemote = ReplicatedStorage:WaitForChild("CombatRemotes"):WaitForChild("ZombieDamageFeedback")
	damageRemote.OnClientEvent:Connect(presentDamageResults)
end

return CombatFeedbackController
