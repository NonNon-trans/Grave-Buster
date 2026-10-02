# GB-028 HUD topbar revision — Human feel recheck

**Historical guide, superseded by the user's version-wide completion instruction.** SHOP is now restored after the HP/CoreUI overlap review; use [v0.2 final Human Check](GB-029-final-human-check.md) and its Release Candidate artifact. The old phase stop below is retained only as review history.

The user reported all prior GB-028 test items PASS on revision `d9c306cd11dea3e116a5a2b1cdd96773c16ca99d`, then requested a layout change because the HUD obstructed play. That functional review is recorded; this new layout still requires Human recheck. Do not mark the new revision Human PASS or begin GB-029/merge before that report.

Current revision: use `SOURCE_REVISION.txt` in the latest Library ZIP. The new artifact filename is **`Grave-Buster-v0.2-GB028-hud-topbar.rbxlx`**. Older `GB028-human-gate.rbxlx` artifacts are superseded for this recheck.

## Fresh delivery

1. Download the latest version of the same Library handoff, `Grave-Buster-GB028-HUD-Topbar-Human-Handoff.zip`, into a new directory. Check its supplied ZIP SHA and run `shasum -a 256 -c SHA256SUMS.txt` (Mac) or `sha256sum -c SHA256SUMS.txt` (Linux). Read `SOURCE_REVISION.txt`, `reports/final-static-gate.json` and `reports/source-artifact.json`; the source/remote revision and all embedded source hashes must agree.
2. **Rojo Disconnect, stop the Grave Buster Rojo serve process, no LiveSync during Human Gate.** Open the new `Grave-Buster-v0.2-GB028-hud-topbar.rbxlx` in a fresh Studio window. Confirm `ReplicatedStorage.Client.HudLayout` exists; its Source uses `GuiService:GetInsetArea`. Shared.ProjectInfo must say `v0.2 development (GB-028 HUD topbar)`.
3. Publish this exact artifact yourself to the already authorized **TEST Experience/test universe only**, with its established DataStore configuration. Do not publish production, change security settings, delete profiles or inject failure into real profiles. If Studio cannot access the existing TEST profile, use the published TEST for normal play; protected load refusal is not a HUD regression.
4. Fully close old RobloxClients and join the fresh TEST version on **PC** and **physical Mobile Landscape**. Keep Rojo disconnected. Check delivery first if the layout/source differs.

## Automatic checks and optional real-engine check

Cloud checks cover full existing numeric/state specs, compile/build, protected gameplay sources, all executable embedded source/dependency agreement, 112 varied live-inset coordinate cases, actual embedded client code with API test doubles, reward/purchase/notice/run/picker integration, and teardown. These are automatic PASS when recorded in the reports; they do not certify Roblox engine rendering, real touch/physics/replication or device performance.

A read-only real-engine client check is included at `source/tests/studio/GB028HudLayoutCheck.luau`. It is deliberately **excluded from the Rojo artifact**. In the existing TEST place only, set its first `TEST_UNIVERSE_ID` value to that TEST universe's GameId, enter Studio Play and select **Client** context, then execute the file's contents in the Command Bar. It observes about 20 seconds of ordinary play and automatically checks real safe rectangles, header/HUD/control separation, field separation, Shop masking and settled server-attribute/counter/power/KILLS agreement. It prints `[GB028 TEST] PASS ...` or asserts the specific failure. Try Shop open/close and viewport/emulator resize while it observes; no manual measurement or numeric checking is needed.

The check refuses Studio-external, server context, unconfigured ID and another universe. It creates no UI, sends no Remote, mutates no gameplay/profile, and disconnects its listeners at completion. Do not add it to src, save it into a production place or Publish it. Its guards are tested automatically in cloud; **real-engine execution is NOTRUN in cloud**. An unobserved event is NOTRUN, not an automatic PASS. If this check is not run, report that clearly; do not substitute the cloud test-double run for it.

## Human questions — feel only

- [ ] PC and physical Mobile Landscape: WAVE and SHOP feel aligned with the Roblox standard menu bar, standard buttons/notch remain usable, and the horizontal HUD feels directly under WAVE without blocking the fight. Text is legible, including on the smallest intended device and after rotation/resize.
- [ ] During normal combat, HUD counter motion and aggregate rewards are noticeable without spam. Level Up / NEW RECORD / clear / retry messages are readable and do not distract or obscure aiming, attack or picker gestures.
- [ ] Shop open/close and its raised button feel easy to reach; picker drag, snap, arrows and deliberate flick retain the previously passed feel. Movement, camera, jump and attack remain comfortable.
- [ ] During a normal crowd fight, UI motion causes no noticeable performance decline. Repeat a death/retry if useful to judge whether the new top HUD still feels unobtrusive.

Numeric contracts, state retention and passed functional regressions are covered by automatic tests and the unchanged gameplay source guard. Do not repeat a broad manual numbers/state checklist solely for this layout change. Never reset or damage stored TEST progression to create a case.

## Report

```text
GB-028 HUD recheck
SHA: [SOURCE_REVISION.txt]
TEST place / published version:
PC: [feel PASS / FAIL, environment]
Mobile: [feel PASS / FAIL, device, Landscape]
1 Topbar/HUD placement and readability:
2 Feedback readability/distraction:
3 Shop/input/picker feel:
4 Crowd/performance feel:
Studio read-only auto-check: PASS / FAIL / NOTRUN [paste Output]
Unobserved cases / failures / screenshot:
Overall new-layout Human Gate: PASS / FAIL / pending
Merge approval: yes / no [separate decision]
```

No develop/main merge, tag/release, production Publish or GB-029 before the recheck and separate merge approval.
