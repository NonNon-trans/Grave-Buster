--!nonstrict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WeaponConfig = require(ReplicatedStorage.Shared.WeaponConfig)
local Rules = require(script.Parent:WaitForChild("ProgressionFeedbackRules"))
local FeedbackScope = require(script.Parent:WaitForChild("FeedbackScope"))
local HudLayout = require(script.Parent:WaitForChild("HudLayout"))

local ProgressionHud = {}
local GUI_NAME = "GraveBusterProgressionGui"
local REMOTE_FOLDER_NAME = "ProgressionRemotes"
local STATE_CHANGED_NAME = "StateChanged"
local KILL_ATTRIBUTE = "SessionKills"
local started = false
local setShopOpenImpl = nil

local function makeLabel(parent, name, x, y, width, height, textSize)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = UDim2.fromScale(x, y)
	label.Size = UDim2.fromScale(width, height)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(244, 242, 230)
	label.TextStrokeColor3 = Color3.fromRGB(20, 20, 20)
	label.TextStrokeTransparency = 0.65
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextSize = textSize
	label.TextScaled = true
	local textConstraint = Instance.new("UITextSizeConstraint")
	textConstraint.MinTextSize = 8
	textConstraint.MaxTextSize = textSize
	textConstraint.Parent = label
	label.Parent = parent
	return label
end

