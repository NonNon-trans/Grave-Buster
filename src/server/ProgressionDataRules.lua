--!strict

local ProgressionDataRules = {}

local SCHEMA_VERSION = 1
local MAX_PROFILE_INTEGER = 2_000_000_000

local function sanitizeInteger(value, minimum: number, fallback: number): number
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return fallback
	end
	return math.clamp(math.floor(value), minimum, MAX_PROFILE_INTEGER)
end

function ProgressionDataRules.DefaultProfile(defaultWeapon: string)
	return {
		SchemaVersion = SCHEMA_VERSION,
		Level = 1,
		XP = 0,
		Coins = 0,
		OwnedWeapons = { defaultWeapon },
		EquippedWeapon = defaultWeapon,
		BestWave = 1,
	}
end

function ProgressionDataRules.Sanitize(raw, weaponOrder: { string }, defaultWeapon: string)
	if type(raw) ~= "table" then
		return nil, "INVALID_PROFILE"
	end
	if raw.SchemaVersion ~= SCHEMA_VERSION then
		return nil, "UNSUPPORTED_SCHEMA"
	end

	local ownedSet = { [defaultWeapon] = true }
	if type(raw.OwnedWeapons) == "table" then
		for _, weaponId in raw.OwnedWeapons do
			if type(weaponId) == "string" and table.find(weaponOrder, weaponId) then
				ownedSet[weaponId] = true
			end
		end
	end
	local ownedWeapons = {}
	for _, weaponId in weaponOrder do
		if ownedSet[weaponId] then
			table.insert(ownedWeapons, weaponId)
		end
	end

	local equippedWeapon = raw.EquippedWeapon
	if type(equippedWeapon) ~= "string" or not ownedSet[equippedWeapon] then
		equippedWeapon = defaultWeapon
	end

	return {
		SchemaVersion = SCHEMA_VERSION,
		Level = sanitizeInteger(raw.Level, 1, 1),
		XP = sanitizeInteger(raw.XP, 0, 0),
		Coins = sanitizeInteger(raw.Coins, 0, 0),
		OwnedWeapons = ownedWeapons,
		EquippedWeapon = equippedWeapon,
		BestWave = sanitizeInteger(raw.BestWave, 1, 1),
	}
end

function ProgressionDataRules.FromState(state)
	return {
		SchemaVersion = SCHEMA_VERSION,
		Level = state.Level,
		XP = state.XP,
		Coins = state.Coins,
		OwnedWeapons = table.clone(state.OwnedWeapons),
		EquippedWeapon = state.EquippedWeapon,
		BestWave = state.BestWave,
	}
end

function ProgressionDataRules.ApplyToState(state, profile)
	state.Level = profile.Level
	state.XP = profile.XP
	state.Coins = profile.Coins
	state.OwnedWeapons = table.clone(profile.OwnedWeapons)
	state.EquippedWeapon = profile.EquippedWeapon
	state.BestWave = profile.BestWave
	return state
end

return ProgressionDataRules
