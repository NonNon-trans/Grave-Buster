--!nonstrict
-- Executes delivered rbxlx modules with in-memory API doubles, not Roblox.
-- No cloud call reaches a real profile, Remote endpoint, world or player.
-- EMBEDDED_TEST_DOUBLES

local queued, jobId, simulatedTime = {}, 0, 0
local function enqueue(thread, at, arguments)
	jobId+=1
	queued[thread]={At=at,Id=jobId,Arguments=arguments}
	return thread
end
function fakeTask.spawn(callback, ...)
	return enqueue(coroutine.create(callback), simulatedTime, table.pack(...))
end
function fakeTask.defer(callback, ...) return fakeTask.spawn(callback, ...) end
function fakeTask.delay(duration, callback, ...)
	return enqueue(coroutine.create(callback), simulatedTime+duration, table.pack(...))
end
function fakeTask.cancel(thread) queued[thread]=nil end
function fakeTask.wait(duration) return coroutine.yield(duration or 0.03) end
local function step(duration)
	local finish=simulatedTime+duration
	local count=0
	while true do
		local nextThread,nextJob
		for thread,job in queued do
			if job.At<=finish and (not nextJob or job.At<nextJob.At or job.At==nextJob.At and job.Id<nextJob.Id) then nextThread,nextJob=thread,job end
		end
		if not nextJob then break end
		queued[nextThread]=nil; simulatedTime=nextJob.At
		local ok,delay=coroutine.resume(nextThread,table.unpack(nextJob.Arguments))
		assert(ok,tostring(delay))
		if coroutine.status(nextThread)~="dead" then enqueue(nextThread,simulatedTime+math.max(delay or 0.03,0.001),{}) end
		count+=1; assert(count<100000,"Harness scheduling did not converge")
	end
	simulatedTime=finish
end
baseEnvironment.os={clock=function() return simulatedTime end,time=function() return 1000+math.floor(simulatedTime) end}
baseEnvironment.warn=function() end
local roster,records,failLoads,guid={}, {}, {}, 0
players._children={}; players.ChildAdded=signal(); players.PlayerAdded=signal(); players.PlayerRemoving=signal()
function players:GetPlayers() return table.clone(roster) end
services.Workspace=world; services.Lighting=newInstance("Lighting")
services.PhysicsService={IsCollisionGroupRegistered=function() return true end,RegisterCollisionGroup=function() end,CollisionGroupSetCollidable=function() end}
services.HttpService={GenerateGUID=function() guid+=1;return "isolated-test-session-"..guid end}
local memoryStore={}
function memoryStore:UpdateAsync(key,transform)
	if failLoads[key] then error("isolated load failure") end
	local updated=transform(records[key])
	if updated then records[key]=updated end
	return records[key]
end
services.DataStoreService={GetDataStore=function() return memoryStore end}
function fakeGame:BindToClose(callback) self.CloseCallback=callback end
local originalNew=newInstance
newInstance=function(kind)
	local node=originalNew(kind)
	node.OnServerEvent=signal();node.InputEnded=signal()
	node.AbsoluteWindowSize=vector(250,60);node.AbsolutePosition=vector(0,0)
	return node
end
baseEnvironment.Instance.new=newInstance
for _,folder in {combatRemotes,shopRemotes} do for _,event in folder._children do event.OnServerEvent=signal() end end
function methods:GetChildren() return table.clone(self._children) end
function methods:GetDescendants()
	local result={}
	local function visit(node) for _,value in node._children do table.insert(result,value);visit(value) end end
	visit(self);return result
end
function methods:TakeDamage(amount) self.Health=math.max(0,self.Health-amount) end
function methods:Kick(reason) self.Kicked=reason end
function methods:FireClient(target,...) if target==players.LocalPlayer then self.OnClientEvent:Fire(...) end end
function methods:FireAllClients(...) self.OnClientEvent:Fire(...) end
function methods:InvokeServer(...) return self.OnServerInvoke(players.LocalPlayer,...) end
function methods:FireServer(...) self.OnServerEvent:Fire(players.LocalPlayer,...) end
local originalWrite=instanceMeta.__newindex
instanceMeta.__newindex=function(node,key,value)
	local before=node._props[key]
	originalWrite(node,key,value)
	if key=="Health" and before and before>0 and value<=0 then node.Died:Fire() end
