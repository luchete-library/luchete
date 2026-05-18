extends Node2D

const CELL_SIZE = Vector2(32, 32)
const ROOM_WIDTH = 14
const ROOM_HEIGHT = 10
const ENTRANCE_POSITION = Vector2(CELL_SIZE.x * 1.5, CELL_SIZE.y * 5)
const EXIT_POSITION = Vector2(-CELL_SIZE.x * 1.5, CELL_SIZE.y * 5)
const READING_SPOTS = {
    "SpotA": Vector2(5, 3) * CELL_SIZE,
    "SpotB": Vector2(9, 3) * CELL_SIZE,
    "SpotC": Vector2(5, 6) * CELL_SIZE,
    "SpotD": Vector2(9, 6) * CELL_SIZE
}

var reading_spot_state := {}

func _ready() -> void:
    var tile_map = _create_floor_map()
    add_child(tile_map)
    _build_walls()
    _create_reading_spots()
    _initialize_spot_state()

func _initialize_spot_state() -> void:
    for spot_name in READING_SPOTS.keys():
        reading_spot_state[spot_name] = false

func get_entrance_position() -> Vector2:
    return ENTRANCE_POSITION

func get_exit_position() -> Vector2:
    return EXIT_POSITION

func claim_reading_spot() -> String:
    for spot_name in READING_SPOTS.keys():
        if not reading_spot_state[spot_name]:
            reading_spot_state[spot_name] = true
            return spot_name
    return ""

func release_reading_spot(spot_name: String) -> void:
    if reading_spot_state.has(spot_name):
        reading_spot_state[spot_name] = false

func get_reading_spot_position(spot_name: String) -> Vector2:
    if READING_SPOTS.has(spot_name):
        return READING_SPOTS[spot_name]
    return Vector2.ZERO

func _create_floor_map() -> TileMap:
    var tile_set = TileSet.new()
    tile_set.create_tile(0)
    tile_set.tile_set_texture(0, _build_floor_texture())
    tile_set.tile_set_region(0, Rect2(Vector2.ZERO, Vector2(16, 16)))
    tile_set.tile_set_name(0, "Floor")

    var tile_map = TileMap.new()
    tile_map.tile_set = tile_set
    tile_map.cell_size = CELL_SIZE
    tile_map.z_index = -1
    for x in ROOM_WIDTH:
        for y in ROOM_HEIGHT:
            tile_map.set_cell_item(x, y, 0)
    return tile_map

func _build_floor_texture() -> Texture2D:
    var image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
    image.lock()
    image.fill(Color8(180, 156, 112, 255))
    for x in 16:
        for y in 16:
            if (x + y) % 3 == 0:
                image.set_pixel(x, y, Color8(199, 170, 128, 255))
    image.unlock()
    return ImageTexture.create_from_image(image, 0)

func _build_walls() -> void:
    _add_wall(Rect2(Vector2.ZERO, Vector2(ROOM_WIDTH * CELL_SIZE.x, CELL_SIZE.y)))
    _add_wall(Rect2(Vector2(0, (ROOM_HEIGHT - 1) * CELL_SIZE.y), Vector2(ROOM_WIDTH * CELL_SIZE.x, CELL_SIZE.y)))
    _add_wall(Rect2(Vector2.ZERO, Vector2(CELL_SIZE.x, ROOM_HEIGHT * CELL_SIZE.y)))
    _add_wall(Rect2(Vector2((ROOM_WIDTH - 1) * CELL_SIZE.x, 0), Vector2(CELL_SIZE.x, ROOM_HEIGHT * CELL_SIZE.y)))

func _add_wall(rect: Rect2) -> void:
    var wall = StaticBody2D.new()
    var collision_shape = CollisionShape2D.new()
    var shape = RectangleShape2D.new()
    shape.size = rect.size
    collision_shape.shape = shape
    wall.position = rect.position + rect.size * 0.5
    wall.add_child(collision_shape)
    add_child(wall)

func _create_reading_spots() -> void:
    for spot_name in READING_SPOTS.keys():
        var marker = Marker2D.new()
        marker.name = spot_name
        marker.position = READING_SPOTS[spot_name]
        add_child(marker)
