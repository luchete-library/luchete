extends CharacterBody2D

const SPEED = 120.0
const ACCELERATION = 640.0
const FRICTION = 900.0
var velocity = Vector2.ZERO

@onready var sprite = $Sprite2D

func _ready() -> void:
    sprite.texture = _build_player_texture()

func _physics_process(delta: float) -> void:
    var direction = Vector2(
        int(Input.is_key_pressed(Key.D)) - int(Input.is_key_pressed(Key.A)),
        int(Input.is_key_pressed(Key.S)) - int(Input.is_key_pressed(Key.W))
    )
    if direction != Vector2.ZERO:
        direction = direction.normalized()
        velocity = velocity.move_toward(direction * SPEED, ACCELERATION * delta)
    else:
        velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)

    velocity = move_and_slide(velocity)

func _build_player_texture() -> Texture2D:
    var image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
    image.lock()
    image.fill(Color8(80, 100, 170, 255))
    for x in 16:
        for y in 16:
            if (x + y) % 4 == 0:
                image.set_pixel(x, y, Color8(90, 110, 180, 255))
    image.unlock()
    return ImageTexture.create_from_image(image, 0)
