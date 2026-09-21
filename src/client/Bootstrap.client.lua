--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProjectInfo = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ProjectInfo"))
local clientModules = ReplicatedStorage:WaitForChild("Client")
local WaveHud = require(clientModules:WaitForChild("WaveHud"))
local CombatController = require(clientModules:WaitForChild("CombatController"))

WaveHud.Start()
CombatController.Start()

print(string.format("[%s] Client loaded (%s)", ProjectInfo.Name, ProjectInfo.Version))
