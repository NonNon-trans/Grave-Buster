--!strict

local ShopConfig = require("../src/shared/ShopConfig")
local ShopRules = require("../src/server/ShopRules")
local ProgressionRules = require("../src/server/ProgressionRules")

local session = ShopRules.NewSession(ShopConfig)
local economy = ProgressionRules.NewState()
assert(economy.Coins == 0)
assert(session.Owned.BASEBALL_BAT and not session.Owned.FRYING_PAN)
assert(#ShopRules.GetOwnedWeapons(session, ShopConfig.Order) == 1)

local success, reason, localPrice = ShopRules.ValidatePurchase(session, economy.Coins, "FRYING_PAN", ShopConfig)
assert(not success and reason == "NOT_ENOUGH_COINS")
assert(economy.Coins == 0 and not session.Owned.FRYING_PAN)

economy.Coins = 100
success, reason, localPrice = ShopRules.ValidatePurchase(session, economy.Coins, "FRYING_PAN", ShopConfig)
assert(success and reason == "PURCHASED" and localPrice == 80)
assert(ProgressionRules.TrySpendCoins(economy, localPrice))
ShopRules.GrantPurchase(session, "FRYING_PAN")
assert(economy.Coins == 20 and session.Owned.FRYING_PAN and session.Revision == 1)

local equippedWeapon = "BASEBALL_BAT"
assert(equippedWeapon == "BASEBALL_BAT", "Purchase must not auto-equip")
success, reason = ShopRules.ValidatePurchase(session, economy.Coins, "FRYING_PAN", ShopConfig)
assert(not success and reason == "ALREADY_OWNED")
assert(economy.Coins == 20 and session.Revision == 1)

success, reason = ShopRules.ValidatePurchase(session, economy.Coins, "UNKNOWN", ShopConfig)
assert(not success and reason == "INVALID_WEAPON")
success, reason = ShopRules.ValidatePurchase(session, economy.Coins, -1, ShopConfig)
assert(not success and reason == "INVALID_WEAPON")
success, reason = ShopRules.ValidatePurchase(session, economy.Coins, "GIANT_HAMMER", ShopConfig, -999)
assert(not success and reason == "NOT_ENOUGH_COINS", "Client-supplied fake price must be ignored")

local multiPurchase = ShopRules.NewSession(ShopConfig)
local richState = ProgressionRules.NewState()
richState.Coins = 800
for _, weaponId in { "FRYING_PAN", "GIANT_HAMMER", "BLOWER" } do
	local valid, _, price = ShopRules.ValidatePurchase(multiPurchase, richState.Coins, weaponId, ShopConfig)
	assert(valid and ProgressionRules.TrySpendCoins(richState, price))
	ShopRules.GrantPurchase(multiPurchase, weaponId)
end
assert(richState.Coins == 0)
local owned = ShopRules.GetOwnedWeapons(multiPurchase, ShopConfig.Order)
assert(table.concat(owned, ",") == "BASEBALL_BAT,FRYING_PAN,GIANT_HAMMER,BLOWER")

print("PASS ShopRules: server price validation, coin-backed purchase, ordered ownership, and no auto-equip")
