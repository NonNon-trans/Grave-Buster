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
        "CombatFeedbackController.Start()",
        "ShopController.Start(CombatController)",
    )
    for fragment in required_bootstrap_fragments:
        assert fragment in bootstrap_source, f"Bootstrap does not resolve {fragment}"
    assert "script.Parent.CombatController" not in bootstrap_source

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
    ):
        assert fragment in wave_hud_source, f"WaveHud feedback contract missing: {fragment}"
    shop_controller_source = source_of(modules["ShopController"])
    for fragment in (
        'script.Parent:WaitForChild("OwnedWeaponSource")',
        'script.Parent:WaitForChild("ShopPresentation")',
        'WaitForChild("PurchaseRequest")',
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
    assert "ImpactLifetime" not in source_of(feedback_config)
    damage_config_source = source_of(damage_config)
    assert "PlayerMaxHP = 100" in damage_config_source
    assert "DefaultZombieHP = 10" in damage_config_source
    direct_child(shared, "ShopConfig", "ModuleScript")

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
        "CombatService", "DamageRules", "KillCounter", "PlayerHealthService",
        "ShopRules", "ShopService", "ShopSessionStore", "ZombieRules", "ZombieService",
    ):
        server_modules[name] = direct_child(server_scripts, name, "ModuleScript")
    server_bootstrap = direct_child(server_scripts, "Bootstrap", "Script")
    server_bootstrap_source = source_of(server_bootstrap)
    for fragment in (
        "require(script.Parent.ShopService)",
        "require(script.Parent.PlayerHealthService)",
        "PlayerHealthService.Start()",
        "ShopService.Start()",
        "CombatService.Start(ZombieService, ShopService)",
        "ZombieService.GetRuntimeDiagnostics()",
        '"[GB021 INIT] path=%s moduleInstance=%s evaluation=%s serviceTable=%s readyBefore=%s"',
        '"[GB021 INIT] path=%s moduleInstance=%s evaluation=%s serviceTable=%s readyAfter=%s container=%s"',
    ):
        assert fragment in server_bootstrap_source, f"Server Bootstrap does not resolve {fragment}"
    shop_service_source = source_of(server_modules["ShopService"])
    for fragment in (
        "ShopRules.TryPurchase(session, weaponId, ShopConfig)",
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
    ):
        assert fragment in combat_service_source, f"CombatService feedback contract missing: {fragment}"
    for fragment in (
        'local DAMAGE_REMOTE_NAME = "ZombieDamageFeedback"',
        "zombieService.ApplyDamage(model, config.BaseDamage)",
        "damageRemote:FireAllClients(damageResults)",
        "if result.Lethal then",
        '"[GB021 HP TEST] HIT id=%s weapon=%s baseDamage=%d beforeHP=%d afterHP=%d maxHP=%d lethal=%s humanoid=%d/%d lifecycle=%s"',
        '"[GB021 HP TEST] RELEASED id=%s sessionKills=%d"',
    ):
        assert fragment in combat_service_source, f"CombatService damage contract missing: {fragment}"

    damage_rules_source = source_of(server_modules["DamageRules"])
    for fragment in ('state.Lifecycle ~= "ACTIVE"', 'state.Lifecycle = "DEFEATED"'):
        assert fragment in damage_rules_source, f"DamageRules lethal guard missing: {fragment}"
    zombie_service_source = source_of(server_modules["ZombieService"])
    for fragment in (
        "local DamageConfig = require(ReplicatedStorage.Shared.DamageConfig)",
        "ZombieRules.ResolveSpawnHP(",
        "local maxHP, testSpawn, rejection = ZombieRules.ResolveSpawnHP(",
        'model:SetAttribute("MaxHP", maxHP)',
        'model:SetAttribute("CurrentHP", maxHP)',
        'model:SetAttribute("GB021HPTest", testSpawn)',
        'marker.Name = "GB021HPTestMarker"',
        '"[GB021 HP TEST] SPAWN id=%s maxHP=%d currentHP=%d lifecycle=ACTIVE humanoid=%d/%d"',
        "function ZombieService.ApplyDamage(model: Model, damage: number)",
        'harness.Name = "GB021HPTestSpawn"',
        "harness.OnInvoke = function(requestedMaxHP: number?)",
        "return ZombieService.Spawn(requestedMaxHP)",
        "function ZombieService.GetRuntimeDiagnostics()",
        "ModuleEvaluationId = moduleEvaluationId",
        '"[GB021 TEST HARNESS] path=%s moduleInstance=%s evaluation=%s serviceTable=%s ready=%s"',
    ):
        assert fragment in zombie_service_source, f"Zombie HP implementation missing: {fragment}"
    spawn_rules_source = source_of(server_modules["ZombieRules"])
    for fragment in (
        "function ZombieRules.ResolveSpawnHP(",
        'return nil, isTestSpawn, "ACTIVE_CAP"',
        'return nil, isTestSpawn, "NOT_READY"',
        "local maxHP = if isTestSpawn then requestedMaxHP else defaultMaxHP",
    ):
        assert fragment in spawn_rules_source, f"Zombie test spawn contract missing: {fragment}"
    player_health_source = source_of(server_modules["PlayerHealthService"])
    for fragment in (
        "humanoid.MaxHealth = DamageConfig.PlayerMaxHP",
        "humanoid.Health = DamageConfig.PlayerMaxHP",
        'player.CharacterAdded:Connect',
    ):
        assert fragment in player_health_source, f"Player HP foundation missing: {fragment}"
    damage_feedback_source = source_of(modules["CombatFeedbackController"])
    for fragment in (
        'WaitForChild("ZombieDamageFeedback")',
        'billboard.Name = "ZombieDamageNumber"',
        'gui.Name = "ZombieHealthBar"',
        "DamageConfig.ZombieHealthBarLifetime",
        "result.Lethal == true",
        '"[GB021 HP TEST] CLIENT id=%s damage=%d hp=%d/%d lethal=%s"',
        '"[GB021 HP TEST] HP BAR SHOWN id=%s hp=%d/%d"',
    ):
        assert fragment in damage_feedback_source, f"Damage presentation missing: {fragment}"
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
        "/ CombatFeedbackController damage UI / ShopController; "
        "ServerScriptService.Bootstrap -> CombatService -> DamageRules / ZombieService / "
        "PlayerHealthService also resolved"
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
