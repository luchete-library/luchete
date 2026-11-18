캐릭터 도트 디테일 개선 · 2026-11-14

원화: fronts_v2.png (내장 image_gen으로 생성, 기존 여섯 기본 의상 참고)
참고 시트: reference_defaults.png
생성 프롬프트: prompts.json
기본 의상: 야토 토끼 후드 / 단밍 달빛요정 / 쿠비 도깨비 /
           유네 베일 드레스 / 도리 탐정 케이프 / 후와 눈꽃 의상

실제 게임 원본은 assets/characters/source/detail_v2의 64×90 PNG.
원화에서 동일한 가로·세로 배율로 등록하고, 발바닥을 y=89에 정렬한다.
한 번의 native sampling과 무디더링 40색 팔레트를 사용한다.
눈·턱·어깨·손의 좌표는 register_fronts.py의 PINS에 기록한다.
기존 대체 의상, 에테, 팬 캐릭터 원화는 교체하지 않는다.

재생성 순서 (프로젝트 루트, Pillow/numpy/opencv 설치된 Python):
python tools/character_detail/register_fronts.py
python tools/bake_yard_sprites.py
python tools/bake_stella_directions.py
python tools/import_stella_interactions.py --atlas-only
python tools/bake_pose_transitions.py
python -c "import sys;sys.path.insert(0,'tools');from bake_yato_storehouse import reaction;reaction()"
python tools/comic_cast.py
python tools/render_dori_comic.py --all
python tools/check_field_faces.py

이후 Godot 에셋 다시 가져오기 및 tests/directional.gd,
tests/smoke.gd, tests/render.gd의 field-face-review로 런타임 확인.
테스트는 _save()를 비워 두므로 사용자 세이브/플레이타임을 변경하지 않는다.

수정 전 백업: artifacts/character_detail_20261114/before
동작 프레임 수와 실행 속도는 유지하고 소스 픽셀만 교체한다.
쿠비의 펼친 소매는 회전 시 어깨 연결을 위해 안쪽 겹침을 3px로 확보한다.
