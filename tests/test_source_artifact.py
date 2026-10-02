#!/usr/bin/env python3
"""Regression: stale Sources, omitted startup helpers and extra scripts fail."""
import argparse
from pathlib import Path
import tempfile
import xml.etree.ElementTree as ET
from validate_client_mapping import instance_name
from validate_source_artifact import audit

parser = argparse.ArgumentParser()
parser.add_argument('place')
args = parser.parse_args()
with tempfile.TemporaryDirectory(prefix='gb028-corruption-') as temp:
    for mode, expected_error in [('source', 'Embedded source/class mismatch'), ('helper', 'Executable set mismatch'), ('extra', 'Executable set mismatch')]:
        root = ET.parse(args.place).getroot()
        client = next(i for i in root.iter('Item') if instance_name(i) == 'Client')
        if mode == 'source':
            hud = next(i for i in client.findall('Item') if instance_name(i) == 'ProgressionHud')
            source = next(p for p in hud.find('Properties') if p.get('name') == 'Source')
            source.text += '\n-- stale revision corruption\n'
        elif mode == 'helper':
            client.remove(next(i for i in client.findall('Item') if instance_name(i) == 'FeedbackScope'))
        else:
            extra = ET.SubElement(client, 'Item', {'class': 'LocalScript'})
            props = ET.SubElement(extra, 'Properties')
            ET.SubElement(props, 'string', {'name': 'Name'}).text = 'UnexpectedStartup'
            ET.SubElement(props, 'ProtectedString', {'name': 'Source'}).text = 'print("unexpected")'
        place = Path(temp) / f'{mode}.rbxlx'
        ET.ElementTree(root).write(place)
        try:
            audit(place, 'default.project.json', 'build/luau-tools/luau-compile')
        except AssertionError as error:
            assert expected_error in str(error), str(error)
        else:
            raise AssertionError(f'Corrupt artifact was accepted: {mode}')
print('PASS artifact corruption regression: stale source, omitted helper and unexpected startup script all rejected')
