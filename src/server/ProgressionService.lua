--!nonstrict

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopConfig = require(ReplicatedStorage.Shared.ShopConfig)
local WeaponConfig = require(ReplicatedStorage.Shared.WeaponConfig)
local ProgressionRules = require(script.Parent.ProgressionRules)
local ProgressionDataRules = require(script.Parent.ProgressionDataRules)
local ProgressionPersistence = require(script.Parent.ProgressionPersistence)
local ProgressionSessionStore = require(script.Parent.ProgressionSessionStore)
local RunRules = require(script.Parent.RunRules)
local ShopRules = require(script.Parent.ShopRules)

local ProgressionService = {}
local REMOTE_FOLDER_NAME = "ProgressionRemotes"
local STATE_CHANGED_NAME = "StateChanged"
local DATASTORE_NAME = "GraveBusterProgression_v1"
local AUTOSAVE_INTERVAL = 45
local DEFAULT_PROFILE_LOAD_FAILURE_MESSAGE = "Progression data could not load. Please rejoin shortly."

local started = false
local closing = false
local store = ProgressionSessionStore.new(ProgressionRules.NewState)
local stateChangedRemote = nil
local persistence = nil
local ready = {}
local loading = {}
local leaving = {}
local cancelledLoads = {}
local saving = {}
local sessionIds = {}
local currentRunWave = 0

local function ensureRemote(folder: Folder, name: string): RemoteEvent
	local existing = folder:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = folder
	return remote
end

