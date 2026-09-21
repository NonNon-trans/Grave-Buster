--!nonstrict

local HoldState = {}
HoldState.__index = HoldState

function HoldState.new()
	return setmetatable({ holding = false, generation = 0 }, HoldState)
end

function HoldState:Begin(): number?
	if self.holding then
		return nil
	end
	self.holding = true
	self.generation += 1
	return self.generation
end

function HoldState:Stop()
	self.holding = false
	self.generation += 1
end

function HoldState:IsCurrent(generation: number): boolean
	return self.holding and self.generation == generation
end

return HoldState
