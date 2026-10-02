#!/usr/bin/env python3
"""GB-028 repeatable Static Gate. Roblox Human Gate is deliberately NOTRUN."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

BASE = '19ef5213eaaffbe982f882374c51fb33397512fc'
BRANCH = 'phase/GB-028-progression-feedback'
parser = argparse.ArgumentParser()
parser.add_argument('--output', default='build/gb028')
args = parser.parse_args()
output = Path(args.output)
output.mkdir(parents=True, exist_ok=True)
place = output / 'Grave-Buster-v0.2-GB028-human-gate.rbxlx'
checks = []
log = (output / 'static-gate.log').open('w')

def run(name, cmd):
    result = subprocess.run([str(c) for c in cmd], capture_output=True, text=True)
    log.write('COMMAND ' + ' '.join(str(c) for c in cmd) + '\n' + result.stdout + result.stderr + 'EXIT ' + str(result.returncode) + '\n')
    log.flush()
    checks.append({'check': name, 'status': 'PASS' if result.returncode == 0 else 'FAIL'})
    if result.returncode:
        print(f'FAIL {name}: {result.stdout}{result.stderr}')
        raise RuntimeError(name)
    return result.stdout.strip()

try:
    branch = run('branch', ['git', 'branch', '--show-current'])
    assert branch == BRANCH, f'Wrong branch {branch}'
    revision = run('source revision', ['git', 'rev-parse', 'HEAD'])
    run('base ancestor', ['git', 'merge-base', '--is-ancestor', BASE, 'HEAD'])
    run('Rojo version', ['build/rojo-tools/rojo', '--version'])
    protected = list(Path('src/server').glob('*.lua'))
    protected += [p for p in Path('src/shared').glob('*.lua') if p.name != 'ProjectInfo.lua']
    protected += [Path('src/client') / (name + '.lua') for name in ['CombatController','OwnedWeaponSource','WeaponPresenter','WeaponSwitcher','WeaponSwitcherRules']]
    for path in protected:
        original = subprocess.check_output(['git','show',f'{BASE}:{path}'])
        assert path.read_bytes() == original, f'Protected gameplay changed: {path}'
    checks.append({'check': f'{len(protected)} protected gameplay sources byte-identical to develop', 'status': 'PASS'})
    specs = sorted(Path('tests').glob('*.spec.luau'))
    for path in specs:
        run(str(path), ['build/luau-tools/luau', path])
    compiled = sorted(p for folder in ['src','tests'] for p in Path(folder).rglob('*') if p.suffix in ('.lua','.luau'))
    for path in compiled:
        run('compile ' + str(path), ['build/luau-tools/luau-compile', '--null', path])
    run('fresh Rojo build', ['build/rojo-tools/rojo','build','default.project.json','-o',place])
    run('generated hierarchy', ['python3','tests/validate_client_mapping.py',place])
    run('embedded executable/source/dependency agreement', ['python3','tests/validate_source_artifact.py',place,'--report',output/'source-artifact.json'])
    run('artifact corruption regression', ['python3','tests/test_source_artifact.py',place])
    run('embedded client feedback runtime with test doubles', ['python3','tests/run_feedback_runtime.py',place])
    run('diff whitespace', ['git','diff',BASE,'--check'])
    result = {'static_gate':'PASS','source_revision':revision,'branch':branch,'verified_develop':BASE,'spec_count':len(specs),'compile_count':len(compiled),'artifact':place.name,'artifact_sha256':hashlib.sha256(place.read_bytes()).hexdigest(),'checks':checks,'human_gate':{'Studio':'NOTRUN','published_PC':'NOTRUN','physical_Mobile_Landscape':'NOTRUN'}}
    (output/'final-static-gate.json').write_text(json.dumps(result,indent=2)+'\n')
    print(f'PASS Static Gate: {len(specs)} specs; {len(compiled)} compile; {len(protected)} protected sources; fresh build/hierarchy; all embedded executable bytes/dependencies/compile; corruption rejection; real embedded client mock regression; diff check')
    print('NOTRUN Studio / published PC / physical Mobile Landscape Human Gate')
except Exception as error:
    (output/'final-static-gate.json').write_text(json.dumps({'static_gate':'FAIL','error':str(error),'checks':checks},indent=2)+'\n')
    raise
finally:
    log.close()
