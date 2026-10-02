--!nonstrict
-- Test doubles model signals, scheduling, ownership and tween completion.
-- Rendering, physics, real remote ordering and device feel require Human Gate.
local connections, tweenCount, clock = 0, 0, 0
local tasks, nodes = {}, {}
local function signal()
	local listeners = {}
	return {
		Connect = function(self, callback)
			local connection = { Connected = true, Callback = callback }
			connections += 1
			function connection:Disconnect()
				if self.Connected then self.Connected = false; connections -= 1 end
			end
			table.insert(listeners, connection)
			return connection
		end,
		Fire = function(self, ...)
			for _, connection in table.clone(listeners) do
				if connection.Connected then connection.Callback(...) end
			end
		end,
	}
end
local fakeTask = {}
function fakeTask.delay(duration, callback)
	local pending = { At = clock + duration, Callback = callback }
	tasks[pending] = true
	return pending
end
function fakeTask.cancel(pending) tasks[pending] = nil end
function fakeTask.defer(callback) return fakeTask.delay(0, callback) end
function fakeTask.spawn(callback) return fakeTask.delay(0, callback) end
local function advance(duration)
	local finish = clock + duration
	while true do
		local nextTask
		for pending in tasks do
			if pending.At <= finish and (not nextTask or pending.At < nextTask.At) then nextTask = pending end
		end
		if not nextTask then break end
		tasks[nextTask] = nil
		clock = nextTask.At
		nextTask.Callback()
	end
	clock = finish
end
local function taskCount()
	local count = 0
	for _ in tasks do count += 1 end
	return count
end
local vectorMeta = { __add = function(a,b) return setmetatable({X=a.X+b.X,Y=a.Y+b.Y,Z=(a.Z or 0)+(b.Z or 0)}, getmetatable(a)) end }
local function vector(x,y,z) return setmetatable({X=x,Y=y,Z=z}, vectorMeta) end
local methods = {}
local instanceMeta = {
	__index = function(self, key)
		if methods[key] then return methods[key] end
		if self._props[key] ~= nil then return self._props[key] end
		for _, child in self._children do if child.Name == key then return child end end
	end,
	__newindex = function(self, key, value)
		assert(not self._destroyed, "Mutation after Destroy: " .. self._props.Name .. "." .. key)
		local old = self._props[key]
		if key == "Parent" then
			if old then local index = table.find(old._children, self); if index then table.remove(old._children, index) end end
			if value then table.insert(value._children, self) end
		end
		self._props[key] = value
		if old ~= value then
			if self._propertySignals[key] then self._propertySignals[key]:Fire() end
			if key == "Value" then self.Changed:Fire(value) end
			if key == "Parent" and value then value.ChildAdded:Fire(self) end
		end
	end,
}
local function newInstance(kind)
	local props = { ClassName=kind, Name=kind, Value=0, Visible=true, AbsoluteSize=vector(568,320), BackgroundTransparency=0, Scale=1 }
	for _, name in {"Destroying", "ChildAdded", "Changed", "Died", "CharacterAdded", "CharacterRemoving", "Activated", "OnClientEvent", "InputBegan"} do props[name] = signal() end
	if kind == "BindableEvent" then props.Event = signal() end
	return setmetatable({_props=props, _children={}, _propertySignals={}, _attributeSignals={}, _attributes={}}, instanceMeta)
end
function methods:FindFirstChild(name)
	for _, child in self._children do if child.Name == name then return child end end
end
function methods:WaitForChild(name) return assert(self:FindFirstChild(name), "Missing executable dependency: " .. self.Name .. "." .. name) end
function methods:FindFirstChildOfClass(kind)
	for _, child in self._children do if child.ClassName == kind then return child end end
end
function methods:IsA(kind) return self.ClassName == kind or (kind == "BasePart" and self.ClassName == "Part") end
function methods:IsDescendantOf(ancestor)
	local current = self.Parent
	while current do if current == ancestor then return true end; current = current.Parent end
	return false
end
function methods:GetAttribute(name) return self._attributes[name] end
function methods:SetAttribute(name, value)
	self._attributes[name] = value
	if self._attributeSignals[name] then self._attributeSignals[name]:Fire() end
