extends SceneTree

const OUT="res://artifacts/ui_fix_20261117/"
class CaptureGame:
	extends "res://scripts/growth_game.gd"
	var drawn_text: Array[String]=[]
	func _save() -> void: pass
	func _draw() -> void:
		drawn_text.clear()
		super._draw()
	func _text(pos: Vector2,value: String,size: int=18,color: Color=CREAM) -> void:
		drawn_text.append(value)
		super._text(pos,value,size,color)

var g: Node2D
var checks:=0
var failures:=0
var metadata: Dictionary={"viewport":[960,600],"members":[],"captures":[]}
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func frame() -> void:
	g.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
func capture(label: String) -> void:
	await frame()
	var image:=root.get_texture().get_image()
	check(image.get_size()==Vector2i(960,600),"native capture is the minimum window size")
	check(image.save_png(OUT+label+".png")==OK,"save screenshot "+label)
	metadata.captures.append(label)
func click_member(id: String) -> void:
	var npc: Dictionary=g._find_object(id)
	check(npc.get("in_studio",false),"click target is at home: "+id)
	var rect: Rect2=g.Field.stella_hit_rect(g._costume_key(id),npc.pos)
	var point: Vector2=rect.get_center()*g.WORLD_SCALE+g.WORLD_OFFSET
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		event.position=point
		g._unhandled_input(event)
	check(g.character_touch.reactions.has(id),"real pointer click starts authored room reaction: "+id)
func reaction_row() -> Array:
	var result: Array=[]
	for member in g.MEMBERS:
		var reaction: Dictionary=g.character_touch.reactions.get(member.id,{})
		var item: Dictionary=g.StellaInteractions.definition(member.id,reaction.get("id",""))
		result.append({"member":member.id,"id":reaction.get("id",""),"label":item.get("label",""),"elapsed":reaction.get("elapsed",0),"column":g.StellaInteractions.Samples.gesture(item.durations,reaction.elapsed,item.get("travel_seconds",[]))})
	return result
func run() -> void:
	seed(27117)
	g=CaptureGame.new()
	g.persist=false
	g.save_path=OUT+"no_player_save.json"
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
	g._action("close")
	g._setup_map()
	g.state.day=29
	g.toast_time=0
	g.clock=10.5
	root.size=Vector2i(960,600)
	await capture("small_01_neutral")
	for member in g.MEMBERS:
		var npc: Dictionary=g._find_object(member.id)
		var p: Vector2=npc.pos*g.WORLD_SCALE+g.WORLD_OFFSET
		var key: String=g._costume_key(member.id)
		var source: Dictionary=g.Field.FACE_REGIONS.data[key]
		var eyes: Array=source.eyes
		var source_eye:=Vector2(16+float(eyes[0][0]+eyes[1][0])*.5,14+float(eyes[0][1]+eyes[1][1])*.5)
		var eye: Vector2=p+(source_eye-g.Field.FOOT)*g.Field.STELLA_SCALE*g.WORLD_SCALE
		metadata.members.append({"id":member.id,"name":member.short,"costume":key,"eye":(eye*.75),"feet":p*.75})
	for member in g.MEMBERS: await click_member(member.id)
	g.character_touch.update(g,.78)
	metadata.first_reactions=reaction_row()
	await capture("small_02_first_greeting")
	g.character_touch.update(g,3.0)
	g.character_touch.update(g,1.0)
	for member in g.MEMBERS: await click_member(member.id)
	g.character_touch.update(g,.78)
	metadata.second_reactions=reaction_row()
	for i in range(g.MEMBERS.size()): check(metadata.first_reactions[i].id!=metadata.second_reactions[i].id,"consecutive clicks choose a different room greeting")
	await capture("small_03_second_greeting")
	g.character_touch.reset()
	g._action("life_open")
	for day in [1,8,15,22,29]:
		g.state.day=day
		await frame()
		var label: String=g.Growth.calendar(day).label
		check(g.drawn_text.any(func(t):return t.contains(label)),"life header follows shared calendar: "+label)
		check(not g.drawn_text.any(func(t):return t.contains("오늘 누구로 지낼까")),"player identity is not confused with member selection")
	g.state.day=8
	await capture("small_04_life_calendar_fixed")
	# Store vectors as plain coordinates for the screenshot-only crop script.
	for row in metadata.members:
		row.eye=[row.eye.x,row.eye.y]
		row.feet=[row.feet.x,row.feet.y]
	FileAccess.open(OUT+"expression_captures.json",FileAccess.WRITE).store_string(JSON.stringify(metadata,"\t"))
	print("SMALL WINDOW EXPRESSIONS: ",checks," checks, ",failures," failures. Real click handlers, two nonrepeating greetings per member; no player saves written.")
	quit(1 if failures else 0)
