# Grave Buster

現在Version: **v0.1 development**

現在Phase: **GB-002 — Zombie Horde**

墓場から大量に出現するZombieを、様々なWeaponで次々に吹き飛ばすシンプルなAction Game。
v0.1では「大量のZombieをほぼ待ち時間なしで一撃で吹っ飛ばし続けること自体が気持ちいいか」を検証します。
Thunder Battleとは独立した新規Projectです。

GB-000のGit / Rojo基盤とGB-001の墓場Arenaに、Damageを与えないZombie Hordeと時間制Waveを追加しています。
LobbyやMenuを経由せず標準Character Spawnで直接Arenaへ入り、移動できます。
Weapon、Combat、Economy、DataStoreは未実装です。ZombieはPlayerへ接近しますが攻撃しません。
Zombie lifecycleとWave progressionはServer Authority、Clientは小さなWave表示だけを担当します。

## Platform direction

Primary Platformは**MOBILE**。今後はMobile-firstで、Touch UX・Mobile Landscape・Mobile Human Gateを優先し、PC専用対応は後回しにします。
GB-002でもRoblox標準Mobile movementを使用します。追加UIは画面上部中央の小さなWave表示だけです。

Future note（未実装）: 一定確率または特殊AttackでZombieを「ホームラン」のように墓石群を越えて場外へ吹き飛ばす演出を検討します。
これはPlayer boundaryとは別契約です。GB-001ではCollision Groupや例外処理も追加せず、将来Phaseで検討します。

## Repository structure

```text
Grave-Buster/
├── src/
│   ├── server/
│   │   ├── ArenaService.lua
│   │   ├── ZombieRules.lua
│   │   ├── ZombieService.lua
│   │   ├── WaveService.lua
│   │   └── Bootstrap.server.lua
│   ├── client/
│   │   ├── WaveHud.lua
│   │   └── Bootstrap.client.lua
│   └── shared/
│       ├── HordeConfig.lua
│       └── ProjectInfo.lua
├── tests/
│   ├── HordeConfig.spec.luau
│   └── ZombieRules.spec.luau
├── default.project.json
├── rokit.toml
├── README.md
└── .gitignore
```

| Source | Roblox mapping | 責務 |
| --- | --- | --- |
| `src/server` | `ServerScriptService` | Arena生成、Zombie lifecycle / target / movement、Wave progression |
| `src/client` | `StarterPlayer.StarterPlayerScripts` | ロードログ、最小Wave HUD。将来: Input、effects、camera |
| `src/shared` | `ReplicatedStorage.Shared` | Project情報とHorde定数・純粋なWave / cap / lifetime規則 |

SharedはServer / Client双方から参照できます。秘密情報やServer専用処理は置きません。
現時点ではフレームワーク、RemoteEvent、将来用の空Service等は追加しません。

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
GB-002の作業branchは`phase/GB-002-zombie-horde`です。
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
- Cleanup: Spawnから30秒でdespawn。倒せないGB-002でも古いZombieが循環し、Capと併用してHuman Gateを継続できます。Health 0、Model消失、Arena下への落下も中央loopでcleanupします。
- GB-003接続: ZombieはModel / Humanoid / PrimaryPartを持ち、BreakJointsOnDeath=false、active registryをServerが所有します。`ZombieService.Release(model)`はModelを破棄せずAI・registry・capから安全に外すhandoff seamで、将来のone-hit defeat時にRootへPhysics launchを与えられます。GB-002では呼び出さず、Knockbackも未実装です。

設定値と純粋規則は`src/shared/HordeConfig.lua`、生成・移動・cleanupは`ZombieService`、Target検証は`ZombieRules`、時間制進行は`WaveService`です。ECS、NPC framework、Behavior Treeは導入していません。

Static test:

```sh
build/luau-tools/luau tests/HordeConfig.spec.luau
build/luau-tools/luau tests/HordeSimulation.spec.luau
build/luau-tools/luau tests/ZombieRules.spec.luau
```

API参照: [Humanoid](https://create.roblox.com/docs/reference/engine/classes/Humanoid)、
[PhysicsService](https://create.roblox.com/docs/reference/engine/classes/PhysicsService)、
[BasePart network ownership](https://create.roblox.com/docs/reference/engine/classes/BasePart#SetNetworkOwner)。

## Human Studio Check（GB-001）

1. 上記buildコマンドを実行し、`build/Grave-Buster.rbxlx`をStudioで開きます。
2. Explorerで`ServerScriptService.Bootstrap`がScript、`StarterPlayer.StarterPlayerScripts.Bootstrap`がLocalScript、`ReplicatedStorage.Shared.ProjectInfo`がModuleScriptであることを確認します。
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
6. Server Explorerで`Workspace.Zombies`の直接の子を数え、28体を超えないことを確認します。約30秒を超えた古いZombieが消え、新規Zombieと入れ替わることを確認します。
7. Character Reset後、新Characterへ追跡が切り替わり、Errorが出ないことを確認します。可能なら2 Clientで最寄りの生存Playerを選ぶことと、片方のLeave後も継続することを確認します。
8. Mobile Landscapeの低・標準画質でZombieがPlayerと区別でき、大群の方向が分かり、Frame rateに明確な異常低下がないことを確認します。
9. GB-001のBrown Ground、墓石境界、Gray overcast、Fog、Clouds、ColorCorrection、Spawn / Respawnが維持されていることを確認します。
10. Stop → Playを繰り返し、`Workspace.Zombies`、`WaveNumber`、Wave HUD、loopが重複せず、OutputにRuntime Errorがないことを確認します。

Rojo buildと静的testだけではHumanoid physics、replicated walk visual、Mobile frame rateを保証できません。GB-003へ進む前にこのHuman / Reviewer Gateを完了してください。
