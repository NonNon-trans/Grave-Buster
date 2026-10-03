#!/usr/bin/env python3
"""Verify and compile every executable Rojo source, including all dependencies."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile
import xml.etree.ElementTree as ET
from validate_client_mapping import instance_name, source_of

CLASSES = {'.server.lua': 'Script', '.client.lua': 'LocalScript'}

def sha(data):
    return hashlib.sha256(data).hexdigest()

def audit(place, project, compiler, report=None):
    root_dir = Path(project).resolve().parent
    tree = json.loads(Path(project).read_text())['tree']
    expected = {}
    def file_source(path, dest):
        suffix = next((s for s in CLASSES if path.name.endswith(s)), None)
        name = path.name[:-len(suffix)] if suffix else path.stem
        kind = CLASSES[suffix] if suffix else 'ModuleScript'
        return name, kind, path.read_text()
    def walk(mapping, dest):
        if '$path' in mapping:
            path = root_dir / mapping['$path']
            if path.is_file():
                _, kind, source = file_source(path, dest)
                expected[dest] = (kind, source, str(path.relative_to(root_dir)))
            else:
                for child in sorted(path.iterdir()):
                    if child.suffix in ('.lua', '.luau'):
                        name, kind, source = file_source(child, dest)
                        expected[dest + '.' + name] = (kind, source, str(child.relative_to(root_dir)))
        for name, child in mapping.items():
            if not name.startswith('$'):
                walk(child, dest + '.' + name if dest else name)
    walk(tree, '')
    actual, instances = {}, {}
    def visit(parent, prefix=''):
        for item in parent.findall('Item'):
            path = prefix + '.' + instance_name(item) if prefix else instance_name(item)
            assert path not in instances, f'Duplicate instance {path}'
            instances[path] = item
            if item.get('class') in ('Script', 'LocalScript', 'ModuleScript'):
                actual[path] = (item.get('class'), source_of(item))
            visit(item, path)
    visit(ET.parse(place).getroot())
    assert set(actual) == set(expected), f'Executable set mismatch: missing={set(expected)-set(actual)}, extra={set(actual)-set(expected)}'
    records, dependencies = [], []
    with tempfile.TemporaryDirectory(prefix='gb028-executable-') as temporary:
        for index, (path, (kind, source, source_path)) in enumerate(sorted(expected.items())):
            assert actual[path] == (kind, source), f'Embedded source/class mismatch: {path}'
            extracted = Path(temporary) / f'{index}.luau'
            extracted.write_text(actual[path][1])
            compiled = subprocess.run([compiler, '--null', str(extracted)], capture_output=True, text=True)
            assert compiled.returncode == 0, f'Embedded compile failed {path}: {compiled.stderr}'
            records.append({'instance': path, 'class': kind, 'source': source_path, 'sha256': sha(source.encode())})
            # All current startup require forms are static instance paths. Audit
            # the actual executable text, including chained WaitForChild calls.
            normalized = re.sub(r':WaitForChild\("([^"\n]+)"\)', r'.\1', actual[path][1])
            for expression in re.findall(r'\brequire\(([^)\n]+)\)', normalized):
                expression = expression.strip()
                if expression.startswith('script.Parent.'):
                    target = path.rsplit('.', 1)[0] + expression[len('script.Parent'):]
                elif expression.startswith('ReplicatedStorage.'):
                    target = expression
                elif expression.startswith('clientModules.'):
                    target = 'ReplicatedStorage.Client' + expression[len('clientModules'):]
                else:
                    raise AssertionError(f'Unaudited require expression {path}: {expression}')
                assert target in actual and actual[target][0] == 'ModuleScript', f'Missing startup dependency: {path} -> {target}'
                dependencies.append({'from': path, 'to': target})
    result = {'status': 'PASS', 'artifact_sha256': sha(Path(place).read_bytes()), 'executable_count': len(records), 'dependency_count': len(dependencies), 'sources': records, 'dependencies': dependencies}
    if report:
        Path(report).write_text(json.dumps(result, indent=2) + '\n')
    print(f"PASS source artifact: {len(records)} executable sources equal checkout bytes; embedded compile; {len(dependencies)} require dependencies resolve")
    return result

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('place')
    parser.add_argument('--project', default='default.project.json')
    parser.add_argument('--compiler', default='build/luau-tools/luau-compile')
    parser.add_argument('--report')
    args = parser.parse_args()
    audit(args.place, args.project, args.compiler, args.report)
