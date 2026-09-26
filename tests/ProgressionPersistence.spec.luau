--!strict

local ProgressionDataRules = require("../src/server/ProgressionDataRules")
local ProgressionPersistence = require("../src/server/ProgressionPersistence")
local WeaponConfig = require("../src/shared/WeaponConfig")

local function makeState()
	return {
		Level = 8,
		XP = 320,
		Coins = 740,
		OwnedWeapons = { "BASEBALL_BAT", "FRYING_PAN", "GIANT_HAMMER" },
		EquippedWeapon = "GIANT_HAMMER",
		BestWave = 17,
		CurrentWave = 8,
		CurrentHP = 42,
		SessionKills = 33,
	}
end

local function makeStore()
	local store = { Records = {}, FailuresRemaining = 0, Calls = 0 }
	function store:UpdateAsync(key, transform)
		self.Calls += 1
		if self.FailuresRemaining > 0 then
			self.FailuresRemaining -= 1
			error("mock DataStore failure")
		end
		local updated = transform(self.Records[key])
		if updated ~= nil then
			self.Records[key] = updated
		end
		return self.Records[key]
	end
	return store
end

local now = 1_000
local function newPersistence(store)
	return ProgressionPersistence.new(store, ProgressionDataRules, {
		WeaponOrder = WeaponConfig.Order,
		DefaultWeapon = WeaponConfig.DefaultWeapon,
		Now = function() return now end,
		Wait = function() end,
		Attempts = 3,
		RetryDelay = 0,
		LeaseSeconds = 120,
	})
end

local default = ProgressionDataRules.DefaultProfile(WeaponConfig.DefaultWeapon)
assert(default.SchemaVersion == 1 and default.Level == 1 and default.XP == 0 and default.Coins == 0)
assert(default.BestWave == 1 and #default.OwnedWeapons == 1)
assert(default.OwnedWeapons[1] == "BASEBALL_BAT" and default.EquippedWeapon == "BASEBALL_BAT")

local profile = ProgressionDataRules.FromState(makeState())
assert(profile.Level == 8 and profile.XP == 320 and profile.Coins == 740 and profile.BestWave == 17)
assert(profile.EquippedWeapon == "GIANT_HAMMER" and #profile.OwnedWeapons == 3)
assert(profile.CurrentWave == nil and profile.CurrentHP == nil and profile.SessionKills == nil)

local sanitized = ProgressionDataRules.Sanitize({
	SchemaVersion = 1,
	Level = -5,
	XP = -20,
	Coins = 20.9,
	BestWave = 0,
	OwnedWeapons = { "UNKNOWN_WEAPON", "THUNDER_ROD", "THUNDER_ROD" },
	EquippedWeapon = "UNKNOWN_WEAPON",
}, WeaponConfig.Order, WeaponConfig.DefaultWeapon)
assert(sanitized.Level == 1 and sanitized.XP == 0 and sanitized.Coins == 20 and sanitized.BestWave == 1)
assert(sanitized.EquippedWeapon == "BASEBALL_BAT")
assert(#sanitized.OwnedWeapons == 2 and sanitized.OwnedWeapons[1] == "BASEBALL_BAT")
assert(ProgressionDataRules.Sanitize({ SchemaVersion = 2 }, WeaponConfig.Order, WeaponConfig.DefaultWeapon) == nil)

local store = makeStore()
local persistence = newPersistence(store)
local firstLoad = persistence:Load(1001, "server-A")
assert(firstLoad.Status == "SUCCESS_NEW")
local originalState = ProgressionDataRules.ApplyToState({}, firstLoad.Profile)
assert(originalState.BestWave == 1 and originalState.EquippedWeapon == "BASEBALL_BAT")

local sessionState = makeState()
local saved, saveReason = persistence:Save(1001, "server-A", sessionState, true)
assert(saved and saveReason == nil)
assert(sessionState.Level == 8 and sessionState.Coins == 740, "Save failure/success must not mutate session state")
local savedRecord = store.Records["Player_1001"]
assert(savedRecord.SchemaVersion == 1 and savedRecord.SessionId == nil)
assert(savedRecord.CurrentWave == nil and savedRecord.CurrentHP == nil and savedRecord.SessionKills == nil)

now += 1
local nextSessionLoad = persistence:Load(1001, "server-B")
assert(nextSessionLoad.Status == "SUCCESS_EXISTING")
assert(nextSessionLoad.Profile.Level == 8 and nextSessionLoad.Profile.XP == 320)
assert(nextSessionLoad.Profile.Coins == 740 and nextSessionLoad.Profile.BestWave == 17)
assert(nextSessionLoad.Profile.EquippedWeapon == "GIANT_HAMMER")
assert(#nextSessionLoad.Profile.OwnedWeapons == 3)

local playerBLoad = persistence:Load(1002, "server-B")
assert(playerBLoad.Status == "SUCCESS_NEW" and playerBLoad.Profile.Coins == 0)

local beforeFailureRecord = table.clone(store.Records["Player_1001"])
store.FailuresRemaining = 3
local failedLoad = persistence:Load(1001, "server-C")
assert(failedLoad.Status == "FAILURE", "Load API failure must stay distinguishable from new data")
assert(store.Records["Player_1001"] == beforeFailureRecord or store.Records["Player_1001"].SessionId == beforeFailureRecord.SessionId)

local unavailableStore = makeStore()
unavailableStore.FailuresRemaining = 3
local failedFirstLoad = newPersistence(unavailableStore):Load(1003, "server-C")
assert(failedFirstLoad.Status == "FAILURE" and unavailableStore.Records["Player_1003"] == nil,
	"A failed first load must not write or finalize a default profile")

store.FailuresRemaining = 3
local saveState = makeState()
local failedSave, failedSaveReason = persistence:Save(1002, "server-B", saveState, false)
assert(not failedSave and failedSaveReason ~= nil)
assert(saveState.Level == 8 and saveState.Coins == 740, "Save failure must preserve session memory")
store.FailuresRemaining = 0
local playerBState = ProgressionDataRules.ApplyToState({}, playerBLoad.Profile)
playerBState.Coins = 25
local playerBSaved = persistence:Save(1002, "server-B", playerBState, true)
assert(playerBSaved and store.Records["Player_1002"].Coins == 25)
assert(store.Records["Player_1001"].Level == 8 and store.Records["Player_1001"].Coins == 740,
	"A separate player's save must not mutate this player's record")

now += 121
local takeover = persistence:Load(1001, "server-D")
assert(takeover.Status == "SUCCESS_EXISTING")
local staleSave, staleReason = persistence:Save(1001, "server-B", makeState(), false)
assert(not staleSave and staleReason == "STALE_SESSION", "An old server cannot overwrite a newer session")
assert(store.Records["Player_1001"].SessionId == "server-D")

print("PASS ProgressionPersistence: schema/defaults, sanitized round-trip, run-state exclusion, load/save failures, player isolation, and stale-session protection")
