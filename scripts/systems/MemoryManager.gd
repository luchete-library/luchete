extends Node
class_name MemoryManager

signal memory_changed(total_memory: int)

var memory_log := []
var total_memory := 0

func create_memory(topic: String, value: int, duration: float) -> MemoryData:
    var memory = MemoryData.new()
    memory.topic = topic
    memory.value = value
    memory.duration = duration
    memory.timestamp = Engine.get_time_since_startup()
    return memory

func record_memory(memory: MemoryData) -> void:
    memory_log.append(memory)
    total_memory += memory.value
    emit_signal("memory_changed", total_memory)
    print("[MemoryManager] Memory gained:", memory.topic, "value=", memory.value, "duration=", memory.duration, "total=", total_memory)

func get_total_memory() -> int:
    return total_memory
