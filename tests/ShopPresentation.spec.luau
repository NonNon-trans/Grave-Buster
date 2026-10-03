--!strict

local ShopPresentation = require("../src/client/ShopPresentation")
local ShopConfig = require("../src/shared/ShopConfig")
local ProgressionRules = require("../src/server/ProgressionRules")

assert(ShopPresentation.ValidateLayout())

local progression = ProgressionRules.NewState()
assert(ShopPresentation.FormatCurrency(progression.Coins) == "COINS: 0")
progression.Coins = 100
local price = ShopConfig.Prices.FRYING_PAN
assert(ProgressionRules.TrySpendCoins(progression, price))
table.insert(progression.OwnedWeapons, "FRYING_PAN")
assert(ShopPresentation.FormatCurrency(progression.Coins) == "COINS: 20")

print("PASS ShopPresentation: fixed header layout renders initial and purchased currency")
