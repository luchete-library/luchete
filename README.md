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
- Simple visitor state labels showing Entering, Reading, or Leaving
- Basic day counter starting at Day 1 with manual next-day input

## Controls

- `W` = move up
- `A` = move left
- `S` = move down
- `D` = move right
- `N` = advance to the next day

## Project structure

- `BRANCH_STRATEGY.md` - Git Flow based branch strategy
- `COMMIT_CONVENTION.md` - commit message convention guide
- `project.godot` - Godot project settings and main scene
- `scenes/Main.tscn` - main scene that loads the room and player
- `scenes/player/Player.tscn` - player scene with movement, collision, and camera
- `scenes/library/LibraryRoom.tscn` - library room scene with floor tiles and walls
- `scripts/Main.gd` - scene setup logic
- `scripts/player/Player.gd` - player movement and sprite generation
- `scripts/library/LibraryRoom.gd` - procedural tilemap and wall collision setup
- `scenes/visitors/Visitor.tscn` - visitor scene with placeholder visuals, movement, and a small state label
- `scripts/visitors/Visitor.gd` - visitor state flow, state label updates, and cozy reading behavior
- `scripts/managers/VisitorManager.gd` - visitor spawning, entrance handling, and spot assignment
- `scripts/systems/MemoryData.gd` - memory resource definition
- `scripts/systems/MemoryManager.gd` - simple memory generation and logging
- `scripts/systems/DayManager.gd` - basic day counter and day change signal

## Visitor system

- Visitors spawn from the library entrance on a timer.
- Visitors claim an open reading spot and move toward it.
- Each visitor shows a small state label above its placeholder sprite.
- The label updates between `Entering`, `Reading`, and `Leaving` as the visitor state changes.
- After reading, visitors keep using the existing Memory generation flow.
- Visitors leave the library after their reading time ends.

## Gameplay loop

1. Visitor enters
2. Visitor moves to an open reading spot
3. Visitor reads for a short time
4. Memory resource is generated
5. Visitor leaves the library

## Day system

- The game starts on `Day: 1`.
- Pressing `N` advances to the next day.
- Advancing the day updates the day UI label and prints a debug message.
- The day system does not change visitor behavior yet.

## Design notes

- Focused on movement, map structure, collisions, camera, and visitor flow
- No combat, inventory, dialogue, or UI systems included
- System is designed to stay simple and scale later with more visitor behavior
