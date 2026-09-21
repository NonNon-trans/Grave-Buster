--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WaveHud = {}
local GUI_NAME = "GraveBusterWaveHud"
local started = false

function WaveHud.Start()
	if started then
		return
	end
	started = true

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local previous = playerGui:FindFirstChild(GUI_NAME)
	if previous then
		previous:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = GUI_NAME
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.DisplayOrder = 1
	gui.Parent = playerGui

	local label = Instance.new("TextLabel")
	label.Name = "WaveLabel"
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.fromScale(0.5, 0.025)
	label.Size = UDim2.fromOffset(132, 32)
	label.BackgroundColor3 = Color3.fromRGB(30, 32, 30)
	label.BackgroundTransparency = 0.35
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(235, 235, 228)
	label.TextSize = 20
	label.TextStrokeColor3 = Color3.fromRGB(20, 20, 20)
	label.TextStrokeTransparency = 0.55
	label.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = label

	local waveValue = ReplicatedStorage:WaitForChild("WaveNumber") :: IntValue
	local function update()
		label.Text = if waveValue.Value > 0 then string.format("WAVE %d", waveValue.Value) else "GET READY"
	end
	waveValue:GetPropertyChangedSignal("Value"):Connect(update)
	update()
end

return WaveHud
