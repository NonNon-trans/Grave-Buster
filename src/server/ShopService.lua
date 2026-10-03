--!nonstrict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopConfig = require(ReplicatedStorage.Shared.ShopConfig)
local WeaponConfig = require(ReplicatedStorage.Shared.WeaponConfig)

local ShopService = {}
local REMOTE_FOLDER_NAME = "ShopRemotes"
local GET_STATE_NAME = "GetState"
local PURCHASE_NAME = "PurchaseRequest"
local STATE_CHANGED_NAME = "StateChanged"

local started = false
local purchaseLocks = {}
local stateRevisions = {}
local stateChangedRemote = nil
local progressionService = nil
local readyConnections = {}

local function ensureRemote(folder, className, name)
	local existing = folder:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = folder
	return remote
end

local function ensureRemotes()
	local folder = ReplicatedStorage:FindFirstChild(REMOTE_FOLDER_NAME)
	if folder and not folder:IsA("Folder") then
		folder:Destroy()
		folder = nil
	end
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = REMOTE_FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end
	return ensureRemote(folder, "RemoteFunction", GET_STATE_NAME),
		ensureRemote(folder, "RemoteFunction", PURCHASE_NAME),
		ensureRemote(folder, "RemoteEvent", STATE_CHANGED_NAME)
end

function ShopService.GetSnapshot(player)
	if not progressionService.IsReady(player) then
		return nil
	end
	return {
		Currency = progressionService.GetCoins(player),
		OwnedWeapons = progressionService.GetOwnedWeapons(player),
		EquippedWeapon = progressionService.GetEquippedWeapon(player),
		Revision = stateRevisions[player] or 1,
	}
end

function ShopService.IsOwned(player, weaponId): boolean
	return player.Parent == Players
		and progressionService.IsReady(player)
		and WeaponConfig.IsValid(weaponId)
		and progressionService.IsWeaponOwned(player, weaponId)
end

local function publishShopState(player: Player)
	local snapshot = ShopService.GetSnapshot(player)
	if snapshot then
		stateChangedRemote:FireClient(player, snapshot)
	end
end

local function bindPlayer(player: Player)
	if readyConnections[player] then
		return
	end
	readyConnections[player] = player:GetAttributeChangedSignal("ProgressionReady"):Connect(function()
		if progressionService.IsReady(player) then
			stateRevisions[player] = 1
			publishShopState(player)
		end
	end)
	if progressionService.IsReady(player) then
		stateRevisions[player] = 1
		publishShopState(player)
	end
end

local function purchase(player, weaponId, ...)
	if player.Parent ~= Players or select("#", ...) ~= 0 or not progressionService.IsReady(player) then
		return { Success = false, Reason = "NOT_READY" }
	end
	if purchaseLocks[player] then
		return { Success = false, Reason = "BUSY", State = ShopService.GetSnapshot(player) }
	end

	purchaseLocks[player] = true
	local callOk, success, reason = pcall(function()
		return progressionService.TryPurchaseWeapon(player, weaponId)
	end)
	purchaseLocks[player] = nil
	if not callOk then
		warn(string.format("[Shop] Purchase processing failed for user %d: %s", player.UserId, tostring(success)))
		return { Success = false, Reason = "PURCHASE_FAILED", State = ShopService.GetSnapshot(player) }
	end

	local snapshot = ShopService.GetSnapshot(player)
	if success then
		stateRevisions[player] = (stateRevisions[player] or 1) + 1
		snapshot = ShopService.GetSnapshot(player)
		progressionService.PublishState(player)
		stateChangedRemote:FireClient(player, snapshot)
	end
	return { Success = success, Reason = reason, State = snapshot }
end

function ShopService.Start(playerProgressionService)
	if started then
		return
	end
	started = true
	progressionService = assert(playerProgressionService, "ProgressionService is required")
	ShopConfig.Validate(WeaponConfig.Order)
	local getStateRemote, purchaseRemote, changedRemote = ensureRemotes()
	stateChangedRemote = changedRemote

	for _, player in Players:GetPlayers() do
		bindPlayer(player)
	end
	Players.PlayerAdded:Connect(bindPlayer)
	Players.PlayerRemoving:Connect(function(player)
		purchaseLocks[player] = nil
		stateRevisions[player] = nil
		local connection = readyConnections[player]
		if connection then
			connection:Disconnect()
			readyConnections[player] = nil
		end
	end)
	getStateRemote.OnServerInvoke = function(player, ...)
		if player.Parent ~= Players or select("#", ...) ~= 0 then
			return nil
		end
		return ShopService.GetSnapshot(player)
	end
	purchaseRemote.OnServerInvoke = purchase
end

return ShopService
