--!nonstrict
-- TEST-only, read-only Studio client smoke. Not mapped into any Rojo artifact.
-- Set to the already authorized TEST universe GameId before explicit execution.
local TEST_UNIVERSE_ID = 0
local RunService = game:GetService("RunService")
assert(RunService:IsStudio(), "GB028 harness: Studio only")
assert(RunService:IsClient(), "GB028 harness: client context only")
assert(TEST_UNIVERSE_ID > 0, "GB028 harness: configure TEST_UNIVERSE_ID first")
assert(game.GameId == TEST_UNIVERSE_ID, "GB028 harness: wrong TEST universe")

local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local function get(parent, name)
	local value = parent:WaitForChild(name, 10)
	assert(value, "GB028 harness: missing " .. name)
	return value
end
local playerGui = get(player, "PlayerGui")
local gui = get(playerGui, "GraveBusterProgressionGui")
local panel = get(gui, "ProgressionPanel")
local content = get(panel, "ProgressionContent")
local toast = get(gui, "LevelUpFeedback")
local waveGui = get(playerGui, "GraveBusterWaveHud")
local wave = get(waveGui, "WaveLabel")
local shopTopbar = get(playerGui, "GraveBusterShopTopbarGui")
local shopButton = get(shopTopbar, "ShopButton")
local shop = get(get(playerGui, "GraveBusterShopGui"), "ShopOverlay")
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
for _, signal in { GuiService:GetPropertyChangedSignal("TopbarInset"), gui:GetPropertyChangedSignal("AbsoluteSize"), gui:GetPropertyChangedSignal("AbsolutePosition") } do
	table.insert(changes, signal:Connect(function() lastGeometry = os.clock() end))
end
for _, name in {"PlayerLevel", "CurrentXP", "RequiredXP", "Coins", "BestWave", "SessionKills", "EquippedWeapon"} do
 table.insert(changes, player:GetAttributeChangedSignal(name):Connect(function() lastChange = os.clock() end))
end
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
 assert(gui.ScreenInsets==Enum.ScreenInsets.CoreUISafeInsets)
 assert(waveGui.ScreenInsets==Enum.ScreenInsets.TopbarSafeInsets)
 assert(shopTopbar.ScreenInsets==Enum.ScreenInsets.TopbarSafeInsets)
 for _, screen in {gui,waveGui,shopTopbar} do assert(screen.SafeAreaCompatibility==Enum.SafeAreaCompatibility.None) end
 local top=GuiService:GetInsetArea(Enum.ScreenInsets.TopbarSafeInsets)
 local origin=gui.AbsolutePosition
 local topRect={X=origin.X+top.Min.X,Y=origin.Y+top.Min.Y,W=top.Width,H=top.Height}
 local h,w,s,n=rect(panel),rect(wave),rect(shopButton),rect(toast)
 assert(h.W>h.H*3, "HUD is not horizontal")
 assert(math.abs(centerX(h)-centerX(w))<=2, "HUD not directly below WAVE")
 assert(h.Y>=origin.Y and h.Y-origin.Y<=10, "HUD extra top inset returned")
 if wave.Visible then assert(inside(w,topRect), "WAVE outside unoccupied topbar") end
 if shopButton.Visible then assert(inside(s,topRect), "SHOP outside unoccupied topbar") end
 assert(math.abs(w.Y+w.H/2-s.Y-s.H/2)<=2, "WAVE/SHOP height mismatch")
 assert(not overlaps(w,s), "Topbar controls overlap")
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
  assert(math.round(gui.DisplayedXP.Value)==xp and math.round(gui.DisplayedCoins.Value)==coins, "Counters disagree with server attributes after settle")
  assert(content.XPLabel.Text==string.format("%d / %d XP",xp,required))
  assert(content.CoinsLabel.Text==string.format("COINS %d",coins))
  assert(content.LevelLabel.Text==string.format("LEVEL %d",level))
  assert(content.BestWaveLabel.Text==string.format("BEST WAVE %d",best))
  assert(content.KillCounter.Text==string.format("KILLS %d",player:GetAttribute("SessionKills") or 0))
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
 local deadline=os.clock()+20
 while os.clock()<deadline and gui.Parent do
	if os.clock()-lastGeometry>0.2 then check() end
	task.wait(0.25)
 end
end)
for _, connection in changes do connection:Disconnect() end
assert(ok, reason)
assert(samples>0, "GB028 harness: no settled layout samples; NOTRUN")
print(string.format("[GB028 TEST] PASS %d real-engine layout/value samples; no gameplay/data mutation. Observation only: untriggered events are NOTRUN.",samples))
