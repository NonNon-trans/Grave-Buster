--!nonstrict

local WeaponSwitcherRules = {}

function WeaponSwitcherRules.ResolveCurrent(ownedWeapons, currentWeapon, fallbackWeapon)
	if table.find(ownedWeapons, currentWeapon) then
		return currentWeapon
	end
	if table.find(ownedWeapons, fallbackWeapon) then
		return fallbackWeapon
	end
	return ownedWeapons[1]
end

function WeaponSwitcherRules.Step(ownedWeapons, currentWeapon, direction)
	if #ownedWeapons == 0 then
		return nil
	end
	local index = table.find(ownedWeapons, currentWeapon) or 1
	return ownedWeapons[(index - 1 + direction) % #ownedWeapons + 1]
end

function WeaponSwitcherRules.GetSwipeDirection(deltaX, deltaY, threshold)
	local horizontal = math.abs(deltaX)
	local vertical = math.abs(deltaY)
	if horizontal < threshold or horizontal <= vertical * 1.25 then
		return 0
	end
	return if deltaX < 0 then 1 else -1
end

local VisibilityState = {}
VisibilityState.__index = VisibilityState

function VisibilityState.new()
	return setmetatable({ mode = "Idle", generation = 0 }, VisibilityState)
end

function VisibilityState:Activate()
	self.generation += 1
	self.mode = "Active"
end

function VisibilityState:ScheduleIdle()
	self.generation += 1
	self.mode = "Hold"
	return self.generation
end

function VisibilityState:BeginFade(generation)
	if self.generation ~= generation or self.mode ~= "Hold" then
		return false
	end
	self.mode = "Fade"
	return true
end

function VisibilityState:CompleteFade(generation)
	if self.generation ~= generation or self.mode ~= "Fade" then
		return false
	end
	self.mode = "Idle"
	return true
end

function VisibilityState:GetMode()
	return self.mode
end

WeaponSwitcherRules.VisibilityState = VisibilityState

local DragState = {}
DragState.__index = DragState

function DragState.new()
	return setmetatable({ token = nil, startX = 0, startY = 0, lastX = 0, lastY = 0 }, DragState)
end

function DragState:Begin(token, x, y)
	if self.token ~= nil then
		return false
	end
	self.token = token
	self.startX = x
	self.startY = y
	self.lastX = x
	self.lastY = y
	return true
end

function DragState:Update(token, x, y)
	if self.token ~= token then
		return false
	end
	self.lastX = x
	self.lastY = y
	return true
end

function DragState:Finish(token, threshold)
	if self.token ~= token then
		return false, 0
	end
	local direction = WeaponSwitcherRules.GetSwipeDirection(
		self.lastX - self.startX,
		self.lastY - self.startY,
		threshold
	)
	self.token = nil
	return true, direction
end

function DragState:Cancel()
	self.token = nil
end

WeaponSwitcherRules.DragState = DragState

return WeaponSwitcherRules
