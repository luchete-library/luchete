extends Node
class_name VisitorManager

const VISITOR_SCENE = preload("res://scenes/visitors/Visitor.tscn")
const SPAWN_INTERVAL = 10.0
const MIN_SPAWN_INTERVAL = 5.0
const SPAWN_INTERVAL_DAY_STEP = 1.0
const MAX_VISITORS = 3

var spawn_timer := 0.0
var current_spawn_interval := SPAWN_INTERVAL
var library_room: Node = null
var memory_manager: Node = null
var active_visitors := []
var game_root: Node = null

func setup(library_room_node: Node, memory_manager_node: Node, game_root_node: Node) -> void:
    library_room = library_room_node
    memory_manager = memory_manager_node
    game_root = game_root_node

func _process(delta: float) -> void:
    if library_room == null or memory_manager == null:
        return
    spawn_timer += delta
    if spawn_timer >= current_spawn_interval and active_visitors.size() < MAX_VISITORS:
        spawn_timer = 0.0
        _try_spawn_visitor()

func update_day(current_day: int) -> void:
    var next_interval: float = maxf(
        MIN_SPAWN_INTERVAL,
        SPAWN_INTERVAL - float(current_day - 1) * SPAWN_INTERVAL_DAY_STEP
    )
    if is_equal_approx(next_interval, current_spawn_interval):
        return
    current_spawn_interval = next_interval
    print(
        "[VisitorManager] Spawn interval changed for Day ",
        current_day,
        ": ",
        current_spawn_interval,
        " seconds"
    )

func _try_spawn_visitor() -> void:
    var entrance = library_room.get_entrance_position()
    var spot_name = library_room.claim_reading_spot()
    if spot_name == "":
        return
    var spot_position = library_room.get_reading_spot_position(spot_name)
    var visitor = VISITOR_SCENE.instantiate()
    visitor.setup(entrance, spot_position, spot_name, library_room, memory_manager, self)
    add_child(visitor)
    active_visitors.append(visitor)

func notify_visitor_left(visitor: Node, spot_name_string: String) -> void:
    active_visitors.erase(visitor)
    if library_room:
        library_room.release_reading_spot(spot_name_string)
