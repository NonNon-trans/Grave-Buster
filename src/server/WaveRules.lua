--!strict

local WaveRules = {}

export type State = {
	Wave: number,
	TotalQuota: number,
	Spawned: number,
	Cleared: boolean,
}

function WaveRules.New(wave: number, totalQuota: number): State
	assert(wave >= 1 and wave % 1 == 0)
	assert(totalQuota >= 0 and totalQuota % 1 == 0)
	return { Wave = wave, TotalQuota = totalQuota, Spawned = 0, Cleared = false }
end

function WaveRules.CanSpawn(state: State, activeCount: number, maxAlive: number): boolean
	return not state.Cleared and state.Spawned < state.TotalQuota and activeCount < maxAlive
end

function WaveRules.RecordSpawn(state: State): boolean
	if state.Cleared or state.Spawned >= state.TotalQuota then
		return false
	end
	state.Spawned += 1
	return true
end

function WaveRules.TryMarkCleared(state: State, activeWaveCount: number): boolean
	if state.Cleared or state.Spawned < state.TotalQuota or activeWaveCount > 0 then
		return false
	end
	state.Cleared = true
	return true
end

return WaveRules