end
function methods:GetAttributeChangedSignal(name)
	self._attributeSignals[name] = self._attributeSignals[name] or signal()
	return self._attributeSignals[name]
end
function methods:GetPropertyChangedSignal(name)
	self._propertySignals[name] = self._propertySignals[name] or signal()
	return self._propertySignals[name]
end
function methods:Fire(...) self.Event:Fire(...) end
function methods:Destroy()
	if self._destroyed then return end
	self.Destroying:Fire()
	for _, child in table.clone(self._children) do child:Destroy() end
	self.Parent = nil
	rawset(self, "_destroyed", true)
end
local function addNode(path, kind, source)
	local node = newInstance(kind)
	node.Name = string.match(path, '[^.]+$')
	local parent = string.match(path, '^(.*)%.[^.]+$')
	if parent then node.Parent = assert(nodes[parent]) end
	nodes[path] = node
	node.Source = source
	return node
end
-- EMBEDDED_ARTIFACT_TOPOLOGY
local replicated = nodes.ReplicatedStorage
local world = newInstance("Workspace")
local player = newInstance("Player")
local playerGui = newInstance("PlayerGui")
playerGui.Name = "PlayerGui"; playerGui.Parent = player
local players = {LocalPlayer=player}
local function child(parent, name, kind)
	local instance = newInstance(kind or "Folder")
	instance.Name = name; instance.Parent = parent
	return instance
end
local progressionRemote = child(child(replicated,"ProgressionRemotes"),"StateChanged","RemoteEvent")
local wave = child(replicated,"WaveNumber","IntValue"); wave.Value=1
local waveClear = child(child(replicated,"WaveRemotes"),"WaveCleared","RemoteEvent")
local combatRemotes = child(replicated,"CombatRemotes")
local combatFeedback = child(combatRemotes,"CombatFeedback","RemoteEvent")
local damageRemote = child(combatRemotes,"ZombieDamageFeedback","RemoteEvent")
child(combatRemotes,"AttackRequest","RemoteEvent")
local equip = child(combatRemotes,"EquipRequest","RemoteEvent")
local shopRemotes = child(replicated,"ShopRemotes")
local getShop = child(shopRemotes,"GetState","RemoteFunction")
local purchase = child(shopRemotes,"PurchaseRequest","RemoteFunction")
local shopChanged = child(shopRemotes,"StateChanged","RemoteEvent")
local tweenService = {}
function tweenService:Create(target, info, properties)
	local tween = { Active=false }
	function tween:Cancel()
		if self.Pending then fakeTask.cancel(self.Pending); self.Pending=nil end
		if self.Active then self.Active=false; tweenCount-=1 end
	end
	function tween:Destroy() self:Cancel() end
	function tween:Play()
		self.Active=true; tweenCount+=1
		self.Pending=fakeTask.delay(info.Duration, function()
			self.Pending=nil; self.Active=false; tweenCount-=1
			for key, value in properties do target[key]=value end
		end)
	end
	return tween
end
local debris = {}
function debris:AddItem(instance, duration) fakeTask.delay(duration, function() instance:Destroy() end) end
local guiService=newInstance("GuiService")
local safeWidth,safeHeight,topLeft,topHeight=568,262,164,58
local function rect(x,y,w,h) return {Min=vector(x,y),Max=vector(x+w,y+h),Width=w,Height=h} end
function guiService:GetInsetArea(kind)
 if kind=="TopbarSafeInsets" then return rect(topLeft,-topHeight,safeWidth-topLeft,topHeight) end
 if kind=="DeviceSafeInsets" then return rect(0,-topHeight,safeWidth,safeHeight+topHeight) end
 return rect(0,0,safeWidth,safeHeight)
