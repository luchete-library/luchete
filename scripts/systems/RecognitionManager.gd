extends Node
class_name RecognitionManager

signal recognition_changed(total_recognition: int)

const MEMORY_THRESHOLD = 3
const RECOGNITION_GAIN = 1

var total_recognition := 0

func get_total_recognition() -> int:
    return total_recognition

func apply_daily_memory(daily_memory: int) -> void:
    if daily_memory < MEMORY_THRESHOLD:
        return
    total_recognition += RECOGNITION_GAIN
    emit_signal("recognition_changed", total_recognition)
    print("[RecognitionManager] Recognition increased: +%d total=%d" % [RECOGNITION_GAIN, total_recognition])
