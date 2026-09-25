--!strict

local ShopConfig = require("../src/shared/ShopConfig")
local WeaponConfig = require("../src/shared/WeaponConfig")
local ProgressionRules = require("../src/server/ProgressionRules")

assert(ShopConfig.Validate(WeaponConfig.Order))
assert(ProgressionRules.NewState().Coins == 0)
assert(#ShopConfig.DefaultOwned == 1 and ShopConfig.DefaultOwned[1] == "BASEBALL_BAT")
assert(ShopConfig.Prices.BASEBALL_BAT == 0)
assert(ShopConfig.Prices.FRYING_PAN == 80)
assert(ShopConfig.Prices.GIANT_HAMMER == 220)
assert(ShopConfig.Prices.BLOWER == 500)
assert(ShopConfig.Prices.THUNDER_ROD == 900)

print("PASS ShopConfig: order, zero initial coins, default ownership, and authoritative v0.2 prices")