end
vectorMeta.__mul=function(a,b)
	if type(a)=="number" then a,b=b,a end
	return vector(a.X*b,a.Y*b,(a.Z or 0)*b)
end
baseEnvironment.CFrame={new=function() return setmetatable({LookVector=vector(0,0,-1),RightVector=vector(1,0,0)}, {__mul=function(a) return a end}) end}
baseEnvironment.OverlapParams={new=function() return {} end}
local oldColor=baseEnvironment.Color3.fromRGB
baseEnvironment.Color3.fromRGB=function(...)
	local color=oldColor(...);function color:Lerp() return self end;return color
end
local oldTween=tweenService.Create
function tweenService:Create(...)
	local value=oldTween(self,...);value.Completed=signal()
	local oldPlay=value.Play
	function value:Play()
		oldPlay(self)
		local pending=self.Pending
		local job=queued[pending]
		if job then
			-- Tween completion is a separate scheduled event after property writes.
			fakeTask.delay(job.At-simulatedTime,function() if self.Active==false then self.Completed:Fire("Completed") end end)
		end
	end
	return value
end
services.UserInputService.InputBegan=signal();services.UserInputService.InputChanged=signal()
services.UserInputService.TouchMoved=signal();services.UserInputService.TouchEnded=signal()
-- Evaluate every generated ModuleScript, including all startup dependencies.
local evaluated=0
for _,node in nodes do if node.ClassName=="ModuleScript" then requireEmbedded(node);evaluated+=1 end end
local function server(name) return requireEmbedded(nodes['ServerScriptService.'..name]) end
local function shared(name) return requireEmbedded(nodes['ReplicatedStorage.Shared.'..name]) end
local P,S,W,H,C=server('ProgressionService'),server('ShopService'),server('WaveService'),server('PlayerHealthService'),server('CombatService')
local D,HC,Weapons,PR=server('DamageRules'),shared('HordeConfig'),shared('WeaponConfig'),server('ProgressionRules')
local container=child(world,"Zombies")
local active,spawnCounts,peak,clears={}, {}, 0, 0
local Z={}
function Z.HasValidTarget()
	for _,p in roster do if p.Character and p.Character.Humanoid.Health>0 then return true end end
	return false
end
function Z.GetActiveCount() local count=0;for _ in active do count+=1 end;return count end
function Z.GetActiveCountForWave(waveNumber) local count=0;for _,e in active do if e.Wave==waveNumber then count+=1 end end;return count end
function Z.GetContainer() return container end
function Z.GetRoot() return nil end -- Geometry/impulses intentionally unmodeled.
function Z.IsActive(model) return active[model]~=nil end
function Z.GetSpawnWave(model) return active[model] and active[model].Wave end
function Z.Spawn(waveNumber)
	local model=child(container,"Zombie","Model");child(model,"Head","Part")
	local hp=HC.GetZombieHP(waveNumber)
	active[model]={Wave=waveNumber,Lifecycle="ACTIVE",CurrentHP=hp,MaxHP=hp}
	spawnCounts[waveNumber]=(spawnCounts[waveNumber] or 0)+1
	peak=math.max(peak,Z.GetActiveCount());assert(peak<=80)
	return model
end
function Z.ApplyDamage(model,damage) return active[model] and D.Apply(active[model],damage) end
function Z.Release(model) if not active[model] then return false end;active[model]=nil;return true end
function Z.ClearForNewRun() clears+=1;for model in active do model:Destroy() end;table.clear(active) end
local function parts()
	local result={};for model in active do table.insert(result,model.Head);table.insert(result,model.Head) end;return result
end
function world:GetPartBoundsInBox() return parts() end
function world:GetPartBoundsInRadius() return parts() end
local function character(p)
	local model=child(world,"Character","Model")
	local humanoid=child(model,"Humanoid","Humanoid");humanoid.Health=100;humanoid.MaxHealth=100
	local root=child(model,"HumanoidRootPart","Part");root.Position=vector(0,0,0);root.CFrame=baseEnvironment.CFrame.new()
	p.Character=model;p.CharacterAdded:Fire(model);step(0)
	return humanoid
