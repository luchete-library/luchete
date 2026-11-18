extends SceneTree
const OUT := "res://artifacts/polish_20261118/"
class ReviewGame:
	extends "res://scripts/growth_game.gd"
	func _save() -> void: pass
var g: Node2D
var checks := 0
var failures := 0
var compared := 0
var mismatches := 0
var report: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func frame() -> void:
	g.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
func run() -> void:
	g=ReviewGame.new()
	g.persist=false
	g.save_path=OUT+"no_user_save.json"
	g.legacy_save_path=OUT+"no_legacy_save.json"
	root.add_child(g)
	await process_frame
	g.set_process(false)
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
	g.toast_time=0
	root.size=Vector2i(960,600)
	for member in g.MEMBERS:
		g.character_touch.reset()
		g.character_touch.react(g,member.id)
		check(g.character_touch.reactions.has(member.id),"live authored reaction starts: "+member.id)
		var reaction: Dictionary=g.character_touch.reactions[member.id]
		var item: Dictionary=g.StellaInteractions.definition(member.id,reaction.id)
		var texture: Texture2D=g.StellaInteractions.sheet_for(member.id,g._costume_key(member.id))
		var source: Image=texture.get_image()
		for elapsed in [.1,.4,.78,1.15]:
			reaction.elapsed=minf(elapsed,reaction.duration-.05)
			await frame()
			var sample: Dictionary=g.character_focus.last_sample
			var expected: int=g.StellaInteractions.Samples.gesture(item.durations,reaction.elapsed,item.get("travel_seconds",[]))
			check(sample.column==expected and sample.row==int(item.row),"focus reads current room cel, never neutral substitute")
			var zoom: int=sample.physical_pixel_scale
			check(zoom>=1,"compact expression lens uses an integer native pixel scale")
			var image := root.get_texture().get_image()
			var src: Rect2=sample.source
			var dst: Rect2=sample.destination
			var physical: Vector2=(dst.position*.75).round()
			check((dst.size*.75).is_equal_approx(src.size*zoom),"expression dimensions use the same scale on both axes")
			var frame_mismatch := 0
			var frame_compared := 0
			for x in range(int(src.size.x)):
				for y in range(int(src.size.y)):
					var pixel := source.get_pixel(int(src.position.x)+x,int(src.position.y)+y)
					if pixel.a<.999: continue
					for dx in range(zoom):
						for dy in range(zoom):
							var actual := image.get_pixel(int(physical.x)+x*zoom+dx,int(physical.y)+y*zoom+dy)
							if absf(actual.r-pixel.r)>.008 or absf(actual.g-pixel.g)>.008 or absf(actual.b-pixel.b)>.008: frame_mismatch+=1
							frame_compared+=1
			compared+=frame_compared
			mismatches+=frame_mismatch
			check(frame_mismatch==0,"opaque output pixels match the current original sprite exactly")
			var lens_area: Rect2=Rect2(1038,588,224,145) if g.world_map_active() else g.character_focus.AREA
			for button in g.buttons:
				if lens_area.intersects(button.rect): check(button.id=="growth_archive","no hidden map action leaks through the current expression lens")
			report.append({"member":member.id,"action":reaction.id,"elapsed":reaction.elapsed,"column":expected,"pixel_scale":sample.physical_pixel_scale,"opaque_pixels":frame_compared,"mismatches":frame_mismatch})
			if elapsed==.78: image.save_png(OUT+"expression_exact_"+member.id+"_960.png")
		g.character_touch.update(g,10)
		await frame()
		check(g.character_focus.last_sample.is_empty(),"focus closes when its actual reaction ends")
	FileAccess.open(OUT+"expression_pixel_match.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"compared_pixels":compared,"mismatches":mismatches,"samples":report},"\t"))
	print("POLISH EXPRESSION: ",checks," checks, ",failures," failures; ",compared," opaque output pixels compared, ",mismatches," mismatches. Six original cels x four animation times at 960px.")
	quit(1 if failures else 0)
