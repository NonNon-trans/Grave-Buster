--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local WeaponConfig = require(ReplicatedStorage.Shared.WeaponConfig)
local Rules = require(script.Parent:WaitForChild("WeaponSwitcherRules"))

local WeaponSwitcher = {}
local SWIPE_THRESHOLD = 48
local FULL_VISIBILITY_HOLD = 1.0
local FADE_DURATION = 0.3
local IDLE_BACKGROUND_TRANSPARENCY = 0.5
local IDLE_CONTENT_TRANSPARENCY = 0.42

local function addCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local function makeText(parent, name, text, size, position)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Text = text
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(246, 246, 242)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Parent = parent
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = 11
	constraint.MaxTextSize = 21
	constraint.Parent = label
	return label
end

local function makeArrow(parent, name, text, position)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = text
	button.Size = UDim2.fromOffset(62, 62)
	button.Position = position
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.BackgroundColor3 = Color3.fromRGB(53, 59, 64)
	button.TextColor3 = Color3.fromRGB(248, 248, 244)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 27
	button.AutoButtonColor = false
	button.Parent = parent
	addCorner(button, 14)
	return button
end

function WeaponSwitcher.Create(parent: Instance, ownedWeapons, onSelectionRequested)
	local root = Instance.new("Frame")
	root.Name = "WeaponSwitcher"
	root.AnchorPoint = Vector2.new(0.5, 1)
	root.Position = UDim2.new(0.5, 0, 1, -12)
	root.Size = UDim2.new(0.42, 0, 0, 74)
	root.BackgroundColor3 = Color3.fromRGB(31, 35, 39)
	root.BorderSizePixel = 0
	root.Parent = parent
	addCorner(root, 18)

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(280, 74)
	sizeConstraint.MaxSize = Vector2.new(430, 74)
	sizeConstraint.Parent = root

	local stroke = Instance.new("UIStroke")
	stroke.Name = "Outline"
	stroke.Color = Color3.fromRGB(188, 195, 198)
	stroke.Thickness = 2
	stroke.Parent = root

	local previousButton = makeArrow(root, "PreviousWeapon", "◀", UDim2.new(0, 38, 0.5, 0))
	local nextButton = makeArrow(root, "NextWeapon", "▶", UDim2.new(1, -38, 0.5, 0))

	local center = Instance.new("TextButton")
	center.Name = "CurrentWeapon"
	center.Text = ""
	center.Size = UDim2.new(1, -142, 1, -12)
	center.Position = UDim2.new(0.5, 0, 0.5, 0)
	center.AnchorPoint = Vector2.new(0.5, 0.5)
	center.BackgroundColor3 = Color3.fromRGB(67, 73, 77)
	center.AutoButtonColor = false
	center.Parent = root
	addCorner(center, 13)

	local icon = makeText(center, "WeaponIcon", "BAT", UDim2.fromOffset(48, 42), UDim2.new(0, 8, 0.5, -21))
	icon.TextColor3 = Color3.fromRGB(208, 224, 211)
	local weaponName = makeText(
		center,
		"WeaponName",
		"BASEBALL BAT",
		UDim2.new(1, -64, 1, -14),
		UDim2.new(0, 60, 0, 7)
	)
	weaponName.TextXAlignment = Enum.TextXAlignment.Left

	local feedbackScale = Instance.new("UIScale")
	feedbackScale.Scale = 1
	feedbackScale.Parent = center

	local visualTargets = {
		{ object = root, property = "BackgroundTransparency", idle = IDLE_BACKGROUND_TRANSPARENCY, active = 0 },
		{ object = previousButton, property = "BackgroundTransparency", idle = IDLE_BACKGROUND_TRANSPARENCY, active = 0 },
		{ object = nextButton, property = "BackgroundTransparency", idle = IDLE_BACKGROUND_TRANSPARENCY, active = 0 },
		{ object = center, property = "BackgroundTransparency", idle = IDLE_BACKGROUND_TRANSPARENCY, active = 0 },
		{ object = previousButton, property = "TextTransparency", idle = IDLE_CONTENT_TRANSPARENCY, active = 0 },
		{ object = nextButton, property = "TextTransparency", idle = IDLE_CONTENT_TRANSPARENCY, active = 0 },
		{ object = icon, property = "TextTransparency", idle = IDLE_CONTENT_TRANSPARENCY, active = 0 },
		{ object = weaponName, property = "TextTransparency", idle = IDLE_CONTENT_TRANSPARENCY, active = 0 },
		{ object = stroke, property = "Transparency", idle = 0.55, active = 0 },
	}
	local visibilityState = Rules.VisibilityState.new()
	local visibilityTweens = {}
	local connections = {}
	local currentOwned = {}
	local selectedWeapon = WeaponConfig.DefaultWeapon
	local pendingWeapon = nil
	local dragState = Rules.DragState.new()
	local activeDragInput = nil
	local destroyed = false

	local function cancelVisibilityTweens()
		for _, tween in visibilityTweens do
			tween:Cancel()
		end
		table.clear(visibilityTweens)
	end

	local function setVisibility(useActive, duration)
		cancelVisibilityTweens()
		for _, target in visualTargets do
			local value = if useActive then target.active else target.idle
			if duration == 0 then
				target.object[target.property] = value
			else
				local tween = TweenService:Create(
					target.object,
					TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ [target.property] = value }
				)
				table.insert(visibilityTweens, tween)
				tween:Play()
			end
		end
	end

	local function activate()
		visibilityState:Activate()
		setVisibility(true, 0)
	end

	local function scheduleIdle()
		local generation = visibilityState:ScheduleIdle()
		task.delay(FULL_VISIBILITY_HOLD, function()
			if destroyed or not visibilityState:BeginFade(generation) then
				return
			end
			setVisibility(false, FADE_DURATION)
			task.delay(FADE_DURATION, function()
				visibilityState:CompleteFade(generation)
			end)
		end)
	end

	local function playSwitchFeedback()
		feedbackScale.Scale = 0.9
		TweenService:Create(
			feedbackScale,
			TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1 }
		):Play()
	end

	local function renderSelected()
		local config = WeaponConfig.Get(selectedWeapon)
		if not config then
			return
		end
		weaponName.Text = config.DisplayName
		icon.Text = config.IconGlyph
		playSwitchFeedback()
	end

	local function requestStep(direction)
		if #currentOwned == 0 then
			return
		end
		activate()
		local cursor = pendingWeapon or selectedWeapon
		local requested = Rules.Step(currentOwned, cursor, direction)
		if requested then
			pendingWeapon = requested
			onSelectionRequested(requested)
		end
		scheduleIdle()
	end

	local function connect(signal, callback)
		local connection = signal:Connect(callback)
		table.insert(connections, connection)
		return connection
	end

	connect(previousButton.InputBegan, function()
		activate()
	end)
	connect(nextButton.InputBegan, function()
		activate()
	end)
	connect(previousButton.InputEnded, scheduleIdle)
	connect(nextButton.InputEnded, scheduleIdle)
	connect(previousButton.Activated, function()
		requestStep(-1)
	end)
	connect(nextButton.Activated, function()
		requestStep(1)
	end)

	connect(center.InputBegan, function(input)
		if (input.UserInputType ~= Enum.UserInputType.Touch
				and input.UserInputType ~= Enum.UserInputType.MouseButton1) then
			return
		end
		if dragState:Begin(input, input.Position.X, input.Position.Y) then
			activeDragInput = input
			activate()
		end
	end)
	connect(UserInputService.InputChanged, function(input)
		if not activeDragInput then
			return
		end
		if input == activeDragInput
			or (activeDragInput.UserInputType == Enum.UserInputType.MouseButton1
				and input.UserInputType == Enum.UserInputType.MouseMovement) then
			dragState:Update(activeDragInput, input.Position.X, input.Position.Y)
		end
	end)
	connect(UserInputService.InputEnded, function(input)
		if input ~= activeDragInput then
			return
		end
		local handled, direction = dragState:Finish(activeDragInput, SWIPE_THRESHOLD)
		activeDragInput = nil
		if not handled then
			return
		end
		if direction ~= 0 then
			requestStep(direction)
		else
			scheduleIdle()
		end
	end)

	local api = {}

	function api:SetOwnedWeapons(newOwnedWeapons)
		local filtered = {}
		local seen = {}
		for _, weapon in newOwnedWeapons do
			if WeaponConfig.IsValid(weapon) and not seen[weapon] then
				seen[weapon] = true
				table.insert(filtered, weapon)
			end
		end
		currentOwned = filtered
		local resolved = Rules.ResolveCurrent(currentOwned, selectedWeapon, WeaponConfig.DefaultWeapon)
		if resolved and resolved ~= selectedWeapon then
			pendingWeapon = resolved
			onSelectionRequested(resolved)
		end
	end

	function api:SetSelected(confirmedWeapon)
		local resolved = Rules.ResolveCurrent(currentOwned, confirmedWeapon, WeaponConfig.DefaultWeapon)
		if not resolved then
			return
		end
		selectedWeapon = resolved
		if pendingWeapon == confirmedWeapon then
			pendingWeapon = nil
		end
		renderSelected()
	end

	function api:CancelInteraction()
		dragState:Cancel()
		activeDragInput = nil
		scheduleIdle()
	end

	function api:Destroy()
		if destroyed then
			return
		end
		destroyed = true
		dragState:Cancel()
		activeDragInput = nil
		visibilityState:Activate()
		cancelVisibilityTweens()
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
		root:Destroy()
	end

	api:SetOwnedWeapons(ownedWeapons)
	setVisibility(false, 0)
	return api
end

WeaponSwitcher.SwipeThreshold = SWIPE_THRESHOLD
WeaponSwitcher.FullVisibilityHold = FULL_VISIBILITY_HOLD
WeaponSwitcher.FadeDuration = FADE_DURATION
WeaponSwitcher.IdleBackgroundTransparency = IDLE_BACKGROUND_TRANSPARENCY
WeaponSwitcher.IdleContentTransparency = IDLE_CONTENT_TRANSPARENCY

return WeaponSwitcher
