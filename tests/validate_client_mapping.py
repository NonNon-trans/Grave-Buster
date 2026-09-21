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
    for name in ("CombatController", "HoldState", "WaveHud", "WeaponPresenter"):
        modules[name] = direct_child(client, name, "ModuleScript")

    starter_player = direct_child(root, "StarterPlayer", "StarterPlayer")
    starter_scripts = direct_child(starter_player, "StarterPlayerScripts", "StarterPlayerScripts")
    bootstrap = direct_child(starter_scripts, "Bootstrap", "LocalScript")

    bootstrap_source = source_of(bootstrap)
    required_bootstrap_fragments = (
        'ReplicatedStorage:WaitForChild("Client")',
        'clientModules:WaitForChild("WaveHud")',
        'clientModules:WaitForChild("CombatController")',
    )
    for fragment in required_bootstrap_fragments:
        assert fragment in bootstrap_source, f"Bootstrap does not resolve {fragment}"
    assert "script.Parent.CombatController" not in bootstrap_source

    controller_source = source_of(modules["CombatController"])
    for dependency in ("HoldState", "WeaponPresenter"):
        fragment = f'script.Parent:WaitForChild("{dependency}")'
        assert fragment in controller_source, f"CombatController does not resolve {fragment}"
    for initialization_guard in (
        "local started = false",
        "if started then",
        'playerGui:FindFirstChild("GraveBusterCombatGui")',
        "previous:Destroy()",
    ):
        assert initialization_guard in controller_source, (
            f"CombatController initialization guard missing: {initialization_guard}"
        )

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
        "-> HoldState / WeaponPresenter; WaveHud also resolved"
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
