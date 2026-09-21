--!nonstrict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopConfig = require(ReplicatedStorage.Shared.ShopConfig)
local WeaponConfig = require(ReplicatedStorage.Shared.WeaponConfig)
local ShopRules = require(script.Parent.ShopRules)
local ShopSessionStore = require(script.Parent.ShopSessionStore)

local ShopService = {}
local REMOTE_FOLDER_NAME = "ShopRemotes"
local GET_STATE_NAME = "GetState"
local PURCHASE_NAME = "PurchaseRequest"
local STATE_CHANGED_NAME = "StateChanged"

local started = false
local store = ShopSessionStore.new(function()
	return ShopRules.NewSession(ShopConfig)
end)
local purchaseLocks = {}
local stateChangedRemote = nil

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

local function initializePlayer(player)
	local session = store:GetOrCreate(player)
	local equipped = player:GetAttribute("EquippedWeapon")
	if not WeaponConfig.IsValid(equipped) or not session.Owned[equipped] then
		player:SetAttribute("EquippedWeapon", WeaponConfig.DefaultWeapon)
	end
end

function ShopService.GetSnapshot(player)
	local session = store:GetOrCreate(player)
	return {
		Currency = session.Currency,
		OwnedWeapons = ShopRules.GetOwnedWeapons(session, ShopConfig.Order),
		EquippedWeapon = player:GetAttribute("EquippedWeapon"),
		Revision = session.Revision,
	}
end

function ShopService.IsOwned(player, weaponId): boolean
	if player.Parent ~= Players then
		return false
	end
	local session = store:GetOrCreate(player)
	return session.Owned[weaponId] == true
end

local function purchase(player, weaponId, ...)
	if player.Parent ~= Players or select("#", ...) ~= 0 then
		return { Success = false, Reason = "INVALID_REQUEST" }
	end
	if purchaseLocks[player] then
		return { Success = false, Reason = "BUSY", State = ShopService.GetSnapshot(player) }
	end

	purchaseLocks[player] = true
	local session = store:GetOrCreate(player)
	local success, reason = ShopRules.TryPurchase(session, weaponId, ShopConfig)
	local snapshot = ShopService.GetSnapshot(player)
	purchaseLocks[player] = nil
	if success then
		stateChangedRemote:FireClient(player, snapshot)
	end
	return { Success = success, Reason = reason, State = snapshot }
end

function ShopService.Start()
	if started then
		return
	end
	started = true
	ShopConfig.Validate(WeaponConfig.Order)
	local getStateRemote, purchaseRemote, changedRemote = ensureRemotes()
	stateChangedRemote = changedRemote

	for _, player in Players:GetPlayers() do
		initializePlayer(player)
	end
	Players.PlayerAdded:Connect(initializePlayer)
	Players.PlayerRemoving:Connect(function(player)
		purchaseLocks[player] = nil
		store:Remove(player)
	end)
	getStateRemote.OnServerInvoke = function(player, ...)
		if player.Parent ~= Players or select("#", ...) ~= 0 then
			return nil
		end
		initializePlayer(player)
		return ShopService.GetSnapshot(player)
	end
	purchaseRemote.OnServerInvoke = purchase
end

return ShopService
