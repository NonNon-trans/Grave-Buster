--!strict

local WeaponSwitcherRules = {}
WeaponSwitcherRules.AuditBuildId = "GB027-CENTER-ALIGNMENT-R1"

WeaponSwitcherRules.Tuning = table.freeze({
	SlotWidthRatio = 0.68,
	ItemWidthRatio = 0.9,
	FlickVelocityThreshold = 550,
	Deceleration = 1800,
	MinimumFlickTravel = 0.85,
	MaximumFlickTravel = 5,
	VelocitySmoothing = 0.45,
	SnapDuration = 0.24,
	ArrowSnapDuration = 0.12,
	FullVisibilityHold = 1.0,
	FadeDuration = 0.3,
	IdleGroupTransparency = 0.5,
})

function WeaponSwitcherRules.ResolveCurrent(ownedWeapons, currentWeapon, fallbackWeapon)
	if table.find(ownedWeapons, currentWeapon) then
		return currentWeapon
	end
	if table.find(ownedWeapons, fallbackWeapon) then
		return fallbackWeapon
	end
	return ownedWeapons[1]
end

function WeaponSwitcherRules.OrderOwned(ownedWeapons, weaponOrder)
	local ownedSet = {}
	for _, weapon in ownedWeapons do
		ownedSet[weapon] = true
	end
	local ordered = {}
	for _, weapon in weaponOrder do
		if ownedSet[weapon] then
			table.insert(ordered, weapon)
		end
	end
	return ordered
end

function WeaponSwitcherRules.ClampPosition(position: number, count: number): number
	if count <= 0 then
		return 0
	end
	return math.clamp(position, 1, count)
end

function WeaponSwitcherRules.SnapIndex(position: number, count: number): number?
	if count <= 0 then
		return nil
	end
	return math.clamp(math.floor(position + 0.5), 1, count)
end

function WeaponSwitcherRules.ArrowStep(index: number, direction: number, count: number): number
	if count <= 0 then
		return 0
	end
	local step = if direction < 0 then -1 else 1
	return math.clamp(index + step, 1, count)
end

function WeaponSwitcherRules.PositionForDrag(startIndex: number, deltaX: number, slotWidth: number, count: number): number
	if slotWidth <= 0 or count <= 0 then
		return startIndex
	end
	return WeaponSwitcherRules.ClampPosition(startIndex - deltaX / slotWidth, count)
end

-- Canvas has symmetric end padding so every card center can reach the
-- viewport center, including the first and last owned weapons.
function WeaponSwitcherRules.CenterGeometry(viewportWidth: number, count: number)
	local width = math.max(1, viewportWidth)
	local slot = width * WeaponSwitcherRules.Tuning.SlotWidthRatio
	local item = slot * WeaponSwitcherRules.Tuning.ItemWidthRatio
	return {
		ViewportWidth = width,
		SlotWidth = slot,
		ItemWidth = item,
		EndPadding = (width - item) / 2,
		CanvasWidth = width + math.max(0, count - 1) * slot,
	}
end

function WeaponSwitcherRules.ItemCenter(index: number, geometry): number
	return geometry.EndPadding + geometry.ItemWidth / 2 + (index - 1) * geometry.SlotWidth
end

function WeaponSwitcherRules.NearestCenter(canvasX: number, geometry, count: number): number?
	local viewportCenter = canvasX + geometry.ViewportWidth / 2
	local nearest = nil
	local distance = math.huge
	for index = 1, count do
		local candidateDistance = math.abs(WeaponSwitcherRules.ItemCenter(index, geometry) - viewportCenter)
		-- At the exact midpoint retain the existing next-item tie break.
		if candidateDistance <= distance then
			distance = candidateDistance
			nearest = index
		end
	end
	return nearest
end

function WeaponSwitcherRules.CanvasOffset(scrollPosition: number, slotWidth: number, count: number): number
	return (WeaponSwitcherRules.ClampPosition(scrollPosition, count) - 1) * slotWidth
end

function WeaponSwitcherRules.PointInside(
	left: number,
	top: number,
	width: number,
	height: number,
	pointX: number,
	pointY: number
): boolean
	return pointX >= left
		and pointY >= top
		and pointX <= left + width
		and pointY <= top + height
end

