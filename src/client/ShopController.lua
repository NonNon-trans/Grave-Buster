--!nonstrict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopConfig = require(ReplicatedStorage.Shared.ShopConfig)
local WeaponConfig = require(ReplicatedStorage.Shared.WeaponConfig)
local OwnedWeaponSource = require(script.Parent:WaitForChild("OwnedWeaponSource"))
local ShopPresentation = require(script.Parent:WaitForChild("ShopPresentation"))
local ProgressionHud = require(script.Parent:WaitForChild("ProgressionHud"))
local FeedbackScope = require(script.Parent:WaitForChild("FeedbackScope"))
local Rules = require(script.Parent:WaitForChild("ProgressionFeedbackRules"))
local HudLayout = require(script.Parent:WaitForChild("HudLayout"))

local ShopController = {}
local player = Players.LocalPlayer
local started = false

local function addCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local function makeLabel(parent, name, text, size, position, textSize)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Text = text
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(244, 244, 240)
	label.Font = Enum.Font.GothamBold
	label.TextSize = textSize
	label.Parent = parent
	return label
end

function ShopController.Start(combatController)
	if started then
		return
	end
	started = true

	local shopRemotes = ReplicatedStorage:WaitForChild("ShopRemotes")
	local getStateRemote = shopRemotes:WaitForChild("GetState")
	local purchaseRemote = shopRemotes:WaitForChild("PurchaseRequest")
	local stateChangedRemote = shopRemotes:WaitForChild("StateChanged")
	local progressionStateChanged = ReplicatedStorage:WaitForChild("ProgressionRemotes"):WaitForChild("StateChanged")
	local equipRemote = ReplicatedStorage:WaitForChild("CombatRemotes"):WaitForChild("EquipRequest")
	local playerGui = player:WaitForChild("PlayerGui")
	local previous = playerGui:FindFirstChild("GraveBusterShopGui")
	if previous then
		previous:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "GraveBusterShopGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.ClipToDeviceSafeArea = true
	gui.DisplayOrder = 10
	gui.Parent = playerGui
	local scope = FeedbackScope.new(gui)
	local shopOpen = false
	local previousTopbar = playerGui:FindFirstChild("GraveBusterShopTopbarGui")
	if previousTopbar then previousTopbar:Destroy() end
	local topbarGui = Instance.new("ScreenGui")
	topbarGui.Name = "GraveBusterShopTopbarGui"
	topbarGui.ResetOnSpawn = false
	topbarGui.ScreenInsets = Enum.ScreenInsets.TopbarSafeInsets
	topbarGui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
	topbarGui.ClipToDeviceSafeArea = true
	topbarGui.DisplayOrder = 10
	topbarGui.Parent = playerGui
	local topbarScope = FeedbackScope.new(topbarGui)

	local shopButton = Instance.new("TextButton")
	shopButton.Name = "ShopButton"
	shopButton.Text = "SHOP"
	shopButton.AnchorPoint = Vector2.new(0.5, 0.5)
	shopButton.BackgroundColor3 = Color3.fromRGB(64, 72, 67)
	shopButton.TextColor3 = Color3.fromRGB(247, 244, 226)
	shopButton.Font = Enum.Font.GothamBold
	shopButton.TextSize = 20
	shopButton.ZIndex = 2
	shopButton.Parent = topbarGui
	local topbarVisible = false
	HudLayout.Watch(topbarScope, topbarGui, function(geometry)
		topbarVisible = geometry.TopbarVisible
		shopButton.Position = UDim2.fromOffset(geometry.ShopX, geometry.ShopY)
		shopButton.Size = UDim2.fromOffset(geometry.ShopWidth, geometry.ShopHeight)
		shopButton.Visible = topbarVisible and not shopOpen
	end)
	shopButton.TextScaled = true
	addCorner(shopButton, 12)

	local overlay = Instance.new("TextButton")
	overlay.Name = "ShopOverlay"
	overlay.Text = ""
	overlay.AutoButtonColor = false
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromRGB(10, 12, 12)
	overlay.BackgroundTransparency = 0.34
	overlay.Visible = false
	overlay.Active = true
	overlay.Modal = true
	overlay.ZIndex = 10
	overlay.Parent = gui

	local panel = Instance.new("Frame")
	panel.Name = "ShopPanel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.76, 0.82)
	panel.BackgroundColor3 = Color3.fromRGB(34, 38, 39)
	panel.BorderSizePixel = 0
	panel.ZIndex = 11
	panel.Parent = overlay
	addCorner(panel, 16)
	local panelConstraint = Instance.new("UISizeConstraint")
	panelConstraint.MinSize = Vector2.new(ShopPresentation.Layout.PanelMinWidth, 270)
	panelConstraint.MaxSize = Vector2.new(720, 400)
	panelConstraint.Parent = panel

	local title = makeLabel(
		panel,
		"Title",
		"WEAPON SHOP",
		UDim2.fromOffset(ShopPresentation.Layout.TitleWidth, 42),
		UDim2.fromOffset(ShopPresentation.Layout.TitleLeft, ShopPresentation.Layout.HeaderTop),
		22
	)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = 12
	local currencyLabel = makeLabel(
		panel,
		"Currency",
		ShopPresentation.FormatCurrency(0),
		UDim2.fromOffset(ShopPresentation.Layout.CurrencyWidth, ShopPresentation.Layout.HeaderHeight),
		UDim2.new(1, -ShopPresentation.Layout.CurrencyRight, 0, ShopPresentation.Layout.HeaderTop),
		20
	)
	currencyLabel.AnchorPoint = Vector2.new(1, 0)
	currencyLabel.TextXAlignment = Enum.TextXAlignment.Right
	currencyLabel.TextScaled = true
	currencyLabel.BackgroundTransparency = 0.15
	currencyLabel.BackgroundColor3 = Color3.fromRGB(46, 51, 50)
	currencyLabel.ZIndex = ShopPresentation.Layout.HeaderZIndex
	addCorner(currencyLabel, 9)
	local currencyTextConstraint = Instance.new("UITextSizeConstraint")
	currencyTextConstraint.MinTextSize = 15
	currencyTextConstraint.MaxTextSize = 20
	currencyTextConstraint.Parent = currencyLabel

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Text = "CLOSE"
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -12, 0, 9)
	closeButton.Size = UDim2.fromOffset(84, 44)
	closeButton.BackgroundColor3 = Color3.fromRGB(89, 58, 58)
	closeButton.TextColor3 = Color3.fromRGB(250, 242, 242)
	closeButton.Font = Enum.Font.GothamBold
	closeButton.TextSize = 15
	closeButton.ZIndex = 12
	closeButton.Parent = panel
	addCorner(closeButton, 10)

	local feedback = makeLabel(
		panel,
		"Feedback",
		"",
		UDim2.new(1, -36, 0, 28),
		UDim2.fromOffset(18, 50),
		16
	)
	feedback.TextColor3 = Color3.fromRGB(235, 211, 129)
	feedback.TextScaled = true
	feedback.ZIndex = 12

	local list = Instance.new("ScrollingFrame")
	list.Name = "WeaponList"
	list.Position = UDim2.fromOffset(16, 82)
	list.Size = UDim2.new(1, -32, 1, -96)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 5
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.ZIndex = 12
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 7)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local cards = {}
	local pendingPurchases = {}
	local syncing = false
	local confirmedEquipped = player:GetAttribute("EquippedWeapon")

	for order, weaponId in ShopConfig.Order do
		local config = WeaponConfig.Get(weaponId)
		local card = Instance.new("TextButton")
		card.Name = weaponId
		card.Text = ""
		card.AutoButtonColor = false
		card.Size = UDim2.new(1, -8, 0, 54)
		card.BackgroundColor3 = Color3.fromRGB(57, 62, 63)
		card.LayoutOrder = order
		card.ZIndex = 13
		card.Parent = list
		addCorner(card, 11)

		local icon = makeLabel(card, "Icon", config.IconGlyph, UDim2.fromOffset(54, 40), UDim2.fromOffset(8, 7), 15)
		icon.ZIndex = 14
		local name = makeLabel(card, "WeaponName", config.DisplayName, UDim2.new(0.55, -74, 0, 29), UDim2.fromOffset(66, 1), 15)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextScaled = true
		name.ZIndex = 14
		local power = makeLabel(card, "WeaponPower", "", UDim2.new(0.55, -74, 0, 20), UDim2.fromOffset(66, 29), 12)
		power.TextXAlignment = Enum.TextXAlignment.Left
		power.TextColor3 = Color3.fromRGB(194, 216, 178)
		power.ZIndex = 14
		local state = makeLabel(card, "State", "", UDim2.new(0.45, -12, 1, 0), UDim2.new(0.55, 0, 0, 0), 15)
		state.TextXAlignment = Enum.TextXAlignment.Right
		state.TextScaled = true
		state.ZIndex = 14
		cards[weaponId] = { Button = card, State = state, Power = power }
	end

	local function makeOwnedSet()
		local set = {}
		for _, weaponId in OwnedWeaponSource.GetOwnedWeapons() do
			set[weaponId] = true
		end
		return set
	end

	local function render()
		currencyLabel.Text = ShopPresentation.FormatCurrency(OwnedWeaponSource.GetCurrency())
		local owned = makeOwnedSet()
		local equipped = confirmedEquipped
		for _, weaponId in ShopConfig.Order do
			local card = cards[weaponId]
			local baseDamage = WeaponConfig.Get(weaponId).BaseDamage
			local level = player:GetAttribute("PlayerLevel") or 1
			card.Power.Text = ShopPresentation.FormatPower(Rules.PowerDamage(baseDamage, level), level)
			if pendingPurchases[weaponId] then
				card.State.Text = "PROCESSING"
				card.Button.BackgroundColor3 = Color3.fromRGB(70, 67, 52)
			elseif owned[weaponId] and equipped == weaponId then
				card.State.Text = "EQUIPPED"
				card.Button.BackgroundColor3 = Color3.fromRGB(52, 82, 62)
			elseif owned[weaponId] then
				card.State.Text = "OWNED • TAP TO EQUIP"
				card.Button.BackgroundColor3 = Color3.fromRGB(52, 67, 71)
			else
				card.State.Text = string.format("BUY • %d COINS", ShopConfig.Prices[weaponId])
				card.Button.BackgroundColor3 = Color3.fromRGB(72, 59, 53)
			end
		end
	end

	local function applyState(state)
		local applied = OwnedWeaponSource.ApplyAuthoritativeState(state)
		if applied and WeaponConfig.IsValid(state.EquippedWeapon) then
			confirmedEquipped = state.EquippedWeapon
		end
		render()
	end

	local function syncState()
		if syncing then
			return
		end
		syncing = true
		scope:Spawn("Sync", function()
			local ok, state = pcall(function()
				return getStateRemote:InvokeServer()
			end)
			syncing = false
			if ok and state then
				applyState(state)
			elseif not ok then
				feedback.Text = "SHOP CONNECTION ERROR"
			end
		end)
	end

	local function setOpen(isOpen)
		shopOpen = isOpen
		overlay.Visible = isOpen
		shopButton.Visible = topbarVisible and not isOpen
		feedback.Text = ""
		combatController.SetShopOpen(isOpen)
		ProgressionHud.SetShopOpen(isOpen)
		if isOpen then
			syncState()
		end
	end

	for weaponId, card in cards do
		scope:Connect(card.Button.Activated, function()
			if not shopOpen or pendingPurchases[weaponId] then
				return
			end
			local owned = makeOwnedSet()
			if owned[weaponId] then
				if player:GetAttribute("EquippedWeapon") ~= weaponId then
					equipRemote:FireServer(weaponId)
				end
				return
			end

			pendingPurchases[weaponId] = true
			feedback.Text = ""
			render()
			scope:Spawn("Purchase" .. weaponId, function()
				local ok, response = pcall(function()
					return purchaseRemote:InvokeServer(weaponId)
				end)
				pendingPurchases[weaponId] = nil
				if not ok or type(response) ~= "table" then
					feedback.Text = "SHOP CONNECTION ERROR"
				elseif response.State then
					applyState(response.State)
					if response.Success then
						feedback.Text = string.format("UNLOCKED %s • TAP TO EQUIP", WeaponConfig.Get(weaponId).DisplayName)
						feedback.TextColor3 = Color3.fromRGB(184, 233, 160)
						scope:Tween("PurchasePulse", feedback, 0.6, { TextColor3 = Color3.fromRGB(235, 211, 129) })
					elseif response.Reason == "NOT_ENOUGH_COINS" then
						feedback.Text = "NOT ENOUGH COINS"
					elseif response.Reason == "ALREADY_OWNED" then
						feedback.Text = "ALREADY OWNED"
					else
						feedback.Text = "PURCHASE FAILED"
					end
				else
					feedback.Text = "PURCHASE FAILED"
				end
				render()
			end)
		end)
	end

	scope:Connect(shopButton.Activated, function()
		setOpen(true)
	end)
	scope:Connect(closeButton.Activated, function()
		setOpen(false)
	end)
	scope:Connect(OwnedWeaponSource.Changed, render)
	scope:Connect(player:GetAttributeChangedSignal("PlayerLevel"), render)
	scope:Connect(player:GetAttributeChangedSignal("EquippedWeapon"), function()
		confirmedEquipped = player:GetAttribute("EquippedWeapon")
		if shopOpen and WeaponConfig.IsValid(confirmedEquipped) then
			feedback.Text = string.format("EQUIPPED %s", WeaponConfig.Get(confirmedEquipped).DisplayName)
		end
		render()
	end)
	scope:Connect(stateChangedRemote.OnClientEvent, function(state)
		applyState(state)
	end)
	scope:Connect(progressionStateChanged.OnClientEvent, function(snapshot)
		if type(snapshot) == "table" then
			OwnedWeaponSource.ApplyAuthoritativeCoins(snapshot.Coins)
		end
	end)
	scope:OnDestroy(function()
		topbarScope:Destroy()
		topbarGui:Destroy()
		ProgressionHud.SetShopOpen(false)
		combatController.SetShopOpen(false)
		started = false
	end)

	render()
	syncState()
end

return ShopController
