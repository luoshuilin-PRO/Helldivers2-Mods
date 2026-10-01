"""Apply only the menu changes to the user's local original Enemy HP ZIP."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('original_zip', type=Path)
    args = parser.parse_args()
    patch = json.loads((ROOT/'mods/enemy-hp/menu-patch.json').read_text(encoding='utf-8'))
    original = None
    with zipfile.ZipFile(args.original_zip) as package:
        for item in package.infolist():
            if not item.filename.endswith('.patch_0'):
                continue
            blob = package.read(item)
            if len(blob) < 104 or struct.unpack_from('<I', blob)[0] != 0xF0000011:
                continue
            count = struct.unpack_from('<I', blob, 8)[0]
            for i in range(count):
                position = 104 + 80 * i
                _, resource_type, offset = struct.unpack_from('<QQQ', blob, position)
                if resource_type != 0xA14E8DFA2CD117E2:
                    continue
                length, _ = struct.unpack_from('<II', blob, offset)
                text = blob[offset+8:offset+8+length].decode('utf-8').replace('\r\n', '\n')
                if hashlib.sha256(text.encode()).hexdigest() == patch['base_sha256']:
                    original = text
    if original is None:
        raise SystemExit('Original source does not match Enemy HP 1.1.1 with names; no patch applied.')
    lines = original.splitlines(keepends=True)
    for change in reversed(patch['changes']):
        lines[change['start']:change['end']] = change['replacement']
    result = ''.join(lines)
    if hashlib.sha256(result.encode()).hexdigest() != patch['result_sha256']:
        raise SystemExit('Patched source checksum mismatch; no file written.')
    target = ROOT/'mods/enemy-hp/Enemy-HP-With-Names-Menu-v1.1.2.lua'
    target.write_bytes(result.encode('utf-8'))
    print(f'Generated local source: {target}. Run python scripts/build.py next.')


if __name__ == '__main__':
    main()
