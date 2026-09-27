--!strict

local ShopConfig = require("../src/shared/ShopConfig")
local ShopRules = require("../src/server/ShopRules")
local ProgressionRules = require("../src/server/ProgressionRules")

local economy = ProgressionRules.NewState()
assert(economy.Coins == 0)
assert(table.find(economy.OwnedWeapons, "BASEBALL_BAT") and not table.find(economy.OwnedWeapons, "FRYING_PAN"))
assert(#ShopRules.GetOwnedWeapons(economy, ShopConfig.Order) == 1)

local success, reason, localPrice = ShopRules.ValidatePurchase(economy, economy.Coins, "FRYING_PAN", ShopConfig)
assert(not success and reason == "NOT_ENOUGH_COINS")
assert(economy.Coins == 0 and not table.find(economy.OwnedWeapons, "FRYING_PAN"))

economy.Coins = 100
success, reason, localPrice = ShopRules.ValidatePurchase(economy, economy.Coins, "FRYING_PAN", ShopConfig)
assert(success and reason == "PURCHASED" and localPrice == 80)
assert(ProgressionRules.TrySpendCoins(economy, localPrice))
ShopRules.GrantPurchase(economy, "FRYING_PAN")
assert(economy.Coins == 20 and table.find(economy.OwnedWeapons, "FRYING_PAN"))

local equippedWeapon = "BASEBALL_BAT"
assert(equippedWeapon == "BASEBALL_BAT", "Purchase must not auto-equip")
success, reason = ShopRules.ValidatePurchase(economy, economy.Coins, "FRYING_PAN", ShopConfig)
assert(not success and reason == "ALREADY_OWNED")
assert(economy.Coins == 20)

success, reason = ShopRules.ValidatePurchase(economy, economy.Coins, "UNKNOWN", ShopConfig)
assert(not success and reason == "INVALID_WEAPON")
success, reason = ShopRules.ValidatePurchase(economy, economy.Coins, -1, ShopConfig)
assert(not success and reason == "INVALID_WEAPON")
success, reason = ShopRules.ValidatePurchase(economy, economy.Coins, "GIANT_HAMMER", ShopConfig, -999)
assert(not success and reason == "NOT_ENOUGH_COINS", "Client-supplied fake price must be ignored")

local richState = ProgressionRules.NewState()
richState.Coins = 800
for _, weaponId in { "FRYING_PAN", "GIANT_HAMMER", "BLOWER" } do
	local valid, _, price = ShopRules.ValidatePurchase(richState, richState.Coins, weaponId, ShopConfig)
	assert(valid and ProgressionRules.TrySpendCoins(richState, price))
	ShopRules.GrantPurchase(richState, weaponId)
end
assert(richState.Coins == 0)
local owned = ShopRules.GetOwnedWeapons(richState, ShopConfig.Order)
assert(table.concat(owned, ",") == "BASEBALL_BAT,FRYING_PAN,GIANT_HAMMER,BLOWER")

print("PASS ShopRules: server price validation, coin-backed purchase, ordered ownership, and no auto-equip")
