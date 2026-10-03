--!strict
local Rules = require("../src/client/ProgressionFeedbackRules")
local Progression = require("../src/server/ProgressionRules")
local Weapons = require("../src/shared/WeaponConfig")

local batch = { XP = 0, Coins = 0 }
Rules.AccumulateRewards(batch, { Level = 30, CurrentXP = 400, Coins = 10000 })
assert(Rules.TakeRewards(batch) == "", "Loading a saved profile is not a reward")
for _ = 1, 80 do Rules.AccumulateRewards(batch, { XPGranted = 7, CoinsGranted = 1 }) end
Rules.AccumulateRewards(batch, { WaveClearBonus = 40 })
assert(Rules.TakeRewards(batch) == "+560 XP  •  +120 COINS")
assert(Rules.TakeRewards(batch) == "", "Flushing a batch must not replay rewards")
Rules.AccumulateRewards(batch, { XPGranted = -1, CoinsGranted = math.huge, WaveClearBonus = "bad" })
assert(Rules.TakeRewards(batch) == "")
local state = Progression.NewState()
state.XP = 95
local reward = Progression.AwardZombieDefeats(state, 1, 6)
Rules.AccumulateRewards(batch, reward)
assert(state.Level == 2 and state.XP == 25)
assert(Rules.TakeRewards(batch) == "+30 XP  •  +6 COINS", "Level rollover must retain the real grant")
for level = 1, 100 do
	for _, id in Weapons.Order do
		local base = Weapons.Get(id).BaseDamage
		assert(Rules.PowerDamage(base, level) == Progression.FinalAttackDamage(base, level))
	end
end
local queue = {}
for n = 1, 80 do Rules.PushNotice(queue, "Record", tostring(n), 4) end
Rules.PushNotice(queue, "Level", "level", 3)
Rules.PushNotice(queue, "Retry", "retry", 5)
assert(Rules.PopNotice(queue).Kind == "Retry")
assert(Rules.PopNotice(queue).Text == "80")
assert(Rules.PopNotice(queue).Kind == "Level")
assert(Rules.PopNotice(queue) == nil)
local function overlap(a, b)
	return a[1] < b[1] + b[3] and a[1] + a[3] > b[1] and a[2] < b[2] + b[4] and a[2] + a[4] > b[2]
end
local cases = 0
for _, size in { {360, 220}, {480, 240}, {568, 262}, {667, 317}, {844, 332}, {1024, 710}, {1920, 1022} } do
 for _, topHeight in {36, 44, 58, 64} do
  for _, leftRatio in {0.12, 0.30, 0.48, 0.62} do
   local w, h = size[1], size[2]
   local left = w * leftRatio
   local top = {X=left, Y=-topHeight, Width=w-left-8, Height=topHeight}
   local device = {X=0, Y=-topHeight, Width=w, Height=h+topHeight}
   local g = Rules.Layout(w,h,top,device)
   local hud = {g.PanelX,g.PanelY,g.PanelWidth,g.PanelHeight}
   local notice = {g.NoticeX,g.NoticeY,g.NoticeWidth,g.NoticeHeight}
   local wave = {top.X+g.WaveX-g.WaveWidth*1.08/2, top.Y+g.WaveY-g.WaveHeight*1.08/2,g.WaveWidth*1.08,g.WaveHeight*1.08}
   local shop = {top.X+g.ShopX-g.ShopWidth/2,top.Y+g.ShopY-g.ShopHeight/2,g.ShopWidth,g.ShopHeight}
   local restoredShop = {w-130,16,112,46}
   local coreHealthBand = {0,-topHeight,w,topHeight}
   local attack = {w-142,device.Y+device.Height*0.6-56,112,112}
   local picker = {(w-math.clamp(w*0.42,280,430))/2,h-86,math.clamp(w*0.42,280,430),74}
   if g.TopbarVisible then
    assert(wave[1]>=top.X and wave[1]+wave[3]<=top.X+top.Width+0.001)
    assert(shop[1]>=top.X and shop[1]+shop[3]<=top.X+top.Width+0.001)
    assert(wave[2]>=top.Y and wave[2]+wave[4]<=0.001)
    assert(shop[2]>=top.Y and shop[2]+shop[4]<=0.001)
    assert(not overlap(wave,shop), "Topbar controls overlap")
    assert(g.WaveY==g.ShopY, "Topbar vertical center differs")
   end
   assert(math.abs(hud[1]+hud[3]/2-g.PanelCenterX)<0.001)
   if 2*(restoredShop[1]-12-g.WaveCenterX)>=240 then
    assert(g.PanelCenterX==g.WaveCenterX, "HUD shifted from WAVE despite available space")
   end
   assert(not overlap(restoredShop,coreHealthBand), "SHOP overlaps CoreUI health/topbar")
   assert(not overlap(hud,restoredShop), "Restored SHOP overlaps horizontal HUD")
   assert(not overlap(notice,restoredShop), "Restored SHOP overlaps notice")
   assert(hud[1]>=0 and hud[1]+hud[3]<=w)
   assert(hud[2]==6 and hud[4]<=58, "Old double-inset/vertical HUD returned")
   assert(hud[3]>hud[4], "HUD must be horizontal")
   assert(not overlap(hud,notice))
   for _, ui in {attack,picker} do
    assert(not overlap(hud,ui), "HUD overlaps combat control")
    assert(not overlap(notice,ui), "Notice overlaps combat control")
   end
   assert(notice[1]>=0 and notice[1]+notice[3]<=w)
   cases+=1
  end
 end
end
local startup=Rules.Layout(0,0,{X=0,Y=0,Width=0,Height=0},{X=0,Y=0,Width=0,Height=0})
assert(not startup.TopbarVisible)
print("PASS ProgressionFeedbackRules: 80-kill aggregation, authoritative power, bounded notices and "..cases.." live-inset layout cases with topbar/HUD/notice/control separation")
