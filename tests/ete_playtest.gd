extends SceneTree

# Interactive sandbox for the player; this window deliberately never saves.
class InteractiveGame:
	extends "res://scripts/main.gd"
	func _save() -> void: pass
	func _action(id: String) -> void:
		if id in ["new","new_confirm","continue"]:
			prepare_test()
			return
		if id=="save":
			_notify("체험 모드에서는 진행 상황을 저장하지 않아요.")
			return
		super._action(id)
	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and event.physical_keycode==KEY_F9:
			prepare_test()
			return
		if event is InputEventKey and event.pressed and event.physical_keycode==KEY_F5:
			_notify("체험 모드에서는 진행 상황을 저장하지 않아요.")
			return
		super._unhandled_input(event)
	func prepare_test() -> void:
		state=State.new()
		state.residents=["yato","danming","kubby","yune","dori","fuwa"]
		for id in state.residents: state.chapter_steps[id]=3
		state.wear_fan_form("dori")
		for i in range(Furniture.ORDER.size()):
			state.place_furniture(Furniture.ORDER[i],Furniture.DEFAULTS[i])
		mode="play"
		comic_started=-1.0
		replay_progress=null
		save_available=false
		player_pos=AETHE_POS+Vector2(0,75)
		_setup_map()
		_notify("지금은 돌돌이! 도리의 방에 인사해 보세요.   ·   에테 곁에서 E → F로 다른 팬 모습 선택")

func _initialize() -> void: call_deferred("run")

func run() -> void:
	root.size=Vector2i(1280,800)
	root.title="루체테 도서관 · 재개관 교류 체험"
	var game := InteractiveGame.new()
	root.add_child(game)
	game.prepare_test()
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png("res://artifacts/ete_playtest_ready.png")
	print("ETE_PLAYTEST_READY screenshot=",result,". Interactive window remains open; player save untouched.")
