extends SceneTree
const Game=preload("res://tests/visual_review/game.gd")
const Art=preload("res://tests/visual_review/care_art.gd")
const OUT:="res://artifacts/visual_review_20261118/"
const CASES:=[ ["dori",2,"clue_rubbing"], ["yune",2,"dream_nights"], ["danming",2,"bee_album"], ["kubby",1,"wisp_watch"], ["yato",1,"mato_truth"], ["fuwa",0,"tenbi_together"] ]
var g
var checks:=0
var failures:=0
var measurements: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(label)
func step(seconds: float) -> void:
	for i in range(ceili(seconds*60)):
		g.background_paused=false;g._process(1.0/60)
func snap(name: String) -> void:
	g.toast_time=0;g.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUT+name+".png")==OK,"saved "+name)
func pair(name: String) -> void:
	var saved: Dictionary=g.state.to_data().duplicate(true)
	g.refined=false;await snap(name+"_before")
	var before: Array=[g.WORLD_SCALE,g.WORLD_OFFSET.x,g.WORLD_OFFSET.y]
	g.refined=true;await snap(name+"_proposal")
	check(g.state.to_data()==saved,"render proposal never mutates progress: "+name)
	measurements.append({"name":name,"before":before,"proposed":[g.WORLD_SCALE,g.WORLD_OFFSET.x,g.WORLD_OFFSET.y]})
func start(id: String,scene: int) -> void:
	# Each staged comparison is an independent scene, not a mid-dialog teleport.
	g.yato_forest.resume([])
	g.state=g.GrowthState.new();g.growth=g.state.growth
	g.state.accept_mission(id)
	if scene>=1: g.state.record_chapter_step(id,0)
	if scene>=2: g.state.mark_first_action(id)
	if scene>=3: g.state.record_chapter_step(id,1)
	g.story_member=g._mission_index_for(id);g._enter_chapter(id)
	g.toast_time=0;g.refined=true
func walk(id: String) -> void:
	var obj: Dictionary=g._find_object(id)
	check(not obj.is_empty(),"target exists: "+id)
	if obj.is_empty(): return
	g._go_to(obj)
	for i in range(1800):
		step(1.0/60)
		if g.pending_object=="": break
	check(g.pending_object=="","target reached: "+id)
func run() -> void:
	root.size=Vector2i(1280,800)
	g=Game.new();g.persist=false;root.add_child(g);g.set_process(false);g.audio_enabled=false
	for entry in CASES:
		start(entry[0],entry[1]);await pair(entry[0]+"_overview")
		if entry[0]=="yato": walk("mato_basket");step(1.7)
		walk(entry[2])
		step(1.9 if entry[0] in ["kubby","yato"] else 1.4 if entry[0]=="yune" else .7)
		await pair(entry[0]+"_focus")
		root.size=Vector2i(960,600)
		await snap(entry[0]+"_focus_960")
		root.size=Vector2i(1280,800)
	# All 24 authored scenes retain an invertible input transform and opaque map coverage.
	for member in g.MEMBERS:
		for scene in range(4):
			start(member.id,scene)
			for p in [g.player_pos,g.Chapters.BOOKS[member.id].points[scene]]:
				var screen: Vector2=p*g.WORLD_SCALE+g.WORLD_OFFSET
				check(((screen-g.WORLD_OFFSET)/g.WORLD_SCALE).distance_to(p)<.001,"input transform roundtrip: "+member.id+str(scene))
			var r: Rect2=Rect2(Vector2(32,140)*g.WORLD_SCALE+g.WORLD_OFFSET,Vector2(904,578)*g.WORLD_SCALE)
			check(r.grow(1).encloses(Rect2(0,0,1280,800)),"map covers camera frame: "+member.id+str(scene))
	# Existing library with authentic care state, all residents and source sprites.
	g.state=g.GrowthState.new();g.growth=g.state.growth;g.mode="play"
	for member in g.MEMBERS:
		g.state.active_mission=member.id;g.state.chapter_steps[member.id]=2;g.state.page_complete=true;g.state.record_chapter_step(member.id,2)
	for task in ["corridor","shelves","reading"]: g.state.complete_reconstruction_task(task)
	g.growth.open_library();g.growth.reward("visual_review",500,250);g.state.minutes=900;g._setup_map()
	g.state.library_day.ensure(g.state.day);g.state.library_day.returned.assign([0,1,0,1,0,1]);g.state.library_day.dirty.assign([0,1]);g.player_pos=Vector2(552,648)
	for i in range(6):
		var npc: Dictionary=g._find_object(g.MEMBERS[i].id)
		npc.pos=[Vector2(500,300),Vector2(680,650),Vector2(824,480),Vector2(890,236),Vector2(1144,552),Vector2(312,592)][i];npc.in_studio=false;npc.facing="down"
	for level in range(1,4):
		g.state.library_day.grime.fill(level);await pair("care_level_%d"%level)
		for i in range(8):
			var im: Image=Art.floor_image(Art.Base.FLOOR_POINTS[i],level,i)
			check(im.get_size()==Art.CELL,"stable native asset cell size")
			for item in Art.fallen_books(Art.Base.FLOOR_POINTS[i],level,i): check(Art.fits(Art.Base.FLOOR_POINTS[i],item.pos,item.frame),"whole book fits floor")
	Art.book_sheet().save_png(OUT+"books_proposal.png")
	Art.Base.book_sheet().save_png(OUT+"books_before.png")
	for level in range(1,4): Art.stain_cell(level,0).save_png(OUT+"stain_%d_proposal.png"%level)
	FileAccess.open(OUT+"camera_review.json",FileAccess.WRITE).store_string(JSON.stringify(measurements,"\t"))
	print("VISUAL PROPOSAL: ",checks," checks; failures=",failures,". Preview-only; saves untouched.")
	g.free();quit(1 if failures else 0)
