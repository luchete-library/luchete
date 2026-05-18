extends Node2D

const LIBRARY_SCENE = preload("res://scenes/library/LibraryRoom.tscn")
const PLAYER_SCENE = preload("res://scenes/player/Player.tscn")
const VISITOR_MANAGER = preload("res://scripts/managers/VisitorManager.gd")
const MEMORY_MANAGER = preload("res://scripts/systems/MemoryManager.gd")
const DAY_MANAGER = preload("res://scripts/systems/DayManager.gd")

@onready var player_start = $PlayerStart
@onready var memory_label = $MemoryUI/MemoryLabel
@onready var day_label = $DayUI/DayLabel

var day_manager = null

func _ready() -> void:
    var library_room = LIBRARY_SCENE.instantiate()
    add_child(library_room)

    var player = PLAYER_SCENE.instantiate()
    player.position = player_start.position
    add_child(player)

    var memory_manager = MEMORY_MANAGER.new()
    add_child(memory_manager)
    memory_manager.connect("memory_changed", Callable(self, "_on_memory_changed"))

    day_manager = DAY_MANAGER.new()
    add_child(day_manager)
    day_manager.connect("day_changed", Callable(self, "_on_day_changed"))
    _on_day_changed(day_manager.get_current_day())

    var visitor_manager = VISITOR_MANAGER.new()
    add_child(visitor_manager)
    visitor_manager.setup(library_room, memory_manager, self)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_N and day_manager != null:
            day_manager.advance_day()

func _on_memory_changed(total_memory: int) -> void:
    memory_label.text = "Memory: %d" % total_memory

func _on_day_changed(current_day: int) -> void:
    day_label.text = "Day: %d" % current_day
