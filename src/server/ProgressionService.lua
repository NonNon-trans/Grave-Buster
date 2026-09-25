--!nonstrict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProgressionRules = require(script.Parent.ProgressionRules)
local ProgressionSessionStore = require(script.Parent.ProgressionSessionStore)

local ProgressionService = {}
local REMOTE_FOLDER_NAME = "ProgressionRemotes"
local STATE_CHANGED_NAME = "StateChanged"

local started = false
local store = ProgressionSessionStore.new(ProgressionRules.NewState)
local stateChangedRemote = nil

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

local function applySnapshot(player: Player, state: ProgressionRules.State)
	player:SetAttribute("PlayerLevel", state.Level)
	player:SetAttribute("CurrentXP", state.XP)
	player:SetAttribute("RequiredXP", ProgressionRules.RequiredXP(state.Level))
	player:SetAttribute("Coins", state.Coins)
end

local function publishSnapshot(player: Player, extra)
	local state = store:GetOrCreate(player)
	applySnapshot(player, state)
	local snapshot = {
		Level = state.Level,
		CurrentXP = state.XP,
		RequiredXP = ProgressionRules.RequiredXP(state.Level),
		Coins = state.Coins,
	}
	if extra then
		for key, value in extra do
			snapshot[key] = value
		end
	end
	stateChangedRemote:FireClient(player, snapshot)
end

local function initializePlayer(player: Player)
	applySnapshot(player, store:GetOrCreate(player))
end

function ProgressionService.GetLevel(player: Player): number
	return store:GetOrCreate(player).Level
end

function ProgressionService.GetCoins(player: Player): number
	return store:GetOrCreate(player).Coins
end

function ProgressionService.TrySpendCoins(player: Player, amount: number): boolean
	if player.Parent ~= Players then
		return false
	end
	local state = store:GetOrCreate(player)
	if not ProgressionRules.TrySpendCoins(state, amount) then
		return false
	end
	applySnapshot(player, state)
	return true
end

function ProgressionService.PublishState(player: Player)
	if player.Parent == Players then
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
	local totalDefeats = 0
	for _, count in defeatsByWave do
		totalDefeats += count
	end
	if totalDefeats <= 0 then
		return nil
	end
	local state = store:GetOrCreate(player)
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
		if store:ClaimWaveBonus(player, wave) then
			local state = store:GetOrCreate(player)
			ProgressionRules.AwardWaveClearBonus(state, wave)
			publishSnapshot(player, { WaveClearBonus = amount, ClearedWave = wave })
		end
	end
	return amount
end

function ProgressionService.Start()
	if started then
		return
	end
	started = true
	stateChangedRemote = ensureRemote(ensureRemoteFolder(), STATE_CHANGED_NAME)
	for _, player in Players:GetPlayers() do
		initializePlayer(player)
	end
	Players.PlayerAdded:Connect(initializePlayer)
	Players.PlayerRemoving:Connect(function(player)
		store:Remove(player)
	end)
end

return ProgressionService
