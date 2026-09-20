# Grave Buster

現在Version: **v0.1 development**

現在Phase: **GB-000 — Project Foundation**

墓場から大量に出現するZombieを、様々なWeaponで次々に吹き飛ばすシンプルなAction Game。
v0.1では「大量のZombieをほぼ待ち時間なしで一撃で吹っ飛ばし続けること自体が気持ちいいか」を検証します。
Thunder Battleとは独立した新規Projectです。

GB-000はGit / Rojoの開発基盤のみです。Gameplay、Arena、UI、Economy、DataStoreは実装していません。
BootstrapはServer / Clientそれぞれから共有Project情報を読み込み、ロード完了をOutputへ出すだけです。

## Repository structure

```text
Grave-Buster/
├── src/
│   ├── server/
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

| Source | Roblox mapping | 今後の責務（GB-000では未実装） |
| --- | --- | --- |
| `src/server` | `ServerScriptService` | Zombie lifecycle、authoritative combat、Wave、purchase validation、progression |
| `src/client` | `StarterPlayer.StarterPlayerScripts` | Input、HUD、Weapon carousel、effects、camera |
| `src/shared` | `ReplicatedStorage.Shared` | constants、contracts、weapon definitions、types/config |

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
このPhaseのPlaceにはArenaや床を配置していません。

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
GB-000の作業branchは`phase/GB-000-foundation`です。
Remote設定は必須ではありません。`origin`が未設定・不正でも推測で変更しません。

## Human Studio Check

1. 上記buildコマンドを実行し、`build/Grave-Buster.rbxlx`をStudioで開きます。
2. Explorerで`ServerScriptService.Bootstrap`がScript、`StarterPlayer.StarterPlayerScripts.Bootstrap`がLocalScript、`ReplicatedStorage.Shared.ProjectInfo`がModuleScriptであることを確認します。
3. 上記serveを起動し、Rojo pluginを接続します。接続・同期エラーがないことを確認します。
4. Playを開始し、Outputに`[Grave Buster] Server loaded (v0.1 development)`と`[Grave Buster] Client loaded (v0.1 development)`が表示され、script errorがないことを確認します。Client確認にはRunではなくPlayを使用します。
5. Stop後、Client Bootstrapのログ文字列へ一時的に` sync-check`を加えて保存し、StudioのSourceにも反映されることを確認します。変更を戻して保存し、再同期を確認します。
6. `git diff --check`と`git status --short`で確認用変更や生成物が残っていないことを確認し、Human / Reviewer Gateの結果を記録します。

Rojo build成功だけではLuau構文やStudio実行時の動作は保証されません。GB-001へ進む前に上記Gateを完了してください。
