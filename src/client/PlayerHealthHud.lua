--!strict

local Players = game:GetService("Players")

local PlayerHealthHud = {}
local GUI_NAME = "GraveBusterPlayerHealthGui"
local started = false

function PlayerHealthHud.Start()
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
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.ClipToDeviceSafeArea = true
	gui.DisplayOrder = 2
	gui.Parent = playerGui

	local panel = Instance.new("Frame")
	panel.Name = "HealthPanel"
	panel.Position = UDim2.fromOffset(18, 58)
	panel.Size = UDim2.fromOffset(190, 48)
	panel.BackgroundColor3 = Color3.fromRGB(30, 32, 30)
	panel.BackgroundTransparency = 0.28
	panel.BorderSizePixel = 0
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = panel

	local label = Instance.new("TextLabel")
	label.Name = "HealthValue"
	label.Position = UDim2.fromOffset(9, 3)
	label.Size = UDim2.new(1, -18, 0, 17)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(244, 242, 230)
	label.TextSize = 13
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = panel

	local bar = Instance.new("Frame")
	bar.Name = "HealthBarBackground"
	bar.Position = UDim2.fromOffset(9, 25)
	bar.Size = UDim2.new(1, -18, 0, 14)
	bar.BackgroundColor3 = Color3.fromRGB(18, 20, 18)
	bar.BorderSizePixel = 0
	bar.ClipsDescendants = true
	bar.Parent = panel
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0.5, 0)
	barCorner.Parent = bar
	local fill = Instance.new("Frame")
	fill.Name = "HealthBarFill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(167, 75, 64)
	fill.BorderSizePixel = 0
	fill.Parent = bar
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0.5, 0)
	fillCorner.Parent = fill

	local healthConnection: RBXScriptConnection? = nil
	local maxHealthConnection: RBXScriptConnection? = nil
	local function bindCharacter(character: Model)
		if healthConnection then healthConnection:Disconnect() end
		if maxHealthConnection then maxHealthConnection:Disconnect() end
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not humanoid or not humanoid:IsA("Humanoid") or player.Character ~= character then
			return
		end
		local function update()
			local maxHealth = math.max(1, humanoid.MaxHealth)
			local health = math.clamp(humanoid.Health, 0, maxHealth)
			label.Text = string.format("HP  %d / %d", math.ceil(health), math.floor(maxHealth))
			fill.Size = UDim2.fromScale(health / maxHealth, 1)
		end
		healthConnection = humanoid.HealthChanged:Connect(update)
		maxHealthConnection = humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(update)
		update()
	end

	player.CharacterAdded:Connect(function(character)
		task.spawn(bindCharacter, character)
	end)
	if player.Character then
		task.spawn(bindCharacter, player.Character)
	end
end

return PlayerHealthHud