function WeaponSwitcherRules.FlickTravel(velocityX: number, slotWidth: number): number
	local tuning = WeaponSwitcherRules.Tuning
	local speed = math.abs(velocityX)
	if speed < tuning.FlickVelocityThreshold or slotWidth <= 0 then
		return 0
	end

	local pixelDistance = speed * speed / (2 * tuning.Deceleration)
	local weaponDistance = pixelDistance / slotWidth
	return math.clamp(weaponDistance, tuning.MinimumFlickTravel, tuning.MaximumFlickTravel)
end

function WeaponSwitcherRules.ProjectFlick(
	position: number,
	velocityX: number,
	slotWidth: number,
	count: number,
	originPosition: number?
): number
	local travel = WeaponSwitcherRules.FlickTravel(velocityX, slotWidth)
	if travel == 0 then
		return WeaponSwitcherRules.ClampPosition(position, count)
	end
	local direction = if velocityX < 0 then 1 else -1
	local projected = position + direction * travel
	if originPosition then
		local maximum = WeaponSwitcherRules.Tuning.MaximumFlickTravel
		projected = math.clamp(projected, originPosition - maximum, originPosition + maximum)
	end
	return WeaponSwitcherRules.ClampPosition(projected, count)
end

function WeaponSwitcherRules.FlickSnapIndex(position: number, originPosition: number, count: number): number?
	local snapped = WeaponSwitcherRules.SnapIndex(position, count)
	if not snapped then
		return nil
	end
	local maximum = WeaponSwitcherRules.Tuning.MaximumFlickTravel
	local minimumIndex = math.max(1, math.ceil(originPosition - maximum))
	local maximumIndex = math.min(count, math.floor(originPosition + maximum))
	return math.clamp(snapped, minimumIndex, maximumIndex)
end

local SnapCommitGate = {}
SnapCommitGate.__index = SnapCommitGate

function SnapCommitGate.new()
	return setmetatable({ token = 0, pendingIndex = nil, committed = false }, SnapCommitGate)
end

function SnapCommitGate:Begin(index: number): number
	self.token += 1
	self.pendingIndex = index
	self.committed = false
	return self.token
end

function SnapCommitGate:Cancel()
	self.token += 1
	self.pendingIndex = nil
	self.committed = false
end

function SnapCommitGate:Commit(token: number): number?
	if token ~= self.token or self.pendingIndex == nil or self.committed then
		return nil
	end
	self.committed = true
	return self.pendingIndex
end

WeaponSwitcherRules.SnapCommitGate = SnapCommitGate

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

function WeaponSwitcherRules.GroupTransparencyForMode(mode: string): number
	return if mode == "Idle" or mode == "Fade" then WeaponSwitcherRules.Tuning.IdleGroupTransparency else 0
end

WeaponSwitcherRules.VisibilityState = VisibilityState

local DragState = {}
DragState.__index = DragState

function DragState.new()
	return setmetatable({
		token = nil,
		startX = 0,
		startY = 0,
		startIndex = 1,
		lastX = 0,
		lastTime = 0,
		velocityX = 0,
	}, DragState)
end

function DragState:Begin(token, x: number, y: number, time: number, startIndex: number)
	if self.token ~= nil then
		return false
	end
	self.token = token
	self.startX = x
	self.startY = y
	self.startIndex = startIndex
	self.lastX = x
	self.lastTime = time
	self.velocityX = 0
	return true
end

function DragState:Update(token, x: number, _y: number, time: number, slotWidth: number, count: number)
	if self.token ~= token then
		return false, nil, nil
	end
	local elapsed = time - self.lastTime
	if elapsed > 0 then
		local instantVelocity = (x - self.lastX) / elapsed
		local smoothing = WeaponSwitcherRules.Tuning.VelocitySmoothing
		self.velocityX = self.velocityX * (1 - smoothing) + instantVelocity * smoothing
	end
	self.lastX = x
	self.lastTime = time
	local position = WeaponSwitcherRules.PositionForDrag(self.startIndex, x - self.startX, slotWidth, count)
	return true, position, self.velocityX
end

function DragState:Finish(token)
	if self.token ~= token then
		return false, nil, 0
	end
	local velocityX = self.velocityX
	self.token = nil
	return true, nil, velocityX
end

function DragState:Cancel()
	self.token = nil
	self.velocityX = 0
end

WeaponSwitcherRules.DragState = DragState

return WeaponSwitcherRules
