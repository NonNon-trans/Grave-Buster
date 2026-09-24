# Grave Buster

現在Version: **v0.2 development**

現在Phase: **GB-021 — Damage / HP Foundation**

墓場から大量に出現するZombieを、様々なWeaponで次々に吹き飛ばすシンプルなAction Game。
v0.1では「大量のZombieをほぼ待ち時間なしで一撃で吹っ飛ばし続けること自体が気持ちいいか」を検証します。
Thunder Battleとは独立した新規Projectです。

GB-000のGit / Rojo基盤とGB-001の墓場Arena、GB-002のZombie Hordeに、Mobile-firstの一撃Combatを追加しています。
LobbyやMenuを経由せず標準Character Spawnで直接Arenaへ入り、移動できます。
5種類のWeaponはRange・Hit shape・Knockbackで差別化し、ZombieはPlayerへ接近しますが攻撃しません。
Combat result、Zombie lifecycle、Wave progression、Session Currency、Weapon ownershipはServer Authorityです。CurrencyとownershipはSession-onlyで、DataStoreは未実装です。

## Platform direction

Primary Platformは**MOBILE**。今後はMobile-firstで、Touch UX・Mobile Landscape・Mobile Human Gateを優先し、PC専用対応は後回しにします。
v0.1 RCでもRoblox標準Mobile movementを使用します。右側にAttack button、下部中央にWeapon Switcher、上部中央にWave表示、左上にKills、右上にSHOP buttonを置きます。

Future note（未実装）: 一定確率または特殊AttackでZombieを「ホームラン」のように墓石群を越えて場外へ吹き飛ばす演出を検討します。
これはPlayer boundaryとは別契約です。GB-003ではDefeated Zombieを非衝突physicsへ移すため場外launch可能ですが、確率・特殊Attack・専用演出は将来Phaseで検討します。

## Repository structure

```text
Grave-Buster/
├── src/
│   ├── server/
│   │   ├── ActiveZombieRegistry.lua
│   │   ├── ArenaService.lua
│   │   ├── CombatRules.lua
│   │   ├── CombatService.lua
│   │   ├── DamageRules.lua
│   │   ├── KillCounter.lua
│   │   ├── PlayerHealthService.lua
│   │   ├── ShopRules.lua
│   │   ├── ShopService.lua
│   │   ├── ShopSessionStore.lua
│   │   ├── ZombieRules.lua
│   │   ├── ZombieService.lua
│   │   ├── WaveService.lua
│   │   └── Bootstrap.server.lua
│   ├── client/
│   │   ├── CombatController.lua
│   │   ├── CombatFeedbackController.lua
│   │   ├── HoldState.lua
│   │   ├── OwnedWeaponSource.lua
│   │   ├── ShopController.lua
│   │   ├── ShopPresentation.lua
│   │   ├── WeaponPresenter.lua
│   │   ├── WeaponSwitcher.lua
│   │   ├── WeaponSwitcherRules.lua
│   │   ├── WaveHud.lua
│   │   └── Bootstrap.client.lua
│   └── shared/
│       ├── DamageConfig.lua
│       ├── HordeConfig.lua
│       ├── FeedbackConfig.lua
│       ├── ShopConfig.lua
│       ├── WeaponConfig.lua
│       └── ProjectInfo.lua
├── tests/
│   ├── ActiveZombieRegistry.spec.luau
│   ├── CombatRules.spec.luau
│   ├── DamageRules.spec.luau
│   ├── FeedbackConfig.spec.luau
│   ├── HoldState.spec.luau
│   ├── HordeConfig.spec.luau
│   ├── HordeSimulation.spec.luau
│   ├── KillCounter.spec.luau
│   ├── ShopConfig.spec.luau
│   ├── ShopPresentation.spec.luau
│   ├── ShopRules.spec.luau
│   ├── ShopSessionStore.spec.luau
│   ├── WeaponConfig.spec.luau
│   ├── WeaponSwitcherRules.spec.luau
│   ├── validate_client_mapping.py
│   └── ZombieRules.spec.luau
├── default.project.json
├── rokit.toml
├── README.md
└── .gitignore
```

| Source | Roblox mapping | 責務 |
| --- | --- | --- |
| `src/server` | `ServerScriptService` | Arena、Zombie / Wave、Combat、Session Shop state / purchase validation |
| `src/client/Bootstrap.client.lua` | `StarterPlayer.StarterPlayerScripts.Bootstrap` | Player join時に起動する唯一のClient Bootstrap |
| `src/client`のModuleScript | `ReplicatedStorage.Client` | Touch input、weapon presentation、Switcher、Shop UI、Wave HUD |
| `src/shared` | `ReplicatedStorage.Shared` | Project情報、Horde / Weapon / Shop設定 |

