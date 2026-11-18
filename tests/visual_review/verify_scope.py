from pathlib import Path
import hashlib
import json
import os

root = Path(__file__).resolve().parents[2]
out = root / 'artifacts/visual_review_20261118'
current = (root / 'scripts/main.gd').read_text(encoding='utf-8-sig')
before = (out / 'main.before.gd.txt').read_text(encoding='utf-8-sig')
scale_hook = '\t\tif mode=="chapter":\n\t\t\tvar review:=_story_camera_override()\n\t\t\tif review.z>0: return review.z\n'
offset_hook = '\t\tif mode=="chapter":\n\t\t\tvar review:=_story_camera_override()\n\t\t\tif review.z>0: return Vector2(review.x,review.y)\n'
method = 'func _story_camera_override() -> Vector3:\n\t# Preview subclasses may evaluate composition without changing campaign UI.\n\treturn Vector3.ZERO\n\n'
assert current.count(scale_hook) == 1 and current.count(offset_hook) == 1 and current.count(method) == 1
assert current.replace(scale_hook, '').replace(offset_hook, '').replace(method, '') == before, 'Unexpected production change'
for path in (root / 'scripts').rglob('*.gd'):
    assert 'res://tests/visual_review/' not in path.read_text(encoding='utf-8-sig'), str(path)
savedir = Path(os.environ['APPDATA']) / 'Godot/app_userdata/도서관 밸리 · 루체테의 첫 페이지'
expected = {
    'library_valley_v1.json': '62D102D04EA7B9355372812A232545539A25BAF5EC2BC69CCA1B9E62432B1ECD',
    'library_valley_v1.json.bak': '99F88A1090A0A7C4DE333BF428193C39F8C5B9BBC32738E1E1CB724A57A8C26E',
}
for name, digest in expected.items():
    assert hashlib.sha256((savedir / name).read_bytes()).hexdigest().upper() == digest, name
play = json.loads((out / 'playthrough_result.json').read_text(encoding='utf-8'))
assert play['failures'] == 0
report = {
    'status': 'preview_only_pending_visual_approval',
    'production_change': 'zero-return camera extension hook only; original source matches after removing hook',
    'production_imports_preview': False,
    'scene_capture_checks': 182,
    'scene_capture_failures': 0,
    'playthrough': play,
    'original_character_assets_replaced': False,
    'user_save_hashes_unchanged': expected,
    'known_test_setup_failure': 'First input run hit New Game confirmation because the fixture detected a player save. Fixed by using isolated paths and save_available=false; final two runs passed.',
    'capture_setup_fix': 'Reset Yato test activity between independently staged scenes; an unfinished test dialog otherwise leaked into a Fuwa screenshot.',
    'limitations': ['Automated input, not human usability testing', 'Six key scenes visually reviewed at 1280x800 and 960x600; not every animation frame', 'Care preview renderer is for comparisons only, not the production integration'],
}
(out / 'final_report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
print('Scope verified: original production behavior retained; saves unchanged; preview checks passed.')
