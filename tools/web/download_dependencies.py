"""Fetch only official Godot web templates and the redistributable Korean font.

Read the remote ZIP directory with HTTP ranges, avoiding a 1.25 GB download of
unrelated platform templates. zipfile validates each extracted entry's CRC.
"""
from pathlib import Path
from urllib.request import Request, urlopen
import io
import json
import hashlib
import zipfile

ROOT = Path(__file__).resolve().parents[2]
VERSION = '4.6.2-stable'
URL = f'https://github.com/godotengine/godot/releases/download/{VERSION}/Godot_v{VERSION}_export_templates.tpz'

class RemoteZip(io.RawIOBase):
    def __init__(self, url):
        with urlopen(Request(url, method='HEAD'), timeout=60) as response:
            self.url = response.url
            self.length = int(response.headers['Content-Length'])
        self.position = 0

    def seekable(self): return True
    def readable(self): return True
    def tell(self): return self.position
    def seek(self, offset, whence=0):
        self.position = offset if whence == 0 else self.position + offset if whence == 1 else self.length + offset
        return self.position
    def read(self, size=-1):
        size = min(self.length - self.position, size if size >= 0 else self.length)
        if size <= 0: return b''
        start = self.position
        request = Request(self.url, headers={'Range': f'bytes={start}-{start+size-1}'})
        with urlopen(request, timeout=120) as response:
            if response.status != 206:
                raise RuntimeError('Server did not honor byte range; refusing full template download')
            if not response.headers.get('Content-Range', '').startswith(f'bytes {start}-'):
                raise RuntimeError('Unexpected byte range response')
            data = response.read(size + 1)
        if len(data) != size: raise RuntimeError('Incomplete range download')
        self.position += len(data)
        return data

def main():
    folder = ROOT / '.cache/web_templates'
    folder.mkdir(parents=True, exist_ok=True)
    records = []
    with zipfile.ZipFile(RemoteZip(URL)) as archive:
        for name in ['web_nothreads_release.zip', 'web_nothreads_debug.zip']:
            destination = folder / name
            data = archive.read('templates/' + name)
            with zipfile.ZipFile(io.BytesIO(data)) as template:
                if template.testzip(): raise RuntimeError('Corrupt inner template')
            destination.write_bytes(data)
            records.append({'file': name, 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest(), 'source': URL})
            print(f'Godot web template: {name}, {len(data):,} bytes', flush=True)
    font_dir = ROOT / 'assets/fonts'
    font_dir.mkdir(parents=True, exist_ok=True)
    for name, remote in [('NotoSansKR.ttf', 'NotoSansKR%5Bwght%5D.ttf'), ('OFL.txt', 'OFL.txt')]:
        url = 'https://raw.githubusercontent.com/google/fonts/main/ofl/notosanskr/' + remote
        destination = font_dir / name
        if destination.exists():
            data = destination.read_bytes()
        else:
            with urlopen(url, timeout=120) as response: data = response.read()
            destination.write_bytes(data)
        records.append({'file': name, 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest(), 'source': url})
        print(f'Font: {name}, {len(data):,} bytes', flush=True)
    (folder / 'sources.json').write_text(json.dumps(records, indent=2), encoding='utf-8')

if __name__ == '__main__': main()
