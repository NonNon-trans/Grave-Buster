--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProjectInfo = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ProjectInfo"))
local WaveHud = require(script.Parent.WaveHud)
local CombatController = require(script.Parent.CombatController)

WaveHud.Start()
CombatController.Start()

print(string.format("[%s] Client loaded (%s)", ProjectInfo.Name, ProjectInfo.Version))