end
local services = {GuiService=guiService,Players=players, ReplicatedStorage=replicated, TweenService=tweenService, Debris=debris, RunService={Heartbeat=signal()}, UserInputService={InputEnded=signal()}}
local fakeGame = {GetService=function(self, name) return assert(services[name], name) end}
local enums = setmetatable({}, {__index=function(self, key)
	local category=setmetatable({}, {__index=function(category, name) rawset(category,name,name); return name end})
	rawset(self,key,category); return category
end})
local baseEnvironment = {
	game=fakeGame, workspace=world, task=fakeTask, Enum=enums,
	Instance={new=newInstance}, Vector2={new=vector, zero=vector(0,0)}, Vector3={new=vector},
	UDim={new=function(s,o) return {Scale=s,Offset=o} end},
	UDim2={new=function(xs,xo,ys,yo) return {X={Scale=xs or 0,Offset=xo or 0},Y={Scale=ys or 0,Offset=yo or 0}} end},
	Color3={fromRGB=function(r,g,b) return {R=r,G=g,B=b} end},
	TweenInfo={new=function(duration) return {Duration=duration} end},
	NumberSequence={new=function(...) return {...} end}, ColorSequence={new=function(...) return {...} end},
	typeof=function(value) return if type(value)=="table" and value._props then "Instance" else typeof(value) end,
}
function baseEnvironment.UDim2.fromOffset(x,y) return baseEnvironment.UDim2.new(0,x,0,y) end
function baseEnvironment.UDim2.fromScale(x,y) return baseEnvironment.UDim2.new(x,0,y,0) end
local cache = {}
local function requireEmbedded(module)
	if cache[module] then return cache[module] end
	assert(module and module:IsA("ModuleScript"), "require must resolve a ModuleScript")
	local env = setmetatable({script=module}, {__index=function(self,key) return baseEnvironment[key] or getfenv(0)[key] end})
	env.require = requireEmbedded
	local executable = assert(loadstring(module.Source, module.Name))
	setfenv(executable,env)
	local result = executable()
	cache[module] = result
	return result
end
-- Evaluate all real client modules and all their Shared requires.
for _, module in nodes['ReplicatedStorage.Client']._children do requireEmbedded(module) end
local Hud = requireEmbedded(nodes['ReplicatedStorage.Client.ProgressionHud'])
local Shop = requireEmbedded(nodes['ReplicatedStorage.Client.ShopController'])
local WaveHud = requireEmbedded(nodes['ReplicatedStorage.Client.WaveHud'])
local CombatFeedback = requireEmbedded(nodes['ReplicatedStorage.Client.CombatFeedbackController'])
player:SetAttribute("PlayerLevel",10); player:SetAttribute("CurrentXP",20); player:SetAttribute("RequiredXP",550)
player:SetAttribute("Coins",1000); player:SetAttribute("BestWave",12); player:SetAttribute("EquippedWeapon","BASEBALL_BAT")
local function character()
	local model = child(world,"Character","Model")
	child(model,"Humanoid","Humanoid")
	player.Character=model
	player.CharacterAdded:Fire(model)
	return model
end
local currentCharacter = character()
local state={Currency=1000,OwnedWeapons={"BASEBALL_BAT"},EquippedWeapon="BASEBALL_BAT",Revision=1}
function getShop:InvokeServer() return state end
local purchases=0
function purchase:InvokeServer(weapon)
	purchases+=1
	if weapon=="GIANT_HAMMER" then return {Success=false,Reason="NOT_ENOUGH_COINS",State=state} end
	state={Currency=920,OwnedWeapons={"BASEBALL_BAT",weapon},EquippedWeapon="BASEBALL_BAT",Revision=2}
	player:SetAttribute("Coins",920)
	shopChanged.OnClientEvent:Fire(state) -- event before response must not erase success
	return {Success=true,State=state}
end
local setOpenCalls=0
Shop.Start({SetShopOpen=function(isOpen) setOpenCalls+=1 end})
Hud.Start(); WaveHud.Start(); CombatFeedback.Start()
advance(0.3)
local gui=playerGui:WaitForChild("GraveBusterProgressionGui")
local panel=gui:WaitForChild("ProgressionPanel")
local content=panel:WaitForChild("ProgressionContent")
local reward=content:WaitForChild("RewardFeedback")
local toast=gui:WaitForChild("LevelUpFeedback")
assert(reward.Text=="" and content:WaitForChild("CoinsLabel").Text=="COINS 1000")
local initialChildren=#gui._children
for index=1,80 do
	progressionRemote.OnClientEvent:Fire({Level=10,CurrentXP=20+index*5,RequiredXP=550,Coins=1000+index,BestWave=12,XPGranted=5,CoinsGranted=1})
