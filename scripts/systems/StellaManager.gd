extends Node
class_name StellaManager

signal stella_unlocked(stella_name: String)

const STELLA_YATO = {
    "id": "yato",
    "name": "야토",
    "required_recognition": 5
}

var unlocked_stellas := {}

func _init() -> void:
    unlocked_stellas[STELLA_YATO["id"]] = false

func update_recognition(total_recognition: int) -> void:
    if unlocked_stellas.get(STELLA_YATO["id"], false):
        return
    if total_recognition < STELLA_YATO["required_recognition"]:
        return
    unlocked_stellas[STELLA_YATO["id"]] = true
    print("Stella unlocked: %s" % STELLA_YATO["name"])
    emit_signal("stella_unlocked", STELLA_YATO["name"])
