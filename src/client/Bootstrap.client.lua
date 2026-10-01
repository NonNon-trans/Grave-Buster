--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local AUDIT_BUILD_ID = "GB027-CENTER-ALIGNMENT-R1"

-- Temporary GB-027 delivery audit: visible even if CombatController cannot create its UI.
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local previousAudit = playerGui:FindFirstChild("GB027SolAuditGui")
if previousAudit then
	previousAudit:Destroy()
end
local auditGui = Instance.new("ScreenGui")
auditGui.Name = "GB027SolAuditGui"
auditGui.ResetOnSpawn = false
auditGui.DisplayOrder = 1000
auditGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
auditGui.Parent = playerGui
local auditLabel = Instance.new("TextLabel")
auditLabel.Name = "BuildAndModuleStatus"
auditLabel.AnchorPoint = Vector2.new(0.5, 0)
auditLabel.Position = UDim2.new(0.5, 0, 0, 4)
auditLabel.Size = UDim2.new(0.9, 0, 0, 72)
auditLabel.BackgroundColor3 = Color3.fromRGB(255, 225, 0)
auditLabel.BackgroundTransparency = 0
auditLabel.TextColor3 = Color3.fromRGB(10, 10, 10)
auditLabel.TextSize = 16
auditLabel.TextWrapped = true
auditLabel.Font = Enum.Font.GothamBold
auditLabel.Text = AUDIT_BUILD_ID .. "\nBOOTSTRAP RUNNING / MODULE CHECK PENDING"
auditLabel.Parent = auditGui

local ProjectInfo = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ProjectInfo"))
local clientModules = ReplicatedStorage:WaitForChild("Client")
local WaveHud = require(clientModules:WaitForChild("WaveHud"))
local CombatController = require(clientModules:WaitForChild("CombatController"))
local ShopController = require(clientModules:WaitForChild("ShopController"))
local CombatFeedbackController = require(clientModules:WaitForChild("CombatFeedbackController"))
local ProgressionHud = require(clientModules:WaitForChild("ProgressionHud"))
local WeaponSwitcher = require(clientModules:WaitForChild("WeaponSwitcher"))
local WeaponSwitcherRules = require(clientModules:WaitForChild("WeaponSwitcherRules"))

WaveHud.Start()
ProgressionHud.Start()
CombatController.Start()
CombatFeedbackController.Start()
ShopController.Start(CombatController)

local combatGui = playerGui:FindFirstChild("GraveBusterCombatGui")
local switcherGui = combatGui and combatGui:FindFirstChild("WeaponSwitcher")
local combatMatch = CombatController.AuditBuildId == AUDIT_BUILD_ID
local switcherMatch = WeaponSwitcher.AuditBuildId == AUDIT_BUILD_ID
local rulesMatch = WeaponSwitcherRules.AuditBuildId == AUDIT_BUILD_ID
auditLabel.Text = string.format(
	"%s\nBOOT=OK COMBAT=%s SWITCHER=%s RULES=%s GUI=%s",
	AUDIT_BUILD_ID,
	if combatMatch then "OK" else "STALE",
	if switcherMatch then "OK" else "STALE",
	if rulesMatch then "OK" else "STALE",
	if switcherGui then switcherGui.ClassName else "MISSING"
)
print("[GB027 SOL AUDIT]", auditLabel.Text)

print(string.format("[%s] Client loaded (%s)", ProjectInfo.Name, ProjectInfo.Version))
