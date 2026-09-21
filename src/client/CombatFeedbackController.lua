--!nonstrict

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local FeedbackConfig = require(ReplicatedStorage.Shared.FeedbackConfig)

local CombatFeedbackController = {}
local GUI_NAME = "GraveBusterFeedbackGui"
local KILL_ATTRIBUTE = "SessionKills"
local started = false

local COLORS = {
	BASEBALL_BAT = Color3.fromRGB(255, 224, 154),
	FRYING_PAN = Color3.fromRGB(255, 242, 196),
	GIANT_HAMMER = Color3.fromRGB(255, 178, 112),
	BLOWER = Color3.fromRGB(174, 232, 236),
	THUNDER_ROD = Color3.fromRGB(190, 174, 255),
}

local function createImpact(position, color)
	local flash = Instance.new("Part")
	flash.Name = "ZombieImpactFlash"
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.new(0.8, 0.8, 0.8)
	flash.Position = position
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanTouch = false
	flash.CanQuery = false
	flash.CastShadow = false
	flash.Material = Enum.Material.Neon
	flash.Color = color
	flash.Transparency = 0.12
	flash.Parent = Workspace
	TweenService:Create(
		flash,
		TweenInfo.new(FeedbackConfig.ImpactLifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(2.6, 2.6, 2.6), Transparency = 1 }
	):Play()
	Debris:AddItem(flash, FeedbackConfig.ImpactLifetime + 0.05)
end

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
	feedbackRemote.OnClientEvent:Connect(function(weaponName, hits)
		if type(weaponName) ~= "string" or type(hits) ~= "table" then
			return
		end
		local color = COLORS[weaponName] or Color3.fromRGB(245, 245, 235)
		local effectCount = math.min(#hits, FeedbackConfig.MaxEffectsPerAttack)
		for index = 1, effectCount do
			local hit = hits[index]
			if type(hit) == "table" and typeof(hit.Position) == "Vector3" then
				createImpact(hit.Position, color)
				createKnockbackTrail(hit.Root, color)
			end
		end
	end)
end

return CombatFeedbackController
