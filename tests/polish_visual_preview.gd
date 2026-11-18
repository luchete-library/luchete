extends SceneTree
const OUT := "res://artifacts/polish_20261118/"
class PreviewGame:
	extends "res://scripts/growth_game.gd"
	func _save() -> void: pass
var g: Node2D
func _initialize() -> void: call_deferred("run")
func capture(label: String) -> void:
	g.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+label+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	g=PreviewGame.new()
	g.persist=false
	g.save_path=OUT+"no_user_save.json"
	g.legacy_save_path=OUT+"no_legacy_save.json"
	root.add_child(g)
	await process_frame
	g.set_process(false)
	g.audio_enabled=false
	g._new_game()
	while g.mode=="dialog": g._action("next")
	for member in g.MEMBERS:
		g.state.residents.append(member.id)
		g.state.chapter_steps[member.id]=3
	g.growth.begin_rebuild(6)
	for task in ["corridor","shelves","reading"]: g.state.complete_reconstruction_task(task)
	g._action("growth_open")
	g.mode="play"
	g._setup_map()
	g.growth.memory_light=100
	g.growth.gold=500
	g.toast_time=0
	g.clock=2.1
	root.size=Vector2i(960,600)
	g.mode="growth_shop"
	g.shop_tab="furniture"
	g.shop_preview.selected.furniture="tea"
	g.shop_preview.member_index=3
	await capture("01_shop_furniture_960")
	g.shop_tab="costume"
	g.shop_preview.selected.costume="danming_racing"
	await capture("02_shop_costume_960")
	g.mode="play"
	g.character_touch.react(g,"fuwa")
	g.character_touch.update(g,.78)
	await capture("03_live_expression_960")
	g.character_touch.reset()
	g.growth.memory_light=0
	await capture("04_growth_stage1_960")
	g.growth.memory_light=250
	await capture("05_growth_stage4_960")
	var visitor: Dictionary=g.state.ink_visits._guest(0,"read","dori","")
	visitor.phase="record"
	visitor.pos=g.navigation.get_point_position(g._grid_at(g.GrowthDecor.RECORD_POINT))
	visitor.elapsed=1.3
	visitor.facing="up"
	g.state.ink_visits.guests.append(visitor)
	await capture("06_memory_record_960")
	print("POLISH VISUAL PREVIEW: generated six real game captures; no saves written.")
	quit()
