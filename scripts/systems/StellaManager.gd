extends Node
class_name StellaManager

signal stella_unlocked(stella_id: String, stella_name: String)

const STELLA_YATO_ID = "yato"
const STELLA_DEFINITIONS = {
    STELLA_YATO_ID: {
    "id": "yato",
    "display_name": "야토",
    "required_recognition": 5,
    "scene_path": "res://scenes/stella/Yato.tscn",
    "spawn_position": Vector2(288, 192),
    "unlocked": false
    }
}

var stella_data := {}

func _init() -> void:
    for stella_id in STELLA_DEFINITIONS.keys():
        stella_data[stella_id] = STELLA_DEFINITIONS[stella_id].duplicate(true)

func get_unlocked_stella_display_name() -> String:
    for stella in stella_data.values():
        if stella["unlocked"]:
            return stella["display_name"]
    return "없음"

func get_stella_data(stella_id: String) -> Dictionary:
    if not stella_data.has(stella_id):
        return {}
    return stella_data[stella_id]

func update_recognition(total_recognition: int) -> void:
    for stella_id in stella_data.keys():
        var stella = stella_data[stella_id]
        if stella["unlocked"]:
            continue
        if total_recognition < stella["required_recognition"]:
            continue
        stella["unlocked"] = true
        print("Stella unlocked: %s" % stella["display_name"])
        emit_signal("stella_unlocked", stella["id"], stella["display_name"])
