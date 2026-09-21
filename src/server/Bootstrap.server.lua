--!strict

local ArenaService = require(script.Parent.ArenaService)
ArenaService.Build()

local ZombieService = require(script.Parent.ZombieService)
local WaveService = require(script.Parent.WaveService)
ZombieService.Start()
WaveService.Start(ZombieService)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProjectInfo = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ProjectInfo"))

print(string.format("[%s] Server loaded (%s)", ProjectInfo.Name, ProjectInfo.Version))
