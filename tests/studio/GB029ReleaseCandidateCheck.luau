--!nonstrict
-- TEST-only, read-only Studio client smoke. Not mapped into any Rojo artifact.
-- Set to the already authorized TEST universe GameId before explicit execution.
local TEST_UNIVERSE_ID = 0
local OBSERVE_SECONDS = 180
local RunService = game:GetService("RunService")
assert(RunService:IsStudio(), "GB029 harness: Studio only")
assert(RunService:IsClient(), "GB029 harness: client context only")
assert(TEST_UNIVERSE_ID > 0, "GB029 harness: configure TEST_UNIVERSE_ID first")
assert(game.GameId == TEST_UNIVERSE_ID, "GB029 harness: wrong TEST universe")

local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local function get(parent, name)
	local value = parent:WaitForChild(name, 10)
	assert(value, "GB029 harness: missing " .. name)
	return value
end
local playerGui = get(player, "PlayerGui")
local gui = get(playerGui, "GraveBusterProgressionGui")
local panel = get(gui, "ProgressionPanel")
local content = get(panel, "ProgressionContent")
local toast = get(gui, "LevelUpFeedback")
local waveGui = get(playerGui, "GraveBusterWaveHud")
local wave = get(waveGui, "WaveLabel")
local shopGui = get(playerGui, "GraveBusterShopGui")
local shopButton = get(shopGui, "ShopButton")
local shop = get(shopGui, "ShopOverlay")
local combatGui = get(playerGui, "GraveBusterCombatGui")
local attack = get(combatGui, "AttackButton")
local picker = get(combatGui, "WeaponSwitcher")
local weapons = require(ReplicatedStorage.Shared.WeaponConfig)
local fields={"LevelLabel","KillCounter","CoinsLabel","BestWaveLabel","XPLabel","PowerLabel","RewardFeedback"}
local labels={}
for _, name in fields do labels[name]=get(content,name) end
local changes = {}
local lastChange = os.clock()
local lastGeometry = os.clock()
local observed={}
local frameStats={Count=0,Seconds=0,Worst=0,CrowdCount=0,CrowdSeconds=0,CrowdWorst=0}
local activeCount,activePeak,damagePeak=0,0,0
table.insert(changes,RunService.RenderStepped:Connect(function(dt)
 frameStats.Count+=1;frameStats.Seconds+=dt;frameStats.Worst=math.max(frameStats.Worst,dt)
 if activeCount>=80 then frameStats.CrowdCount+=1;frameStats.CrowdSeconds+=dt;frameStats.CrowdWorst=math.max(frameStats.CrowdWorst,dt) end
end))
local attributeEvents={PlayerLevel="level growth",CurrentXP="XP gain",Coins="coins change",BestWave="new record",SessionKills="kill reward",EquippedWeapon="weapon equip"}
for _, signal in { GuiService:GetPropertyChangedSignal("TopbarInset"), gui:GetPropertyChangedSignal("AbsoluteSize"), gui:GetPropertyChangedSignal("AbsolutePosition") } do
	table.insert(changes, signal:Connect(function() lastGeometry = os.clock() end))
end
for _, name in {"PlayerLevel", "CurrentXP", "RequiredXP", "Coins", "BestWave", "SessionKills", "EquippedWeapon"} do
 table.insert(changes, player:GetAttributeChangedSignal(name):Connect(function()
  lastChange = os.clock()
  if attributeEvents[name] then observed[attributeEvents[name]]=true end
 end))
end
local healthConnection=nil
local function observeHealth(character)
 if healthConnection then healthConnection:Disconnect();healthConnection=nil end
 local humanoid=character:WaitForChild("Humanoid",10)
 if not humanoid then return end
 local previous=humanoid.Health
 healthConnection=humanoid.HealthChanged:Connect(function(hp)
  if hp<previous then observed["player damaged"]=true end
  if hp<=0 then observed["death"]=true end
  previous=hp
 end)
