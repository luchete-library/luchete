"""Fail the release if the exported bundle is incomplete or over Pages limits."""
from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parents[2] / 'build/web'
required = ['index.html', 'index.js', 'index.wasm', 'index.pck', 'index.audio.worklet.js']
for name in required:
    file = root / name
    assert file.is_file() and file.stat().st_size > 0, f'Missing export: {name}'
html = (root / 'index.html').read_text(encoding='utf-8')
assert '$GODOT_' not in html, 'Unexpanded export shell variable'
assert 'getMissingFeatures({threads:false})' in html, 'Threaded build cannot use ordinary Pages hosting'
assert (root / 'index.wasm').read_bytes()[:4] == b'\x00asm', 'Invalid WASM'
assert (root / 'index.pck').read_bytes()[:4] == b'GDPC', 'Invalid PCK'
files = [{ 'file': p.name, 'bytes': p.stat().st_size, 'sha256': hashlib.sha256(p.read_bytes()).hexdigest() }
         for p in sorted(root.iterdir()) if p.is_file() and p.name != 'build-info.json']
total = sum(p['bytes'] for p in files)
assert total < 1024**3, 'GitHub Pages site size exceeded'
(root / 'build-info.json').write_text(json.dumps({'engine': '4.6.2', 'threaded': False, 'bytes': total, 'files': files}, indent=2), encoding='utf-8')
print(f'WEB BUILD OK: {len(files)} files, {total / 1024**2:.1f} MiB')
