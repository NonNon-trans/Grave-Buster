--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local WeaponConfig = require(ReplicatedStorage.Shared.WeaponConfig)
local Rules = require(script.Parent:WaitForChild("WeaponSwitcherRules"))
local Tuning = Rules.Tuning

local WeaponSwitcher = {}

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
	constraint.MinTextSize = 10
	constraint.MaxTextSize = 20
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

	local center = Instance.new("Frame")
	center.Name = "CurrentWeapon"
	center.Size = UDim2.new(1, -142, 1, -12)
	center.Position = UDim2.new(0.5, 0, 0.5, 0)
	center.AnchorPoint = Vector2.new(0.5, 0.5)
	center.BackgroundColor3 = Color3.fromRGB(67, 73, 77)
	center.Active = true
	center.ClipsDescendants = true
	center.Parent = root
	addCorner(center, 13)

	local track = Instance.new("Frame")
	track.Name = "WeaponTrack"
	track.BackgroundTransparency = 1
	track.Size = UDim2.fromScale(1, 1)
	track.Parent = center

	local visualTargets = {
		{ object = root, property = "BackgroundTransparency", idle = Tuning.IdleBackgroundTransparency, active = 0 },
		{ object = previousButton, property = "BackgroundTransparency", idle = Tuning.IdleBackgroundTransparency, active = 0 },
		{ object = nextButton, property = "BackgroundTransparency", idle = Tuning.IdleBackgroundTransparency, active = 0 },
		{ object = center, property = "BackgroundTransparency", idle = Tuning.IdleBackgroundTransparency, active = 0 },
		{ object = previousButton, property = "TextTransparency", idle = Tuning.IdleContentTransparency, active = 0 },
		{ object = nextButton, property = "TextTransparency", idle = Tuning.IdleContentTransparency, active = 0 },
		{ object = stroke, property = "Transparency", idle = 0.55, active = 0 },
	}
	local visibilityState = Rules.VisibilityState.new()
	local snapCommitGate = Rules.SnapCommitGate.new()
	local visibilityTweens = {}
	local connections = {}
	local currentOwned = {}
	local selectedWeapon = WeaponConfig.DefaultWeapon
	local requestedWeapon = selectedWeapon
	local visualPosition = 1
	local cardInstances = {}
	local baseVisualTargetCount = #visualTargets
	local dragState = Rules.DragState.new()
	local activeDragInput = nil
	local interactionStartPosition = 1
	local snapTween = nil
	local inertiaConnection = nil
	local motionGeneration = 0
	local destroyed = false

	local positionValue = Instance.new("NumberValue")
	positionValue.Name = "PreviewPosition"
	positionValue.Value = visualPosition
	positionValue.Parent = root

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
		task.delay(Tuning.FullVisibilityHold, function()
			if destroyed or not visibilityState:BeginFade(generation) then
				return
			end
			setVisibility(false, Tuning.FadeDuration)
			task.delay(Tuning.FadeDuration, function()
				visibilityState:CompleteFade(generation)
			end)
		end)
	end

	local function playSwitchFeedback()
		local scale = center:FindFirstChildOfClass("UIScale")
		if not scale then
			scale = Instance.new("UIScale")
			scale.Parent = center
		end
		scale.Scale = 0.94
		TweenService:Create(scale, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end

	local function slotWidth(): number
		return math.max(1, center.AbsoluteSize.X * Tuning.SlotWidthRatio)
	end

	local function renderCarousel()
		visualPosition = Rules.ClampPosition(positionValue.Value, #currentOwned)
		positionValue.Value = visualPosition
		local width = center.AbsoluteSize.X
		local stepWidth = width * Tuning.SlotWidthRatio
		for index, card in cardInstances do
			local offset = (index - visualPosition) * stepWidth
			card.Position = UDim2.new(0, width * 0.5 + offset, 0.5, 0)
			local distance = math.abs(index - visualPosition)
			card.BackgroundColor3 = if distance < 0.18
				then Color3.fromRGB(94, 116, 104)
				else Color3.fromRGB(78, 87, 92)
			local strokeLine = card:FindFirstChild("SelectionOutline")
			if strokeLine then
				strokeLine.Transparency = if distance < 0.18 then 0 else 1
			end
		end
	end

	local function connect(signal, callback)
		local connection = signal:Connect(callback)
		table.insert(connections, connection)
		return connection
	end

	local function disconnectInertia()
		if inertiaConnection then
			inertiaConnection:Disconnect()
			inertiaConnection = nil
		end
	end

	local function cancelMotion()
		motionGeneration += 1
		snapCommitGate:Cancel()
		disconnectInertia()
		if snapTween then
			snapTween:Cancel()
			snapTween = nil
		end
		return motionGeneration
	end

	local function requestEquip(index)
		local weaponId = currentOwned[index]
		if not weaponId or weaponId == requestedWeapon then
			return false
		end
		requestedWeapon = weaponId
		onSelectionRequested(weaponId)
		return true
	end

	local function finishSnap(index, generation, snapToken)
		if destroyed or generation ~= motionGeneration then
			return
		end
		visualPosition = index
		positionValue.Value = index
		renderCarousel()
		local committedIndex = snapCommitGate:Commit(snapToken)
		if committedIndex then
			requestEquip(committedIndex)
		end
		playSwitchFeedback()
		snapTween = nil
		scheduleIdle()
	end

	local function snapTo(index, duration, shouldEquipAtEnd)
		local finalIndex = Rules.SnapIndex(index, #currentOwned)
		if not finalIndex then
			scheduleIdle()
			return
		end
		local generation = cancelMotion()
		local snapToken = if shouldEquipAtEnd then snapCommitGate:Begin(finalIndex) else nil
		local function completed()
			if destroyed or generation ~= motionGeneration then
				return
			end
			if shouldEquipAtEnd then
				finishSnap(finalIndex, generation, snapToken)
			else
				visualPosition = finalIndex
				positionValue.Value = finalIndex
				renderCarousel()
				snapTween = nil
				scheduleIdle()
			end
		end
		if math.abs(positionValue.Value - finalIndex) < 0.001 or duration <= 0 then
			positionValue.Value = finalIndex
			completed()
			return
		end
		snapTween = TweenService:Create(
			positionValue,
			TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Value = finalIndex }
		)
		local completionConnection
		completionConnection = snapTween.Completed:Connect(function(playbackState)
			if completionConnection then
				completionConnection:Disconnect()
			end
			if playbackState == Enum.PlaybackState.Completed then
				completed()
			end
		end)
		snapTween:Play()
	end

	local function endInertia(targetPosition, velocityX, currentSlotWidth)
		local origin = positionValue.Value
		local remaining = targetPosition - origin
		if math.abs(remaining) < 0.01 then
			snapTo(targetPosition, Tuning.SnapDuration, true)
			return
		end

		local generation = cancelMotion()
		local direction = if remaining < 0 then -1 else 1
		local speed = math.abs(velocityX) / currentSlotWidth
		local deceleration = speed * speed / (2 * math.abs(remaining))
		local position = origin
		local currentSpeed = speed
		inertiaConnection = RunService.Heartbeat:Connect(function(deltaTime)
			if destroyed or generation ~= motionGeneration then
				disconnectInertia()
				return
			end
			local nextSpeed = math.max(0, currentSpeed - deceleration * deltaTime)
			local distance = (currentSpeed + nextSpeed) * 0.5 * deltaTime
			local remainingDistance = math.abs(targetPosition - position)
			distance = math.min(distance, remainingDistance)
			position += direction * distance
			positionValue.Value = Rules.ClampPosition(position, #currentOwned)
			currentSpeed = nextSpeed
			if remainingDistance - distance <= 0.001 or currentSpeed <= 0.001 then
				disconnectInertia()
				snapTo(targetPosition, Tuning.SnapDuration, true)
			end
		end)
	end

	local function stopGesture(input)
		if input ~= activeDragInput then
			return
		end
		local handled, _, velocityX = dragState:Finish(input)
		activeDragInput = nil
		if not handled then
			return
		end
		local currentSlotWidth = slotWidth()
		local projected = Rules.ProjectFlick(
			positionValue.Value,
			velocityX,
			currentSlotWidth,
			#currentOwned,
			interactionStartPosition
		)
		if Rules.FlickTravel(velocityX, currentSlotWidth) > 0 and math.abs(projected - positionValue.Value) > 0.01 then
			local target = Rules.FlickSnapIndex(projected, interactionStartPosition, #currentOwned)
			endInertia(target or projected, velocityX, currentSlotWidth)
		else
			snapTo(Rules.SnapIndex(positionValue.Value, #currentOwned), Tuning.SnapDuration, true)
		end
	end

	local function requestArrow(direction)
		if #currentOwned == 0 then
			return
		end
		activate()
		if activeDragInput then
			dragState:Cancel()
			activeDragInput = nil
		end
		local baseIndex = Rules.SnapIndex(positionValue.Value, #currentOwned) or 1
		local nextIndex = Rules.ArrowStep(baseIndex, direction, #currentOwned)
		requestEquip(nextIndex)
		playSwitchFeedback()
		snapTo(nextIndex, Tuning.ArrowSnapDuration, false)
	end

	local function buildCards()
		for _, card in cardInstances do
			card:Destroy()
		end
		table.clear(cardInstances)
		for index = #visualTargets, baseVisualTargetCount + 1, -1 do
			table.remove(visualTargets, index)
		end
		for index, weaponId in currentOwned do
			local config = WeaponConfig.Get(weaponId)
			local card = Instance.new("Frame")
			card.Name = "WeaponPreview_" .. weaponId
			card.AnchorPoint = Vector2.new(0.5, 0.5)
			card.Position = UDim2.new(0.5, 0, 0.5, 0)
			card.Size = UDim2.new(Tuning.SlotWidthRatio, 0, 1, -8)
			card.BackgroundColor3 = Color3.fromRGB(94, 106, 111)
			card.BackgroundTransparency = 0.05
			card.BorderSizePixel = 0
			card.Active = false
			card.Parent = track
			addCorner(card, 10)
			local outline = Instance.new("UIStroke")
			outline.Name = "SelectionOutline"
			outline.Color = Color3.fromRGB(207, 232, 209)
			outline.Thickness = 1.5
			outline.Transparency = 1
			outline.Parent = card
			local icon = makeText(card, "WeaponIcon", config.IconGlyph, UDim2.new(0.26, 0, 0.62, 0), UDim2.new(0.04, 0, 0.19, 0))
			icon.TextColor3 = Color3.fromRGB(208, 224, 211)
			local weaponName = makeText(card, "WeaponName", config.DisplayName, UDim2.new(0.67, 0, 0.7, 0), UDim2.new(0.31, 0, 0.15, 0))
			weaponName.TextXAlignment = Enum.TextXAlignment.Left
			table.insert(cardInstances, card)
			table.insert(visualTargets, { object = card, property = "BackgroundTransparency", idle = Tuning.IdleBackgroundTransparency, active = 0 })
			table.insert(visualTargets, { object = icon, property = "TextTransparency", idle = Tuning.IdleContentTransparency, active = 0 })
			table.insert(visualTargets, { object = weaponName, property = "TextTransparency", idle = Tuning.IdleContentTransparency, active = 0 })
		end
		renderCarousel()
	end

	connect(positionValue.Changed, renderCarousel)
	connect(center.InputBegan, function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		if dragState:Begin(input, input.Position.X, input.Position.Y, os.clock(), visualPosition) then
			cancelMotion()
			activeDragInput = input
			interactionStartPosition = visualPosition
			activate()
		end
	end)
	connect(previousButton.InputBegan, activate)
	connect(nextButton.InputBegan, activate)
	connect(previousButton.InputEnded, scheduleIdle)
	connect(nextButton.InputEnded, scheduleIdle)
	connect(UserInputService.InputChanged, function(input)
		if not activeDragInput then
			return
		end
		local isMouseMovement = activeDragInput.UserInputType == Enum.UserInputType.MouseButton1
			and input.UserInputType == Enum.UserInputType.MouseMovement
		if input ~= activeDragInput and not isMouseMovement then
			return
		end
		local updated, position = dragState:Update(
			activeDragInput,
			input.Position.X,
			input.Position.Y,
			os.clock(),
			slotWidth(),
			#currentOwned
		)
		if updated and position then
			positionValue.Value = position
		end
	end)
	connect(UserInputService.InputEnded, stopGesture)
	connect(previousButton.Activated, function()
		requestArrow(-1)
	end)
	connect(nextButton.Activated, function()
		requestArrow(1)
	end)
	connect(center:GetPropertyChangedSignal("AbsoluteSize"), renderCarousel)

	local api = {}

	function api:SetOwnedWeapons(newOwnedWeapons)
		local validOwned = {}
		for _, weapon in newOwnedWeapons do
			if WeaponConfig.IsValid(weapon) then
				table.insert(validOwned, weapon)
			end
		end
		currentOwned = Rules.OrderOwned(validOwned, WeaponConfig.Order)
		cancelMotion()
		dragState:Cancel()
		activeDragInput = nil
		local resolved = Rules.ResolveCurrent(currentOwned, selectedWeapon, WeaponConfig.DefaultWeapon)
		if not resolved then
			positionValue.Value = 0
			requestedWeapon = selectedWeapon
			buildCards()
			return
		end
		if resolved ~= selectedWeapon then
			selectedWeapon = resolved
			requestedWeapon = resolved
			onSelectionRequested(resolved)
		end
		local index = table.find(currentOwned, requestedWeapon) or table.find(currentOwned, resolved) or 1
		positionValue.Value = index
		visualPosition = index
		buildCards()
	end

	function api:SetSelected(confirmedWeapon)
		local resolved = Rules.ResolveCurrent(currentOwned, confirmedWeapon, WeaponConfig.DefaultWeapon)
		if not resolved then
			return
		end
		selectedWeapon = resolved
		requestedWeapon = resolved
		local index = table.find(currentOwned, resolved) or 1
		if not activeDragInput and not inertiaConnection and not snapTween then
			positionValue.Value = index
			visualPosition = index
			renderCarousel()
		end
	end

	function api:CancelInteraction()
		cancelMotion()
		dragState:Cancel()
		activeDragInput = nil
		local index = table.find(currentOwned, selectedWeapon)
		if index then
			positionValue.Value = index
			visualPosition = index
			renderCarousel()
		end
		scheduleIdle()
	end

	function api:SetEnabled(enabled)
		root.Visible = enabled
		if not enabled then
			self:CancelInteraction()
		end
	end

	function api:Destroy()
		if destroyed then
			return
		end
		destroyed = true
		cancelMotion()
		dragState:Cancel()
		activeDragInput = nil
		visibilityState:Activate()
		cancelVisibilityTweens()
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
		positionValue:Destroy()
		root:Destroy()
	end

	api:SetOwnedWeapons(ownedWeapons)
	setVisibility(false, 0)
	return api
end

WeaponSwitcher.Tuning = Tuning

return WeaponSwitcher