end
if player.Character then observeHealth(player.Character) end
table.insert(changes,player.CharacterAdded:Connect(function(character) observed["spawn/retry"]=true;observeHealth(character) end))
local waveValue=get(ReplicatedStorage,"WaveNumber")
table.insert(changes,waveValue.Changed:Connect(function() lastChange=os.clock();observed["wave transition"]=true end))
local owned=require(ReplicatedStorage.Client.OwnedWeaponSource)
local previousOwned=#owned.GetOwnedWeapons()
table.insert(changes,owned.Changed:Connect(function()
 local count=#owned.GetOwnedWeapons()
 if count>previousOwned then observed["ownership/picker update"]=true end
 previousOwned=count
end))
table.insert(changes,shop:GetPropertyChangedSignal("Visible"):Connect(function() observed["Shop open/close"]=true end))
local function rect(object)
 local p, s = object.AbsolutePosition, object.AbsoluteSize
 return {X=p.X,Y=p.Y,W=s.X,H=s.Y}
end
local function overlaps(a,b)
 return a.X < b.X+b.W-2 and a.X+a.W > b.X+2 and a.Y < b.Y+b.H-2 and a.Y+a.H > b.Y+2
end
local function inside(a,b)
 return a.X>=b.X-2 and a.Y>=b.Y-2 and a.X+a.W<=b.X+b.W+2 and a.Y+a.H<=b.Y+b.H+2
end
local function centerX(r) return r.X+r.W/2 end
local samples = 0
local function check()
 local zombies=workspace:FindFirstChild("Zombies")
 local numbers=0
 activeCount=0
 if zombies then for _,model in zombies:GetChildren() do
  if model:GetAttribute("ZombieState")=="ACTIVE" then activeCount+=1 end
  local head=model:FindFirstChild("Head")
  local bars=0
  if head then for _,item in head:GetChildren() do
   if item.Name=="ZombieDamageNumber" then numbers+=1 end
   if item.Name=="ZombieHealthBar" then bars+=1 end
  end end
  assert(bars<=1,"Duplicate zombie HP bars")
 end end
 assert(numbers<=24,"Damage number live cap exceeded")
 activePeak=math.max(activePeak,activeCount);damagePeak=math.max(damagePeak,numbers)
 assert(gui.ScreenInsets==Enum.ScreenInsets.CoreUISafeInsets)
 assert(waveGui.ScreenInsets==Enum.ScreenInsets.TopbarSafeInsets)
 assert(shopGui.ScreenInsets==Enum.ScreenInsets.CoreUISafeInsets)
 assert(not playerGui:FindFirstChild("GraveBusterShopTopbarGui"),"Old topbar SHOP survived")
 for _, screen in {gui,waveGui} do assert(screen.SafeAreaCompatibility==Enum.SafeAreaCompatibility.None) end
 local top=GuiService:GetInsetArea(Enum.ScreenInsets.TopbarSafeInsets)
 local origin=gui.AbsolutePosition
 local topRect={X=origin.X+top.Min.X,Y=origin.Y+top.Min.Y,W=top.Width,H=top.Height}
 local h,w,s,n=rect(panel),rect(wave),rect(shopButton),rect(toast)
 assert(h.W>h.H*3, "HUD is not horizontal")
 if 2*(s.X-12-centerX(w))>=240 then assert(math.abs(centerX(h)-centerX(w))<=2, "HUD shifted despite available space") end
 assert(h.Y>=origin.Y and h.Y-origin.Y<=10, "HUD extra top inset returned")
 if wave.Visible then assert(inside(w,topRect), "WAVE outside unoccupied topbar") end
 local core=GuiService:GetInsetArea(Enum.ScreenInsets.CoreUISafeInsets)
 local coreRect={X=origin.X,Y=origin.Y,W=core.Width,H=core.Height}
 local coreHealthBand={X=origin.X,Y=origin.Y+top.Min.Y,W=core.Width,H=-top.Min.Y}
 assert(inside(s,coreRect) and not overlaps(s,coreHealthBand),"SHOP overlaps reserved CoreUI/health band")
 assert(math.abs(s.Y-origin.Y-16)<=2 and math.abs(coreRect.X+coreRect.W-s.X-s.W-18)<=2,"SHOP original position changed")
 assert(math.abs(s.W-112)<=2 and math.abs(s.H-46)<=2,"SHOP original size changed")
 assert(not overlaps(w,s) and not overlaps(h,s),"SHOP overlaps WAVE/HUD")
 if toast.Visible then assert(not overlaps(n,s),"SHOP/notice overlap") end
 if shop.Visible then assert(not panel.Visible and not toast.Visible, "Shop/HUD overlap") end
 if panel.Visible then
  assert(not overlaps(h,rect(attack)) and not overlaps(h,rect(picker)), "HUD/combat overlap")
  assert(not overlaps(h,n) or not toast.Visible, "HUD/notice overlap")
 end
 if toast.Visible then assert(not overlaps(n,rect(attack)) and not overlaps(n,rect(picker)), "Notice/combat overlap") end
 for _, name in fields do assert(inside(rect(labels[name]),h), "HUD field outside panel: "..name) end
 for i=1,#fields do for j=i+1,#fields do
  assert(not overlaps(rect(labels[fields[i]]),rect(labels[fields[j]])), "HUD fields overlap")
 end end
 if player:GetAttribute("ProgressionReady")==true and os.clock()-lastChange>0.4 then
  local level,xp,required,coins,best=player:GetAttribute("PlayerLevel"),player:GetAttribute("CurrentXP"),player:GetAttribute("RequiredXP"),player:GetAttribute("Coins"),player:GetAttribute("BestWave")
  assert(level>=1 and required==100+(level-1)*50 and xp>=0 and xp<required and coins>=0 and best>=1,"Invalid settled progression attributes")
  assert(math.round(gui.DisplayedXP.Value)==xp and math.round(gui.DisplayedCoins.Value)==coins, "Counters disagree with server attributes after settle")
  assert(content.XPLabel.Text==string.format("%d / %d XP",xp,required))
  assert(content.CoinsLabel.Text==string.format("COINS %d",coins))
  assert(content.LevelLabel.Text==string.format("LEVEL %d",level))
  assert(content.BestWaveLabel.Text==string.format("BEST WAVE %d",best))
  assert(content.KillCounter.Text==string.format("KILLS %d",player:GetAttribute("SessionKills") or 0))
  local ownedWeapons=owned.GetOwnedWeapons()
  local viewport=picker.CurrentWeapon.WeaponTrack
  for _,weaponId in ownedWeapons do assert(viewport:FindFirstChild("WeaponPreview_"..weaponId),"Owned weapon missing from picker: "..weaponId) end
  local equippedIndex=table.find(ownedWeapons,player:GetAttribute("EquippedWeapon"))
  assert(equippedIndex,"Equipped weapon absent from owned picker list")
  if math.abs(picker.ScrollPosition.Value-equippedIndex)<0.001 then
   assert(math.abs(centerX(rect(viewport["WeaponPreview_"..ownedWeapons[equippedIndex]]))-centerX(rect(viewport)))<=2,"Settled picker card not centered")
  end
  local weapon=weapons.Get(player:GetAttribute("EquippedWeapon"))
  if weapon then
   local damage=math.round(weapon.BaseDamage*(1+0.05*(level-1)))
   assert(content.PowerLabel.Text==string.format("%s  •  %d DMG",weapon.IconGlyph,damage))
  end
 end
 samples+=1
