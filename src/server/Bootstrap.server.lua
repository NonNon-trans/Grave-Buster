--!strict

local ArenaService = require(script.Parent.ArenaService)
ArenaService.Build()

local ZombieService = require(script.Parent.ZombieService)
local WaveService = require(script.Parent.WaveService)
local CombatService = require(script.Parent.CombatService)
local ShopService = require(script.Parent.ShopService)
local PlayerHealthService = require(script.Parent.PlayerHealthService)
local ProgressionService = require(script.Parent.ProgressionService)
ZombieService.Start()
PlayerHealthService.Start()
ProgressionService.Start()
ShopService.Start(ProgressionService)
CombatService.Start(ZombieService, ShopService, ProgressionService)
WaveService.Start(ZombieService, ProgressionService)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProjectInfo = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ProjectInfo"))

print(string.format("[%s] Server loaded (%s)", ProjectInfo.Name, ProjectInfo.Version))
