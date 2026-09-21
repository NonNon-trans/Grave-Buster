--!nonstrict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local WeaponConfig = require(ReplicatedStorage.Shared.WeaponConfig)
local HoldState = require(script.Parent:WaitForChild("HoldState"))
local OwnedWeaponSource = require(script.Parent:WaitForChild("OwnedWeaponSource"))
local WeaponPresenter = require(script.Parent:WaitForChild("WeaponPresenter"))
local WeaponSwitcher = require(script.Parent:WaitForChild("WeaponSwitcher"))

local CombatController = {}
local player = Players.LocalPlayer
local started = false
local holdState = HoldState.new()
local activeInput = nil
local currentWeapon = WeaponConfig.DefaultWeapon
local lastLocalAttack = -math.huge

local function makeButton(name: string, text: string, size: UDim2, position: UDim2): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = text
	button.Size = size
	button.Position = position
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.BackgroundColor3 = Color3.fromRGB(49, 55, 61)
	button.BackgroundTransparency = 0.12
	button.TextColor3 = Color3.fromRGB(245, 245, 245)
	button.TextScaled = true
	button.Font = Enum.Font.GothamBold
	button.AutoButtonColor = true
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.22, 0)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(175, 185, 190)
	stroke.Thickness = 2
	stroke.Transparency = 0.25
	stroke.Parent = button
	return button
end

function CombatController.Start()
	if started then
		return
	end
	started = true

	local remotes = ReplicatedStorage:WaitForChild("CombatRemotes")
	local attackRemote = remotes:WaitForChild("AttackRequest")
	local equipRemote = remotes:WaitForChild("EquipRequest")
	local playerGui = player:WaitForChild("PlayerGui")
	local previous = playerGui:FindFirstChild("GraveBusterCombatGui")
	if previous then
		previous:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "GraveBusterCombatGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.ClipToDeviceSafeArea = true
	gui.Parent = playerGui

	local attackButton = makeButton(
		"AttackButton",
		"ATTACK",
		UDim2.fromOffset(112, 112),
		UDim2.new(1, -86, 0.6, 0)
	)
	attackButton.Parent = gui

	local function stopHold()
		holdState:Stop()
		activeInput = nil
	end
	local ownedWeapons = OwnedWeaponSource.GetOwnedWeapons()
	local switcher = WeaponSwitcher.Create(gui, ownedWeapons, function(requestedWeapon)
		stopHold()
		equipRemote:FireServer(requestedWeapon)
	end)

	local function equipPresentation()
		local selected = player:GetAttribute("EquippedWeapon")
		if not WeaponConfig.IsValid(selected) or not table.find(ownedWeapons, selected) then
			selected = WeaponConfig.DefaultWeapon
		end
		currentWeapon = selected
		stopHold()
		switcher:SetSelected(currentWeapon)
		if player.Character then
			WeaponPresenter.Equip(player.Character, currentWeapon)
		end
	end

	local function attackOnce()
		local config = WeaponConfig.Get(currentWeapon)
		if not config or not player.Character then
			return
		end
		local now = os.clock()
		if now - lastLocalAttack < config.Interval * 0.9 then
			return
		end
		lastLocalAttack = now
		WeaponPresenter.PlayAttack(currentWeapon, config.Interval)
		attackRemote:FireServer()
	end

	local function beginHold(input: InputObject)
		local generation = holdState:Begin()
		if not generation then
			return
		end
		activeInput = input
		attackOnce()
		task.spawn(function()
			while holdState:IsCurrent(generation) do
				local config = WeaponConfig.Get(currentWeapon)
				task.wait(if config then config.Interval else 0.1)
				if holdState:IsCurrent(generation) then
					attackOnce()
				end
			end
		end)
	end

	attackButton.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1 then
			beginHold(input)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input == activeInput then
			stopHold()
		end
	end)

	player:GetAttributeChangedSignal("EquippedWeapon"):Connect(equipPresentation)
	player.CharacterRemoving:Connect(function()
		stopHold()
		switcher:CancelInteraction()
		WeaponPresenter.Detach()
	end)
	player.CharacterAdded:Connect(function()
		stopHold()
		task.defer(equipPresentation)
	end)
	equipPresentation()
end

return CombatController
