extends CharacterBody2D
class_name Visitor

enum State {
    SPAWN,
    MOVE_TO_SPOT,
    READING,
    LEAVING
}

const SPEED = 80.0
const ACCELERATION = 420.0
const FRICTION = 720.0
const ARRIVAL_THRESHOLD = 6.0
const READING_TIME = 5.0

var state := State.SPAWN
var target_position := Vector2.ZERO
var reading_timer := 0.0
var spot_name := ""
var memory_manager: Node = null
var library_room: Node = null
var visitor_manager: Node = null

@onready var sprite = $Sprite2D
@onready var state_label = $StateLabel

func _ready() -> void:
    sprite.texture = _build_visitor_texture()
    _update_state_label()

func setup(entry_position: Vector2, destination_position: Vector2, spot_name_string: String, library_room_node: Node, memory_manager_node: Node, manager_node: Node) -> void:
    position = entry_position
    target_position = destination_position
    library_room = library_room_node
    memory_manager = memory_manager_node
    visitor_manager = manager_node
    spot_name = spot_name_string
    _set_state(State.MOVE_TO_SPOT)
    if spot_name == "":
        _leave_library()

func _physics_process(delta: float) -> void:
    match state:
        State.MOVE_TO_SPOT:
            _move_to_target(delta)
            if position.distance_to(target_position) < ARRIVAL_THRESHOLD:
                _set_state(State.READING)
                reading_timer = 0.0
                print("Visitor arrived at reading spot.")
        State.READING:
            reading_timer += delta
            if reading_timer >= READING_TIME:
                _generate_memory()
                _leave_library()
        State.LEAVING:
            _move_to_target(delta)
            if position.distance_to(target_position) < ARRIVAL_THRESHOLD:
                queue_free()
                if visitor_manager:
                    visitor_manager.notify_visitor_left(self, spot_name)

func _move_to_target(delta: float) -> void:
    var direction = (target_position - position).normalized()
    if position.distance_to(target_position) > ARRIVAL_THRESHOLD:
        velocity = velocity.move_toward(direction * SPEED, ACCELERATION * delta)
    else:
        velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
    move_and_slide()

func _leave_library() -> void:
    _set_state(State.LEAVING)
    target_position = library_room.get_exit_position()
    if state == State.LEAVING:
        print("Visitor leaving library.")

func _set_state(new_state: int) -> void:
    state = new_state
    _update_state_label()

func _update_state_label() -> void:
    if state_label == null:
        return
    match state:
        State.MOVE_TO_SPOT:
            state_label.text = "Entering"
        State.READING:
            state_label.text = "Reading"
        State.LEAVING:
            state_label.text = "Leaving"
        _:
            state_label.text = ""

func _generate_memory() -> void:
    if memory_manager == null:
        return
    var memory = memory_manager.create_memory("Cozy Reading", 1, READING_TIME)
    memory_manager.record_memory(memory)

func _build_visitor_texture() -> Texture2D:
    var image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
    image.fill(Color8(190, 170, 140, 255))
    for x in 16:
        for y in 16:
            if (x + y) % 5 == 0:
                image.set_pixel(x, y, Color8(210, 190, 160, 255))
    return ImageTexture.create_from_image(image)
