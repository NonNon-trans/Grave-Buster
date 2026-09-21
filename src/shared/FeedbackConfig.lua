--!strict

local FeedbackConfig = {
	MaxEffectsPerAttack = 8,
	ImpactLifetime = 0.18,
	TrailLifetime = 0.22,
	WaveEmphasisHold = 0.55,
	WaveEmphasisFade = 0.35,
}

function FeedbackConfig.GetEffectCount(defeatCount: number): number
	return math.min(math.max(math.floor(defeatCount), 0), FeedbackConfig.MaxEffectsPerAttack)
end

function FeedbackConfig.Validate(): boolean
	assert(FeedbackConfig.MaxEffectsPerAttack >= 1 and FeedbackConfig.MaxEffectsPerAttack <= 12)
	assert(FeedbackConfig.ImpactLifetime >= 0.1 and FeedbackConfig.ImpactLifetime <= 0.25)
	assert(FeedbackConfig.TrailLifetime > 0 and FeedbackConfig.TrailLifetime <= 0.3)
	assert(FeedbackConfig.WaveEmphasisHold <= 1)
	assert(FeedbackConfig.WaveEmphasisFade <= 0.5)
	return true
end

return table.freeze(FeedbackConfig)
