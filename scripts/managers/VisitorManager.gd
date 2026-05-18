extends Node
class_name VisitorManager

const VISITOR_SCENE = preload("res://scenes/visitors/Visitor.tscn")
const SPAWN_INTERVAL = 10.0
const MAX_VISITORS = 3

var spawn_timer := 0.0
var library_room = null
var memory_manager = null
var active_visitors := []
var game_root = null

func setup(library_room_node: Node, memory_manager_node: Node, game_root_node: Node) -> void:
    library_room = library_room_node
    memory_manager = memory_manager_node
    game_root = game_root_node

func _process(delta: float) -> void:
    if library_room == null or memory_manager == null:
        return
    spawn_timer += delta
    if spawn_timer >= SPAWN_INTERVAL and active_visitors.size() < MAX_VISITORS:
        spawn_timer = 0.0
        _try_spawn_visitor()

func _try_spawn_visitor() -> void:
    var entrance = library_room.get_entrance_position()
    var spot_name = library_room.claim_reading_spot()
    if spot_name == "":
        return
    var spot_position = library_room.get_reading_spot_position(spot_name)
    var visitor = VISITOR_SCENE.instantiate() as Visitor
    visitor.setup(entrance, spot_position, spot_name, library_room, memory_manager, self)
    add_child(visitor)
    active_visitors.append(visitor)

func notify_visitor_left(visitor: Node, spot_name_string: String) -> void:
    active_visitors.erase(visitor)
    if library_room:
        library_room.release_reading_spot(spot_name_string)
