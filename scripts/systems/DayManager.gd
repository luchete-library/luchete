extends Node
class_name DayManager

signal day_changed(current_day: int)
signal day_ending(current_day: int)

var current_day := 1

func get_current_day() -> int:
    return current_day

func advance_day() -> void:
    emit_signal("day_ending", current_day)
    current_day += 1
    emit_signal("day_changed", current_day)
    print("[DayManager] Day advanced: Day ", current_day)
