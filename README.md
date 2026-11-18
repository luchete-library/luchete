# 루체테 · 도서관 밸리

리스텔라 비공식 팬게임의 Godot 프로젝트입니다. 에테의 의뢰를 받고 여섯 스텔라의 이야기를 진행한 뒤, 함께 도서관을 재건하고 운영합니다. 개발 중인 시제품이며 공식 서비스가 아닙니다.

## 웹으로 플레이

게임 실행: https://luchete-library.github.io/luchete/

- PC의 최신 Chrome 또는 Edge와 키보드·마우스를 권장합니다.
- 첫 실행 시 약 101 MB의 게임 자료를 받습니다.
- 이동: 방향키 / WASD, 상호작용: E, 메뉴: Esc, 저장: F5. 장면별 안내를 함께 확인하세요.
- 저장은 현재 기기와 브라우저에 보관됩니다. 다른 기기와 공유되지 않으며 브라우저 데이터를 삭제하면 저장도 지워집니다.
- Windows판 저장과 웹판 저장은 별개입니다.

## 로컬 실행

Godot **4.6.2 stable**에서 `project.godot`을 열고 실행하세요. Compatibility 렌더러를 사용합니다.

## 웹 배포

`main`에 변경을 올리면 `.github/workflows/pages.yml`이 게임을 빌드하고 GitHub Pages에 배포합니다. `build/web` 결과물은 저장소에 직접 넣지 않고 Actions에서 생성합니다.

처음 한 번 저장소의 **Settings → Pages → Build and deployment → Source**를 **GitHub Actions**로 설정해야 합니다. GitHub Free에서는 공개 저장소만 Pages를 사용할 수 있습니다. 비공개 저장소를 공개로 바꾸면 현재 파일뿐 아니라 기존 변경 이력도 공개되므로 소유자가 공개 범위를 결정해야 합니다.

Pages 설정이 완료되기 전에도 Actions의 `luchete-web` 빌드 파일을 내려받을 수 있습니다. `index.html`을 파일로 직접 열면 실행되지 않으므로 HTTP 서버로 제공해야 합니다.

로컬 웹 빌드(아래 `godot`은 Godot 4.6.2 실행 파일 경로로 바꿀 수 있습니다):

```sh
python tools/web/download_dependencies.py
godot --headless --path . --editor --import
godot --headless --path . --export-release Web build/web/index.html
python tools/web/check_build.py
python -m http.server 8000 --directory build/web
```

브라우저에서 http://localhost:8000 을 열어 테스트합니다. 배포 설정은 일반 정적 호스팅에 맞춘 단일 스레드 방식입니다. 멀티플레이 서버와 온라인 계정 동기화 기능은 없습니다.

## 프로젝트 구성

- `scripts/`, `main.tscn`: 게임 로직과 시작 장면
- `assets/`: 캐릭터, 배경, 연출 및 한글 글꼴
- `tests/`, `previews/`, `tools/`: 개발 중 검사·시안·에셋 제작 도구
- 루트의 기획 문서: 확정 사항과 미정 사항, 출처 및 기존 검토 기록

작업용 캡처, 다운로드 캐시, 사용자 첨부 파일, 개인 저장 데이터는 저장소에 포함하지 않습니다. 기존 저장소 파일은 현재 프로젝트로 교체하되 이전 커밋 이력은 보존합니다.

## 글꼴과 출처

웹판의 Noto Sans KR과 Noto Sans Symbols 2는 SIL Open Font License 1.1로 제공됩니다. 라이선스 전문은 `assets/fonts/OFL.txt`, `assets/fonts/OFL-Symbols.txt`에 있습니다. 캐릭터·세계관은 각 권리자의 소유이며, 이 저장소 공개가 그 권리의 양도나 재배포 허락을 의미하지 않습니다.
