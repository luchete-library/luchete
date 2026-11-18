extends RefCounted

# The fan is the player's role in a memory, not a new canonical witness.
# Reuse the same recognizable mascot inside and outside the book.
const Fans = preload("res://scripts/fan_forms.gd")

static func draw(g, id: String, pos: Vector2, walking: bool, _accent: Color) -> void:
	Fans.draw(g,id,pos,walking)
