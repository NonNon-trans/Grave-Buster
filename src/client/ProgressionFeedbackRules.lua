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

function Rules.Layout(width: number, height: number)
	local panelWidth = 186
	local noticeWidth = math.min(280, math.max(0, width - panelWidth - 54))
	return {
		PanelX = 18, PanelY = 58, PanelWidth = panelWidth, PanelHeight = 116,
		NoticeX = math.clamp((width - noticeWidth) / 2, panelWidth + 36, width - noticeWidth - 18),
		NoticeY = 68, NoticeWidth = noticeWidth, NoticeHeight = 48,
		PanelScale = math.min(1, math.max(0.65, (height - 126) / 116)),
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
