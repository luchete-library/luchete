extends SceneTree
const Game=preload("res://scripts/growth_game.gd")
const Driver=preload("res://tests/stella_play_driver.gd")
const OUT="res://artifacts/stella_adventures_20261118/"
var g
func _initialize() -> void: call_deferred("run")
func shot(label: String) -> void:
	g.queue_redraw();g.stella_book.queue_redraw()
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+label+".png")
func run() -> void:
	root.size=Vector2i(1280,800)
	for member in ["dori","yune","danming","kubby","yato"]:
		g=Game.new();g.persist=false;root.add_child(g);g.set_process(false);g.audio_enabled=false;g.background_paused=false
		g.mode="missions";g.mission_index=g._mission_index_for(member);g._take_mission();g._turn_story()
		var b=g.stella_book;b.pause_on_focus_loss=false
		Driver.play_stage(g)
		if b.intro: Driver.press(g)
		match member:
			"dori":
				Driver.walk(g,b.target(0));Driver.step(g,1.2);await shot("dori_stone_watch")
				Driver.step(g,1.5);Driver.press(g);Driver.walk(g,b.target(1));Driver.step(g,2.7);Driver.press(g);Driver.step(g,.1)
				Driver.play_stage(g);Driver.press(g);Driver.step(g,4.1);await shot("dori_ete_carry")
			"yune":
				Driver.walk(g,b.target(0));Driver.key(g,KEY_E);Driver.step(g,.8);await shot("yune_eating_nightmare")
				Driver.key(g,KEY_E,false);b.facing="down"
			"danming":
				Driver.walk(g,b.target(0));Driver.key(g,KEY_E);Driver.step(g,.5);await shot("danming_workbench_action")
				Driver.key(g,KEY_E,false)
				var pointer:=InputEventMouseButton.new();pointer.pressed=true;pointer.button_index=MOUSE_BUTTON_LEFT;pointer.position=b.screen_world(Vector2(400,285));g._unhandled_input(pointer)
				for i in range(35):
					var motion:=InputEventMouseMotion.new();motion.position=b.screen_world(Vector2(400+i%2*80,285));g._unhandled_input(motion)
				pointer.pressed=false;g._unhandled_input(pointer);await shot("danming_drag_polished")
			"kubby":
				Driver.walk(g,b.target(0));Driver.step(g,.5);await shot("kubby_hamster_flinch")
				Driver.step(g,1.5);Driver.play_stage(g);Driver.press(g);Driver.step(g,3.5);await shot("kubby_wisp_transformation")
			"yato":
				Driver.walk(g,b.target(0));Driver.step(g,2);Driver.walk(g,b.target(1));Driver.press(g);Driver.step(g,1.4);await shot("yato_family_confession")
		root.size=Vector2i(960,600);await shot(member+"_action_960");root.size=Vector2i(1280,800)
		g.free()
	print("STELLA VISUALS: captured native action frames and 960px checks")
	quit()