end
local function add(p,id)
	p.UserId=id;p.Parent=players;table.insert(roster,p);players.PlayerAdded:Fire(p);step(0)
end
local function leave(p)
	players.PlayerRemoving:Fire(p);p.Parent=nil
	table.remove(roster,assert(table.find(roster,p)));step(0)
end
add(player,1001);local humanoid=character(player)
P.Start();S.Start(P);H.Start(W);C.Start(Z,S,P,H);W.Start(Z,P);step(0)
assert(P.IsReady(player) and player:GetAttribute("PlayerLevel")==1 and player:GetAttribute("Coins")==0)
assert(player:GetAttribute("SessionKills")==0 and humanoid.Health==100 and H.IsProtected(player))
local Owned=requireEmbedded(nodes['ReplicatedStorage.Client.OwnedWeaponSource'])
Owned.ApplyAuthoritativeState(S.GetSnapshot(player))
local Hud=requireEmbedded(nodes['ReplicatedStorage.Client.ProgressionHud'])
local Shop=requireEmbedded(nodes['ReplicatedStorage.Client.ShopController'])
local WaveHud=requireEmbedded(nodes['ReplicatedStorage.Client.WaveHud'])
local Switcher=requireEmbedded(nodes['ReplicatedStorage.Client.WeaponSwitcher'])
local pickerParent=child(playerGui,"IntegrationPickerGui","ScreenGui")
local picker,requests
requests=0
picker=Switcher.Create(pickerParent,Owned.GetOwnedWeapons(),function(weapon) requests+=1;equip:FireServer(weapon) end)
local ownedConnection=Owned.Changed:Connect(function() picker:SetOwnedWeapons(Owned.GetOwnedWeapons());picker:SetSelected(player:GetAttribute("EquippedWeapon")) end)
local equipConnection=player:GetAttributeChangedSignal("EquippedWeapon"):Connect(function() picker:SetSelected(player:GetAttribute("EquippedWeapon")) end)
Hud.Start();WaveHud.Start();Shop.Start({SetShopOpen=function(open) picker:SetEnabled(not open) end});step(0.3)
assert(not H.DamagePlayer(player,10),"Respawn protection lost")
local attack=combatRemotes.AttackRequest
local function swing()
	local before=player:GetAttribute("SessionKills")
	attack.OnServerEvent:Fire(player)
	return player:GetAttribute("SessionKills")-before
