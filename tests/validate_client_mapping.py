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
        'clientModules:WaitForChild("ShopController")',
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
    direct_child(shared, "ShopConfig", "ModuleScript")

    server_scripts = direct_child(root, "ServerScriptService", "ServerScriptService")
    server_modules = {}
    for name in ("CombatService", "ShopRules", "ShopService", "ShopSessionStore"):
        server_modules[name] = direct_child(server_scripts, name, "ModuleScript")
    server_bootstrap = direct_child(server_scripts, "Bootstrap", "Script")
    server_bootstrap_source = source_of(server_bootstrap)
    for fragment in (
        "require(script.Parent.ShopService)",
        "ShopService.Start()",
        "CombatService.Start(ZombieService, ShopService)",
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
        "/ ShopController -> OwnedWeaponSource / WeaponSwitcher; "
        "ServerScriptService.Bootstrap -> ShopService / CombatService also resolved"
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
