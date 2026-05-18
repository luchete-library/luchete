# Lucete Library Game

A minimal Godot 4 playable prototype with cozy top-down exploration.

## Implemented systems

- Top-down 2D movement using `CharacterBody2D`
- WASD controls
- Smooth, slightly slow-paced player motion with acceleration and friction
- Camera follow using `Camera2D`
- Placeholder library room built with `TileMap`
- Solid perimeter wall collisions using `StaticBody2D` and `CollisionShape2D`
- Simple Memory UI display showing current Memory amount

## Controls

- `W` = move up
- `A` = move left
- `S` = move down
- `D` = move right

## Project structure

- `project.godot` — Godot project settings and main scene
- `scenes/Main.tscn` — main scene that loads the room and player
- `scenes/player/Player.tscn` — player scene with movement, collision, and camera
- `scenes/library/LibraryRoom.tscn` — library room scene with floor tiles and walls
- `scripts/Main.gd` — scene setup logic
- `scripts/player/Player.gd` — player movement and sprite generation
- `scripts/library/LibraryRoom.gd` — procedural tilemap and wall collision setup
- `scenes/visitors/Visitor.tscn` — visitor scene with placeholder visuals and movement
- `scripts/visitors/Visitor.gd` — visitor state flow and cozy reading behavior
- `scripts/managers/VisitorManager.gd` — visitor spawning, entrance handling, and spot assignment
- `scripts/systems/MemoryData.gd` — memory resource definition
- `scripts/systems/MemoryManager.gd` — simple memory generation and logging

## Visitor system

- 방문자는 도서관 입구에서 주기적으로 등장합니다
- 방문자는 빈 독서 자리를 선택하고 이동합니다
- 각 방문자는 위에 상태 레이블을 표시하여 현재 행동을 보여줍니다 (Entering / Reading / Leaving)
- 도착 후 일정 시간 동안 앉아 독서를 진행합니다
- 독서 완료 시 `MemoryData` 리소스를 생성하고 로그를 출력합니다
- 독서가 끝나면 도서관을 떠납니다

## Gameplay loop

1. 방문자 등장
2. 빈 읽기 자리로 이동
3. 읽기/휴식 시간
4. 메모리 자원 생성
5. 도서관 퇴장

## Design notes

- Focused on movement, map structure, collisions, camera, and visitor flow
- No combat, inventory, dialogue, or UI systems included
- System is designed to stay simple and scale later with more visitor behavior