SharedはServer / Client双方から参照できます。秘密情報やServer専用処理は置きません。
Combat intentとWeapon selectionは`CombatRemotes`、Shop state取得とWeapon IDだけの購入要求は`ShopRemotes`を使います。Clientはhit target、defeat、price、currency、ownershipを指定できません。
Client ModuleScriptはStarter containerのruntime cloneへ依存せず、`ReplicatedStorage.Client`の安定したhierarchyからBootstrapがrequireします。

## Toolchain

- Git
- RokitとRojo **7.7.0**（`rokit.toml`で固定）
- Roblox StudioとRojo Studio plugin

既存のtoolchainを優先して利用してください。このMacでは必要な実体とプラグインファイルを確認済みです。
新しい開発環境ではRokit導入後、Repository直下で`rokit install`を実行して指定バージョンを用意します。
Studio側のプラグイン有効状態と接続互換性は、下記Human Studio Checkで確認します。

## Rojo build

Repository直下で実行します。

```sh
cd /Users/kihak/Developer/Grave-Buster
rojo --version
mkdir -p build
rojo build default.project.json -o build/Grave-Buster.rbxlx
```

生成したPlaceをRoblox Studioで開けます。`build/`とPlace生成物はGit管理対象外です。
ArenaはPlay時にServerで生成されます。編集モードで床がない状態は正常です。
他のBaseplateやSpawnLocation、Atmosphereを含むテンプレートではなく、buildしたPlaceを使用してください。

## Rojo serve / Studio sync

```sh
rojo serve default.project.json --address 127.0.0.1 --port 34872
```

Studioで生成したGrave BusterのPlaceを開き、Rojo pluginから`127.0.0.1:34872`へConnectします。
同期先と変更プレビューがGrave Busterであることを確認して同期します。
ポートが使用中なら他Projectのプロセスは停止せず、`--port 34873`等へ変更し、plugin側も合わせます。
終了時はターミナルでCtrl+Cを押します。

