--!strict

local ArenaService = require(script.Parent.ArenaService)
ArenaService.Build()

local ZombieService = require(script.Parent.ZombieService)
local WaveService = require(script.Parent.WaveService)
local CombatService = require(script.Parent.CombatService)
local ShopService = require(script.Parent.ShopService)
local PlayerHealthService = require(script.Parent.PlayerHealthService)
local zombieServiceBefore = ZombieService.GetRuntimeDiagnostics()
print(string.format(
	"[GB021 INIT] path=%s moduleInstance=%s evaluation=%s serviceTable=%s readyBefore=%s",
	zombieServiceBefore.ModulePath, zombieServiceBefore.ModuleInstance,
	zombieServiceBefore.ModuleEvaluationId, zombieServiceBefore.ServiceTable,
	tostring(zombieServiceBefore.Ready)
))
ZombieService.Start()
local zombieServiceAfter = ZombieService.GetRuntimeDiagnostics()
print(string.format(
	"[GB021 INIT] path=%s moduleInstance=%s evaluation=%s serviceTable=%s readyAfter=%s container=%s",
	zombieServiceAfter.ModulePath, zombieServiceAfter.ModuleInstance,
	zombieServiceAfter.ModuleEvaluationId, zombieServiceAfter.ServiceTable,
	tostring(zombieServiceAfter.Ready), tostring(zombieServiceAfter.ContainerPath)
))
ShopService.Start()
PlayerHealthService.Start()
CombatService.Start(ZombieService, ShopService)
WaveService.Start(ZombieService)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProjectInfo = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ProjectInfo"))

print(string.format("[%s] Server loaded (%s)", ProjectInfo.Name, ProjectInfo.Version))