end
local ok,reason=pcall(function()
 -- Gives real inset/parenting/tweens time to settle, then observes normal play.
 task.wait(1)
 local deadline=os.clock()+OBSERVE_SECONDS
 while os.clock()<deadline and gui.Parent do
	if os.clock()-lastGeometry>0.2 then check() end
	task.wait(0.25)
 end
end)
for _, connection in changes do connection:Disconnect() end
if healthConnection then healthConnection:Disconnect() end
assert(ok, reason)
assert(samples>0, "GB029 harness: no settled layout samples; NOTRUN")
print(string.format("[GB029 TEST] PASS %d real-engine layout/value samples; read-only, no gameplay/data mutation.",samples))
print(string.format("[GB029 TEST] client ACTIVE peak %d; damage number peak %d; sampled FPS %.1f; worst frame %.1f ms (measurements, no invented performance threshold)",activePeak,damagePeak,frameStats.Count/math.max(0.001,frameStats.Seconds),frameStats.Worst*1000))
if frameStats.CrowdCount>0 then
 print(string.format("[GB029 TEST] 80+ replicated ACTIVE crowd: %d frames, %.1f FPS, %.1f ms worst; physics/device feel not certified",frameStats.CrowdCount,frameStats.CrowdCount/frameStats.CrowdSeconds,frameStats.CrowdWorst*1000))
else print("[GB029 TEST] real 80-crowd performance: NOTRUN / not observed") end
for _,event in {"player damaged","level growth","XP gain","coins change","new record","kill reward","weapon equip","death","spawn/retry","wave transition","ownership/picker update","Shop open/close"} do
 print(string.format("[GB029 TEST] %s: %s",event,if observed[event] then "OBSERVED (sampled layout/display checks)" else "NOTRUN / not observed"))
end
