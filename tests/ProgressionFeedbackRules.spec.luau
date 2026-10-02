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
for _, size in { {480, 300}, {568, 320}, {667, 375}, {844, 390}, {1024, 768}, {1920, 1080} } do
	local w, h = size[1], size[2]
	local layout = Rules.Layout(w, h)
	local hud = {layout.PanelX, layout.PanelY, layout.PanelWidth, layout.PanelHeight * layout.PanelScale}
	local notice = {layout.NoticeX, layout.NoticeY, layout.NoticeWidth, layout.NoticeHeight}
	local wave = {w / 2 - 184 * 1.08 / 2, 16, 184 * 1.08, 32 * 1.08}
	local kills = {18, 16, 116, 36}
	local shop = {w - 130, 16, 112, 46}
	local attack = {w - 142, h * 0.6 - 56, 112, 112}
	local picker = {(w - math.clamp(w * 0.42, 280, 430)) / 2, h - 86, math.clamp(w * 0.42, 280, 430), 74}
	assert(not overlap(hud, notice))
	for _, ui in {wave, kills, shop, attack, picker} do
		assert(not overlap(hud, ui), string.format("HUD overlap %dx%d", w, h))
		assert(not overlap(notice, ui), string.format("Notice overlap %dx%d", w, h))
	end
	assert(not overlap(wave, kills) and not overlap(wave, shop))
	assert(notice[1] + notice[3] <= w - 18)
end
print("PASS ProgressionFeedbackRules: 80-kill aggregation, no load/purchase gains, overflow, authoritative damage agreement, bounded notices and PC/landscape lanes")
