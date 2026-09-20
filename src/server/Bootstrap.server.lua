--!strict

local ArenaService = require(script.Parent.ArenaService)
ArenaService.Build()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProjectInfo = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ProjectInfo"))

print(string.format("[%s] Server loaded (%s)", ProjectInfo.Name, ProjectInfo.Version))
