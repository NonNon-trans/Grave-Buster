--!strict

local ShopConfig = require("../src/shared/ShopConfig")
local ShopRules = require("../src/server/ShopRules")
local ProgressionRules = require("../src/server/ProgressionRules")
local ShopSessionStore = require("../src/server/ShopSessionStore")

local store = ShopSessionStore.new(function()
	return ShopRules.NewSession(ShopConfig)
end)
local player = {}
local session = store:GetOrCreate(player)
local progression = ProgressionRules.NewState()
progression.Coins = 100
local valid, _, price = ShopRules.ValidatePurchase(session, progression.Coins, "FRYING_PAN", ShopConfig)
assert(valid and ProgressionRules.TrySpendCoins(progression, price))
ShopRules.GrantPurchase(session, "FRYING_PAN")

local sameSession = store:GetOrCreate(player)
assert(sameSession == session and sameSession.Owned.FRYING_PAN and progression.Coins == 20)

store:Remove(player)
assert(store:Get(player) == nil)
local rejoined = store:GetOrCreate(player)
assert(rejoined ~= session)
assert(rejoined.Owned.BASEBALL_BAT and not rejoined.Owned.FRYING_PAN)

store:Clear()
assert(store:Get(player) == nil)

print("PASS ShopSessionStore: reset persistence, leave cleanup, and rejoin initialization")
