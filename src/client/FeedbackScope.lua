--!nonstrict

local TweenService = game:GetService("TweenService")
local FeedbackScope = {}
FeedbackScope.__index = FeedbackScope

-- Repeated rewards replace keyed work, without a task/connection per kill.
function FeedbackScope.new(owner)
	local self = setmetatable({ Connections = {}, Tasks = {}, Tweens = {}, Cleanup = {}, Destroyed = false }, FeedbackScope)
	self:Connect(owner.Destroying, function() self:Destroy() end)
	return self
end

function FeedbackScope:OnDestroy(callback)
	table.insert(self.Cleanup, callback)
end

function FeedbackScope:Connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(self.Connections, connection)
	return connection
end

function FeedbackScope:CancelDelay(key)
	local pending = self.Tasks[key]
	if pending then self.Tasks[key] = nil; task.cancel(pending) end
end

function FeedbackScope:Delay(key, duration, callback)
	self:CancelDelay(key)
	if self.Destroyed then return end
	self.Tasks[key] = task.delay(duration, function()
		self.Tasks[key] = nil
		if not self.Destroyed then callback() end
	end)
end

function FeedbackScope:Spawn(key, callback)
	self:CancelDelay(key)
	if self.Destroyed then return end
	self.Tasks[key] = task.defer(function()
		if not self.Destroyed then callback() end
		self.Tasks[key] = nil
	end)
end

function FeedbackScope:Tween(key, target, duration, properties)
	local old = self.Tweens[key]
	if old then old:Cancel(); old:Destroy() end
	if self.Destroyed then return end
	local tween = TweenService:Create(target, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), properties)
	self.Tweens[key] = tween
	tween:Play()
	return tween
end

function FeedbackScope:Destroy()
	if self.Destroyed then return end
	self.Destroyed = true
	for _, connection in self.Connections do connection:Disconnect() end
	for _, pending in self.Tasks do task.cancel(pending) end
	for _, tween in self.Tweens do tween:Cancel(); tween:Destroy() end
	for _, callback in self.Cleanup do callback() end
	table.clear(self.Connections)
	table.clear(self.Tasks)
	table.clear(self.Tweens)
	table.clear(self.Cleanup)
end

return FeedbackScope
