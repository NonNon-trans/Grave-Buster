--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FeedbackConfig = require(ReplicatedStorage.Shared.FeedbackConfig)
local FeedbackScope = require(script.Parent:WaitForChild("FeedbackScope"))
local HudLayout = require(script.Parent:WaitForChild("HudLayout"))

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
	gui.ScreenInsets = Enum.ScreenInsets.TopbarSafeInsets
	gui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
	gui.ClipToDeviceSafeArea = true
	gui.DisplayOrder = 1
	gui.Parent = playerGui
	local scope = FeedbackScope.new(gui)

	local label = Instance.new("TextLabel")
	label.Name = "WaveLabel"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	HudLayout.Watch(scope, gui, function(geometry)
		label.Position = UDim2.fromOffset(geometry.WaveX, geometry.WaveY)
		label.Size = UDim2.fromOffset(geometry.WaveWidth, geometry.WaveHeight)
		label.Visible = geometry.TopbarVisible
	end)
	label.BackgroundColor3 = Color3.fromRGB(30, 32, 30)
	label.BackgroundTransparency = 0.35
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(235, 235, 228)
	label.TextSize = 17
	label.TextScaled = true
	local textConstraint = Instance.new("UITextSizeConstraint")
	textConstraint.MaxTextSize = 17
	textConstraint.MinTextSize = 11
	textConstraint.Parent = label
	label.TextStrokeColor3 = Color3.fromRGB(20, 20, 20)
	label.TextStrokeTransparency = 0.55
	label.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = label

	local waveValue = ReplicatedStorage:WaitForChild("WaveNumber") :: IntValue
	local waveRemotes = ReplicatedStorage:WaitForChild("WaveRemotes")
	local waveCleared = waveRemotes:WaitForChild("WaveCleared") :: RemoteEvent
	local clearGeneration = 0
	local clearedWave: number? = nil
	local emphasisGeneration = 0
	local activeTween = nil
	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = label
	local function emphasize()
		emphasisGeneration += 1
		local generation = emphasisGeneration
		if activeTween then
			activeTween:Cancel()
		end
		scale.Scale = 1.08
		label.BackgroundTransparency = 0.08
		scope:Delay("Emphasis", FeedbackConfig.WaveEmphasisHold, function()
			if generation ~= emphasisGeneration then
				return
			end
			activeTween = scope:Tween("Scale", scale, FeedbackConfig.WaveEmphasisFade, { Scale = 1 })
			scope:Tween("Background", label, FeedbackConfig.WaveEmphasisFade, { BackgroundTransparency = 0.35 })
		end)
	end
	local function update()
		label.Text = if clearedWave
			then string.format("WAVE %d CLEAR!", clearedWave)
			else if waveValue.Value > 0 then string.format("WAVE %d", waveValue.Value) else "GET READY"
		if clearedWave and waveValue.Value > clearedWave then
			label.Text ..= string.format(" → %d", waveValue.Value)
		end
		if waveValue.Value > 0 then
			emphasize()
		end
	end
	scope:Connect(waveCleared.OnClientEvent, function(wave: number)
		if type(wave) ~= "number" or wave < 1 then
			return
		end
		clearGeneration += 1
		local generation = clearGeneration
		clearedWave = wave
		update()
		scope:Delay("Clear", FeedbackConfig.WaveClearLifetime, function()
			if generation ~= clearGeneration or not label.Parent then
				return
			end
			clearedWave = nil
			update()
		end)
	end)
	scope:Connect(waveValue:GetPropertyChangedSignal("Value"), function()
		if waveValue.Value == 0 then
			clearGeneration += 1
			clearedWave = nil
		end
		update()
	end)
	scope:OnDestroy(function() started = false end)
	update()
end

return WaveHud