local function ensureRemoteFolder(): Folder
	local existing = ReplicatedStorage:FindFirstChild(REMOTE_FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = REMOTE_FOLDER_NAME
	folder.Parent = ReplicatedStorage
	return folder
end

local function getState(player: Player)
	if not ready[player] or leaving[player] then
		return nil
	end
	return store:Get(player)
end

local function applySnapshot(player: Player, state)
	player:SetAttribute("PlayerLevel", state.Level)
	player:SetAttribute("CurrentXP", state.XP)
	player:SetAttribute("RequiredXP", ProgressionRules.RequiredXP(state.Level))
	player:SetAttribute("Coins", state.Coins)
	player:SetAttribute("BestWave", state.BestWave)
	player:SetAttribute("EquippedWeapon", state.EquippedWeapon)
end

local function publishSnapshot(player: Player, extra)
	local state = getState(player)
	if not state then
		return
	end
	applySnapshot(player, state)
	local snapshot = {
		Level = state.Level,
		CurrentXP = state.XP,
		RequiredXP = ProgressionRules.RequiredXP(state.Level),
		Coins = state.Coins,
		BestWave = state.BestWave,
	}
	if extra then
		for key, value in extra do
			snapshot[key] = value
		end
	end
	stateChangedRemote:FireClient(player, snapshot)
end

local function recordWaveForPlayer(player: Player, wave: number, showFeedback: boolean)
	local state = getState(player)
	if state and RunRules.RecordBestWave(state, wave) then
		publishSnapshot(player, if showFeedback then { NewRecord = true, RecordWave = wave } else nil)
	end
end

local function saveState(player: Player, state, sessionId: string, releaseSession: boolean): (boolean, string?)
	while saving[player] do
		task.wait(0.05)
	end
	if not state or not sessionId or not persistence then
		return false, "NO_LOADED_SESSION"
	end
	saving[player] = true
	local callOk, saved, reason = pcall(function()
		return persistence:Save(player.UserId, sessionId, state, releaseSession)
	end)
	saving[player] = nil
	if not callOk then
		warn(string.format("[Progression] Save failed for user %d: %s", player.UserId, tostring(saved)))
		return false, tostring(saved)
	end
	if not saved then
		warn(string.format("[Progression] Save failed for user %d: %s", player.UserId, tostring(reason)))
		if reason == "STALE_SESSION" and player.Parent == Players and not leaving[player] then
			player:Kick("Your progression session moved to another server. Please rejoin.")
		end
		return false, reason
	end
	return true, nil
end

local function savePlayer(player: Player, releaseSession: boolean): (boolean, string?)
	local state = store:Get(player)
	local sessionId = sessionIds[player]
	if not ready[player] or (leaving[player] and not releaseSession) then
		return false, "NO_LOADED_SESSION"
	end
	return saveState(player, state, sessionId, releaseSession)
end

local function initializePlayer(player: Player)
	if loading[player] or ready[player] then
		return
	end
	loading[player] = true
	player:SetAttribute("ProgressionReady", false)
	local sessionId = HttpService:GenerateGUID(false)
	sessionIds[player] = sessionId
	task.spawn(function()
		local result = if persistence
			then persistence:Load(player.UserId, sessionId)
			else { Status = "FAILURE", Reason = "DATASTORE_UNAVAILABLE" }
		loading[player] = nil

		if player.Parent ~= Players or cancelledLoads[player] then
			cancelledLoads[player] = nil
			if result.Status == "SUCCESS_NEW" or result.Status == "SUCCESS_EXISTING" then
				local abandonedState = ProgressionRules.NewState()
				ProgressionDataRules.ApplyToState(abandonedState, result.Profile)
				persistence:Save(player.UserId, sessionId, abandonedState, true)
			end
			sessionIds[player] = nil
			return
		end

		if result.Status ~= "SUCCESS_NEW" and result.Status ~= "SUCCESS_EXISTING" then
			warn(string.format(
				"[Progression] Refusing to initialize user %d after load failure: %s",
				player.UserId,
				tostring(result.Reason or result.Status)
			))
			player:SetAttribute("ProgressionReady", false)
			player:Kick(DEFAULT_PROFILE_LOAD_FAILURE_MESSAGE)
			return
		end

		local state = ProgressionRules.NewState()
		ProgressionDataRules.ApplyToState(state, result.Profile)
		store:Set(player, state)
		ready[player] = true
		applySnapshot(player, state)
		player:SetAttribute("ProgressionReady", true)
		if currentRunWave > 0 then
			recordWaveForPlayer(player, currentRunWave, true)
		end
		publishSnapshot(player)
		print(string.format("[Progression] Loaded user %d (%s)", player.UserId, result.Status))
	end)
end

local function removePlayer(player: Player)
	leaving[player] = true
	player:SetAttribute("ProgressionReady", false)
	if loading[player] then
		cancelledLoads[player] = true
	end
	local state = store:Get(player)
	local sessionId = sessionIds[player]
	if ready[player] and state and sessionId then
		saveState(player, state, sessionId, true)
	end
	ready[player] = nil
	loading[player] = nil
	sessionIds[player] = nil
	leaving[player] = nil
	store:Remove(player)
end

local function autosaveLoop()
	while not closing do
		task.wait(AUTOSAVE_INTERVAL)
		if closing then
			break
		end
		for _, player in Players:GetPlayers() do
			if ready[player] and not leaving[player] then
				task.spawn(savePlayer, player, false)
			end
		end
	end
end

local function saveAllOnClose()
	closing = true
	local pending = 0
	for _, player in Players:GetPlayers() do
		if ready[player] then
			pending += 1
			task.spawn(function()
				savePlayer(player, true)
				pending -= 1
			end)
		end
	end
	local deadline = os.clock() + 25
	while pending > 0 and os.clock() < deadline do
		task.wait(0.05)
	end
end

function ProgressionService.IsReady(player: Player): boolean
	return ready[player] == true and not leaving[player] and store:Get(player) ~= nil
end

function ProgressionService.GetLevel(player: Player): number
	local state = getState(player)
	return if state then state.Level else 1
end

function ProgressionService.GetCoins(player: Player): number
	local state = getState(player)
	return if state then state.Coins else 0
end

function ProgressionService.IsWeaponOwned(player: Player, weaponId: string): boolean
	local state = getState(player)
	return state ~= nil and table.find(state.OwnedWeapons, weaponId) ~= nil
end

function ProgressionService.GetOwnedWeapons(player: Player): { string }
	local state = getState(player)
	return if state then table.clone(state.OwnedWeapons) else {}
end

function ProgressionService.GetEquippedWeapon(player: Player): string?
	local state = getState(player)
	return if state then state.EquippedWeapon else nil
end

function ProgressionService.SetEquippedWeapon(player: Player, weaponId: string): boolean
	local state = getState(player)
	if not state or not WeaponConfig.IsValid(weaponId) or not table.find(state.OwnedWeapons, weaponId) then
		return false
	end
	state.EquippedWeapon = weaponId
	player:SetAttribute("EquippedWeapon", weaponId)
	return true
end

function ProgressionService.TryPurchaseWeapon(player: Player, weaponId: unknown): (boolean, string, number?)
	local state = getState(player)
	if not state or player.Parent ~= Players then
		return false, "NOT_READY", nil
	end
	local valid, reason, price = ShopRules.ValidatePurchase(state, state.Coins, weaponId, ShopConfig)
	if not valid or not price then
		return false, reason, nil
	end
	if not ProgressionRules.TrySpendCoins(state, price) then
		return false, "NOT_ENOUGH_COINS", nil
	end
	ShopRules.GrantPurchase(state, weaponId)
	applySnapshot(player, state)
	return true, "PURCHASED", price
end

function ProgressionService.TrySpendCoins(player: Player, amount: number): boolean
	local state = getState(player)
	if not state or player.Parent ~= Players then
		return false
	end
	if not ProgressionRules.TrySpendCoins(state, amount) then
		return false
	end
	applySnapshot(player, state)
	return true
end

function ProgressionService.PublishState(player: Player)
	if ProgressionService.IsReady(player) then
		publishSnapshot(player)
	end
end

function ProgressionService.ResolveFinalAttackDamage(player: Player, baseDamage: number): number
	return ProgressionRules.FinalAttackDamage(baseDamage, ProgressionService.GetLevel(player))
end

function ProgressionService.AwardZombieDefeats(player: Player, defeatsByWave: { [number]: number })
	if player.Parent ~= Players then
		return nil
	end
	local state = getState(player)
	if not state then
		return nil
	end
	local totalDefeats = 0
	for _, count in defeatsByWave do
		totalDefeats += count
	end
	if totalDefeats <= 0 then
		return nil
	end
	local result = ProgressionRules.AwardZombieDefeatsByWave(state, defeatsByWave)
	publishSnapshot(player, {
		CurrentXP = result.XP,
		XPGranted = result.XPGranted,
		CoinsGranted = result.CoinsGranted,
		LevelsGained = result.LevelsGained,
		OldLevel = result.OldLevel,
		DamageIncreasePercent = result.DamageIncreasePercent,
	})
	return result
end

function ProgressionService.AwardWaveClearBonus(wave: number): number
	local amount = ProgressionRules.WaveClearBonus(wave)
	for _, player in Players:GetPlayers() do
		local state = getState(player)
		if state and store:ClaimWaveBonus(player, wave) then
			ProgressionRules.AwardWaveClearBonus(state, wave)
			publishSnapshot(player, { WaveClearBonus = amount, ClearedWave = wave })
		end
	end
	return amount
end

function ProgressionService.RecordWaveReached(wave: number)
	currentRunWave = wave
	for _, player in Players:GetPlayers() do
		recordWaveForPlayer(player, wave, true)
	end
end

function ProgressionService.ResetRunWaveTracking()
	currentRunWave = 0
end

function ProgressionService.Start()
	if started then
		return
	end
	started = true
	stateChangedRemote = ensureRemote(ensureRemoteFolder(), STATE_CHANGED_NAME)
	ShopConfig.Validate(WeaponConfig.Order)
	local dataStoreOk, dataStore = pcall(function()
		return DataStoreService:GetDataStore(DATASTORE_NAME)
	end)
	if dataStoreOk then
		persistence = ProgressionPersistence.new(dataStore, ProgressionDataRules, {
			WeaponOrder = WeaponConfig.Order,
			DefaultWeapon = WeaponConfig.DefaultWeapon,
		})
	else
		warn(string.format("[Progression] DataStore unavailable: %s", tostring(dataStore)))
	end

	Players.PlayerAdded:Connect(initializePlayer)
	Players.PlayerRemoving:Connect(removePlayer)
	for _, player in Players:GetPlayers() do
		initializePlayer(player)
	end
	game:BindToClose(saveAllOnClose)
	task.spawn(autosaveLoop)
end

return ProgressionService
