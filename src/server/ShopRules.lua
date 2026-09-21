--!strict

local ShopRules = {}

function ShopRules.NewSession(shopConfig)
	local owned = {}
	for _, weaponId in shopConfig.DefaultOwned do
		owned[weaponId] = true
	end
	return {
		Currency = shopConfig.StartCurrency,
		Owned = owned,
		Revision = 0,
	}
end

function ShopRules.TryPurchase(session, weaponId: unknown, shopConfig)
	if type(weaponId) ~= "string" then
		return false, "INVALID_WEAPON"
	end
	local price = shopConfig.Prices[weaponId]
	if type(price) ~= "number" or price < 0 or not table.find(shopConfig.Order, weaponId) then
		return false, "INVALID_WEAPON"
	end
	if session.Owned[weaponId] then
		return false, "ALREADY_OWNED"
	end
	if session.Currency < price then
		return false, "NOT_ENOUGH_COINS"
	end

	local newCurrency = session.Currency - price
	session.Owned[weaponId] = true
	session.Currency = newCurrency
	session.Revision += 1
	return true, "PURCHASED"
end

function ShopRules.GetOwnedWeapons(session, displayOrder)
	local ordered = {}
	for _, weaponId in displayOrder do
		if session.Owned[weaponId] then
			table.insert(ordered, weaponId)
		end
	end
	return ordered
end

return ShopRules
