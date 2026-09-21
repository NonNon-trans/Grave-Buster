--!strict

local ShopConfig = require("../src/shared/ShopConfig")
local WeaponConfig = require("../src/shared/WeaponConfig")

assert(ShopConfig.Validate(WeaponConfig.Order))
assert(ShopConfig.StartCurrency == 2000)
assert(#ShopConfig.DefaultOwned == 1 and ShopConfig.DefaultOwned[1] == "BASEBALL_BAT")
assert(ShopConfig.Prices.BASEBALL_BAT == 0)
assert(ShopConfig.Prices.FRYING_PAN == 200)
assert(ShopConfig.Prices.GIANT_HAMMER == 400)
assert(ShopConfig.Prices.BLOWER == 600)
assert(ShopConfig.Prices.THUNDER_ROD == 1000)

print("PASS ShopConfig: order, start currency, default ownership, and authoritative prices")
