# Lucete Library Game

Godot 4로 만드는 작은 도서관 운영 프로토타입입니다.

## 구현된 시스템

- `CharacterBody2D` 기반 탑다운 2D 이동
- `WASD` 이동 조작
- 가속과 마찰이 있는 느긋한 플레이어 움직임
- `Camera2D` 플레이어 추적
- `TileMap` 기반 임시 도서관 방
- `StaticBody2D`와 `CollisionShape2D`를 사용한 외곽 벽 충돌
- 현재 총 Memory를 보여주는 간단한 UI
- 현재 Recognition을 보여주는 간단한 UI
- 방문자 상태를 보여주는 작은 텍스트 라벨
- 독서 자리의 빈 상태와 점유 상태를 보여주는 단순 색상 마커
- Day 1부터 시작하는 기본 날짜 카운터
- 날짜가 지날수록 조금 빨라지는 방문자 스폰 간격
- 다음 날로 넘어갈 때 출력되는 간단한 일일 Memory 요약
- 하루 요약을 2초 동안 보여주는 간단한 UI 메시지
- 일일 Memory가 일정 기준 이상일 때 증가하는 기본 Recognition 자원
- Recognition 조건을 만족하면 야토를 해금하는 첫 Stella 진행 기반
- 현재 해금된 Stella를 보여주는 작은 UI 라벨
- 야토가 해금되면 도서관 안 고정 위치에 나타나는 간단한 Stella 존재감
- Stella 메타데이터를 `StellaManager`에서 관리하는 확장용 구조

## 조작

- `W` = 위로 이동
- `A` = 왼쪽으로 이동
- `S` = 아래로 이동
- `D` = 오른쪽으로 이동
- `N` = 다음 날로 진행

## 프로젝트 구조

- `BRANCH_STRATEGY.md` - Git Flow 기반 브랜치 전략
- `COMMIT_CONVENTION.md` - 커밋 메시지 컨벤션
- `project.godot` - Godot 프로젝트 설정과 메인 씬
- `scenes/Main.tscn` - 방, 플레이어, 날짜 UI, Memory UI, Recognition UI, Stella UI, 요약 메시지 UI를 포함하는 메인 씬
- `scenes/player/Player.tscn` - 플레이어 씬
- `scenes/library/LibraryRoom.tscn` - 도서관 방 씬
- `scenes/visitors/Visitor.tscn` - 방문자 씬
- `scenes/stella/Yato.tscn` - 야토 Stella placeholder 씬
- `scripts/Main.gd` - 전체 씬 구성, UI 연결, 날짜 요약과 Stella 해금 메시지 표시
- `scripts/player/Player.gd` - 플레이어 이동과 임시 스프라이트 생성
- `scripts/library/LibraryRoom.gd` - 도서관 타일맵, 벽 충돌, 독서 자리 상태와 시각화 관리
- `scripts/visitors/Visitor.gd` - 방문자 상태 흐름과 상태 라벨 갱신
- `scripts/stella/Yato.gd` - 야토 Stella placeholder 시각 요소와 이름 라벨
- `scripts/managers/VisitorManager.gd` - 방문자 스폰, 독서 자리 배정, 날짜 기반 스폰 간격 조정
- `scripts/systems/MemoryData.gd` - Memory 데이터 리소스
- `scripts/systems/MemoryManager.gd` - 총 Memory와 일일 Memory 추적
- `scripts/systems/DayManager.gd` - 날짜 카운터, 하루 종료 시그널, 날짜 변경 시그널
- `scripts/systems/RecognitionManager.gd` - Recognition 자원과 일일 Memory 기준 증가 처리
- `scripts/systems/StellaManager.gd` - Stella 메타데이터, 잠금 상태, Recognition 기준 해금 처리

## 방문자 시스템

- 방문자는 도서관 입구에서 일정 시간마다 등장합니다.
- 방문자는 비어 있는 독서 자리를 배정받고 그 위치로 이동합니다.
- 각 방문자 위에는 현재 상태를 보여주는 작은 라벨이 표시됩니다.
- 라벨은 `Entering`, `Reading`, `Leaving` 상태에 맞춰 갱신됩니다.
- Day 2부터 방문자 스폰 간격이 조금씩 짧아집니다.
- 스폰 간격은 너무 빨라지지 않도록 최소값을 가집니다.
- 방문자가 독서를 마치면 기존 Memory 생성 흐름을 그대로 사용합니다.
- 독서가 끝난 방문자는 도서관을 떠납니다.

