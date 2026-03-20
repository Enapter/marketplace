#!/usr/bin/env python3
"""
Regenerates references/profiles/catalog.md from the Enapter profiles GitHub repository.

Usage:
    python3 .claude/skills/enapter-blueprint/scripts/update_profiles.py

Requirements: python3, curl (or requests library if available)
"""

import json
import os
import subprocess
import sys
from pathlib import Path

REPO = 'Enapter/profiles'
RAW_BASE = f'https://raw.githubusercontent.com/{REPO}/main'
API_BASE = f'https://api.github.com/repos/{REPO}'

SKILL_DIR = Path(__file__).parent.parent
CATALOG_PATH = SKILL_DIR / 'references' / 'profiles' / 'catalog.md'


def fetch(url: str) -> str:
    result = subprocess.run(['curl', '-sf', url], capture_output=True, text=True)
    if result.returncode != 0:
        print(f'ERROR: failed to fetch {url}', file=sys.stderr)
        sys.exit(1)
    return result.stdout


def list_repo_files() -> list[str]:
    data = json.loads(fetch(f'{API_BASE}/git/trees/main?recursive=1'))
    return [item['path'] for item in data['tree'] if item['type'] == 'blob' and item['path'].endswith('.yml')]


try:
    import yaml
    def parse_yaml(text: str) -> dict:
        return yaml.safe_load(text)
except ImportError:
    # Minimal YAML parser for the simple profile format (no nested lists in values)
    def parse_yaml(text: str) -> dict:
        import re
        result = {}
        current_section = None
        current_item = None
        current_item_section = None

        for line in text.splitlines():
            if not line.strip() or line.strip().startswith('#'):
                continue

            indent = len(line) - len(line.lstrip())

            if indent == 0:
                m = re.match(r'^(\w[\w_]*):\s*(.*)', line)
                if m:
                    key, val = m.group(1), m.group(2).strip()
                    result[key] = val if val else {}
                    current_section = key
                    current_item = None
            elif indent == 2 and current_section:
                m = re.match(r'^\s+-\s+(.*)', line)
                if m:
                    if not isinstance(result.get(current_section), list):
                        result[current_section] = []
                    result[current_section].append(m.group(1).strip())
                else:
                    m = re.match(r'^\s+(\w[\w_]*):\s*(.*)', line)
                    if m:
                        key, val = m.group(1), m.group(2).strip()
                        if isinstance(result.get(current_section), dict):
                            result[current_section][key] = val if val else {}
                            current_item = key
            elif indent == 4 and current_section and current_item:
                m = re.match(r'^\s+(\w[\w_]*):\s*(.*)', line)
                if m:
                    key, val = m.group(1), m.group(2).strip()
                    if isinstance(result.get(current_section), dict) and isinstance(result[current_section].get(current_item), dict):
                        result[current_section][current_item][key] = val

        return result


def path_to_id(path: str) -> str:
    """Convert file path to profile identifier: energy/battery.yml -> energy.battery"""
    return path.replace('/', '.').removesuffix('.yml')


def format_fields(profile: dict) -> str:
    """Format telemetry and properties into a compact string."""
    parts = []

    telemetry = profile.get('telemetry', {})
    if isinstance(telemetry, dict):
        for field, meta in telemetry.items():
            if isinstance(meta, dict):
                unit = meta.get('unit', '')
                parts.append(f'`{field}`' + (f' ({unit})' if unit else ''))
            else:
                parts.append(f'`{field}`')

    properties = profile.get('properties', {})
    if isinstance(properties, dict):
        prop_parts = []
        for field, meta in properties.items():
            if isinstance(meta, dict):
                type_ = meta.get('type', '')
                enum = meta.get('enum', {})
                if isinstance(enum, dict) and enum:
                    values = ', '.join(enum.keys())
                    prop_parts.append(f'`{field}` (enum: {values})')
                else:
                    prop_parts.append(f'`{field}`' + (f' ({type_})' if type_ else ''))
            else:
                prop_parts.append(f'`{field}`')
        if prop_parts:
            parts.append('**properties**: ' + ', '.join(prop_parts))

    implements = profile.get('implements', [])
    if isinstance(implements, list) and implements:
        short = [i.replace('lib.', '').replace('energy.', '').replace('device.', 'device.') for i in implements]
        parts.append('implements: ' + ', '.join(short))

    return ', '.join(parts) if parts else '—'


