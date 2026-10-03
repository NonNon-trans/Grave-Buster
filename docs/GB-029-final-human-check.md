# v0.2 Release Candidate — 最終Human Check

旧 `86d2635896fa3098504b57357abae995ded39165` では、SHOPと被弾HP表示の重なり以外はユーザーPASSでした。今回SHOPを元のCoreUI下の位置へ戻し、WAVE・横長HUDの構成を維持しました。version単位の統合・回帰も自動検証済みです。追加機能や細かいUI polishは行いません。

対象は最新Library ZIP内の `SOURCE_REVISION.txt` にあるSHAです。新artifactは **`Grave-Buster-v0.2-Release-Candidate.rbxlx`**。旧GB028 artifactを再利用しないでください。

## 必ずfresh artifactを届ける

1. 最新版 `Grave-Buster-v0.2-Release-Candidate-Handoff.zip` を新しいフォルダへ展開し、報告されたZIP SHAを確認。展開先で `shasum -a 256 -c SHA256SUMS.txt`（Mac）または `sha256sum -c SHA256SUMS.txt`（Linux）を実行。`SOURCE_REVISION.txt` / `reports/final-static-gate.json` / `reports/source-artifact.json` のSHA・全embedded sourceが一致することを確認します。
2. **Rojo Disconnect → Grave BusterのRojo serveを停止 → LiveSyncなし。** 新artifactをfresh Studio windowで開きます。`Shared.ProjectInfo.Version` は `v0.2 Release Candidate (GB-029)`。`Client.ShopController` はCoreUISafeInsets、ShopButton `(1,-18,0,16)`・112×46。`Client.HudLayout` と横長Progression HUDは残っています。
3. ユーザー自身が、この正確なartifactを既存の許可済み **TEST Experienceのみ** にPublishします。既存DataStore設定を維持し、production Publish・security変更・profile削除・報酬注入は行いません。
4. 古いRobloxClientを完全終了し、fresh TEST versionへPCと実機Mobile Landscapeでjoinします。表示が違う場合は、gameplayを修正する前にartifact/Publish versionの配送一致を確認します。Human中はRojoを再接続しません。

## 数値・状態は自動チェックへ

Cloudの19 specs、63 compile、全41embedded source、67 require依存、39 ModuleScripts評価、実Service/Pickerのin-memory player journey、lease/failure/cleanup/cap/quota/UI回帰は `reports/` を参照してください。これは実Robloxではありません。

実Engine用のread-only observerは `source/tests/studio/GB029ReleaseCandidateCheck.luau` です。artifactには含まれません。既存TEST Studio placeで、冒頭 `TEST_UNIVERSE_ID = 0` を許可済みTEST universeのGameIdへ置換し、Play後にCommand Barを **Client** contextへ切り替えて内容を実行します。デフォルト約180秒、普通に遊ぶ間に、実safe bounds、復元SHOP/CoreUI/HUD/control非重なり、settled counter/power/KILLS表示一致、damage number cap、HP bar重複を自動assertします。被弾、Shop開閉、通常のcombat/swap、viewport変更は自然なプレイ中で十分です。

Outputは `[GB029 TEST] PASS ...` または具体的assert failure。観測できたeventsと未観測 `NOTRUN`、client active peak、frame time/FPS、80体crowdの観測有無も自動で表示します。表示一致のPASSを実DataStore/physics/全journeyのPASSへ広げないでください。実Engine harness、real DataStore concurrency、実機performanceはcloudでは **NOTRUN** です。未発生ケースを作るためのprofile resetや大量の手作業再試験は不要です。

Studio外・Server context・未設定ID・別universeでは拒否します。Remote送信、DataStoreアクセス、UI作成、gameplay/profile変更をせず、終了/失敗でlistenersを解除します。srcに追加したり、production placeへ保存/Publishしないでください。

## Humanはこの2点のみ

- [ ] **今回の修正:** PCと実機Mobile Landscapeで普通に被弾してHP表示が現れたとき、SHOPが元の位置にあり、HP/CoreUI・横長HUDと重ならず使える。
- [ ] **最小統合play feel:** 少しcombatし、Shop/pickerでswapし、自然に可能ならdeath/retry。v0.2の成長・報酬・record・入力・crowdの感覚に、既にPASSした版から重大な悪化がない。新しい細部polishの要望は次versionへ。

数値計算、所有権、run/保存状態を手で逐一記録する大きなチェックリストはありません。実Engineで未観測の範囲は正直にNOTRUNとして残します。

## 報告

```text
v0.2 RC最終Human
SHA: [SOURCE_REVISION.txt]
TEST place/published version:
PC / Mobile機種・Landscape:
1 SHOP被弾時配置: PASS / FAIL
2 最小統合play feel: PASS / FAIL
Studio auto-check: PASS / FAIL / NOTRUN [Output]
未観測/問題:
最終Human: PASS / FAIL / pending
v0.2 Release判断: approve / defer
develop/main merge・tag/正式Releaseの承認範囲:
```

今回のhandoffはRelease Candidateです。最終Humanと判断までdevelop/main merge、tag、正式Release、Roblox Publishをcloudでは行いません。