end
step(3)
assert(wave.Value==1 and Z.GetActiveCount()>0)
assert(swing()>0 and not H.IsProtected(player))
assert(player:GetAttribute("CurrentXP")>0 and player:GetAttribute("Coins")>0)
local kills=player:GetAttribute("SessionKills");swing();assert(player:GetAttribute("SessionKills")==kills,"Attack cooldown lost")
assert(H.DamagePlayer(player,10) and humanoid.Health==90)
assert(not H.DamagePlayer(player,10) and humanoid.Health==90,"Hit invulnerability lost")
local baseDamage=P.ResolveFinalAttackDamage(player,10)
while W.GetCurrentWave()<5 do swing();step(0.7) end
assert(player:GetAttribute("PlayerLevel")>1 and P.ResolveFinalAttackDamage(player,10)>baseDamage)
assert(HC.GetZombieHP(5)>HC.GetZombieHP(1) and HC.GetZombieDamage(5)>HC.GetZombieDamage(1))
assert(player:GetAttribute("BestWave")>=5)
local shopGui=playerGui.GraveBusterShopGui
shopGui.ShopButton.Activated:Fire();step(0)
local pan=shopGui.ShopOverlay.ShopPanel.WeaponList.FRYING_PAN
local coins=player:GetAttribute("Coins")
pan.Activated:Fire();step(0)
assert(S.IsOwned(player,"FRYING_PAN") and player:GetAttribute("Coins")==coins-shared('ShopConfig').Prices.FRYING_PAN)
assert(player:GetAttribute("EquippedWeapon")=="BASEBALL_BAT","Purchase auto-equipped")
assert(pickerParent.WeaponSwitcher.CurrentWeapon.WeaponTrack:FindFirstChild("WeaponPreview_FRYING_PAN"),"Purchase did not immediately update actual picker")
local costAfter=player:GetAttribute("Coins")
local duplicate=purchase.OnServerInvoke(player,"FRYING_PAN")
assert(not duplicate.Success and duplicate.Reason=="ALREADY_OWNED" and player:GetAttribute("Coins")==costAfter)
shopGui.ShopOverlay.ShopPanel.CloseButton.Activated:Fire()
pickerParent.WeaponSwitcher.NextWeapon.Activated:Fire();step(0.4)
assert(player:GetAttribute("EquippedWeapon")=="FRYING_PAN" and requests==1,"Actual picker one-step equip integration failed")
pickerParent.WeaponSwitcher.NextWeapon.Activated:Fire();step(0.4)
assert(requests==1,"Picker wrapped beyond owned weapons")
local current=player:GetAttribute("EquippedWeapon")
equip.OnServerEvent:Fire(player,"THUNDER_ROD");assert(player:GetAttribute("EquippedWeapon")==current,"Unowned equip accepted")
while W.GetCurrentWave()<20 do swing();step(0.7) end
local quotaWave=W.GetCurrentWave();local quota=HC.GetTotalSpawn(quotaWave)
while Z.GetActiveCount()<80 do step(0.7) end
local atCap=spawnCounts[quotaWave];step(3);assert(Z.GetActiveCount()==80 and spawnCounts[quotaWave]==atCap)
while W.GetCurrentWave()==quotaWave do swing();step(0.7) end
assert(spawnCounts[quotaWave]==quota,"Actual WaveService lost quota under cap pressure")
assert(peak==80 and HC.Intermission==0)
-- Buy through the actual Shop client/server path, then exercise actual picker
-- signals and Heartbeat inertia without changing the protected implementation.
shopGui.ShopButton.Activated:Fire();step(0)
for _,weapon in {"GIANT_HAMMER","BLOWER","THUNDER_ROD"} do
	shopGui.ShopOverlay.ShopPanel.WeaponList[weapon].Activated:Fire();step(0)
	assert(S.IsOwned(player,weapon) and pickerParent.WeaponSwitcher.CurrentWeapon.WeaponTrack:FindFirstChild("WeaponPreview_"..weapon))
