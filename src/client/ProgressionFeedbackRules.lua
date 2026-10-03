--!strict

local Rules = {}
Rules.Tuning = table.freeze({
	RewardWindow = 0.65, RewardHold = 1.1, CounterDuration = 0.22,
	NoticeLifetime = 2.2, MaxDamageNumbers = 24,
})

local function positive(value): number
	return if type(value) == "number" and value > 0 and value < math.huge then math.floor(value) else 0
end

-- Only explicit server grants are rewards. Load/purchase/equip/replication
-- must never synthesize a gain, including across a current-level XP rollover.
function Rules.AccumulateRewards(batch, snapshot)
	batch.XP += positive(snapshot.XPGranted)
	batch.Coins += positive(snapshot.CoinsGranted) + positive(snapshot.WaveClearBonus)
end

function Rules.TakeRewards(batch): string
	local parts = {}
	if batch.XP > 0 then table.insert(parts, string.format("+%d XP", batch.XP)) end
	if batch.Coins > 0 then table.insert(parts, string.format("+%d COINS", batch.Coins)) end
	batch.XP, batch.Coins = 0, 0
	return table.concat(parts, "  •  ")
end

-- Display estimate only; combat continues to use the server's AttackDamage.
function Rules.PowerDamage(baseDamage: number, level: number): number
	return math.round(baseDamage * (1 + 0.05 * (math.max(1, level) - 1)))
end

function Rules.Layout(width: number, height: number, topbar, device)
	local margin, gap = 8, 12
	local topWidth = math.max(0, topbar.Width)
	local topHeight = math.max(0, topbar.Height)
	local shopWidth = math.min(112, math.max(44, topWidth * 0.3), topWidth)
	local waveWidth = math.max(0, math.min(184, (topWidth - shopWidth - margin * 2 - gap) / 1.08))
	local waveHalf = waveWidth * 1.08 / 2
	local firstCenter = topbar.X + margin + waveHalf
	local lastCenter = math.max(firstCenter, topbar.X + topWidth - shopWidth - margin - gap - waveHalf)
	local waveCenter = math.clamp(width / 2, firstCenter, lastCenter)
	local panelWidth = math.max(0, math.min(520, 2 * math.min(waveCenter - margin, width - margin - waveCenter)))
	-- SHOP is restored below CoreUI at its original right/top offsets. Keep the
	-- horizontal HUD under WAVE when space permits, excluding that button lane.
	local shopLeft = width - 130
	local centeredRoom = math.max(0, 2 * (shopLeft - gap - waveCenter))
	local panelCenter = waveCenter
	if centeredRoom >= 240 then
		panelWidth = math.min(panelWidth, centeredRoom)
	else
		panelWidth = math.max(0, math.min(panelWidth, 240, shopLeft - gap - margin))
		panelCenter = math.max(margin + panelWidth / 2, math.min(waveCenter, shopLeft - gap - panelWidth / 2))
	end
	local attackLeft = device.X + device.Width - 142
	local attackTop = device.Y + device.Height * 0.6 - 56
	local panelHeight = math.max(0, math.min(58, attackTop - 6 - 8))
	local noticeWidth = math.max(0, math.min(280, attackLeft - gap - margin))
	local noticeCenter = math.clamp(waveCenter, margin + noticeWidth / 2, math.max(margin + noticeWidth / 2, attackLeft - gap - noticeWidth / 2))
	local noticeY = 6 + panelHeight + 6
	local pickerTop = device.Y + device.Height - 86
	return {
		TopbarVisible = waveWidth > 0 and topHeight > 0,
		WaveCenterX = waveCenter, WaveX = waveCenter - topbar.X,
		WaveY = topHeight / 2, WaveWidth = waveWidth,
		WaveHeight = math.max(0, math.min(32, (topHeight - margin) / 1.08)),
		ShopX = topWidth - margin - shopWidth / 2, ShopY = topHeight / 2,
		ShopWidth = shopWidth, ShopHeight = math.max(0, math.min(44, topHeight - margin)),
		PanelX = panelCenter - panelWidth / 2, PanelY = 6,
		PanelCenterX = panelCenter,
		PanelWidth = panelWidth, PanelHeight = panelHeight,
		NoticeX = noticeCenter - noticeWidth / 2, NoticeY = noticeY,
		NoticeWidth = noticeWidth, NoticeHeight = math.max(0, math.min(44, pickerTop - noticeY - margin)),
	}
end

-- Three coalescing slots; crowds cannot create an unbounded toast queue.
function Rules.PushNotice(queue, kind: string, text: string, priority: number)
	assert(kind == "Level" or kind == "Record" or kind == "Retry")
	queue[kind] = { Kind = kind, Text = text, Priority = priority }
end

function Rules.PopNotice(queue)
	local best = nil
	for _, kind in { "Retry", "Record", "Level" } do
		local notice = queue[kind]
		if notice and (not best or notice.Priority > best.Priority) then best = notice end
	end
	if best then queue[best.Kind] = nil end
	return best
end

return table.freeze(Rules)
