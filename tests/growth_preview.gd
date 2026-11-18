extends SceneTree
const Game=preload("res://scripts/growth_game.gd")
func _initialize() -> void:
	call_deferred("begin")
func begin() -> void:
	var game=Game.new()
	game.preview_mode=true
	root.add_child(game)
