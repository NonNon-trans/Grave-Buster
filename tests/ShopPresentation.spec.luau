--!strict

local ShopPresentation = require("../src/client/ShopPresentation")
local ShopConfig = require("../src/shared/ShopConfig")
local ShopRules = require("../src/server/ShopRules")

assert(ShopPresentation.ValidateLayout())

local session = ShopRules.NewSession(ShopConfig)
assert(ShopPresentation.FormatCurrency(session.Currency) == "COINS: 2000")
assert(ShopRules.TryPurchase(session, "FRYING_PAN", ShopConfig))
assert(ShopPresentation.FormatCurrency(session.Currency) == "COINS: 1800")

print("PASS ShopPresentation: fixed header layout renders initial and purchased currency")
