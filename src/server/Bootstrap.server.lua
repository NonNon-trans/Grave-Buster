--!strict

local ArenaService = require(script.Parent.ArenaService)
ArenaService.Build()

local ZombieService = require(script.Parent.ZombieService)
local WaveService = require(script.Parent.WaveService)
local CombatService = require(script.Parent.CombatService)
local ShopService = require(script.Parent.ShopService)
local PlayerHealthService = require(script.Parent.PlayerHealthService)
local ProgressionService = require(script.Parent.ProgressionService)
ProgressionService.Start()
ShopService.Start(ProgressionService)
PlayerHealthService.Start(WaveService)
ZombieService.Start(PlayerHealthService)
CombatService.Start(ZombieService, ShopService, ProgressionService, PlayerHealthService)
WaveService.Start(ZombieService, ProgressionService)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProjectInfo = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ProjectInfo"))

print(string.format("[%s] Server loaded (%s)", ProjectInfo.Name, ProjectInfo.Version))
