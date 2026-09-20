# Grave Buster

現在Version: **v0.1 development**

現在Phase: **GB-001 — Arena & Immediate Start**

墓場から大量に出現するZombieを、様々なWeaponで次々に吹き飛ばすシンプルなAction Game。
v0.1では「大量のZombieをほぼ待ち時間なしで一撃で吹っ飛ばし続けること自体が気持ちいいか」を検証します。
Thunder Battleとは独立した新規Projectです。

GB-000のGit / Rojo基盤に、平坦な墓場Arena・昼の薄霧・中央Spawnを追加しています。
LobbyやMenuを経由せず標準Character Spawnで直接Arenaへ入り、移動できます。
Zombie、Weapon、Combat、UI、Economy、DataStoreは未実装です。
Server BootstrapがArenaを生成し、Server / Clientそれぞれのロード完了ログも維持しています。

## Platform direction

Primary Platformは**MOBILE**。今後はMobile-firstで、Touch UX・Mobile Landscape・Mobile Human Gateを優先し、PC専用対応は後回しにします。
GB-001ではRoblox標準Mobile movementを使用し、新しいMobile UIやInputは追加しません。

Future note（未実装）: 一定確率または特殊AttackでZombieを「ホームラン」のように墓石群を越えて場外へ吹き飛ばす演出を検討します。
これはPlayer boundaryとは別契約です。GB-001ではCollision Groupや例外処理も追加せず、将来Phaseで検討します。

## Repository structure

```text
Grave-Buster/
├── src/
│   ├── server/
│   │   ├── ArenaService.lua
│   │   └── Bootstrap.server.lua
│   ├── client/
│   │   └── Bootstrap.client.lua
│   └── shared/
│       └── ProjectInfo.lua
├── default.project.json
├── rokit.toml
├── README.md
└── .gitignore
```

| Source | Roblox mapping | 責務 |
| --- | --- | --- |
| `src/server` | `ServerScriptService` | Arena生成。将来: Zombie lifecycle、authoritative combat、Wave、purchase validation |
| `src/client` | `StarterPlayer.StarterPlayerScripts` | ロードログ。将来: Input、HUD、effects、camera |
| `src/shared` | `ReplicatedStorage.Shared` | Project情報。将来: constants、contracts、types/config |

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
GB-001の作業branchは`phase/GB-001-arena-start`です。
Remote設定は必須ではありません。`origin`が未設定・不正でも推測で変更しません。

## Arena仕様

- 床: 208 × 2 × 208 studs、上面Y=0。MaterialはGround、茶色RGB(133, 105, 73)。
- 中央約160 × 160 studsは障害物なし。外周に片側21基＋23基の2列、四方合計176基の墓石。
- 墓石: Concreteの通常型・縦長・8度傾斜・十字架型、Gray系4色。非衝突の装飾。
- 境界: 最内周墓石列と同じX/Z=±84に、墓石と同じ厚さ1.2、高さ40 studs（Y=-1〜39）、長さ169.2の透明な衝突Partを4枚配置。内側は166.8 × 166.8 studs。四隅は重なり、床下まで覆います。墓石の手前面と境界の内側面が一致し、墓石列を通り抜けて外側の空地へ歩けない構成です。床208 × 208と中央約160 × 160のfree areaは維持しています。
- Spawn: (X,Z)=(±10,±10)の4地点。透明・非衝突、上面Y=0、Neutral、Enabled、Duration=0。
- 標準の自動Spawn / Respawnを利用。複数地点で重なりを減らしますが、同時Joinの完全な排他割当は行いません。
- Lighting: ClockTime=14、Brightness=2、Ambient=(130,130,125)、OutdoorAmbient=(165,165,155)、ExposureCompensation=0、GlobalShadows=true。
- 距離Fog: Start=50、End=260 studs、Color=(190,198,184)。従来の120 / 450では中央から84 / 92 studs先の墓石列が霧の開始距離より手前だったため、開始・終了距離を短縮。近距離50 studsまでは明瞭さを保ち、墓石列から遠景へ徐々に霞ませます。DAYTIME・明るさは変更せず、Atmosphereや追加エフェクトも導入しません。見た目と中距離の視認性はMobile Landscapeで再確認が必要です。
- 合計220 BaseParts（床1＋墓石211＋境界4＋Spawn4）。すべてAnchored。外部Asset、Heartbeat、毎フレーム処理なし。

生成元は`src/server/ArenaService.lua`です。Server起動時にyieldせず構築し、床とSpawnを含めたModelをまとめてWorkspaceへ配置します。
生成先は`Workspace.GraveyardArena`。`Build()`再実行時は同名Modelのみ置換します。
Rojo同期後に生成コードを変更した場合は、Stop → Playで再生成してください。

API参照: [SpawnLocation](https://create.roblox.com/docs/reference/engine/classes/SpawnLocation)、
[Lighting](https://create.roblox.com/docs/reference/engine/classes/Lighting)。

## Human Studio Check（GB-001）

1. 上記buildコマンドを実行し、`build/Grave-Buster.rbxlx`をStudioで開きます。
2. Explorerで`ServerScriptService.Bootstrap`がScript、`StarterPlayer.StarterPlayerScripts.Bootstrap`がLocalScript、`ReplicatedStorage.Shared.ProjectInfo`がModuleScriptであることを確認します。
3. `ServerScriptService.ArenaService`もModuleScriptであることを確認します。上記serveを起動し、Rojo pluginを接続します。接続・同期エラーがないことを確認します。
4. Playを開始し、Outputに`[Grave Buster] Server loaded (v0.1 development)`と`[Grave Buster] Client loaded (v0.1 development)`が表示され、script errorがないことを確認します。Client確認にはRunではなくPlayを使用します。
5. Mobile Landscapeエミュレーションを優先し、LobbyやMenuなしで中央付近へSpawnし、標準Touch移動 / ジャンプで平坦な床を自由に移動できることを確認します。PC操作は補助確認とします。
6. 茶色の土、四方の多数の墓石、中央に障害物がないこと、見える巨大Wallがないことを確認します。
7. 四辺と四隅へ移動し、最内周の墓石列で止まり、その隙間を歩く・ジャンプする操作でも墓石群の外の空地へ出られないことを確認します。墓石から離れた何もない空間で突然止まる状態がないこと、見える巨大Wallがないことも確認します。
8. Mobile Landscapeで中央から四方を見て、遠方の墓石列に薄いGray系の霧が視覚的に分かることを確認します。中央と端から見比べ、昼の明るさ、近距離・中距離のCharacterの識別しやすさが維持されていることも確認します。Fogの数値設定だけではPASSにしません。
9. CharacterをResetし、Arena内へRespawnすることを確認します。可能ならStudioのServer & Clientsを2人以上で起動し、両者が正常にSpawn・移動できることも確認します。
10. Stop → Playを繰り返し、Arenaが重複しないことと、Outputにエラーがないことを確認します。
11. `git diff --check`と`git status --short`で確認用変更や生成物が残っていないことを確認し、Human / Reviewer Gateの結果を記録します。

Rojo build成功だけではStudio実行時の動作・見た目は保証されません。GB-002へ進む前に上記Gateを完了してください。
GB-001はHuman GateでFog / 境界位置の再確認待ちです。既存PASS項目を維持し、この2点が視覚・操作確認でPASSするまでCLOSEしません。
