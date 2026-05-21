extends CharacterBody2D
class_name Yato

const BODY_SIZE = Vector2(18, 24)
const BODY_COLOR = Color8(116, 148, 214, 255)
const BODY_HIGHLIGHT_COLOR = Color8(145, 174, 232, 255)

@onready var sprite = $Sprite2D
@onready var name_label = $NameLabel
@onready var interaction_area = $InteractionArea
@onready var hint_label = $HintLabel

func _ready() -> void:
    sprite.texture = _build_placeholder_texture()
    name_label.text = "야토"
    hint_label.visible = false
    interaction_area.body_entered.connect(_on_interaction_area_body_entered)
    interaction_area.body_exited.connect(_on_interaction_area_body_exited)

func _on_interaction_area_body_entered(body: Node) -> void:
    if body.name == "Player":
        hint_label.visible = true

func _on_interaction_area_body_exited(body: Node) -> void:
    if body.name == "Player":
        hint_label.visible = false

func _build_placeholder_texture() -> Texture2D:
    var image = Image.create(int(BODY_SIZE.x), int(BODY_SIZE.y), false, Image.FORMAT_RGBA8)
    image.fill(BODY_COLOR)
    for x in int(BODY_SIZE.x):
        image.set_pixel(x, 0, BODY_HIGHLIGHT_COLOR)
    return ImageTexture.create_from_image(image)
