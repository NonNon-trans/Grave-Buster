--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HordeConfig = require(ReplicatedStorage.Shared.HordeConfig)
local WaveRules = require(script.Parent.WaveRules)

local WaveService = {}
local WAVE_VALUE_NAME = "WaveNumber"
local WAVE_REMOTE_FOLDER = "WaveRemotes"
local WAVE_CLEARED_REMOTE = "WaveCleared"

local running = false
local currentWave = 0
local waveClearedRemote: RemoteEvent? = nil
local progressionService = nil

type ZombieServiceApi = {
	HasValidTarget: () -> boolean,
	Spawn: (number) -> Model?,
	GetActiveCount: () -> number,
	GetActiveCountForWave: (number) -> number,
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

local function waitForTarget(zombieService: ZombieServiceApi): boolean
	while running and not zombieService.HasValidTarget() do
		task.wait(HordeConfig.NoTargetPollInterval)
	end
	return running
end

local function runWaves(zombieService: ZombieServiceApi, waveValue: IntValue)
	if not waitForTarget(zombieService) then
		return
	end
	task.wait(HordeConfig.InitialDelay)
	while running do
		if not waitForTarget(zombieService) then
			return
		end
		currentWave += 1
		waveValue.Value = currentWave
		local state = WaveRules.New(currentWave, HordeConfig.GetTotalSpawn(currentWave))

		while running and state.Spawned < state.TotalQuota do
			if not waitForTarget(zombieService) then
				return
			end
			if WaveRules.CanSpawn(state, zombieService.GetActiveCount(), HordeConfig.MaxAliveZombies) then
				local zombie = zombieService.Spawn(currentWave)
				if zombie and WaveRules.RecordSpawn(state) then
					task.wait(HordeConfig.SpawnInterval)
				else
					-- A race for the last cap slot leaves the quota untouched.
					task.wait(HordeConfig.CapPollInterval)
				end
			else
				-- Keep the unsatisfied quota and resume as soon as a cap slot opens.
				task.wait(HordeConfig.CapPollInterval)
			end
		end

		while running do
			if WaveRules.TryMarkCleared(state, zombieService.GetActiveCountForWave(currentWave)) then
				progressionService.AwardWaveClearBonus(currentWave)
				local clearedRemote = assert(waveClearedRemote, "Wave clear RemoteEvent is not initialized")
				clearedRemote:FireAllClients(currentWave)
				break
			end
			task.wait(HordeConfig.ClearPollInterval)
		end

		if HordeConfig.Intermission > 0 then
			task.wait(HordeConfig.Intermission)
		end
	end
end

function WaveService.Start(zombieService: ZombieServiceApi, playerProgressionService)
	if running then
		return
	end
	running = true
	progressionService = assert(playerProgressionService, "ProgressionService is required")
	currentWave = 0
	waveClearedRemote = ensureWaveClearedRemote()
	local waveValue = ensureWaveValue()
	waveValue.Value = 0
	task.spawn(runWaves, zombieService, waveValue)
end

function WaveService.GetCurrentWave(): number
	return currentWave
end

return WaveService
