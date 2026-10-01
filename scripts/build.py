"""Rebuild addon ZIPs from the included final Lua entries (Python 3 standard library)."""
import json
from pathlib import Path
import struct
import zipfile

ROOT = Path(__file__).resolve().parents[1]
ARCHIVE = '9ba626afa44a3aa3.patch_0'
LUA_TYPE = 0xA14E8DFA2CD117E2


def resource_hash(name):
    data = name.encode('utf-8')
    mask, mix = (1 << 64) - 1, 0xC6A4A7935BD1E995
    value = len(data) * mix & mask
    end = len(data) // 8 * 8
    for (word,) in struct.iter_unpack('<Q', data[:end]):
        word = word * mix & mask
        word ^= word >> 47
        value = (value ^ (word * mix & mask)) * mix & mask
    if data[end:]:
        value = (value ^ int.from_bytes(data[end:], 'little')) * mix & mask
    value ^= value >> 47
    value = value * mix & mask
    return value ^ (value >> 47)


def archive(name, source):
    resource = struct.pack('<II', len(source), 2) + source
    offset = (104 + 80 + 15) & ~15
    body = bytearray(offset)
    body += resource
    body += b'\0' * (-len(body) % 16)
    header = struct.pack('<III20sQQ24s', 0xF0000011, 1, 1, b'', len(body), 0, b'')
    types = struct.pack('<IIQIIII', 0, 0, LUA_TYPE, 1, 0, 16, 16)
    entry = struct.pack('<7Q6I', resource_hash(name), LUA_TYPE, offset, 0, 0, 0, 0,
                        len(resource), 0, 0, 16, 16, 0)
    body[:184] = header + types + entry
    return bytes(body)


PACKAGES = {'faf14-spear': 'FAF-14-Spear-Sliders-v0.2.0.zip', 'sh32-shield': 'SH-32-Shield-Pack-Sliders-v0.2.0.zip', 'democracy-protects': 'Democracy-Protects-Slider-v0.4.0.zip', 'null-cipher': 'RS-67-Null-Cipher-Stealth-Sliders-v0.2.0.zip', 's11-speargun': 'S-11-Speargun-Three-Tiers-v1.4.0.zip'}

def main():
    output = ROOT / 'build'
    output.mkdir(exist_ok=True)
    for slug, filename in PACKAGES.items():
        folder = ROOT / 'mods' / slug
        files = list(folder.glob('*.lua'))
        if len(files) != 1:
            raise ValueError(f'Expected one final Lua entry in {folder}')
        lua = files[0]
        source = lua.read_bytes()
        first = source.decode('utf-8').splitlines()[0]
        if not first.startswith('-- HD2-Addon: '):
            raise ValueError(f'Missing entry declaration in {lua}')
        manifest = json.loads((folder / 'manifest.json').read_text(encoding='utf-8'))
        members = {
            'manifest.json': json.dumps(manifest, ensure_ascii=False, indent=2).encode('utf-8'),
            'Addon/' + ARCHIVE: archive(first.split(': ', 1)[1], source),
            'Addon/' + ARCHIVE + '.stream': b'',
            'Addon/' + ARCHIVE + '.gpu_resources': b'',
            'README.txt': (folder / 'README.txt').read_bytes(),
            'Source/' + lua.name: source,
        }
        with zipfile.ZipFile(output / filename, 'w', compression=zipfile.ZIP_DEFLATED) as package:
            for name, content in members.items():
                package.writestr(name, content)
        print(output / filename)


if __name__ == '__main__':
    main()