end
shopGui.ShopOverlay.ShopPanel.CloseButton.Activated:Fire()
local track=pickerParent.WeaponSwitcher.CurrentWeapon.WeaponTrack
equip:FireServer("BASEBALL_BAT")
local slow={UserInputType="Touch",Position=vector(220,30)}
services.UserInputService.InputBegan:Fire(slow);step(0.2)
slow.Position=vector(100,30);services.UserInputService.TouchMoved:Fire(slow)
assert(math.abs(track.CanvasPosition.X-120)<0.001,"Actual picker drag lost continuous pixel movement")
local requestBefore=requests
services.UserInputService.TouchEnded:Fire(slow);services.UserInputService.InputEnded:Fire(slow);step(0.4)
assert(player:GetAttribute("EquippedWeapon")=="FRYING_PAN" and requests==requestBefore+1,"Release did not snap/equip once")
local flick={UserInputType="Touch",Position=vector(220,30)}
services.UserInputService.InputBegan:Fire(flick);step(0.02)
flick.Position=vector(30,30);services.UserInputService.TouchMoved:Fire(flick)
services.UserInputService.TouchEnded:Fire(flick)
for _=1,40 do services.RunService.Heartbeat:Fire(0.02);step(0.02) end
assert(player:GetAttribute("EquippedWeapon")=="THUNDER_ROD","Actual strong flick/inertia did not reach three slots")
local card=track.WeaponPreview_THUNDER_ROD
assert(math.abs(card.Position.X.Offset-track.CanvasPosition.X-track.AbsoluteWindowSize.X/2)<0.001,"Actual picker card not centered after snap")
track.AbsoluteWindowSize=vector(160,60)
assert(math.abs(card.Position.X.Offset-track.CanvasPosition.X-80)<0.001,"Picker resize broke final card center")
local cancelled={UserInputType="Touch",Position=vector(220,30)}
services.UserInputService.InputBegan:Fire(cancelled);step(0.02)
cancelled.Position=vector(400,30);services.UserInputService.TouchMoved:Fire(cancelled)
local cancelCount=requests
shopGui.ShopButton.Activated:Fire();step(0)
services.UserInputService.TouchEnded:Fire(cancelled);step(0.4)
assert(requests==cancelCount,"Shop-open cancelled drag still equipped")
shopGui.ShopOverlay.ShopPanel.CloseButton.Activated:Fire()
equip:FireServer("FRYING_PAN")
assert(records.Player_1001.SessionExpiresAt>baseEnvironment.os.time(),"Autosave did not retain an active lease")
local beforeDeath=S.GetSnapshot(player);local levelBefore=player:GetAttribute("PlayerLevel");local xpBefore=player:GetAttribute("CurrentXP");local best=player:GetAttribute("BestWave")
humanoid.Health=0;step(0)
assert(wave.Value==0 and clears==1,"Solo death did not reset run")
assert(player:GetAttribute("PlayerLevel")==levelBefore and player:GetAttribute("CurrentXP")==xpBefore and S.GetSnapshot(player).Currency==beforeDeath.Currency)
humanoid=character(player);step(0.6)
assert(wave.Value==1 and player:GetAttribute("BestWave")==best and S.IsOwned(player,"FRYING_PAN"))
assert(player:GetAttribute("EquippedWeapon")=="FRYING_PAN")
while W.GetCurrentWave()<=best do swing();step(0.7) end
assert(player:GetAttribute("BestWave")>best,"Retry could not beat prior record")
local second=newInstance("Player");add(second,1002);local secondHP=character(second);step(0)
local sharedWave=wave.Value
humanoid.Health=0;step(0)
assert(wave.Value==sharedWave,"A surviving multiplayer player lost the shared run")
secondHP.Health=0;step(0)
assert(wave.Value==0,"Last-player death did not reset shared run")
humanoid=character(player);step(0.6);assert(wave.Value==1)
local saved=S.GetSnapshot(player);local savedLevel=player:GetAttribute("PlayerLevel");local savedXP=player:GetAttribute("CurrentXP");local savedBest=player:GetAttribute("BestWave")
leave(player)
local record=records.Player_1001
assert(record.SessionId==nil and record.Level==savedLevel and record.XP==savedXP and record.Coins==saved.Currency and record.BestWave==savedBest)
for _,name in {"Wave","CurrentWave","CurrentHP","SessionKills","RespawnProtected"} do assert(record[name]==nil,"Run state persisted: "..name) end
add(player,1001);humanoid=character(player);step(0.6)
assert(P.IsReady(player) and player:GetAttribute("PlayerLevel")==savedLevel and player:GetAttribute("CurrentXP")==savedXP and player:GetAttribute("BestWave")==savedBest)
assert(S.IsOwned(player,"FRYING_PAN") and S.IsOwned(player,"THUNDER_ROD") and player:GetAttribute("EquippedWeapon")==saved.EquippedWeapon and player:GetAttribute("SessionKills")==0 and wave.Value==1)
local failed=newInstance("Player");failLoads.Player_1003=true;add(failed,1003);step(4)
assert(not P.IsReady(failed) and failed.Kicked and records.Player_1003==nil,"Failed load created defaults")
leave(failed)
shopGui:Destroy() -- Same ownership order as CombatController's live Shop adapter.
ownedConnection:Disconnect();equipConnection:Disconnect();picker:Destroy();pickerParent:Destroy()
for _,guiNode in table.clone(playerGui._children) do guiNode:Destroy() end
leave(player);leave(second);step(5)
assert(#playerGui._children==0 and tweenCount==0)
local longLived=connections
for i=1,20 do local p=newInstance("Player");add(p,2000+i);character(p);leave(p) end
step(5);assert(connections==longLived,"Player lifecycle leaked per-player listeners")
fakeGame.CloseCallback();step(0)
table.clear(queued) -- Test world ends; service lifetime loops are not production leaks.
print(string.format("PASS v0.2 embedded integration: %d ModuleScripts evaluated; actual Progression/Shop/Combat/Health/Wave services and picker; Wave1 rewards→level/power→purchase/immediate picker→high-wave 80/quota→continuous drag/snap/one-step arrows/strong flick/inertia/resize/Shop cancel→solo/multiplayer reset→retain/beat record→save/rejoin/run exclusion/load refusal; lifecycle stable. Engine physics/real DataStore/device NOTRUN.",evaluated))
