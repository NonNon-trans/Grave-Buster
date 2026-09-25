--!strict

local ShopPresentation = require("../src/client/ShopPresentation")
local ShopConfig = require("../src/shared/ShopConfig")
local ShopRules = require("../src/server/ShopRules")
local ProgressionRules = require("../src/server/ProgressionRules")

assert(ShopPresentation.ValidateLayout())

local session = ShopRules.NewSession(ShopConfig)
local progression = ProgressionRules.NewState()
assert(ShopPresentation.FormatCurrency(progression.Coins) == "COINS: 0")
progression.Coins = 100
local valid, _, price = ShopRules.ValidatePurchase(session, progression.Coins, "FRYING_PAN", ShopConfig)
assert(valid and ProgressionRules.TrySpendCoins(progression, price))
ShopRules.GrantPurchase(session, "FRYING_PAN")
assert(ShopPresentation.FormatCurrency(progression.Coins) == "COINS: 20")

print("PASS ShopPresentation: fixed header layout renders initial and purchased currency")