def build_catalog(files: list[str]) -> str:
    profiles: dict[str, dict] = {}

    for path in files:
        if path == 'README.md':
            continue
        text = fetch(f'{RAW_BASE}/{path}')
        parsed = parse_yaml(text)
        profiles[path] = parsed

    lines = [
        '# Enapter Profiles Catalog',
        '',
        f'Auto-generated from https://github.com/{REPO}',
        'Run `.claude/skills/enapter-blueprint/scripts/update_profiles.py` to refresh.',
        '',
        '## Table of Contents',
        '',
        '- [Device Profiles](#device-profiles)',
        '  - [Energy Devices](#energy-devices)',
        '  - [Sensors](#sensors)',
        '- [Lib Components](#lib-components)',
        '  - [lib.device](#libdevice)',
        '  - [lib.energy.battery](#libenergybattery)',
        '  - [lib.energy.inverter](#libenergyinverter)',
        '  - [lib.energy.power_meter](#libenergypowermeter)',
        '  - [lib.energy.pv](#libenergypv)',
        '  - [lib.sensor](#libsensor)',
        '',
        '---',
        '',
        '## Device Profiles',
        '',
        'Use these identifiers directly in `implements:` in your manifest.',
        '',
    ]

    # Energy device profiles
    energy_paths = sorted(p for p in profiles if p.startswith('energy/'))
    if energy_paths:
        lines += ['### Energy Devices', '', '| Identifier | Display Name | Implements (lib components) |', '|---|---|---|']
        for path in energy_paths:
            p = profiles[path]
            identifier = path_to_id(path)
            name = p.get('display_name', '')
            impls = p.get('implements', [])
            short_impls = ', '.join(
                i.replace('lib.', '').replace('energy.', '').replace('device.', 'device.') if isinstance(i, str) else str(i)
                for i in (impls if isinstance(impls, list) else [])
            )
            lines.append(f'| `{identifier}` | {name} | {short_impls} |')
        lines.append('')

    # Sensor profiles
    sensor_paths = sorted(p for p in profiles if p.startswith('sensor/'))
    if sensor_paths:
        lines += ['### Sensors', '', '| Identifier | Display Name | Implements (lib components) |', '|---|---|---|']
        for path in sensor_paths:
            p = profiles[path]
            identifier = path_to_id(path)
            name = p.get('display_name', '')
            impls = p.get('implements', [])
            short_impls = ', '.join(
                i.replace('lib.', '').replace('energy.', '').replace('device.', 'device.') if isinstance(i, str) else str(i)
                for i in (impls if isinstance(impls, list) else [])
            )
            lines.append(f'| `{identifier}` | {name} | {short_impls} |')
        lines.append('')

    lines += ['---', '', '## Lib Components', '', 'Granular building blocks. Use only when no device profile fits or for extending a device profile.', '']

    # Group lib components by top-level category
    lib_groups: dict[str, list[str]] = {}
    for path in sorted(profiles):
        if not path.startswith('lib/'):
            continue
        parts = path.split('/')
        # Group by first two parts: lib/device, lib/energy, lib/sensor etc.
        group = '.'.join(parts[:2])
        lib_groups.setdefault(group, []).append(path)

    section_anchors = {
        'lib/device': 'libdevice',
        'lib/energy': 'libenergy',
        'lib/sensor': 'libsensor',
    }

    for group, group_paths in sorted(lib_groups.items()):
        group_id = path_to_id(group)
        lines += [f'### {group_id}', '', '| Identifier | Display Name | Telemetry / Properties |', '|---|---|---|']
        for path in group_paths:
            p = profiles[path]
            identifier = path_to_id(path)
            name = p.get('display_name', '')
            fields = format_fields(p)
            lines.append(f'| `{identifier}` | {name} | {fields} |')
        lines.append('')

    return '\n'.join(lines)


def main():
    print('Fetching file list from GitHub...')
    files = list_repo_files()
    print(f'Found {len(files)} YAML files')

    print('Fetching and parsing profiles...')
    catalog = build_catalog(files)

    CATALOG_PATH.write_text(catalog)
    print(f'Written: {CATALOG_PATH}')


if __name__ == '__main__':
    main()
