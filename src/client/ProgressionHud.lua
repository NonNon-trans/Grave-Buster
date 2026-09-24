--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProgressionHud = {}
local GUI_NAME = "GraveBusterProgressionGui"
local REMOTE_FOLDER_NAME = "ProgressionRemotes"
local STATE_CHANGED_NAME = "StateChanged"
local started = false

local function makeLabel(parent: Instance, name: string, position: UDim2, size: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(244, 242, 230)
	label.TextStrokeColor3 = Color3.fromRGB(20, 20, 20)
	label.TextStrokeTransparency = 0.65
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

function ProgressionHud.Start()
	if started then
		return
	end
	started = true

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
	gui.DisplayOrder = 2
	gui.Parent = playerGui

	local panel = Instance.new("Frame")
	panel.Name = "ProgressionPanel"
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, -18, 0, 70)
	panel.Size = UDim2.fromOffset(186, 62)
	panel.BackgroundColor3 = Color3.fromRGB(30, 32, 30)
	panel.BackgroundTransparency = 0.28
	panel.BorderSizePixel = 0
	panel.Parent = gui
	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 6)
	panelCorner.Parent = panel

	local levelLabel = makeLabel(panel, "LevelLabel", UDim2.fromOffset(10, 3), UDim2.new(1, -20, 0, 18))
	levelLabel.TextSize = 14
	local barBackground = Instance.new("Frame")
	barBackground.Name = "XPBarBackground"
	barBackground.Position = UDim2.fromOffset(10, 25)
	barBackground.Size = UDim2.new(1, -20, 0, 10)
	barBackground.BackgroundColor3 = Color3.fromRGB(18, 20, 18)
	barBackground.BorderSizePixel = 0
	barBackground.ClipsDescendants = true
	barBackground.Parent = panel
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0.5, 0)
	barCorner.Parent = barBackground
	local barFill = Instance.new("Frame")
	barFill.Name = "XPBarFill"
	barFill.Size = UDim2.fromScale(0, 1)
	barFill.BackgroundColor3 = Color3.fromRGB(126, 190, 111)
	barFill.BorderSizePixel = 0
	barFill.Parent = barBackground
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0.5, 0)
	fillCorner.Parent = barFill
	local xpLabel = makeLabel(panel, "XPLabel", UDim2.fromOffset(10, 39), UDim2.new(1, -20, 0, 17))
	xpLabel.Font = Enum.Font.GothamMedium
	xpLabel.TextSize = 12

	local levelUpLabel = Instance.new("TextLabel")
	levelUpLabel.Name = "LevelUpFeedback"
	levelUpLabel.AnchorPoint = Vector2.new(0.5, 0)
	levelUpLabel.Position = UDim2.new(0.5, 0, 0, 52)
	levelUpLabel.Size = UDim2.fromOffset(250, 54)
	levelUpLabel.BackgroundColor3 = Color3.fromRGB(57, 66, 46)
	levelUpLabel.BackgroundTransparency = 0.12
	levelUpLabel.BorderSizePixel = 0
	levelUpLabel.Font = Enum.Font.GothamBold
	levelUpLabel.TextColor3 = Color3.fromRGB(255, 242, 189)
	levelUpLabel.TextStrokeColor3 = Color3.fromRGB(20, 20, 20)
	levelUpLabel.TextStrokeTransparency = 0.5
	levelUpLabel.TextSize = 15
	levelUpLabel.TextWrapped = true
	levelUpLabel.Visible = false
	levelUpLabel.Parent = gui
	local toastCorner = Instance.new("UICorner")
	toastCorner.CornerRadius = UDim.new(0, 6)
	toastCorner.Parent = levelUpLabel

	local function render(snapshot)
		local level = if snapshot then snapshot.Level else player:GetAttribute("PlayerLevel")
		local currentXP = if snapshot then snapshot.CurrentXP else player:GetAttribute("CurrentXP")
		local requiredXP = if snapshot then snapshot.RequiredXP else player:GetAttribute("RequiredXP")
		level = if type(level) == "number" then level else 1
		currentXP = if type(currentXP) == "number" then currentXP else 0
		requiredXP = if type(requiredXP) == "number" and requiredXP > 0 then requiredXP else 100
		levelLabel.Text = string.format("LEVEL %d", level)
		xpLabel.Text = string.format("%d / %d XP", currentXP, requiredXP)
		barFill.Size = UDim2.fromScale(math.clamp(currentXP / requiredXP, 0, 1), 1)
	end

	local toastGeneration = 0
	local function showLevelUp(snapshot)
		local levelsGained = snapshot.LevelsGained
		if type(levelsGained) ~= "number" or levelsGained <= 0 then
			return
		end
		local oldLevel = snapshot.OldLevel
		local newLevel = snapshot.Level
		local damageIncrease = snapshot.DamageIncreasePercent
		if type(oldLevel) ~= "number" or type(newLevel) ~= "number" or type(damageIncrease) ~= "number" then
			return
		end
		toastGeneration += 1
		local generation = toastGeneration
		levelUpLabel.Text = string.format(
			"LEVEL UP!\n%d → %d  •  DAMAGE +%d%%",
			oldLevel, newLevel, damageIncrease
		)
		levelUpLabel.Visible = true
		task.delay(2.2, function()
			if generation == toastGeneration and levelUpLabel.Parent then
				levelUpLabel.Visible = false
			end
		end)
	end

	for _, attributeName in { "PlayerLevel", "CurrentXP", "RequiredXP" } do
		player:GetAttributeChangedSignal(attributeName):Connect(function()
			render(nil)
		end)
	end
	local remoteFolder = ReplicatedStorage:WaitForChild(REMOTE_FOLDER_NAME)
	local stateChanged = remoteFolder:WaitForChild(STATE_CHANGED_NAME) :: RemoteEvent
	stateChanged.OnClientEvent:Connect(function(snapshot)
		if type(snapshot) ~= "table" then
			return
		end
		render(snapshot)
		showLevelUp(snapshot)
	end)
	render(nil)
end

return ProgressionHud
