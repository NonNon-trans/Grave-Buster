--!strict

local ProgressionPersistence = {}
ProgressionPersistence.__index = ProgressionPersistence

local DEFAULT_ATTEMPTS = 3
local DEFAULT_RETRY_DELAY = 1
local DEFAULT_LEASE_SECONDS = 120

local function waitBeforeRetry(waitFunction, attempt: number, baseDelay: number)
	waitFunction(baseDelay * attempt)
end

local function makeRecord(profile, sessionId: string, expiresAt: number)
	local record = table.clone(profile)
	record.SessionId = sessionId
	record.SessionExpiresAt = expiresAt
	return record
end

function ProgressionPersistence.new(dataStore, dataRules, options)
	options = options or {}
	return setmetatable({
		DataStore = dataStore,
		DataRules = dataRules,
		WeaponOrder = options.WeaponOrder,
		DefaultWeapon = options.DefaultWeapon,
		Now = options.Now or os.time,
		Wait = options.Wait or task.wait,
		Attempts = options.Attempts or DEFAULT_ATTEMPTS,
		RetryDelay = options.RetryDelay or DEFAULT_RETRY_DELAY,
		LeaseSeconds = options.LeaseSeconds or DEFAULT_LEASE_SECONDS,
		KeyPrefix = options.KeyPrefix or "Player_",
	}, ProgressionPersistence)
end

function ProgressionPersistence:Load(userId: number, sessionId: string)
	local key = self.KeyPrefix .. tostring(userId)
	local lastReason = "DATASTORE_ERROR"
	for attempt = 1, self.Attempts do
		local transformStatus = "FAILURE"
		local transformReason = nil
		local ok, record = pcall(function()
			return self.DataStore:UpdateAsync(key, function(oldRecord)
				local now = self.Now()
				if oldRecord == nil then
					transformStatus = "SUCCESS_NEW"
					return makeRecord(
						self.DataRules.DefaultProfile(self.DefaultWeapon),
						sessionId,
						now + self.LeaseSeconds
					)
				end
				if type(oldRecord) ~= "table" then
					transformReason = "INVALID_RECORD"
					return nil
				end
				local sanitized, reason = self.DataRules.Sanitize(oldRecord, self.WeaponOrder, self.DefaultWeapon)
				if not sanitized then
					transformReason = reason
					return nil
				end
				local activeLease = type(oldRecord.SessionId) == "string"
					and oldRecord.SessionId ~= sessionId
					and type(oldRecord.SessionExpiresAt) == "number"
					and oldRecord.SessionExpiresAt > now
				if activeLease then
					transformReason = "SESSION_ACTIVE"
					return nil
				end
				transformStatus = "SUCCESS_EXISTING"
				return makeRecord(sanitized, sessionId, now + self.LeaseSeconds)
			end)
		end)

		if ok and type(record) == "table" and record.SessionId == sessionId then
			local profile, reason = self.DataRules.Sanitize(record, self.WeaponOrder, self.DefaultWeapon)
			if profile then
				return { Status = transformStatus, Profile = profile }
			end
			lastReason = reason
		elseif ok then
			lastReason = transformReason or "UPDATE_CANCELLED"
		else
			lastReason = tostring(record)
		end

		if attempt < self.Attempts then
			waitBeforeRetry(self.Wait, attempt, self.RetryDelay)
		end
	end
	return { Status = "FAILURE", Reason = lastReason }
end

function ProgressionPersistence:Save(userId: number, sessionId: string, state, releaseSession: boolean?): (boolean, string?)
	local key = self.KeyPrefix .. tostring(userId)
	local snapshot = self.DataRules.FromState(state)
	local sanitized, reason = self.DataRules.Sanitize(snapshot, self.WeaponOrder, self.DefaultWeapon)
	if not sanitized then
		return false, reason
	end

	local lastReason = "DATASTORE_ERROR"
	for attempt = 1, self.Attempts do
		local transformReason = nil
		local transformApplied = false
		local ok, record = pcall(function()
			return self.DataStore:UpdateAsync(key, function(oldRecord)
				transformApplied = false
				if type(oldRecord) ~= "table" then
					transformReason = "MISSING_RECORD"
					return nil
				end
				if oldRecord.SessionId ~= sessionId then
					transformReason = "STALE_SESSION"
					return nil
				end
				transformApplied = true
				local nextRecord = makeRecord(sanitized, sessionId, self.Now() + self.LeaseSeconds)
				if releaseSession then
					nextRecord.SessionId = nil
					nextRecord.SessionExpiresAt = nil
				end
				return nextRecord
			end)
		end)
		if ok and transformApplied and type(record) == "table"
			and (record.SessionId == sessionId or (releaseSession and record.SessionId == nil)) then
			return true, nil
		end
		lastReason = if ok then transformReason or "UPDATE_CANCELLED" else tostring(record)
		if lastReason == "STALE_SESSION" or lastReason == "MISSING_RECORD" then
			return false, lastReason
		end
		if attempt < self.Attempts then
			waitBeforeRetry(self.Wait, attempt, self.RetryDelay)
		end
	end
	return false, lastReason
end

return ProgressionPersistence
