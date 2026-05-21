extends Node
class_name MemoryManager

signal memory_changed(total_memory: int)

const MEMORY_DATA = preload("res://scripts/systems/MemoryData.gd")

var memory_log := []
var total_memory := 0
var daily_memory := 0

func create_memory(topic: String, value: int, duration: float) -> Resource:
    var memory = MEMORY_DATA.new()
    memory.topic = topic
    memory.value = value
    memory.duration = duration
    memory.timestamp = Time.get_ticks_msec() / 1000.0
    return memory

func record_memory(memory: Resource) -> void:
    memory_log.append(memory)
    total_memory += memory.value
    daily_memory += memory.value
    emit_signal("memory_changed", total_memory)
    print("[MemoryManager] Memory gained:", memory.topic, "value=", memory.value, "duration=", memory.duration, "total=", total_memory)

func get_total_memory() -> int:
    return total_memory

func get_daily_memory() -> int:
    return daily_memory

func reset_daily_memory() -> void:
    daily_memory = 0
