extends CharacterBody2D

const SPEED = 120.0
const ACCELERATION = 640.0
const FRICTION = 900.0

@onready var sprite = $Sprite2D

func _ready() -> void:
    sprite.texture = _build_player_texture()

func _physics_process(delta: float) -> void:
    var direction = Vector2(
        int(Input.is_key_pressed(KEY_D)) - int(Input.is_key_pressed(KEY_A)),
        int(Input.is_key_pressed(KEY_S)) - int(Input.is_key_pressed(KEY_W))
    )
    if direction != Vector2.ZERO:
        direction = direction.normalized()
        velocity = velocity.move_toward(direction * SPEED, ACCELERATION * delta)
    else:
        velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)

    move_and_slide()

func _build_player_texture() -> Texture2D:
    var image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
    image.fill(Color8(80, 100, 170, 255))
    for x in 16:
        for y in 16:
            if (x + y) % 4 == 0:
                image.set_pixel(x, y, Color8(90, 110, 180, 255))
    return ImageTexture.create_from_image(image)
