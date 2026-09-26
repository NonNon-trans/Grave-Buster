#!/usr/bin/env python3

import argparse
import sys
import xml.etree.ElementTree as ET


def instance_name(item: ET.Element) -> str:
    properties = item.find("Properties")
    if properties is None:
        return ""
    for value in properties:
        if value.get("name") == "Name":
            return value.text or ""
    return ""


def direct_child(parent: ET.Element, name: str, class_name: str) -> ET.Element:
    matches = [
        item
        for item in parent.findall("Item")
        if instance_name(item) == name and item.get("class") == class_name
    ]
    if len(matches) != 1:
        raise AssertionError(
            f"expected one direct {class_name} named {name!r} under "
            f"{instance_name(parent) or '<DataModel>'}, found {len(matches)}"
        )
    return matches[0]


def source_of(item: ET.Element) -> str:
    properties = item.find("Properties")
    if properties is None:
        return ""
    for value in properties:
        if value.get("name") == "Source":
            return value.text or ""
    return ""


def validate(place_path: str) -> None:
    root = ET.parse(place_path).getroot()
    generated_sources = "\n".join(source_of(item) for item in root.iter("Item"))
    investigation_residue = (
        "[GB021 INIT]",
        "[GB021 HP TEST]",
        "[GB021 TEST HARNESS]",
        "GB021HPTestSpawn",
        "GB021HPTestMarker",
        "TEST HP ",
        "GetRuntimeDiagnostics",
        "ModuleEvaluationId",
        "ResolveSpawnHP",
    )
    for residue in investigation_residue:
        assert residue not in generated_sources, f"investigation-only source remains: {residue}"

    replicated_storage = direct_child(root, "ReplicatedStorage", "ReplicatedStorage")
    client = direct_child(replicated_storage, "Client", "Folder")

    modules = {}
    for name in (
        "CombatFeedbackController",
        "CombatController",
        "HoldState",
        "OwnedWeaponSource",
        "ShopController",
        "ShopPresentation",
        "WaveHud",
        "ProgressionHud",
        "WeaponPresenter",
        "WeaponSwitcher",
        "WeaponSwitcherRules",
    ):
        modules[name] = direct_child(client, name, "ModuleScript")

    starter_player = direct_child(root, "StarterPlayer", "StarterPlayer")
    starter_scripts = direct_child(starter_player, "StarterPlayerScripts", "StarterPlayerScripts")
    bootstrap = direct_child(starter_scripts, "Bootstrap", "LocalScript")

    bootstrap_source = source_of(bootstrap)
    required_bootstrap_fragments = (
        'ReplicatedStorage:WaitForChild("Client")',
        'clientModules:WaitForChild("WaveHud")',
        'clientModules:WaitForChild("CombatController")',
        'clientModules:WaitForChild("CombatFeedbackController")',
        'clientModules:WaitForChild("ShopController")',
        'clientModules:WaitForChild("ProgressionHud")',
        "CombatFeedbackController.Start()",
        "ProgressionHud.Start()",
        "ShopController.Start(CombatController)",
    )
    for fragment in required_bootstrap_fragments:
        assert fragment in bootstrap_source, f"Bootstrap does not resolve {fragment}"
    assert "script.Parent.CombatController" not in bootstrap_source
    assert not any(instance_name(item) == "PlayerHealthHud" for item in client.findall("Item")), (
        "Redundant PlayerHealthHud remains in generated place"
    )
    assert "PlayerHealthHud" not in bootstrap_source, "Bootstrap still depends on the removed PlayerHealthHud"

    controller_source = source_of(modules["CombatController"])
    for dependency in ("HoldState", "OwnedWeaponSource", "WeaponPresenter", "WeaponSwitcher"):
        fragment = f'script.Parent:WaitForChild("{dependency}")'
        assert fragment in controller_source, f"CombatController does not resolve {fragment}"
    for initialization_guard in (
        "local started = false",
        "if started then",
        'playerGui:FindFirstChild("GraveBusterCombatGui")',
        "previous:Destroy()",
        "WeaponSwitcher.Create(gui, ownedWeapons",
        "equipRemote:FireServer(requestedWeapon)",
        "switcher:SetSelected(currentWeapon)",
        "player.CharacterRemoving:Connect",
        "player.CharacterAdded:Connect",
    ):
        assert initialization_guard in controller_source, (
            f"CombatController initialization guard missing: {initialization_guard}"
        )

    switcher_source = source_of(modules["WeaponSwitcher"])
    assert 'script.Parent:WaitForChild("WeaponSwitcherRules")' in switcher_source
    assert "requested and requested ~= cursor" in switcher_source
    owned_source = source_of(modules["OwnedWeaponSource"])
    assert "ApplyAuthoritativeState" in owned_source
    assert "WeaponConfig.DefaultWeapon" in owned_source

    feedback_source = source_of(modules["CombatFeedbackController"])
    for fragment in (
        'WaitForChild("CombatFeedback")',
        'local KILL_ATTRIBUTE = "SessionKills"',
        "player:GetAttributeChangedSignal(KILL_ATTRIBUTE)",
        "FeedbackConfig.MaxEffectsPerAttack",
        "Debris:AddItem(trail, FeedbackConfig.TrailLifetime)",
        "Debris:AddItem(upper, FeedbackConfig.TrailLifetime)",
        "Debris:AddItem(lower, FeedbackConfig.TrailLifetime)",
        "local started = false",
        'playerGui:FindFirstChild(GUI_NAME)',
    ):
        assert fragment in feedback_source, f"CombatFeedbackController contract missing: {fragment}"
    assert "Heartbeat" not in feedback_source

    wave_hud_source = source_of(modules["WaveHud"])
    for fragment in (
        "FeedbackConfig.WaveEmphasisHold",
        "FeedbackConfig.WaveEmphasisFade",
        "emphasisGeneration += 1",
        "activeTween:Cancel()",
        'WaitForChild("WaveRemotes")',
        'WaitForChild("WaveCleared")',
        'string.format("WAVE %d CLEAR!", clearedWave)',
        "FeedbackConfig.WaveClearLifetime",
        "clearGeneration += 1",
    ):
        assert fragment in wave_hud_source, f"WaveHud feedback contract missing: {fragment}"
    shop_controller_source = source_of(modules["ShopController"])
    for fragment in (
        'script.Parent:WaitForChild("OwnedWeaponSource")',
        'script.Parent:WaitForChild("ShopPresentation")',
        'WaitForChild("PurchaseRequest")',
        'WaitForChild("ProgressionRemotes")',
        "OwnedWeaponSource.ApplyAuthoritativeCoins(snapshot.Coins)",
        "OwnedWeaponSource.ApplyAuthoritativeState(state)",
        "combatController.SetShopOpen(isOpen)",
        "purchaseRemote:InvokeServer(weaponId)",
        "local started = false",
        'playerGui:FindFirstChild("GraveBusterShopGui")',
        "previous:Destroy()",
        "player:GetAttributeChangedSignal(\"EquippedWeapon\")",
        "if isOpen then",
        "syncState()",
        'makeLabel(\n\t\tpanel,\n\t\t"Currency"',
        "currencyLabel.ZIndex = ShopPresentation.Layout.HeaderZIndex",
        "currencyLabel.Text = ShopPresentation.FormatCurrency(OwnedWeaponSource.GetCurrency())",
    ):
        assert fragment in shop_controller_source, f"ShopController does not resolve {fragment}"

    shop_presentation_source = source_of(modules["ShopPresentation"])
    for fragment in (
        'CurrencyPrefix = "COINS"',
        "CurrencyRight = 108",
        "HeaderZIndex = 13",
        'return string.format("%s: %d"',
        "currencyLeftAtMinimumWidth > titleRight",
        "currencyRightGap >= 8",
    ):
        assert fragment in shop_presentation_source, (
            f"ShopPresentation currency visibility contract missing: {fragment}"
        )

    shared = direct_child(replicated_storage, "Shared", "Folder")
    feedback_config = direct_child(shared, "FeedbackConfig", "ModuleScript")
    damage_config = direct_child(shared, "DamageConfig", "ModuleScript")
    horde_config = direct_child(shared, "HordeConfig", "ModuleScript")
    assert "ImpactLifetime" not in source_of(feedback_config)
    damage_config_source = source_of(damage_config)
    assert "PlayerMaxHP = 100" in damage_config_source
    direct_child(shared, "ShopConfig", "ModuleScript")
    horde_config_source = source_of(horde_config)
    for fragment in (
        "ZombieHP = 10, ZombieDamage = 10, TotalSpawn = 15",
        "Intermission = 0",
        "MaxAliveZombies = 80",
        "function HordeConfig.GetZombieHP(wave: number)",
        "math.round(50 * 1.10 ^ (wave - 10))",
        "function HordeConfig.GetZombieDamage(wave: number)",
        "15 + math.floor((wave - 10) / 3)",
        "function HordeConfig.GetTotalSpawn(wave: number)",
        "60 + (wave - 10) * 5",
    ):
        assert fragment in horde_config_source, f"Wave scaling contract missing: {fragment}"

    server_scripts = direct_child(root, "ServerScriptService", "ServerScriptService")
    all_zombie_services = [
        item for item in root.iter("Item")
        if instance_name(item) == "ZombieService" and item.get("class") == "ModuleScript"
    ]
    assert len(all_zombie_services) == 1 and all_zombie_services[0] in server_scripts.findall("Item"), (
        "generated place must contain exactly one authoritative ServerScriptService.ZombieService"
    )
    server_modules = {}
    for name in (
        "ActiveZombieRegistry", "CombatService", "DamageRules", "KillCounter", "PlayerHealthService", "RunRules",
        "ProgressionRules", "ProgressionService", "ProgressionSessionStore",
        "ShopRules", "ShopService", "ShopSessionStore", "WaveRules", "WaveService",
        "ZombieRules", "ZombieService",
    ):
        server_modules[name] = direct_child(server_scripts, name, "ModuleScript")
    server_bootstrap = direct_child(server_scripts, "Bootstrap", "Script")
    server_bootstrap_source = source_of(server_bootstrap)
    for fragment in (
        "require(script.Parent.ProgressionService)",
        "require(script.Parent.ShopService)",
        "require(script.Parent.PlayerHealthService)",
        "PlayerHealthService.Start(WaveService)",
        "ZombieService.Start(PlayerHealthService)",
        "ShopService.Start(ProgressionService)",
        "ProgressionService.Start()",
        "CombatService.Start(ZombieService, ShopService, ProgressionService, PlayerHealthService)",
        "WaveService.Start(ZombieService, ProgressionService)",
    ):
        assert fragment in server_bootstrap_source, f"Server Bootstrap does not resolve {fragment}"
    shop_service_source = source_of(server_modules["ShopService"])
    for fragment in (
        "ShopRules.ValidatePurchase(",
        "progressionService.GetCoins(player)",
        "progressionService.TrySpendCoins(player, price)",
        "ShopRules.GrantPurchase(session, weaponId)",
        "store:Remove(player)",
        "purchaseLocks[player]",
    ):
        assert fragment in shop_service_source, f"ShopService contract missing: {fragment}"
    combat_service_source = source_of(server_modules["CombatService"])
    assert "shopService.IsOwned(player, requestedWeapon)" in combat_service_source
    for fragment in (
        'local KILL_ATTRIBUTE = "SessionKills"',
        "killCounter:Add(player, defeatCount)",
        "feedbackRemote:FireClient(player, weaponName, feedbackRoots)",
        "local defeatedRoot, released = defeatZombie(model, root, weaponName, config)",
        "if released then",
        "if defeatedRoot and #feedbackRoots < effectLimit then",
        "FeedbackConfig.GetEffectCount(config.MaxTargets)",
        "killCounter:Remove(player)",
        "progressionService.ResolveFinalAttackDamage(player, config.BaseDamage)",
        "progressionService.AwardZombieDefeats(player, defeatsByWave)",
        "local spawnWave = zombieService.GetSpawnWave(model)",
        "defeatsByWave[spawnWave] = (defeatsByWave[spawnWave] or 0) + 1",
    ):
        assert fragment in combat_service_source, f"CombatService feedback contract missing: {fragment}"
    for fragment in (
        'local DAMAGE_REMOTE_NAME = "ZombieDamageFeedback"',
        "zombieService.ApplyDamage(model, attackDamage)",
        "damageRemote:FireAllClients(damageResults)",
        "if result.Lethal then",
        "AttackDamage = result.AttackDamage",
        "CurrentHP = result.AfterHP",
    ):
        assert fragment in combat_service_source, f"CombatService damage contract missing: {fragment}"

    progression_service_source = source_of(server_modules["ProgressionService"])
    for fragment in (
        'local REMOTE_FOLDER_NAME = "ProgressionRemotes"',
        'local STATE_CHANGED_NAME = "StateChanged"',
        'player:SetAttribute("PlayerLevel", state.Level)',
        'player:SetAttribute("CurrentXP", state.XP)',
        'player:SetAttribute("RequiredXP"',
        'player:SetAttribute("BestWave", state.BestWave)',
        'player:SetAttribute("Coins", state.Coins)',
        "ProgressionRules.AwardZombieDefeatsByWave(state, defeatsByWave)",
        "function ProgressionService.GetCoins(player: Player): number",
        "function ProgressionService.TrySpendCoins(player: Player, amount: number): boolean",
        "function ProgressionService.AwardWaveClearBonus(wave: number): number",
        "stateChangedRemote:FireClient(player",
        "store:Remove(player)",
    ):
        assert fragment in progression_service_source, f"ProgressionService contract missing: {fragment}"
    for fragment in (
        "require(script.Parent.ProgressionRules)",
        "require(script.Parent.ProgressionSessionStore)",
    ):
        assert fragment in progression_service_source, f"ProgressionService dependency missing: {fragment}"
    wave_rules_source = source_of(server_modules["WaveRules"])
    for fragment in (
        "state.Spawned < state.TotalQuota",
        "activeCount < maxAlive",
        "state.Spawned += 1",
        "activeWaveCount > 0",
        "state.Cleared = true",
    ):
        assert fragment in wave_rules_source, f"WaveRules contract missing: {fragment}"
    wave_service_source = source_of(server_modules["WaveService"])
    for fragment in (
        "require(script.Parent.WaveRules)",
        'local WAVE_CLEARED_REMOTE = "WaveCleared"',
        "HordeConfig.GetTotalSpawn(wave)",
        "WaveRules.CanSpawn(state, zombieService.GetActiveCount(), HordeConfig.MaxAliveZombies)",
        "zombieService.Spawn(wave)",
        "task.wait(HordeConfig.CapPollInterval)",
        "WaveRules.TryMarkCleared(state, zombieService.GetActiveCountForWave(wave))",
        "progressionService.AwardWaveClearBonus(wave)",
        "clearedRemote:FireAllClients(wave)",
        "zombieService.ClearForNewRun()",
        "if HordeConfig.Intermission > 0 and isCurrent(runGeneration) then",
    ):
        assert fragment in wave_service_source, f"WaveService contract missing: {fragment}"
    registry_source = source_of(server_modules["ActiveZombieRegistry"])
    assert "function ActiveZombieRegistry:CountForWave(wave: number): number" in registry_source
    assert "entry.SpawnWave == wave" in registry_source
    progression_rules_source = source_of(server_modules["ProgressionRules"])
    for fragment in (
        "BASE_REQUIRED_XP = 100",
        "REQUIRED_XP_PER_LEVEL = 50",
        "DAMAGE_INCREASE_PER_LEVEL = 0.05",
        "math.round(baseDamage * ProgressionRules.DamageMultiplier(level))",
        "while state.XP >= ProgressionRules.RequiredXP(state.Level) do",
        "BASE_ZOMBIE_XP + math.floor(safeWave / XP_WAVE_DIVISOR)",
    ):
        assert fragment in progression_rules_source, f"ProgressionRules contract missing: {fragment}"
    shop_config_source = source_of(direct_child(shared, "ShopConfig", "ModuleScript"))
    for fragment in (
        "FRYING_PAN = 80",
        "GIANT_HAMMER = 220",
        "BLOWER = 500",
        "THUNDER_ROD = 900",
    ):
        assert fragment in shop_config_source, f"GB-024 shop price source missing: {fragment}"
    progression_hud_source = source_of(modules["ProgressionHud"])
    for fragment in (
        'gui.Name = GUI_NAME',
        'panel.Name = "ProgressionPanel"',
        'barBackground.Name = "XPBarBackground"',
        'barFill.Name = "XPBarFill"',
        'xpLabel.Text = string.format("%d / %d XP"',
        'levelUpLabel.Name = "LevelUpFeedback"',
        "DAMAGE +%d%%",
        'stateChanged.OnClientEvent:Connect',
    ):
        assert fragment in progression_hud_source, f"Progression HUD contract missing: {fragment}"

    damage_rules_source = source_of(server_modules["DamageRules"])
    for fragment in (
        'state.Lifecycle ~= "ACTIVE"',
        'state.Lifecycle = "DEFEATED"',
        "AttackDamage = appliedDamage",
        "ActualHPLoss = actualHPLoss",
        "BeforeHP = beforeHP",
        "AfterHP = afterHP",
        "local actualHPLoss = beforeHP - afterHP",
    ):
        assert fragment in damage_rules_source, f"DamageRules lethal guard missing: {fragment}"
    zombie_service_source = source_of(server_modules["ZombieService"])
    for fragment in (
        "local maxHP = HordeConfig.GetZombieHP(spawnWave)",
        "local zombieDamage = HordeConfig.GetZombieDamage(spawnWave)",
        'model:SetAttribute("SpawnWave", spawnWave)',
        'model:SetAttribute("ZombieDamage", zombieDamage)',
        'model:SetAttribute("MaxHP", maxHP)',
        'model:SetAttribute("CurrentHP", maxHP)',
        "function ZombieService.ApplyDamage(model: Model, damage: number)",
        "function ZombieService.Spawn(spawnWave: number): Model?",
        "function ZombieService.GetActiveCountForWave(wave: number): number",
        "function ZombieService.GetSpawnWave(model: Model): number?",
        "SpawnWave = spawnWave",
        "ZombieDamage = zombieDamage",
        "humanoid.MaxHealth = maxHP",
        "humanoid.Health = maxHP",
    ):
        assert fragment in zombie_service_source, f"Zombie HP implementation missing: {fragment}"
    spawn_rules_source = source_of(server_modules["ZombieRules"])
    assert "ResolveSpawnHP" not in spawn_rules_source
    player_health_source = source_of(server_modules["PlayerHealthService"])
    for fragment in (
        "humanoid.MaxHealth = DamageConfig.PlayerMaxHP",
        "humanoid.Health = DamageConfig.PlayerMaxHP",
        'player.CharacterAdded:Connect',
        "runCoordinator.NotifyPlayerUnavailable(player)",
        'Players.RespawnTime = DamageConfig.RespawnDelay',
        'humanoid:TakeDamage(damage)',
        'player:SetAttribute(PROTECTED_ATTRIBUTE, true)',
        "nextZombieDamageAt[player] = now + DamageConfig.PlayerHitInvulnerabilityDuration",
        "RunRules.CanReceiveZombieDamage(now, nextDamageAt, PlayerHealthService.IsProtected(player))",
        "if humanoid.Health >= beforeHP then",
        "nextZombieDamageAt[player] = nil",
    ):
        assert fragment in player_health_source, f"Player HP foundation missing: {fragment}"
    damage_feedback_source = source_of(modules["CombatFeedbackController"])
    for fragment in (
        'WaitForChild("ZombieDamageFeedback")',
        'billboard.Name = "ZombieDamageNumber"',
        'gui.Name = "ZombieHealthBar"',
        "DamageConfig.ZombieHealthBarLifetime",
        "result.Lethal == true",
        'type(result.AttackDamage) == "number"',
        "createDamageNumber(root, result.AttackDamage,",
    ):
        assert fragment in damage_feedback_source, f"Damage presentation missing: {fragment}"
    zombie_service_source = source_of(server_modules["ZombieService"])
    for fragment in (
        "DamageConfig.ZombieAttackInterval",
        "entry.ZombieDamage",
        "healthService.DamagePlayer(entry.TargetPlayer, entry.ZombieDamage)",
        "function ZombieService.ClearForNewRun()",
    ):
        assert fragment in zombie_service_source, f"Zombie attack/run cleanup contract missing: {fragment}"
    run_rules_source = source_of(server_modules["RunRules"])
    for fragment in (
        "function RunRules.CanZombieAttack",
        "function RunRules.CanReceiveZombieDamage",
        "function RunRules.ShouldResetRun",
        "function RunRules.RecordBestWave",
    ):
        assert fragment in run_rules_source, f"RunRules contract missing: {fragment}"
    damage_config_source = source_of(direct_child(shared, "DamageConfig", "ModuleScript"))
    assert "PlayerHitInvulnerabilityDuration = 2.0" in damage_config_source
    assert "Position = hitPosition" not in combat_service_source
    assert "createImpact" not in feedback_source
    assert "ZombieImpactFlash" not in feedback_source

    for name, module in modules.items():
        source = source_of(module)
        assert '"DEV:' not in source, f"Player-facing DEV text remains in {name}"
        assert "DevWeaponCycle" not in source, f"DEV selector remains in {name}"

    starter_module_names = {
        instance_name(item)
        for item in starter_scripts.findall("Item")
        if item.get("class") == "ModuleScript"
    }
    assert not starter_module_names, (
        "Client ModuleScripts must be mapped to ReplicatedStorage.Client, found in "
        f"StarterPlayerScripts: {sorted(starter_module_names)}"
    )

    print(
        "PASS client mapping: "
        "StarterPlayerScripts.Bootstrap -> ReplicatedStorage.Client.CombatController "
        "/ WaveHud clear presentation / ProgressionHud / ShopController; "
        "ServerScriptService.Bootstrap -> WaveService / WaveRules / CombatService / "
        "ProgressionService / DamageRules / ZombieService / PlayerHealthService resolved"
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate generated Roblox client hierarchy")
    parser.add_argument("place", help="Path to a Rojo-generated .rbxlx file")
    args = parser.parse_args()
    try:
        validate(args.place)
    except (AssertionError, ET.ParseError, OSError) as error:
        print(f"FAIL client mapping: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
