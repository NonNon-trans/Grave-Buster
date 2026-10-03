--!strict

local ShopRules = {}

local function isOwned(profile, weaponId: string): boolean
	return table.find(profile.OwnedWeapons, weaponId) ~= nil
end

function ShopRules.ValidatePurchase(session, coins: number, weaponId: unknown, shopConfig)
	if type(weaponId) ~= "string" then
		return false, "INVALID_WEAPON"
	end
	local price = shopConfig.Prices[weaponId]
	if type(price) ~= "number" or price < 0 or not table.find(shopConfig.Order, weaponId) then
		return false, "INVALID_WEAPON"
	end
	if isOwned(session, weaponId) then
		return false, "ALREADY_OWNED"
	end
	if coins < price then
		return false, "NOT_ENOUGH_COINS"
	end
	return true, "PURCHASED", price
end

function ShopRules.GrantPurchase(session, weaponId: string)
	assert(not isOwned(session, weaponId), "Weapon must not already be owned")
	table.insert(session.OwnedWeapons, weaponId)
	return true
end

function ShopRules.GetOwnedWeapons(session, displayOrder)
	local ordered = {}
	for _, weaponId in displayOrder do
		if isOwned(session, weaponId) then
			table.insert(ordered, weaponId)
		end
	end
	return ordered
end

return ShopRules
