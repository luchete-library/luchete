extends SceneTree
const Book=preload("res://scripts/stella_adventure/game.gd")
const Fuwa=preload("res://scripts/fuwa_adventure/campaign.gd")
const OUT="res://artifacts/tester_feedback_20261119/"
var book
func _initialize() -> void: call_deferred("run")
func shot(name: String) -> void:
	book.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png")
func run() -> void:
	root.content_scale_size=Vector2i(1280,800)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_KEEP
	for spec in [["danming",0],["dori",1],["yune",1],["kubby",1],["yato",1],["fuwa",0]]:
		book=Fuwa.new() if spec[0]=="fuwa" else Book.new()
		if spec[0]!="fuwa": book.member=spec[0]
		root.add_child(book);book.set_process(false);book.pause_on_focus_loss=false
		if spec[0]!="fuwa": book.enter_stage(spec[1]);book.intro=false
		book.notice_left=0;root.min_size=Vector2i(320,200);root.size=Vector2i(1280,800)
		await shot(spec[0]+"_applied")
		root.size=Vector2i(844,390);await shot(spec[0]+"_applied_small")
		if spec[0]=="fuwa":
			book.start_return_preview();await shot("fuwa_spell_applied_small")
		elif spec[0]=="danming":
			book.enter_stage(1);book.intro=false;book.done=3;book.player_pos=book.target(0)
			await shot("danming_arrow_partial_applied_small")
		book.free()
	print("STORY MARKER VISUALS: six production scenes and compact views")
	quit()