手順の参照: [Rojo公式 build / syncガイド](https://rojo.space/docs/v7/getting-started/new-game/)、
[Project format](https://rojo.space/docs/v7/project-format/)。

## Branch strategy

```text
main
└── develop
    └── phase/*
```

各Phaseは`develop`からbranchを切り、Human / Reviewer Gate完了後に`develop`へmergeします。
Release時のみ`develop` → `main`へmergeします。
GB-007の作業branchは`phase/GB-007-integration-qa`です。
Remote設定は必須ではありません。`origin`が未設定・不正でも推測で変更しません。

## Arena仕様

- 床: 208 × 2 × 208 studs、上面Y=0。MaterialはGround、茶色RGB(133, 105, 73)。
- 中央約160 × 160 studsは障害物なし。外周に片側21基＋23基の2列、四方合計176基の墓石。
- 墓石: Concreteの通常型・縦長・8度傾斜・十字架型、Gray系4色。非衝突の装飾。
- 境界: 最内周墓石列と同じX/Z=±84に、墓石と同じ厚さ1.2、高さ40 studs（Y=-1〜39）、長さ169.2の透明な衝突Partを4枚配置。内側は166.8 × 166.8 studs。四隅は重なり、床下まで覆います。墓石の手前面と境界の内側面が一致し、墓石列を通り抜けて外側の空地へ歩けない構成です。床208 × 208と中央約160 × 160のfree areaは維持しています。
- Spawn: (X,Z)=(±10,±10)の4地点。透明・非衝突、上面Y=0、Neutral、Enabled、Duration=0。
- 標準の自動Spawn / Respawnを利用。複数地点で重なりを減らしますが、同時Joinの完全な排他割当は行いません。
- Lighting: ClockTime=14、Brightness=2、Ambient=(130,130,125)、OutdoorAmbient=(165,165,155)、ExposureCompensation=0、GlobalShadows=true。
- 距離Fog: Start=50、End=260 studs、Color=(190,198,184)。Human Gate PASS済みの値を維持します。近距離50 studsまでは明瞭さを保ち、墓石列から遠景へ徐々に霞ませます。
- 曇天: `Workspace.Terrain`配下の標準Cloudsを使用。Enabled=true、Cover=1、Density=0.6、Color=(200,200,200)。青空の露出を抑えた昼間のGray系曇天を目指します。既存Cloudsがあれば再利用し、再生成しても増殖しません。外部Sky Assetなし。ClockTime・Brightness・Ambient・Fog・Arena geometryは変更していません。
- Sky strategy: Atmosphereは完全に削除し、外部Sky / skybox Assetも使用しません。Cloudsが上空を覆い、従来Fogが遠景を霞ませ、ColorCorrectionがCloudsの下に残るRoblox標準SkyのBlue / Cyanを抑える構成です。これによりAtmosphere導入前にPASSしたFog描画を再び有効にします。
- ColorCorrection: `Lighting.GraveyardColorCorrection`を1個だけ生成。Enabled=true、Saturation=-0.45、Contrast=-0.05、Brightness=0.02、TintColor=(225,225,220)。明るさを大きく落とさず、色を完全なMonochromeにせず、GroundのBrownとCharacter colorを残したまま晴天色を弱めます。
- 合計220 BaseParts（床1＋墓石211＋境界4＋Spawn4）。すべてAnchored。外部Asset、Heartbeat、毎フレーム処理なし。

生成元は`src/server/ArenaService.lua`です。Server起動時にyieldせず構築し、床とSpawnを含めたModelをまとめてWorkspaceへ配置します。
生成先は`Workspace.GraveyardArena`。`Build()`再実行時は同名Modelのみ置換します。
Rojo同期後に生成コードを変更した場合は、Stop → Playで再生成してください。

API参照: [SpawnLocation](https://create.roblox.com/docs/reference/engine/classes/SpawnLocation)、
[Lighting](https://create.roblox.com/docs/reference/engine/classes/Lighting)、
[Clouds](https://create.roblox.com/docs/reference/engine/classes/Clouds)、
[ColorCorrectionEffect](https://create.roblox.com/docs/reference/engine/classes/ColorCorrectionEffect)。

## Zombie Horde仕様（GB-002）

- Zombie model: 外部Assetを使わない7-Partの簡易R6型Humanoid。Green skin、暗い紫Grayの胴、暗い脚でPlayerと区別します。MaxHealth / Healthは固定1で、Wave別HP・Armor・Typeはありません。
- Walk visual: 外部Animation IDを使わず、中央AI更新内で非衝突・Masslessの腕脚4本のMotor6D C0を動かします。Attack Animationはありません。
- Spawn: 境界内側のX/Z=±76、各辺8 lane（-60〜60）の計32地点をround-robin。Player Spawn (±10,±10)から最低約66 studs離れ、墓石・透明境界の内側から四方向に出現します。
- Target: Character、alive Humanoid、HumanoidRootPartが揃うPlayerのうち最寄り。0.75秒ごとに再評価し、現在TargetがReset / Death / Leaveで無効になった場合は次の0.25秒AI tickで即再取得します。Player不在時は停止し、Waveも待機します。
- Movement: 平坦Arena向けの`Humanoid:MoveTo()`による直線追跡。Pathfindingなし。WalkSpeedは全Wave固定8。14方向×2 ringの28接近offset（半径5.5 / 8）と停止距離2.5で、Active cap内の全Zombieに異なる目的位置を割り当て、Player目前の完全重複・振動を抑えます。
- Collision / authority: `Zombie` CollisionGroup同士は非衝突、Ground / Playerとは通常衝突。Zombie physicsはServer network ownership。Damage、Attack、Touched処理、Damage Remoteはありません。
- AI cost: 全Zombie共通loopを0.25秒（4 Hz）で更新。ZombieごとのHeartbeat / connection、毎Frame target search、高頻度Pathfinding、Zombie同士の全組み合わせ計算はありません。
- Mobile part budget: Zombie 1体は7 BaseParts、Active cap時は最大196 dynamic BaseParts / 28 Humanoids。装飾用Accessory、Mesh、Particle、個別Billboardは追加していません。腕脚のwalk visualも同じ4 Hz loopで更新します。
- Wave: 有効Player検出後3秒で開始。Wave 1は6体、以後+3体、1 Wave最大24体。Spawn間隔0.65秒、Wave間2.5秒。ZombieのHP / Speed / Damageは増加しません。WaveはServerの`ReplicatedStorage.WaveNumber`に複製し、Clientは上部中央132×32 pxの表示だけを行います。
- Active cap: 28体。208×208 Arenaで大群感を保ちつつ、Mobile上のHumanoid / Partコストを抑える値です。Cap中のspawn slotはskipし、無制限生成しません。
- Cleanup: GB-002専用の30秒Lifetimeは撤廃済みです。ACTIVE Zombieは時間だけでは消えず、Playerの処理が遅ければ28体のcapまで蓄積します。Model消失、Health 0、Arena下への落下は中央loopでcleanupします。
- Combat接続: `ZombieService.Release(model)`はModelを破棄せずAI・registry・capから即座に外します。CombatServiceがその後のphysics launchと短時間後のcleanupを所有するため、吹っ飛び中のModelは新規spawn用のactive slotを占有しません。

設定値と純粋規則は`src/shared/HordeConfig.lua`、生成・移動・cleanupは`ZombieService`、Target検証は`ZombieRules`、時間制進行は`WaveService`です。ECS、NPC framework、Behavior Treeは導入していません。

## Core Weapon Combat仕様（GB-003）

- Input: 標準Jump buttonを避けた画面右側の112×112 px `ATTACK` button。Touch beginで即attackし、保持中は現在Weaponのintervalで繰り返し、release / cancel / Character reset / Weapon切替でloopを停止します。画面下部中央はGB-004用に空けています。
- Authority: Clientは引数なしのattack intentだけを送信します。ServerはPlayer、alive Character、Server上のequipped weapon、Server時計によるintervalを検証し、target query・defeat・knockback・cleanupを決定します。不正なWeapon名は拒否します。
- Hit query: `Workspace:GetPartBoundsInBox` / `GetPartBoundsInRadius`とInclude filterで`Workspace.Zombies`だけを検索し、Model単位でdeduplicateします。ACTIVE registryにないReleased Zombie、Player、墓石、Arena geometryは対象外です。
- Defeat lifecycle: ACTIVE → `ZombieService.Release` → cap slot解放 → DEFEATED → server-owned physics impulse → 1.8〜2.4秒表示 → Debris cleanup。同じZombieの二重Releaseはregistryが拒否します。
- Collision: Defeated rigは全BasePartを非衝突・非Touchにし、`DefeatedZombie` groupへ移します。PlayerやHordeを押さず、Player用透明boundaryにも阻まれないため、将来の場外Home Runへ拡張できます。
- Presentation: 外部Asset IDなし。5種類のprimitive weaponをLocal Characterの右手へMotor6Dで保持し、attack時はlocal procedural swingを再生します。Server gameplayをAnimation timingへ依存させません。
- Equip pipeline: 選択要求はServerの既存`EquipRequest`へ送り、確認済み`EquippedWeapon` attributeによってWeapon modelとUI表示を更新します。選択はSession内で保持され、respawn後も復元します。

| Weapon | Interval | Hit shape / range | Max | Knockback H / V | Physics表示 |
| --- | ---: | --- | ---: | ---: | ---: |
| Baseball Bat | 0.34s | 前方Box 10、幅8 | 6 | 68 / 30 | 2.0s |
| Frying Pan | 0.38s | 前方Box 9、幅13 | 8 | 60 / 24、左右へ散開 | 2.0s |
| Giant Hammer | 0.55s | 前方寄りRadius 7.5 | 10 | 74 / 48 | 2.4s |
| Blower | 0.28s | 前方Cone近似 17、幅16 | 12 | 80 / 18、外向き | 1.8s |
| Thunder Rod | 0.42s | 前方11から半径11でchain | 8 | 62 / 34、各target外向き | 2.1s |

全Weaponは固定Health 1のZombieを一撃でdefeatします。Damage number、HP scaling、Player damageはありません。Waveは6 → 9 → 12 → 15 → 18 → 21 → 24を維持し、transitionで生存Zombieを消しません。cap中のspawn slotはskipされ、defeatでslotが空けば以後のscheduleから再供給されます。

## Weapon Switcher仕様（GB-004）

- Layout: `ScreenInsets=DeviceSafeInsets`のScreenGui内、画面下部中央へAnchorPoint `(0.5, 1)`、相対幅42%、高さ74 pxで配置します。幅は280〜430 pxに制限し、標準Movement、Jump、右側ATTACKを避けます。
- Controls: 左右に62×62 pxのPrevious / Next touch target、中央に短い文字IconとWeapon名を表示します。外部Image Assetは使用しません。
- Owned source: `OwnedWeaponSource`はServer snapshotのrevision、Currency、正式順のOwned listをClient presentation用に保持します。Join直後はBatのみで、購入成功イベントからSwitcherの`SetOwnedWeapons()`へ即反映します。
- Selection authority: Arrow / Swipeは既存`EquipRequest`へselection intentを送り、表示とWeapon modelはServerが更新した`EquippedWeapon` attributeで確定します。UI animation完了を待たず即requestします。
- Wrap: 最初からPreviousで最後、最後からNextで最初へ移動します。高速操作中はpending cursorで順序を保持し、表示は最新のServer確認へ追従します。
- Swipe: 中央領域でのみdragを開始し、release時の水平移動48 px以上かつ水平量が垂直量の1.25倍を超えた場合だけ1段切り替えます。LeftはNext、RightはPreviousです。Gestureはfinish時に消費されるため1 Swipeから複数切替しません。
- Visibility: Idle時は背景Transparency 0.50、文字 / Icon 0.42、Outline 0.55。Touch時はすべて0へ即時変更します。操作終了後1.0秒完全表示を保ち、0.3秒でIdleへfadeします。generation tokenとTween cancelによりfade中の再Touchを即時反映します。
- Feedback: Server確認後、中央itemを0.90から1.00へ0.14秒でscaleして切替を示します。GameplayのEquip処理は待ちません。
- Lifecycle: Weapon切替要求時に旧Hold-to-Attack loopを停止します。GUIはrespawnを越えて維持され、Character再生成後はSession内の確認済みWeaponを再装備します。DEV selectorとPlayer-facing development文字列は削除済みです。

## Online Weapon Shop仕様（GB-005）

- Economy: Join時2000 Coins。BASEBALL BATだけをDefault Owned / Equippedとし、Character Resetでは維持、Leaveで破棄、Rejoinで初期化します。DataStore、Kill Reward、Monetizationはありません。
- Prices: Baseball Bat 0、Frying Pan 200、Giant Hammer 400、Blower 600、Thunder Rod 1000 Coins。`ShopConfig`が正式Order、Price、Default Ownedを一元管理します。
- Server authority: `ShopService`がPlayerごとのSession state、revision、purchase lockを所有します。ClientはWeapon IDだけを送信し、ServerがID、Price、already-owned、残高、request shapeを検証します。同一callback内にyieldを挟まずCurrency更新とownership grantを完結します。
- State sync: `GetState`でCurrency / Owned Weapons / Equipped Weapon / Revisionを取得し、購入成功時は`StateChanged`とPurchase responseでsnapshotを返します。Clientは新しいrevisionだけを`OwnedWeaponSource`へ適用します。
- SHOP button: `CoreUISafeInsets`内の右上、112×46 px。Shop Panelは中央の相対76%×82%、480×270〜720×400 pxに制限します。HeaderのCurrencyは固定し、5枚のCard領域だけをscroll可能にします。
- Currency visibility: `COINS: N`はPanel直下の固定Header layer（右上、160×44 px、ZIndex 13）に表示します。Close buttonと12 px、最小幅時のTitleと14 px以上離れ、Weapon listのscrollに影響されません。
- Card: 短い文字Icon、Weapon Name、`BUY • PRICE COINS` / `OWNED • TAP TO EQUIP` / `EQUIPPED`を表示します。購入は自動Equipしません。Owned CardのTapは既存`EquipRequest`を再利用します。
- Combat interaction: Shop open時にHold-to-Attackを停止し、ATTACKとSwitcherを隠します。Closeで即復帰しますがAttackは自動再開しません。Server Wave / Zombie simulationは停止しません。
- Failure: 残高不足は`NOT ENOUGH COINS`、既購入はServerでrejectします。Client pending guardとServer purchase lockによりrapid double-purchaseを防止します。
- Source boundary: ShopとSwitcherは同じ`OwnedWeaponSource`をpresentation sourceとして購読し、authoritative sourceはServer sessionだけです。購入順に関係なくSwitcherは正式Weapon orderを維持します。

## Feel & Feedback仕様（GB-006）

- Hit / knockback feedback: Serverで実際にZombieをReleaseできたattackだけを`CombatFeedback`で攻撃Playerへ通知し、Defeated rootへ0.22秒だけ短いTrailをlocal生成します。Human Gate結果によりNeon hit flashは削除済みです。
- Weapon identity: TrailをWeapon別に暖色 / 金属色 / Orange / Cyan / Violetへ軽微に色分けします。既存のKnockback force、hitbox、interval、physics lifetimeは変更しません。
- Bounded effects: 1 attackの表示は最大8 Zombie分。TrailとAttachmentはDebrisで必ずcleanupし、Part、ParticleEmitter、Heartbeat、Zombie別connectionは使用しません。
- Kill counter: Serverの`KillCounter`がRelease成功数をPlayer単位で加算し、`SessionKills` attributeを複製します。左上Safe Areaの116×36 px `KILLS N`表示へ反映し、Character Resetでは維持、Leave / Rejoinでは0へ戻ります。Currency / Rewardとは接続しません。
- Wave emphasis: 既存132×32 px表示を維持し、Wave更新時だけ0.55秒間1.16倍・背景を明瞭化し、0.35秒で通常表示へ戻します。巨大Bannerは追加しません。
- Camera / Audio: Mobile camera操作と連続attackの安定性を優先してCamera shakeは追加しません。信頼できるAsset IDを新規導入しないためAudioも追加しません。

## v0.1 Release Candidate Gate（GB-007）

- Frozen scope: Arena、cap 28のZombie Horde、5 Weaponsの一撃Combat、Trail、Wave / Kills、Weapon Switcher、Session Shopをv0.1 contractとして固定します。Hit Flash、Player Damage、Kill Reward、Persistence、Audioは含みません。
- Static gate: Rojo build、全Luau compile、全spec、generated hierarchy、Arena / Horde / Combat / Switcher / Shop / Feedback regression、`git diff --check`を通過させます。
- RC artifact: `build/Grave-Buster-v0.1-RC.rbxlx`。`build/`はGit ignore対象で、Published TEST ExperienceへPublishする入力です。
- Release gate: Release Blocker 0件かつStatic gate PASS後、Physical Mobile DeviceのLandscapeでJoinからLeave / RejoinまでのE2Eを実施します。Published Mobile E2E PASS後にv0.1をRelease Readyとします。

## Damage / HP Foundation（GB-021）

- Weapon BaseDamageは`WeaponConfig`をsingle sourceとして保持します。Bat 10、Pan 15、Hammer 25、Blower 18、Thunder Rod 30。既存のinterval、hit shape、range、max targets、knockback、special behaviorとShop価格は維持します。
- `ZombieService`は通常Wave spawnでHP 10のZombieを生成し、Server registry entryとModel attributeにMaxHP / CurrentHPを保持します。MaxHP / CurrentHPはServerが所有し、ACTIVE中のDamage適用とlethal transitionを管理します。
- `DamageRules`はACTIVE個体だけにDamageを適用し、`AttackDamage`（Server解決値）、`ActualHPLoss`、`BeforeHP`、`AfterHP`を分けて返します。AfterHPは0未満にならず、lethal transition時にLifecycleを同期的にDEFEATEDへ変更します。CombatServiceはlethal個体だけを既存ZombieService.Release → knockback → cleanupへ送り、Session KillsもRelease成功時だけ増やします。
- Damage NumberはHP残量でclampせず、Serverが解決した`AttackDamage`を表示します。`ActualHPLoss`と`AfterHP`は独立して扱い、OverkillでもAfterHPは0です。
- `ZombieDamageFeedback`はServer結果の`AttackDamage` / CurrentHP / MaxHP / lethal stateをClientへ送ります。ClientはAttackDamageをDamage Numberに表示し、non-lethal hitのZombieだけにHP barを最大1.5秒表示します。再被弾で表示期限を更新し、lethal hitでは即時削除します。
- `PlayerHealthService`はCharacter spawn / respawn時にHumanoid MaxHealthとHealthを100へ設定し、Playerの`MaxHP` attributeも100にします。Zombie attack、Player Damage、Level / XP / Coins reward、Wave scaling、Death run reset、persistenceはGB-021に含めません。
- `DamageRules.spec.luau`はHP10 + Bat、HP15 + Batのnon-lethalと次撃lethal、HP15 + Pan、二重lethal拒否、複数個体の独立HP、Player MaxHP契約を検証します。Static validationはStudio / Published Human Gateの代替ではありません。

Static test:

```sh
build/luau-tools/luau tests/HordeConfig.spec.luau
build/luau-tools/luau tests/HordeSimulation.spec.luau
build/luau-tools/luau tests/ZombieRules.spec.luau
build/luau-tools/luau tests/WeaponConfig.spec.luau
build/luau-tools/luau tests/CombatRules.spec.luau
build/luau-tools/luau tests/DamageRules.spec.luau
build/luau-tools/luau tests/ActiveZombieRegistry.spec.luau
build/luau-tools/luau tests/HoldState.spec.luau
build/luau-tools/luau tests/WeaponSwitcherRules.spec.luau
build/luau-tools/luau tests/ShopConfig.spec.luau
build/luau-tools/luau tests/ShopRules.spec.luau
build/luau-tools/luau tests/ShopSessionStore.spec.luau
build/luau-tools/luau tests/FeedbackConfig.spec.luau
build/luau-tools/luau tests/KillCounter.spec.luau
python3 tests/validate_client_mapping.py build/Grave-Buster.rbxlx
```

API参照: [Humanoid](https://create.roblox.com/docs/reference/engine/classes/Humanoid)、
[PhysicsService](https://create.roblox.com/docs/reference/engine/classes/PhysicsService)、
[BasePart network ownership](https://create.roblox.com/docs/reference/engine/classes/BasePart#SetNetworkOwner)。

## Human Studio Check（GB-001）

1. 上記buildコマンドを実行し、`build/Grave-Buster.rbxlx`をStudioで開きます。
2. Explorerで`ServerScriptService.Bootstrap`がScript、`StarterPlayer.StarterPlayerScripts.Bootstrap`がLocalScript、`ReplicatedStorage.Client`にCombat / Weapon Switcher関連ModuleScriptが存在することを確認します。`ReplicatedStorage.Shared.ProjectInfo`もModuleScriptであることを確認します。
3. `ServerScriptService.ArenaService`もModuleScriptであることを確認します。上記serveを起動し、Rojo pluginを接続します。接続・同期エラーがないことを確認します。
4. Playを開始し、Outputに`[Grave Buster] Server loaded (v0.1 development)`と`[Grave Buster] Client loaded (v0.1 development)`が表示され、script errorがないことを確認します。Client確認にはRunではなくPlayを使用します。
5. Mobile Landscapeエミュレーションを優先し、LobbyやMenuなしで中央付近へSpawnし、標準Touch移動 / ジャンプで平坦な床を自由に移動できることを確認します。PC操作は補助確認とします。
6. 茶色の土、四方の多数の墓石、中央に障害物がないこと、見える巨大Wallがないことを確認します。
7. 四辺と四隅へ移動し、最内周の墓石列で止まり、その隙間を歩く・ジャンプする操作でも墓石群の外の空地へ出られないことを確認します。墓石から離れた何もない空間で突然止まる状態がないこと、見える巨大Wallがないことも確認します。
8. Mobile Landscapeで中央から四方を見て、遠方の墓石列に薄いGray系の霧が視覚的に分かることを確認します。中央と端から見比べ、昼の明るさ、近距離・中距離のCharacterの識別しやすさが維持されていることも確認します。Fogの数値設定だけではPASSにしません。
   空も見上げ、鮮やかな青空の露出が大幅に減り、Gray系の曇天に見えることを確認します。特に地平線にBlue / Cyanの帯が残らず、厚いGray cloud layer → Gray horizon → light gray fog → brown groundへ自然につながることを確認します。Mobileの低・標準画質でも雲と地上の視認性を確認し、夜のように暗くなっていないことを確認します。
9. CharacterをResetし、Arena内へRespawnすることを確認します。可能ならStudioのServer & Clientsを2人以上で起動し、両者が正常にSpawn・移動できることも確認します。
10. Stop → Playを繰り返し、Arenaが重複しないことと、Outputにエラーがないことを確認します。
11. `git diff --check`と`git status --short`で確認用変更や生成物が残っていないことを確認し、Human / Reviewer Gateの結果を記録します。

上記GB-001項目はGB-002でのEnvironment regression確認として維持します。GB-001自体はHuman Gate PASS / CLOSED済みです。

## Human Studio Check（GB-002）

1. buildしたPlaceをStudioで開くかRojo同期後にStop → Playし、Mobile Landscape emulationを有効にします。
2. Arenaへ直接Spawnし、約3秒後に外周内側の複数方向からZombieが順次出現することを確認します。
3. ZombieがPlayerへ歩き、目前の複数位置で停止・追従すること、激しい左右jitterや完全な一点重複がないことを確認します。
4. Zombieへ触れてもPlayer Healthが減らず、Attack / Killが発生しないことを確認します。
5. 上部中央の`GET READY`が`WAVE 1`へ変わり、その後Waveが自動進行すること、初期Waveほどspawn数が少ないことを確認します。
6. Server ExplorerでACTIVE Zombieが28体を超えないことを確認します。GB-003では30秒を超えたZombieも時間だけでは消えず、defeatされたZombieだけが短いphysics表示後に消えることを確認します。
7. Character Reset後、新Characterへ追跡が切り替わり、Errorが出ないことを確認します。可能なら2 Clientで最寄りの生存Playerを選ぶことと、片方のLeave後も継続することを確認します。
8. Mobile Landscapeの低・標準画質でZombieがPlayerと区別でき、大群の方向が分かり、Frame rateに明確な異常低下がないことを確認します。
9. GB-001のBrown Ground、墓石境界、Gray overcast、Fog、Clouds、ColorCorrection、Spawn / Respawnが維持されていることを確認します。
10. Stop → Playを繰り返し、`Workspace.Zombies`、`WaveNumber`、Wave HUD、loopが重複せず、OutputにRuntime Errorがないことを確認します。

このGB-002手順はWave / Horde regression確認としてGB-003でも維持します。

## Human Studio Check（GB-003）

1. buildしたPlaceをStudioで開き、Device EmulatorをMobile LandscapeにしてPlayします。LobbyなしでSpawnし、3秒後からWaveが始まることを確認します。
2. 右側の`ATTACK`をtapし、即座にweapon swingが見えることを確認します。移動しながら押せること、長押し中は連続attackし、指を離すと即停止することを確認します。
3. 下部中央のProduction Weapon SwitcherでOwned Weaponだけが正式順に表示・装備されることを確認します。切替中にhold loopや旧modelが残らないことも確認します。
4. Batは前方、Panは左右へ散らす、Hammerは高く重く複数、Blowerは広い前方、Thunder Rodは近傍へ連鎖することを確認します。各Weaponで複数体を一撃defeatでき、hit直後に消えず1.8〜2.4秒飛んでから消えることを確認します。
5. Defeated ZombieがPlayerを押さず、ACTIVE ZombieのAIへ戻らず、同じtargetが二重defeatされないことを確認します。Player用墓石boundaryを越えるlaunchが可能であることも観察します。
6. 何もattackせず30秒以上待ち、ACTIVE Zombieが時間だけでは消えずcapまで圧力が蓄積することを確認します。大量にdefeatすると空間が開き、空いたslotへ後続WaveからZombieが供給されることを確認します。
7. Zombie接触でPlayer Healthが減らないこと、Wave表示と6 → 9 → 12…の進行が続くこと、28体のACTIVE capを超えないことを確認します。
8. Attack hold中とWeapon切替後にCharacterをResetし、holdが残らず、respawn後に選択中Weaponが再装備されAttackが復旧することを確認します。
9. Brown Ground、墓石境界、Gray overcast、Fog、Clouds、ColorCorrection、Spawn / Respawnが維持されていることを確認します。
10. 低・標準画質でHordeとlaunchが読み取れ、明確なframe rate異常がないことを確認します。Stop → Playも繰り返し、Remote、GUI、foldersが重複せずOutputにRuntime Errorがないことを確認します。

Static validationではserver rules、registry、hold lifecycle、config、Wave pressureを確認します。最終的なTouch feel、Humanoid physics、Knockback量、Mobile frame rateは上記Human Gateで判断してください。

## Human Studio / Published Mobile Check（GB-004）

1. `build/Grave-Buster-gb004.rbxlx`をStudioで開き、Mobile LandscapeでJoinします。Baseball Batが装備され、下部中央にSwitcher、右側にATTACKが表示されることを確認します。
2. Idle時にもSwitcherを認識でき、Touch直後に背景、Icon、Weapon名、Arrowが完全表示になることを確認します。
3. Previous / Nextの62×62 px領域をtapし、1回につき1 Weaponだけ切り替わること、両端でwrapすることを確認します。
4. 中央領域を左へ48 px以上swipeしてNext、右へswipeしてPreviousへ切り替わることを確認します。短いdragと縦dragでは切り替わらないことも確認します。
5. 操作終了から1.0秒は完全表示され、その後0.3秒でIdleへ戻ること、fade中のTouchで即完全表示へ戻ることを確認します。
6. 切替確定直後にWeapon modelと表示名が一致し、すぐATTACKできることを確認します。ATTACK hold中の切替では旧loopが停止し、再Holdで新しいintervalが使われることを確認します。
7. Arrow連打と連続Swipeを行い、Weapon model重複、古い表示、複数段誤移動、animation破綻がないことを確認します。
8. Character Reset後も直前Weapon、Switcher表示、Weapon modelが一致し、GUIが重複しないことを確認します。
9. Movement、Camera、Jump、ATTACKと重大なTouch干渉がなく、小さいPhone Landscapeでも文字やArrowがclipしないことを確認します。
10. GB-003 Combat Feel、Zombie Horde、Wave、Environmentを再確認し、OutputにRuntime Errorがないことを確認します。最終判定はTEST ExperienceへPublishしたPlaceをPhysical Mobile DeviceのLandscapeで行います。

## Human Studio / Published Mobile Check（GB-005）

1. `build/Grave-Buster-gb005.rbxlx`をStudioで開き、Mobile LandscapeでJoinします。SwitcherがBASEBALL BATだけを表示し、CharacterもBatを装備することを確認します。
2. 右上のSHOPを押し、中央Panel、固定Currency表示`COINS: 2000`、Close、5 Weapon Cardを確認します。
3. Batが`EQUIPPED`、他4 Weaponが購入前Price付きで表示されることを確認します。
4. Panを購入し、Coinsが1800、Cardが`OWNED`、SwitcherへPanが即追加されることを確認します。現在WeaponはBatのままであることも確認します。
5. OWNED CardをTapし、既存Equip pipelineでShop、Switcher、Characterが同じWeaponになることを確認します。
6. Pan / Hammer / Blowerを購入後、残高800でThunder Rodを購入し、`NOT ENOUGH COINS`、残高不変、UNOWNED維持を確認します。
7. 同じCardを高速連打し、成功とCurrency減算が1回だけであることを確認します。
8. Shopを閉じ、購入済みWeaponだけをSwitcherで自由に切り替え、直後にATTACKできることを確認します。
9. ATTACK Hold中にShopを開き、Holdが停止すること、Shop中はATTACKとSwitcherが隠れ、Close後もAttackが自動再開しないことを確認します。WaveとZombieは継続します。
10. Close / ReopenでCurrency、Owned、Equipped stateがServer snapshotと一致することを確認します。
11. Character Reset後もCurrency、Owned list、Equipped Weapon、Shop stateが維持され、UIが重複しないことを確認します。
12. ExperienceをLeaveしてRejoinし、2000 Coins、BatのみOwnedへ戻ることを確認します。
13. Panel scroll、Card tap、CloseがCamera / Movementへ重大に漏れず、小さいPhone LandscapeでもPanelがclipしないことを確認します。
14. GB-004 Switcher、GB-003 Combat、GB-002 Horde、GB-001 Environmentを確認し、OutputにRuntime Errorがないことを確認します。最終判定はTEST ExperienceへPublishしたPlaceをPhysical Mobile DeviceのLandscapeで行います。

## Human Studio / Published Mobile Check（GB-006）

1. `build/Grave-Buster-gb006.rbxlx`をStudioで開き、Mobile LandscapeでJoinします。左上Safe Areaに`KILLS 0`、上部中央に既存Wave表示があることを確認します。
2. ZombieへBatを当て、Neon flashが表示されず、吹っ飛ぶZombieの短いTrailだけが見えることと、既存Knockback量が変わっていないことを確認します。
3. 複数Zombieを同時に倒し、全defeat数だけKILLSが増えることを確認します。連続Hold attackでもEffectが短時間で消え、画面を覆わないことを確認します。
4. 5 Weaponを試し、Trail色に軽微な差があること、Thunder Rodでも高コストなLightning effectがないことを確認します。
5. Character Reset後もKILLSを維持し、ExperienceをLeaveしてRejoinすると`KILLS 0`へ戻ることを確認します。
6. Wave切替時だけ既存表示が短く1.16倍になり、その後通常サイズへ戻ることを確認します。Gameplayを遮るBannerがないことも確認します。
7. Shop、Currency、Ownership、Switcher、Combat、Horde、EnvironmentがGB-005以前と同じ動作を維持していることを確認します。
8. 28 Active Zombieと複数のDefeated bodyがある状態で連続attackし、Mobile frame rateに明確な悪化がなく、OutputにRuntime Errorがないことを確認します。
