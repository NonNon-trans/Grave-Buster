#!/usr/bin/env python3
"""Execute real embedded client modules with deterministic Roblox API test doubles.
This is an automated regression test, not a Studio/Roblox Human Gate.
"""
import argparse
from pathlib import Path
import subprocess
import tempfile
import xml.etree.ElementTree as ET
from validate_client_mapping import instance_name, source_of

parser = argparse.ArgumentParser()
parser.add_argument('place')
parser.add_argument('--luau', default='build/luau-tools/luau')
parser.add_argument('--harness', default=str(Path(__file__).with_name('feedback_runtime.luau')))
args = parser.parse_args()
rows = []
def visit(parent, prefix=''):
    for item in parent.findall('Item'):
        path = f'{prefix}.{instance_name(item)}' if prefix else instance_name(item)
        source = source_of(item)
        assert ']====]' not in source
        rows.append(f'addNode([====[{path}]====], [====[{item.get("class")}]====], [====[{source}]====])')
        visit(item, path)
visit(ET.parse(args.place).getroot())
harness = Path(args.harness).read_text()
if '-- EMBEDDED_TEST_DOUBLES' in harness:
    prefix = Path(__file__).with_name('feedback_runtime.luau').read_text().split('-- Evaluate all real client modules')[0]
    harness = harness.replace('-- EMBEDDED_TEST_DOUBLES', prefix)
assert harness.count('-- EMBEDDED_ARTIFACT_TOPOLOGY') == 1
runner = harness.replace('-- EMBEDDED_ARTIFACT_TOPOLOGY', '\n'.join(rows))
with tempfile.TemporaryDirectory(prefix='gb028-runtime-') as temp:
    path = Path(temp) / 'runner.luau'
    path.write_text(runner)
    result = subprocess.run([args.luau, str(path)], capture_output=True, text=True)
    print(result.stdout, end='')
    print(result.stderr, end='')
    raise SystemExit(result.returncode)
