extends SceneTree

const OUT := "res://artifacts/comic_smooth_20261117/"
class ReviewGame:
	extends "res://scripts/growth_game.gd"
	var drawn_lines: Array=[]
	func _save() -> void: pass
	func _draw() -> void:
		drawn_lines.clear()
		super._draw()
	func _text(pos: Vector2,value: String,size: int=18,color: Color=CREAM) -> void:
		drawn_lines.append({"pos":pos,"text":value,"size":size})
		super._text(pos,value,size,color)

var g: Node2D
var failures:=0
var checks:=0
var measured: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(label)
func frame() -> void:
	g.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
func snap(name: String) -> void:
	await frame()
	root.get_texture().get_image().save_png(OUT+name+".png")
func key(code: int) -> void:
	var event:=InputEventKey.new()
	event.physical_keycode=code;event.pressed=true
	g._unhandled_input(event)
func click(id: String) -> bool:
	await frame()
	for b in g.buttons:
		if b.id==id:
			var event:=InputEventMouseButton.new()
			event.position=b.rect.get_center();event.pressed=true;event.button_index=MOUSE_BUTTON_LEFT
			g._unhandled_input(event)
			return true
	return false
func advance(seconds: float) -> void:
	g.background_paused=false
	g._process(seconds)
func run() -> void:
	g=ReviewGame.new();g.persist=false
	g.save_path=OUT+"never_saved.json";g.legacy_save_path=OUT+"no_legacy.json"
	root.add_child(g)
	await process_frame
	g.set_process(false);g.audio_enabled=false
	for member in g.MEMBERS: g.state.residents.append(member.id);g.state.chapter_steps[member.id]=3
	g.growth.begin_rebuild(6)
	for task in ["corridor","shelves","reading"]: g.state.complete_reconstruction_task(task)
	g.growth.open_library();g.state.operating.ensure(g.state)
	g._setup_map()
	g.clock=0;g.mode="story";g.story_member=0;g.story_page=0
	g._action("comic_play");key(KEY_4)
	check(g.comic_started>=0 and g.Comics.sample(g.MEMBERS[0].id,g.comic_player.elapsed(g))==Vector2i(3,0),"early cut seeking keeps reader open at clock zero")
	key(KEY_SPACE);key(KEY_SPACE)
	check(g.comic_started>=0,"early pause/resume never uses a negative open timestamp")
	var opening_page: int=g.story_page
	g.buttons.append({"rect":Rect2(0,0,1280,800),"id":"story_next"})
	var stale_click:=InputEventMouseButton.new()
	stale_click.position=Vector2(200,200);stale_click.pressed=true;stale_click.button_index=MOUSE_BUTTON_LEFT
	g._unhandled_input(stale_click)
	check(g.mode=="story" and g.story_page==opening_page,"opening reader consumes stale underlying story buttons")
	for index in range(g.MEMBERS.size()):
		var id: String=g.MEMBERS[index].id
		g.story_member=index;g.mode="story";g.story_page=0;g.story_sources=false
		g._action("comic_play")
		var saved: Dictionary=g.state.to_data()
		advance(.6)
		key(KEY_SPACE)
		var paused_at: float=g.comic_player.elapsed(g)
		advance(12)
		check(g.comic_player.paused and is_equal_approx(paused_at,g.comic_player.elapsed(g)),id+" Space holds the exact animation time")
		check(g.comic_started>=0 and g.mode=="story",id+" pause does not close the book")
		key(KEY_SPACE);advance(.2)
		check(g.comic_player.elapsed(g)>paused_at,id+" resume continues instead of restarting")
		for cut in range(4):
			key(KEY_1+cut)
			check(g.Comics.sample(id,g.comic_player.elapsed(g))==Vector2i(cut,0),id+" number key selects cut "+str(cut))
			advance(10)
			check(g.comic_player.paused and g.Comics.sample(id,g.comic_player.elapsed(g))==Vector2i(cut,g.Comics.FRAMES-1),id+" selected cut holds its final frame")
			check(await click("comic_cut_%d"%cut),id+" actual panel click selects cut")
			check(not g.comic_player.paused and g.Comics.sample(id,g.comic_player.elapsed(g))==Vector2i(cut,0),id+" panel click replays just this cut")
		key(KEY_LEFT)
		check(g.Comics.sample(id,g.comic_player.elapsed(g)).x==2,id+" left selects previous")
		key(KEY_RIGHT)
		check(g.Comics.sample(id,g.comic_player.elapsed(g)).x==3,id+" right selects next")
		check(await click("comic_zoom") and g.comic_player.enlarged,id+" zoom button toggles focused view")
		key(KEY_Z)
		check(not g.comic_player.enlarged,id+" Z returns to four panels")
		key(KEY_V);advance(g.Comics.duration(id)+.2)
		check(g.comic_player.paused and g.Comics.sample(id,g.comic_player.elapsed(g))==Vector2i(3,g.Comics.FRAMES-1),id+" full replay holds final page")
		check(g.state.to_data()==saved,id+" all reader controls preserve operating and story save data")
		for size in [Vector2i(960,600),Vector2i(1280,800),Vector2i(1280,720),Vector2i(1920,1080)]:
			root.size=size
			await frame()
			var plan: Dictionary=g.Comics.layout(g)
			check(plan.factor>=2,id+" four cuts retain at least two physical pixels per original pixel")
			for box in plan.boxes:
				var ui: Rect2=g.Comics.ui_rect(box,plan)
				var physical: Rect2=g.get_viewport().get_final_transform()*ui
				check(physical.position.is_equal_approx(physical.position.round()),id+" art begins at whole physical pixels")
				check(physical.size.is_equal_approx(Vector2(228,110)*plan.factor),id+" art uses one uniform integer scale")
				check(Rect2(Vector2.ZERO,Vector2(size)).encloses(physical),id+" art stays inside window")
			var caption_overflow:=false
			var caption_size: int=maxi(1,roundi((13 if plan.compact else 16)/plan.scale))
			for full_caption in g.Comics.PROFILES.data[id].captions:
				for paragraph in full_caption.split("\n"):
					var physical_width: float=g.font.get_string_size(paragraph,HORIZONTAL_ALIGNMENT_LEFT,-1,caption_size).x*plan.scale
					caption_overflow=caption_overflow or physical_width>plan.boxes[0].size.x-38
			check(not caption_overflow,id+" all four captions fit their panels")
			if size.x==960 or size==Vector2i(1280,800): await snap(id+"_four_"+str(size.x))
			measured.append({"member":id,"window":[size.x,size.y],"physical_scale":plan.factor})
		root.size=Vector2i(960,600)
		key(KEY_Z)
		await snap(id+"_focus_960")
		check(g.Comics.layout(g).factor>=3,id+" focused view uses larger integer scale")
		check(await click("comic_close") and g.comic_started<0,id+" close button returns to same story page")
		check(g.mode=="story" and g.state.to_data()==saved,id+" close preserves story and day")
	# Even if opened from a live map, inspection never advances the operating day.
	g.mode="play";g.comic_started=g.clock;g.comic_player.reset()
	var minutes: int=g.state.minutes
	advance(16)
	check(g.state.minutes==minutes,"comic pauses live library operating clock")
	key(KEY_ESCAPE)
	check(g.comic_started<0 and g.mode=="play","Esc closes comic without changing underlying mode")
	g.mode="rescue";g._action("comic_play")
	var rescued_state: Dictionary=g.state.to_data()
	key(KEY_E)
	check(g.comic_started<0 and g.mode=="rescue" and g.state.to_data()==rescued_state,"E closes only comic without also recruiting or returning from rescue")
	check(g.buttons.is_empty(),"closing clears obsolete reader button targets until redraw")
	FileAccess.open(OUT+"reader_layout.json",FileAccess.WRITE).store_string(JSON.stringify(measured,"\t"))
	print("COMIC READER: ",checks," checks; ",failures," failures; six books, physical integer pixels, 4 windows, actual mouse/key controls, saves untouched.")
	g.free();quit(1 if failures else 0)
