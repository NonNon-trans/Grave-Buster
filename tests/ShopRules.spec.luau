--!strict

local ShopConfig = require("../src/shared/ShopConfig")
local ShopRules = require("../src/server/ShopRules")

local session = ShopRules.NewSession(ShopConfig)
assert(session.Currency == 2000)
assert(session.Owned.BASEBALL_BAT and not session.Owned.FRYING_PAN)
assert(#ShopRules.GetOwnedWeapons(session, ShopConfig.Order) == 1)

local success, reason = ShopRules.TryPurchase(session, "FRYING_PAN", ShopConfig)
assert(success and reason == "PURCHASED")
assert(session.Currency == 1800 and session.Owned.FRYING_PAN and session.Revision == 1)

local currencyAfterPurchase = session.Currency
success, reason = ShopRules.TryPurchase(session, "FRYING_PAN", ShopConfig)
assert(not success and reason == "ALREADY_OWNED")
assert(session.Currency == currencyAfterPurchase and session.Revision == 1)

success, reason = ShopRules.TryPurchase(session, "UNKNOWN", ShopConfig)
assert(not success and reason == "INVALID_WEAPON" and session.Currency == currencyAfterPurchase)
success, reason = ShopRules.TryPurchase(session, -1, ShopConfig)
assert(not success and reason == "INVALID_WEAPON")

local fakePriceSession = ShopRules.NewSession(ShopConfig)
success = ShopRules.TryPurchase(fakePriceSession, "GIANT_HAMMER", ShopConfig, -999)
assert(success and fakePriceSession.Currency == 1600, "Client-supplied fake price must be ignored")

local poorSession = ShopRules.NewSession(ShopConfig)
assert(ShopRules.TryPurchase(poorSession, "FRYING_PAN", ShopConfig))
assert(ShopRules.TryPurchase(poorSession, "GIANT_HAMMER", ShopConfig))
assert(ShopRules.TryPurchase(poorSession, "BLOWER", ShopConfig))
assert(poorSession.Currency == 800)
success, reason = ShopRules.TryPurchase(poorSession, "THUNDER_ROD", ShopConfig)
assert(not success and reason == "NOT_ENOUGH_COINS")
assert(poorSession.Currency == 800 and not poorSession.Owned.THUNDER_ROD)

local owned = ShopRules.GetOwnedWeapons(poorSession, ShopConfig.Order)
assert(table.concat(owned, ",") == "BASEBALL_BAT,FRYING_PAN,GIANT_HAMMER,BLOWER")

print("PASS ShopRules: valid/atomic purchase, price authority, ordered ownership, and rejection paths")
