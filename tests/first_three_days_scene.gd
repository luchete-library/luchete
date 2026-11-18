extends Node

const Review = preload("res://tests/first_three_days_manual.gd")
const OUT := "res://artifacts/first_three_days_20261117/"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	FileAccess.open(OUT+".gdignore",FileAccess.WRITE).store_string("")
	var window:=get_window()
	window.mode=Window.MODE_WINDOWED
	window.borderless=false
	window.size=Vector2i(1280,800)
	window.position=Vector2i(100,100)
	var game:=Review.ManualGame.new()
	add_child(game)
	window.mode=Window.MODE_WINDOWED
	window.size=Vector2i(1280,800)
	window.position=Vector2i(100,100)
	window.show()
	window.grab_focus()
	game.record("window_ready",{"entry":"normal_scene","visible":window.visible,
		"display_server":DisplayServer.get_name(),"size":[window.size.x,window.size.y],
		"position":[window.position.x,window.position.y]})
