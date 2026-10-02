# GB-028 audit and Static Gate scope

Current delivery continues under the user's version-wide instruction in [GB-029 v0.2 RC](GB-029-v0.2-release-candidate.md); older phase-stop statements below are historical. The original audit/baseline remains valid.

The post-review HUD layout revision is documented in [GB-028 HUD layout review](GB-028-hud-layout-review.md). The prior functional Human PASS applies to `d9c306cd11dea3e116a5a2b1cdd96773c16ca99d`; the revised layout awaits a focused Human feel recheck.

Verified develop: `19ef5213eaaffbe982f882374c51fb33397512fc` (live remote matched the user handoff). Initial checkout was the older main revision, with a main-only fetch refspec. Explicit fetch of develop succeeded, then phase branch was created from it with a clean tree. Public visibility was verified through connected GitHub metadata. No remote/visibility change, history rewrite or merge.

No AGENTS.md, repository .agents skills, separate project mapping document or phase-plan file exists in the checked-out develop tree or supplied workspace instruction directories. README and default.project.json provided the mapping/build/phase contracts; the user's handoff is authoritative for GB-021–027 PASS and GB-028/029 gating. Older README Human Gate text is historical and does not supersede the handoff.

Baseline on develop: **18 specs, 56 Lua/Luau compile checks, Rojo 7.7.0 build, generated hierarchy and diff check PASS**. This is separate from the earlier main 14/42 result. Baseline log is included in the handoff.

Changes are feedback presentation and ownership/cleanup of UI tasks only: aggregated explicit XP/Coins grants; counter/bar tween and pulse; current damage and Best Wave in the HUD; one coalescing priority notice area; Shop deferral and named unlock/power feedback; wave clear/current-wave clarity; death/retry cue using the live shared wave; bounded popping damage numbers and replacing HP-bar timers. Shared.ProjectInfo's stale v0.1 label is corrected to v0.2/GB-028. No feedback Heartbeat, external asset, new Remote, gameplay wait or blocking overlay was added.

All server files, numeric/shared gameplay config, CombatController, OwnedWeaponSource, WeaponPresenter, WeaponSwitcher and WeaponSwitcherRules must remain byte-identical to verified develop. The gate enforces this. Shop ownership/purchase authority, DataStore schema/lease, death/run coordination, Damage/HP/overkill, progression/economy, wave quota/cap/intermission and picker tuning are therefore unchanged. Existing full specs are rerun as well.

New tests exercise actual Luau reward/power/layout rules and execute the actual embedded client modules with deterministic Roblox API test doubles. They cover crowd aggregation, level rollover, record/level priority, Shop deferral, purchase event/response ordering and pending guard, power display, live shared-wave retry, full overkill, damage-number cap, HP timer replacement, respawn connection stability and zero retained UI tasks/tweens/connections after teardown. Tests also verify every executable source's bytes/class/hierarchy/compile and literal require target in the fresh rbxlx; corrupt/missing/unexpected executable sources must fail validation.

**Automatic tests are not Roblox engine execution.** Rendering, real replication/order, touch feel, physics, DataStore runtime and physical device performance remain **NOTRUN**, requiring the GB-028 Human Gate. The final artifact SHA, committed source SHA, counts and PASS/FAIL/NOTRUN results are recorded in the ZIP reports. Stop after artifact/checklist delivery. No GB-029 implementation.
