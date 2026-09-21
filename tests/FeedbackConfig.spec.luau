--!strict

local FeedbackConfig = require("../src/shared/FeedbackConfig")

assert(FeedbackConfig.Validate())
assert(FeedbackConfig.GetEffectCount(0) == 0)
assert(FeedbackConfig.GetEffectCount(3) == 3)
assert(FeedbackConfig.GetEffectCount(100) == FeedbackConfig.MaxEffectsPerAttack)
assert(FeedbackConfig.TrailLifetime == 0.22)

print("PASS FeedbackConfig: short trail cleanup lifetime and bounded effect batch")
