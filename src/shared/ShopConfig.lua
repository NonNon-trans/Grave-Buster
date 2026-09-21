--!strict

local ShopConfig = {
	StartCurrency = 2000,
	Order = { "BASEBALL_BAT", "FRYING_PAN", "GIANT_HAMMER", "BLOWER", "THUNDER_ROD" },
	DefaultOwned = { "BASEBALL_BAT" },
	Prices = {
		BASEBALL_BAT = 0,
		FRYING_PAN = 200,
		GIANT_HAMMER = 400,
		BLOWER = 600,
		THUNDER_ROD = 1000,
	},
}

function ShopConfig.Validate(weaponOrder: { string }): boolean
	assert(ShopConfig.StartCurrency >= 0)
	assert(#ShopConfig.Order == #weaponOrder)
	for index, weaponId in ShopConfig.Order do
		assert(weaponId == weaponOrder[index], "Shop and weapon display order must match")
		local price = ShopConfig.Prices[weaponId]
		assert(type(price) == "number" and price >= 0 and price % 1 == 0)
	end
	for _, weaponId in ShopConfig.DefaultOwned do
		assert(table.find(ShopConfig.Order, weaponId), `Unknown default-owned weapon: {weaponId}`)
	end
	return true
end

return table.freeze(ShopConfig)
