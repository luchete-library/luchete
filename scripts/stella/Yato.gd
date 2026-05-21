extends CharacterBody2D
class_name Yato

const BODY_SIZE = Vector2(18, 24)
const BODY_COLOR = Color8(116, 148, 214, 255)
const BODY_HIGHLIGHT_COLOR = Color8(145, 174, 232, 255)

@onready var sprite = $Sprite2D
@onready var name_label = $NameLabel

func _ready() -> void:
    sprite.texture = _build_placeholder_texture()
    name_label.text = "야토"

func _build_placeholder_texture() -> Texture2D:
    var image = Image.create(int(BODY_SIZE.x), int(BODY_SIZE.y), false, Image.FORMAT_RGBA8)
    image.fill(BODY_COLOR)
    for x in int(BODY_SIZE.x):
        image.set_pixel(x, 0, BODY_HIGHLIGHT_COLOR)
    return ImageTexture.create_from_image(image)