function ProgressionHud.Start()
	if started then return end
	started = true
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local previous = playerGui:FindFirstChild(GUI_NAME)
	if previous then previous:Destroy() end
	local gui = Instance.new("ScreenGui")
	gui.Name = GUI_NAME
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
	gui.ClipToDeviceSafeArea = true
	gui.DisplayOrder = 2
	gui.Parent = playerGui
	local scope = FeedbackScope.new(gui)
	local panel = Instance.new("Frame")
	panel.Name = "ProgressionPanel"
	panel.BackgroundColor3 = Color3.fromRGB(30, 32, 30)
	panel.BackgroundTransparency = 0.28
	panel.BorderSizePixel = 0
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = panel
	local content = Instance.new("Frame")
	content.Name = "ProgressionContent"
	content.Position = UDim2.fromOffset(10, 0)
	content.Size = UDim2.new(1, -20, 1, 0)
	content.BackgroundTransparency = 1
	content.Parent = panel
	local levelLabel = makeLabel(content, "LevelLabel", 0, 0.05, 0.18, 0.30, 14)
	local killsLabel = makeLabel(content, "KillCounter", 0.20, 0.05, 0.17, 0.30, 12)
	local function updateKills()
		local count = player:GetAttribute(KILL_ATTRIBUTE)
		killsLabel.Text = string.format("KILLS %d", if type(count) == "number" then count else 0)
	end
	scope:Connect(player:GetAttributeChangedSignal(KILL_ATTRIBUTE), updateKills)
	updateKills()
	local barBackground = Instance.new("Frame")
	barBackground.Name = "XPBarBackground"
	barBackground.Position = UDim2.fromScale(0, 0.78)
	barBackground.Size = UDim2.fromScale(0.44, 0.09)
	barBackground.BackgroundColor3 = Color3.fromRGB(18, 20, 18)
	barBackground.BorderSizePixel = 0
	barBackground.ClipsDescendants = true
	barBackground.Parent = content
	local barFill = Instance.new("Frame")
	barFill.Name = "XPBarFill"
	barFill.Size = UDim2.fromScale(0, 1)
	barFill.BackgroundColor3 = Color3.fromRGB(126, 190, 111)
	barFill.BorderSizePixel = 0
	barFill.Parent = barBackground
	local xpLabel = makeLabel(content, "XPLabel", 0, 0.39, 0.44, 0.27, 12)
	local coinsLabel = makeLabel(content, "CoinsLabel", 0.39, 0.05, 0.28, 0.30, 14)
	coinsLabel.TextColor3 = Color3.fromRGB(255, 225, 144)
	local powerLabel = makeLabel(content, "PowerLabel", 0.48, 0.39, 0.52, 0.27, 12)
	local bestLabel = makeLabel(content, "BestWaveLabel", 0.70, 0.05, 0.30, 0.30, 11)
	bestLabel.TextColor3 = Color3.fromRGB(199, 208, 190)
	local rewardLabel = makeLabel(content, "RewardFeedback", 0.48, 0.70, 0.52, 0.27, 11)
	rewardLabel.TextColor3 = Color3.fromRGB(184, 233, 160)
	rewardLabel.Text = ""
	local levelUpLabel = Instance.new("TextLabel")
	levelUpLabel.Name = "LevelUpFeedback"
	levelUpLabel.BackgroundColor3 = Color3.fromRGB(57, 66, 46)
	levelUpLabel.BackgroundTransparency = 0.12
	levelUpLabel.BorderSizePixel = 0
	levelUpLabel.Font = Enum.Font.GothamBold
	levelUpLabel.TextColor3 = Color3.fromRGB(255, 242, 189)
	levelUpLabel.TextSize = 14
	levelUpLabel.TextWrapped = true
	levelUpLabel.TextScaled = true
	local noticeTextConstraint = Instance.new("UITextSizeConstraint")
	noticeTextConstraint.MinTextSize = 9
	noticeTextConstraint.MaxTextSize = 14
	noticeTextConstraint.Parent = levelUpLabel
	levelUpLabel.Visible = false
	levelUpLabel.Parent = gui
	local toastCorner = Instance.new("UICorner")
	toastCorner.CornerRadius = UDim.new(0, 6)
	toastCorner.Parent = levelUpLabel
	HudLayout.Watch(scope, gui, function(geometry)
		panel.Position = UDim2.fromOffset(geometry.PanelX, geometry.PanelY)
		panel.Size = UDim2.fromOffset(geometry.PanelWidth, geometry.PanelHeight)
		levelUpLabel.Position = UDim2.fromOffset(geometry.NoticeX, geometry.NoticeY)
		levelUpLabel.Size = UDim2.fromOffset(geometry.NoticeWidth, geometry.NoticeHeight)
	end)
	local xpValue = Instance.new("NumberValue")
	xpValue.Name = "DisplayedXP"
	xpValue.Parent = gui
	local coinsValue = Instance.new("NumberValue")
	coinsValue.Name = "DisplayedCoins"
	coinsValue.Parent = gui
	local required = 100
	scope:Connect(xpValue.Changed, function()
		xpLabel.Text = string.format("%d / %d XP", math.round(xpValue.Value), required)
	end)
	scope:Connect(coinsValue.Changed, function()
		coinsLabel.Text = string.format("COINS %d", math.round(coinsValue.Value))
	end)
	local function pulse()
		panel.BackgroundTransparency = 0.08
		scope:Tween("PanelPulse", panel, 0.35, { BackgroundTransparency = 0.28 })
	end
	local function render(snapshot)
		local level = if snapshot then snapshot.Level else player:GetAttribute("PlayerLevel")
		local currentXP = if snapshot then snapshot.CurrentXP else player:GetAttribute("CurrentXP")
		local requiredXP = if snapshot then snapshot.RequiredXP else player:GetAttribute("RequiredXP")
		local coins = if snapshot then snapshot.Coins else player:GetAttribute("Coins")
		local best = if snapshot then snapshot.BestWave else player:GetAttribute("BestWave")
		level = if type(level) == "number" then level else 1
		currentXP = if type(currentXP) == "number" then currentXP else 0
		required = if type(requiredXP) == "number" and requiredXP > 0 then requiredXP else 100
		coins = if type(coins) == "number" then coins else 0
		levelLabel.Text = string.format("LEVEL %d", level)
		bestLabel.Text = string.format("BEST WAVE %d", if type(best) == "number" then best else 1)
		local weapon = WeaponConfig.Get(player:GetAttribute("EquippedWeapon")) or WeaponConfig.Get(WeaponConfig.DefaultWeapon)
		powerLabel.Text = string.format("%s  •  %d DMG", weapon.IconGlyph, Rules.PowerDamage(weapon.BaseDamage, level))
		if xpValue.Value > currentXP then xpValue.Value = 0 end
		xpLabel.Text = string.format("%d / %d XP", math.round(xpValue.Value), required)
		coinsLabel.Text = string.format("COINS %d", math.round(coinsValue.Value))
		scope:Tween("XP", xpValue, Rules.Tuning.CounterDuration, { Value = currentXP })
		scope:Tween("Coins", coinsValue, Rules.Tuning.CounterDuration, { Value = coins })
		scope:Tween("XPBar", barFill, Rules.Tuning.CounterDuration, { Size = UDim2.fromScale(math.clamp(currentXP / required, 0, 1), 1) })
	end
	local queue = {}
	local activeNotice = nil
	local shopOpen = false
	local showNext
	showNext = function()
		if shopOpen then return end
		activeNotice = Rules.PopNotice(queue)
		levelUpLabel.Visible = activeNotice ~= nil
		if not activeNotice then return end
		levelUpLabel.Text = activeNotice.Text
		scope:Delay("Notice", Rules.Tuning.NoticeLifetime, function()
			activeNotice = nil
			showNext()
		end)
	end
	local function notice(kind, text, priority)
		Rules.PushNotice(queue, kind, text, priority)
		if not activeNotice then showNext()
		elseif kind == activeNotice.Kind or priority > activeNotice.Priority then
			scope:CancelDelay("Notice")
			if kind ~= activeNotice.Kind then queue[activeNotice.Kind] = activeNotice end
			activeNotice = nil
			showNext()
		end
	end
	setShopOpenImpl = function(isOpen)
		shopOpen = isOpen
		panel.Visible = not isOpen
		if isOpen then
			if activeNotice then queue[activeNotice.Kind] = activeNotice; activeNotice = nil end
			scope:CancelDelay("Notice")
			levelUpLabel.Visible = false
		else showNext() end
	end
	local batch = { XP = 0, Coins = 0 }
	local function reward(snapshot)
		Rules.AccumulateRewards(batch, snapshot)
		if (batch.XP > 0 or batch.Coins > 0) and not scope.Tasks.RewardBatch then
			scope:Delay("RewardBatch", Rules.Tuning.RewardWindow, function()
				rewardLabel.Text = Rules.TakeRewards(batch)
				pulse()
				scope:Delay("RewardHide", Rules.Tuning.RewardHold, function() rewardLabel.Text = "" end)
			end)
		end
	end
	for _, attribute in { "PlayerLevel", "CurrentXP", "RequiredXP", "Coins", "BestWave", "EquippedWeapon" } do
		scope:Connect(player:GetAttributeChangedSignal(attribute), function() render(nil) end)
	end
	local stateChanged = ReplicatedStorage:WaitForChild(REMOTE_FOLDER_NAME):WaitForChild(STATE_CHANGED_NAME)
	scope:Connect(stateChanged.OnClientEvent, function(snapshot)
		if type(snapshot) ~= "table" then return end
		render(snapshot)
		reward(snapshot)
		if type(snapshot.LevelsGained) == "number" and snapshot.LevelsGained > 0 then
			notice("Level", string.format("LEVEL UP!  %d → %d\nDAMAGE +%d%%", snapshot.OldLevel, snapshot.Level, snapshot.DamageIncreasePercent), 3)
		end
		if snapshot.NewRecord == true and type(snapshot.RecordWave) == "number" then
			notice("Record", string.format("NEW RECORD!  WAVE %d\nKEEP PUSHING", snapshot.RecordWave), 4)
		end
	end)
	local died = false
	local characterScope = nil
	local function bindCharacter(character)
		if characterScope then characterScope:Destroy() end
		characterScope = FeedbackScope.new(character)
		local function bindHumanoid(humanoid)
			characterScope:Connect(humanoid.Died, function()
				died = true
				queue = {}
				notice("Retry", "BACK IN THE FIGHT SOON\nLEVEL • COINS • WEAPONS RETAINED", 5)
			end)
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then bindHumanoid(humanoid) else
			local waiting
			waiting = characterScope:Connect(character.ChildAdded, function(child)
				if child:IsA("Humanoid") then waiting:Disconnect(); bindHumanoid(child) end
			end)
		end
		if died then
			died = false
			local wave = ReplicatedStorage:WaitForChild("WaveNumber").Value
			notice("Retry", string.format("BACK IN THE FIGHT  •  WAVE %d\nYOUR GROWTH IS RETAINED", math.max(1, wave)), 5)
		end
	end
	scope:Connect(player.CharacterAdded, bindCharacter)
	scope:Connect(player.CharacterRemoving, function()
		if characterScope then characterScope:Destroy(); characterScope = nil end
	end)
	scope:OnDestroy(function()
		if characterScope then characterScope:Destroy(); characterScope = nil end
		setShopOpenImpl = nil
		started = false
	end)
	if player.Character then bindCharacter(player.Character) end
	render(nil)
end

function ProgressionHud.SetShopOpen(isOpen)
	if setShopOpenImpl then setShopOpenImpl(isOpen) end
end

return ProgressionHud
