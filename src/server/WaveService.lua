--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HordeConfig = require(ReplicatedStorage.Shared.HordeConfig)

local WaveService = {}
local WAVE_VALUE_NAME = "WaveNumber"

local running = false
local currentWave = 0

type ZombieServiceApi = {
	HasValidTarget: () -> boolean,
	Spawn: () -> Model?,
}

local function getWaveValue(): IntValue
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
		local spawnCount = HordeConfig.GetWaveSpawnCount(currentWave)
		for _ = 1, spawnCount do
			if not running then
				return
			end
			if zombieService.HasValidTarget() then
				zombieService.Spawn() -- A full active cap intentionally skips this slot.
			else
				if not waitForTarget(zombieService) then
					return
				end
				zombieService.Spawn()
			end
			task.wait(HordeConfig.SpawnInterval)
		end
		task.wait(HordeConfig.Intermission)
	end
end

function WaveService.Start(zombieService: ZombieServiceApi)
	if running then
		return
	end
	running = true
	currentWave = 0
	local waveValue = getWaveValue()
	waveValue.Value = 0
	task.spawn(runWaves, zombieService, waveValue)
end

function WaveService.GetCurrentWave(): number
	return currentWave
end

return WaveService
