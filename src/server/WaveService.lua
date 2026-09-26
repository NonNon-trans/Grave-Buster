--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HordeConfig = require(ReplicatedStorage.Shared.HordeConfig)
local WaveRules = require(script.Parent.WaveRules)
local RunRules = require(script.Parent.RunRules)

local WaveService = {}
local WAVE_VALUE_NAME = "WaveNumber"
local WAVE_REMOTE_FOLDER = "WaveRemotes"
local WAVE_CLEARED_REMOTE = "WaveCleared"

local running = false
local currentWave = 0
local generation = 0
local resetInProgress = false
local waveClearedRemote: RemoteEvent? = nil
local waveValue: IntValue? = nil
local zombieServiceRef = nil
local progressionService = nil

type ZombieServiceApi = {
	HasValidTarget: () -> boolean,
	Spawn: (number) -> Model?,
	GetActiveCount: () -> number,
	GetActiveCountForWave: (number) -> number,
	ClearForNewRun: () -> (),
}

local function ensureWaveValue(): IntValue
	local existing = ReplicatedStorage:FindFirstChild(WAVE_VALUE_NAME)
	if existing and not existing:IsA("IntValue") then
		existing:Destroy()
		existing = nil
	end
	if not existing then
		existing = Instance.new("IntValue")
		existing.Name = WAVE_VALUE_NAME
		existing.Value = 0
		existing.Parent = ReplicatedStorage
	end
	return existing :: IntValue
end

local function ensureWaveClearedRemote(): RemoteEvent
	local folder = ReplicatedStorage:FindFirstChild(WAVE_REMOTE_FOLDER)
	if not folder or not folder:IsA("Folder") then
		if folder then
			folder:Destroy()
		end
		folder = Instance.new("Folder")
		folder.Name = WAVE_REMOTE_FOLDER
		folder.Parent = ReplicatedStorage
	end
	local existing = folder:FindFirstChild(WAVE_CLEARED_REMOTE)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local remote = Instance.new("RemoteEvent")
	remote.Name = WAVE_CLEARED_REMOTE
	remote.Parent = folder
	return remote
end

local function isCurrent(runGeneration: number): boolean
	return running and generation == runGeneration
end

local function waitForTarget(zombieService: ZombieServiceApi, runGeneration: number): boolean
	while isCurrent(runGeneration) and not zombieService.HasValidTarget() do
		task.wait(HordeConfig.NoTargetPollInterval)
	end
	return isCurrent(runGeneration)
end

local function runWaves(zombieService: ZombieServiceApi, runGeneration: number, initialDelay: number)
	if not waitForTarget(zombieService, runGeneration) then
		return
	end
	if initialDelay > 0 then
		task.wait(initialDelay)
	end
	while isCurrent(runGeneration) do
		if not waitForTarget(zombieService, runGeneration) then
			return
		end
		currentWave += 1
		local wave = currentWave
		local replicatedWaveValue = assert(waveValue, "WaveNumber is not initialized")
		replicatedWaveValue.Value = wave
		progressionService.RecordWaveReached(wave)
		local state = WaveRules.New(wave, HordeConfig.GetTotalSpawn(wave))

		while isCurrent(runGeneration) and state.Spawned < state.TotalQuota do
			if not waitForTarget(zombieService, runGeneration) then
				return
			end
			if WaveRules.CanSpawn(state, zombieService.GetActiveCount(), HordeConfig.MaxAliveZombies) then
				local zombie = zombieService.Spawn(wave)
				if zombie and WaveRules.RecordSpawn(state) then
					task.wait(HordeConfig.SpawnInterval)
				else
					task.wait(HordeConfig.CapPollInterval)
				end
			else
				task.wait(HordeConfig.CapPollInterval)
			end
		end

		while isCurrent(runGeneration) do
			if WaveRules.TryMarkCleared(state, zombieService.GetActiveCountForWave(wave)) then
				progressionService.AwardWaveClearBonus(wave)
				local clearedRemote = assert(waveClearedRemote, "Wave clear RemoteEvent is not initialized")
				clearedRemote:FireAllClients(wave)
				break
			end
			task.wait(HordeConfig.ClearPollInterval)
		end

		if HordeConfig.Intermission > 0 and isCurrent(runGeneration) then
			task.wait(HordeConfig.Intermission)
		end
	end
end

local function livingPlayerCount(excludedPlayer: Player?): number
	local count = 0
	for _, player in Players:GetPlayers() do
		if player ~= excludedPlayer then
			local character = player.Character
			local humanoid = if character and character.Parent == Workspace
				then character:FindFirstChildOfClass("Humanoid") else nil
			if humanoid and humanoid.Health > 0 then
				count += 1
			end
		end
	end
	return count
end

function WaveService.NotifyPlayerUnavailable(player: Player)
	if not RunRules.ShouldResetRun(livingPlayerCount(player), resetInProgress) then
		return false
	end
	resetInProgress = true
	generation += 1
	currentWave = 0
	progressionService.ResetRunWaveTracking()
	local replicatedWaveValue = waveValue
	if replicatedWaveValue then
		replicatedWaveValue.Value = 0
	end
	local zombieService = zombieServiceRef
	if zombieService then
		zombieService.ClearForNewRun()
		task.spawn(runWaves, zombieService, generation, 0)
	end
	return true
end

function WaveService.NotifyPlayerAvailable(_player: Player)
	resetInProgress = false
end

function WaveService.Start(zombieService: ZombieServiceApi, playerProgressionService)
	if running then
		return
	end
	running = true
	currentWave = 0
	generation += 1
	zombieServiceRef = zombieService
	progressionService = assert(playerProgressionService, "ProgressionService is required")
	progressionService.ResetRunWaveTracking()
	waveClearedRemote = ensureWaveClearedRemote()
	waveValue = ensureWaveValue()
	waveValue.Value = 0
	task.spawn(runWaves, zombieService, generation, HordeConfig.InitialDelay)
end

function WaveService.GetCurrentWave(): number
	return currentWave
end

return WaveService
