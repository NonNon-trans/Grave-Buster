--!strict

local ShopConfig = require("../src/shared/ShopConfig")
local ShopRules = require("../src/server/ShopRules")
local ShopSessionStore = require("../src/server/ShopSessionStore")

local store = ShopSessionStore.new(function()
	return ShopRules.NewSession(ShopConfig)
end)
local player = {}
local session = store:GetOrCreate(player)
assert(ShopRules.TryPurchase(session, "FRYING_PAN", ShopConfig))

local sameSession = store:GetOrCreate(player)
assert(sameSession == session and sameSession.Currency == 1800 and sameSession.Owned.FRYING_PAN)

store:Remove(player)
assert(store:Get(player) == nil)
local rejoined = store:GetOrCreate(player)
assert(rejoined ~= session)
assert(rejoined.Currency == ShopConfig.StartCurrency)
assert(rejoined.Owned.BASEBALL_BAT and not rejoined.Owned.FRYING_PAN)

store:Clear()
assert(store:Get(player) == nil)

print("PASS ShopSessionStore: reset persistence, leave cleanup, and rejoin initialization")