end
assert(reward.Text=="" and #gui._children==initialChildren, "Per-kill GUI spam")
assert(taskCount()<12, "Crowd created unbounded reward tasks")
advance(0.66)
assert(reward.Text=="+400 XP  •  +80 COINS")
assert(content:WaitForChild("CoinsLabel").Text=="COINS 1080")
progressionRemote.OnClientEvent:Fire({Level=11,CurrentXP=10,RequiredXP=600,Coins=1080,BestWave=13,LevelsGained=1,OldLevel=10,DamageIncreasePercent=5,NewRecord=true,RecordWave=13})
assert(toast.Visible and string.find(toast.Text,"NEW RECORD",1,true))
advance(2.21)
assert(string.find(toast.Text,"LEVEL UP!",1,true) and string.find(toast.Text,"DAMAGE +5%",1,true))
local shopGui=playerGui:WaitForChild("GraveBusterShopGui")
playerGui:WaitForChild("GraveBusterShopTopbarGui"):WaitForChild("ShopButton").Activated:Fire()
advance(0)
assert(not panel.Visible and not toast.Visible, "Shop overlaps progression UI")
progressionRemote.OnClientEvent:Fire({Level=11,CurrentXP=10,RequiredXP=600,Coins=1080,BestWave=14,NewRecord=true,RecordWave=14})
advance(3)
local overlay=shopGui:WaitForChild("ShopOverlay")
local shopPanel=overlay:WaitForChild("ShopPanel")
local pan=shopPanel:WaitForChild("WeaponList"):WaitForChild("FRYING_PAN")
pan.Activated:Fire(); pan.Activated:Fire(); advance(0)
assert(purchases==1, "Purchase pending guard lost")
assert(shopPanel:WaitForChild("Feedback").Text=="UNLOCKED FRYING PAN • TAP TO EQUIP")
assert(player:GetAttribute("EquippedWeapon")=="BASEBALL_BAT", "Purchase auto-equipped")
shopChanged.OnClientEvent:Fire(state)
assert(string.find(shopPanel:WaitForChild("Feedback").Text,"UNLOCKED",1,true), "State event erased purchase feedback")
shopPanel:WaitForChild("WeaponList"):WaitForChild("GIANT_HAMMER").Activated:Fire(); advance(0)
assert(shopPanel:WaitForChild("Feedback").Text=="NOT ENOUGH COINS" and state.Currency==920 and #state.OwnedWeapons==2)
shopPanel:WaitForChild("CloseButton").Activated:Fire()
assert(panel.Visible and toast.Visible and string.find(toast.Text,"NEW RECORD!  WAVE 14",1,true))
safeWidth,safeHeight,topLeft,topHeight=844,326,210,64
 guiService:GetPropertyChangedSignal("TopbarInset"):Fire()
 gui.AbsoluteSize=vector(844,326)
 local waveHeader=playerGui:WaitForChild("GraveBusterWaveHud"):WaitForChild("WaveLabel")
 local shopHeader=playerGui:WaitForChild("GraveBusterShopTopbarGui"):WaitForChild("ShopButton")
 assert(math.abs(panel.Position.X.Offset+panel.Size.X.Offset/2-(topLeft+waveHeader.Position.X.Offset))<0.001, "HUD no longer below wave center")
 assert(waveHeader.Position.Y.Offset==shopHeader.Position.Y.Offset and panel.Size.X.Offset>panel.Size.Y.Offset*5, "Topbar/horizontal HUD layout lost")
 player:SetAttribute("SessionKills",80)
 assert(content:WaitForChild("KillCounter").Text=="KILLS 80")
 assert(not playerGui:WaitForChild("GraveBusterFeedbackGui"):FindFirstChild("KillCounter"), "Duplicate KILLS")
player:SetAttribute("PlayerLevel",11); player:SetAttribute("EquippedWeapon","FRYING_PAN")
assert(content:WaitForChild("PowerLabel").Text=="PAN  •  23 DMG")
assert(pan:WaitForChild("WeaponPower").Text=="23 DAMAGE AT LEVEL 11")
waveClear.OnClientEvent:Fire(1); wave.Value=2
local waveLabel=playerGui:WaitForChild("GraveBusterWaveHud"):WaitForChild("WaveLabel")
assert(waveLabel.Text=="WAVE 1 CLEAR! → 2")
wave.Value=0
assert(waveLabel.Text=="GET READY", "Stale clear after run reset")
currentCharacter:WaitForChild("Humanoid").Died:Fire()
assert(string.find(toast.Text,"RETAINED",1,true))
player.CharacterRemoving:Fire(currentCharacter); currentCharacter:Destroy()
currentCharacter=character()
assert(string.find(toast.Text,"WAVE 1",1,true))
-- A survivor keeps the shared run: retry must report the live wave, not force 1.
wave.Value=12
currentCharacter:WaitForChild("Humanoid").Died:Fire()
player.CharacterRemoving:Fire(currentCharacter); currentCharacter:Destroy(); currentCharacter=character()
assert(string.find(toast.Text,"WAVE 12",1,true))
local zombie=child(world,"Zombie","Model")
local head=child(zombie,"Head","Part")
for _=1,80 do damageRemote.OnClientEvent:Fire({{Model=zombie,AttackDamage=99,CurrentHP=0,MaxHP=10,Lethal=true}}) end
local numbers=0
for _, item in head._children do
	if item.Name=="ZombieDamageNumber" then numbers+=1; assert(item:WaitForChild("Damage").Text=="99", "Overkill number was clamped") end
end
assert(numbers==24, "Damage number live cap exceeded")
advance(0.81)
assert(#head._children==0, "Damage number instances leaked")
for _=1,80 do damageRemote.OnClientEvent:Fire({{Model=zombie,AttackDamage=1,CurrentHP=9,MaxHP=10,Lethal=false}}) end
assert(head:FindFirstChild("ZombieHealthBar"))
local healthTimers=0
for pending in tasks do if math.abs(pending.At-clock-1.5)<0.001 then healthTimers+=1 end end
assert(healthTimers==1, "Repeated hits created health-bar timer spam")
damageRemote.OnClientEvent:Fire({{Model=zombie,AttackDamage=50,CurrentHP=0,MaxHP=10,Lethal=true}})
assert(not head:FindFirstChild("ZombieHealthBar"))
damageRemote.OnClientEvent:Fire({{Model=zombie,AttackDamage=1,CurrentHP=9,MaxHP=10,Lethal=false}})
zombie:Destroy() -- owner deletion must cancel HP timers and release model refs
advance(4)
local steadyConnections=connections
for _=1,20 do
	player.CharacterRemoving:Fire(currentCharacter); currentCharacter:Destroy(); currentCharacter=character()
end
assert(connections==steadyConnections, "Respawn accumulated connections")
for _, instance in table.clone(playerGui._children) do instance:Destroy() end
advance(4)
assert(connections==0 and tweenCount==0 and taskCount()==0, string.format("Feedback cleanup leak: connections=%d tweens=%d tasks=%d",connections,tweenCount,taskCount()))
-- Restart after teardown; Start guards still prohibit duplicates.
Hud.Start(); Hud.Start(); WaveHud.Start(); WaveHud.Start(); CombatFeedback.Start(); CombatFeedback.Start()
Shop.Start({SetShopOpen=function() end}); Shop.Start({SetShopOpen=function() end})
advance(0.3)
assert(#playerGui._children==5)
for _, instance in table.clone(playerGui._children) do instance:Destroy() end
advance(4)
assert(connections==0 and tweenCount==0 and taskCount()==0)
print("PASS embedded feedback runtime: all client module evaluation; 80-kill aggregation; level/record priority; Shop deferral; purchase success/order/guard; power growth; wave/reset; solo/multiplayer retry; overkill/cap; 20 respawns; zero retained connections/tasks/tweens; restart idempotence")
print("NOTRUN Roblox engine / Studio / published PC / physical Mobile Landscape Human Gate")