## 독서 자리 표시

- 독서 자리는 단순한 색상 사각형 마커로 표시됩니다.
- 빈 독서 자리는 초록색 계열로 표시됩니다.
- 점유된 독서 자리는 붉은색 계열로 표시됩니다.
- 방문자가 독서 자리를 배정받거나 떠날 때 마커 색이 자동으로 갱신됩니다.
- 가구 그림, 장식 에셋, 상호작용 시스템은 아직 없습니다.

## 날짜와 결과 시스템

- 게임은 `Day: 1`에서 시작합니다.
- `N` 키를 누르면 다음 날로 진행됩니다.
- 다음 날로 넘어가기 전에 일일 Memory 요약이 디버그 메시지로 출력됩니다.
- 예: `Day 1 Summary: Memory gained today: 3`
- 같은 시점에 화면에도 작은 요약 메시지가 표시됩니다.
- 예: `Day 1 Summary: Memory +3`
- 요약 UI 메시지는 2초 후 자동으로 사라집니다.
- 다음 날이 시작되면 날짜 UI가 갱신됩니다.
- 날짜가 바뀌면 방문자 스폰 간격도 함께 갱신됩니다.
- 일일 Memory는 요약 출력 후 `0`으로 리셋됩니다.
- 총 Memory는 리셋되지 않고 유지됩니다.
- Recognition은 `0`에서 시작합니다.
- 하루 동안 얻은 Memory가 `3` 이상이면 Recognition이 `1` 증가합니다.
- Recognition이 증가하면 디버그 메시지가 출력되고 UI가 갱신됩니다.

## Stella 진행 기반

- Stella는 기본적으로 잠긴 상태에서 시작합니다.
- Stella 메타데이터는 id, 표시 이름, 필요 Recognition, 씬 경로, 스폰 위치, 해금 상태를 포함합니다.
- `StellaManager`가 Stella 메타데이터와 해금 상태를 소유합니다.
- 현재 등록된 Stella는 `yato` 하나입니다.
- `yato`의 표시 이름은 `야토`입니다.
- Recognition이 `5` 이상이 되면 야토가 해금됩니다.
- 해금 시 `Stella unlocked: 야토` 디버그 메시지가 출력됩니다.
- 화면에는 `야토가 루체테에 도착했습니다` 임시 메시지가 표시됩니다.
- 화면의 작은 Stella UI는 기본적으로 `Stella: 없음`을 표시합니다.
- 야토가 해금되면 Stella UI가 `Stella: 야토`로 갱신됩니다.
- 야토가 해금되면 도서관 안 고정 위치에 단순 placeholder 몸체와 `야토` 라벨이 표시됩니다.
- 대화, 능력, 홍보, 방송, 해금 트리, 캐릭터 아트는 아직 없습니다.

## 기본 플레이 흐름

1. 방문자가 등장합니다.
2. 방문자가 비어 있는 독서 자리로 이동합니다.
3. 독서 자리 마커가 점유 색상으로 바뀝니다.
4. 방문자가 잠시 독서합니다.
5. 독서가 끝나면 Memory가 생성됩니다.
6. 방문자가 도서관을 떠납니다.
7. 독서 자리 마커가 빈 색상으로 돌아옵니다.
8. `N` 키로 다음 날을 시작합니다.
9. 하루 동안 얻은 Memory 요약을 화면과 디버그 출력으로 확인합니다.
10. 일일 Memory가 기준 이상이면 Recognition이 증가합니다.
11. Recognition이 5 이상이 되면 야토가 해금됩니다.

## 설계 메모

- 현재는 이동, 도서관 공간, 충돌, 카메라, 방문자 흐름, 날짜 흐름에 집중합니다.
- 전투, 인벤토리, 대화, 저장/불러오기, 복잡한 UI는 아직 없습니다.
- Stella는 아직 해금 상태, 도착 메시지, 작은 UI 표시, 야토 placeholder 존재감만 가집니다.
- Stella 구조는 야토 interaction hint, 밤 Phase, 방송 슬롯 순서로 확장할 예정입니다.
- Stella 능력, 홍보, 방송, 추가 해금 시스템은 아직 없습니다.
- 하루 요약은 전체 패널이 아니라 간단한 임시 텍스트 메시지만 사용합니다.
- 독서 자리는 가구 아트가 아니라 상태 이해를 위한 단순 마커만 사용합니다.
- 시스템은 작게 유지하고, 이후 도서관 운영 루프와 성장 구조로 확장하기 쉽게 구성합니다.
