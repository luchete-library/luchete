extends Node2D

const LIBRARY_SCENE = preload("res://scenes/library/LibraryRoom.tscn")
const PLAYER_SCENE = preload("res://scenes/player/Player.tscn")
const VISITOR_MANAGER = preload("res://scripts/managers/VisitorManager.gd")
const MEMORY_MANAGER = preload("res://scripts/systems/MemoryManager.gd")
const DAY_MANAGER = preload("res://scripts/systems/DayManager.gd")
const RECOGNITION_MANAGER = preload("res://scripts/systems/RecognitionManager.gd")
const STELLA_MANAGER = preload("res://scripts/systems/StellaManager.gd")

@onready var player_start = $PlayerStart
@onready var memory_label = $MemoryUI/MemoryLabel
@onready var recognition_label = $RecognitionUI/RecognitionLabel
@onready var day_label = $DayUI/DayLabel
@onready var stella_label = $StellaUI/StellaLabel
@onready var summary_label = $SummaryUI/SummaryLabel
@onready var summary_timer = $SummaryTimer

var day_manager: Node = null
var memory_manager: Node = null
var recognition_manager: Node = null
var stella_manager: Node = null
var visitor_manager: Node = null
var library_room: Node = null
var spawned_stellas := {}

func _ready() -> void:
    library_room = LIBRARY_SCENE.instantiate()
    add_child(library_room)

    var player = PLAYER_SCENE.instantiate()
    player.position = player_start.position
    add_child(player)

    memory_manager = MEMORY_MANAGER.new()
    add_child(memory_manager)
    memory_manager.connect("memory_changed", Callable(self, "_on_memory_changed"))
    summary_timer.connect("timeout", Callable(self, "_on_summary_timer_timeout"))

    recognition_manager = RECOGNITION_MANAGER.new()
    add_child(recognition_manager)
    recognition_manager.connect("recognition_changed", Callable(self, "_on_recognition_changed"))

    stella_manager = STELLA_MANAGER.new()
    add_child(stella_manager)
    stella_manager.connect("stella_unlocked", Callable(self, "_on_stella_unlocked"))
    _update_stella_label()
    _on_recognition_changed(recognition_manager.get_total_recognition())

    day_manager = DAY_MANAGER.new()
    add_child(day_manager)
    day_manager.connect("day_ending", Callable(self, "_on_day_ending"))
    day_manager.connect("day_changed", Callable(self, "_on_day_changed"))
    _on_day_changed(day_manager.get_current_day())

    visitor_manager = VISITOR_MANAGER.new()
    add_child(visitor_manager)
    visitor_manager.setup(library_room, memory_manager, self)
    day_manager.connect("day_changed", Callable(visitor_manager, "update_day"))
    visitor_manager.update_day(day_manager.get_current_day())

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_N and day_manager != null:
            day_manager.advance_day()

func _on_memory_changed(total_memory: int) -> void:
    memory_label.text = "Memory: %d" % total_memory

func _on_recognition_changed(total_recognition: int) -> void:
    recognition_label.text = "Recognition: %d" % total_recognition
    stella_manager.update_recognition(total_recognition)

func _on_day_changed(current_day: int) -> void:
    day_label.text = "Day: %d" % current_day

func _update_stella_label() -> void:
    stella_label.text = "Stella: %s" % stella_manager.get_unlocked_stella_display_name()

func _on_day_ending(current_day: int) -> void:
    var daily_memory = memory_manager.get_daily_memory()
    print("Day %d Summary: Memory gained today: %d" % [current_day, daily_memory])
    summary_label.text = "Day %d Summary: Memory +%d" % [current_day, daily_memory]
    summary_label.visible = true
    summary_timer.start()
    recognition_manager.apply_daily_memory(daily_memory)
    memory_manager.reset_daily_memory()

func _on_summary_timer_timeout() -> void:
    summary_label.visible = false

func _on_stella_unlocked(stella_id: String, stella_name: String) -> void:
    _spawn_stella(stella_id)
    _update_stella_label()
    summary_label.text = "%s가 루체테에 도착했습니다" % stella_name
    summary_label.visible = true
    summary_timer.start()

func _spawn_stella(stella_id: String) -> void:
    if spawned_stellas.has(stella_id):
        return
    var stella_data = stella_manager.get_stella_data(stella_id)
    if stella_data.is_empty():
        return
    var stella_scene = load(stella_data["scene_path"])
    if stella_scene == null:
        return
    var stella = stella_scene.instantiate()
    stella.position = stella_data["spawn_position"]
    library_room.add_child(stella)
    spawned_stellas[stella_id] = stella
