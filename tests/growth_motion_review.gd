extends SceneTree
const Game=preload("res://scripts/growth_game.gd")
const OUT="res://artifacts/growth_20261116/"
var g=Game.new()
func _initialize() -> void: call_deferred("run")
func run() -> void:
	g.preview_mode=true
	g.persist=false
	root.add_child(g)
	await process_frame
	g.set_process(false)
	g.toast_time=0
	g._start_work("corridor")
	for i in range(96):
		g.work_elapsed=6.3+i/24.0
		g.clock=i/24.0
		g.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+"carry_%03d.png"%i)
	print("CARRY_REVIEW_24_FPS_COMPLETE")
	quit()
