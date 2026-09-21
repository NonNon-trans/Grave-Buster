--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WeaponConfig = require(ReplicatedStorage.Shared.WeaponConfig)

local OwnedWeaponSource = {}

function OwnedWeaponSource.GetOwnedWeapons(): { string }
	return table.clone(WeaponConfig.Order)
end

return OwnedWeaponSource
