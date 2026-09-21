--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WeaponConfig = require(ReplicatedStorage.Shared.WeaponConfig)

local OwnedWeaponSource = {}
local changed = Instance.new("BindableEvent")
local ownedWeapons = { WeaponConfig.DefaultWeapon }
local currency = 0
local revision = -1

OwnedWeaponSource.Changed = changed.Event

function OwnedWeaponSource.GetOwnedWeapons(): { string }
	return table.clone(ownedWeapons)
end

function OwnedWeaponSource.GetCurrency(): number
	return currency
end

function OwnedWeaponSource.ApplyAuthoritativeState(state): boolean
	if type(state) ~= "table"
		or type(state.Currency) ~= "number"
		or state.Currency < 0
		or type(state.OwnedWeapons) ~= "table"
		or type(state.Revision) ~= "number"
		or state.Revision <= revision then
		return false
	end

	local supplied = {}
	for _, weaponId in state.OwnedWeapons do
		if WeaponConfig.IsValid(weaponId) then
			supplied[weaponId] = true
		end
	end
	local ordered = {}
	for _, weaponId in WeaponConfig.Order do
		if supplied[weaponId] then
			table.insert(ordered, weaponId)
		end
	end
	if #ordered == 0 then
		return false
	end

	ownedWeapons = ordered
	currency = math.floor(state.Currency)
	revision = state.Revision
	changed:Fire()
	return true
end

return OwnedWeaponSource
