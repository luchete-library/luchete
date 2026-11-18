extends "res://tests/render.gd"

# Run in Godot graphics mode. --realtime presents every walking frame and uses the wall clock.
# The accelerated pass sends the same input through the same screens and advances the game clock.
const FAST_CPS := 10.0
const SLOW_CPS := 6.0
var realtime := false
var inputs := 0
var issues: Array[String]=[]
var books: Array = []
var check_count := 0
var active_member := ""
var started_ms := 0
var comic_seconds := 0.0
var saves_checked := 0
var probe_signs := false

class MeasuredGame:
	extends "res://scripts/main.gd"
	var saved: Dictionary={}
	var walk_time := 0.0
	func _process(delta: float) -> void:
		super._process(delta)
		if moving: walk_time+=minf(delta,.04)
	func _save() -> void:
		state.player=chapter_home if mode in ["chapter","rescue"] else player_pos
		saved=state.to_data().duplicate(true)

	var read_lines := {}
	var story_chars := 0

	func count_text(value: String) -> void:
		if not value.is_empty() and not read_lines.has(value):
			read_lines[value]=true
			story_chars+=value.length()

	# Count the unwrapped narrative as it is shown, keeping headings, repeated UI,
	# comic captions (already timed) and any field covered by a modal off the reading clock.
	func _text_block(pos: Vector2,value: String,width: float,size: int=18,color: Color=CREAM,line_height: int=30) -> float:
		if not in_world and comic_started<0 and mode in ["dialog","story","missions","rescue","chapter"]:
			count_text(value)
		return super._text_block(pos,value,width,size,color,line_height)

	func _text(pos: Vector2,value: String,size: int=18,color: Color=CREAM) -> void:
		if not in_world and comic_started<0:
			if mode=="ending" and pos.y>=280 and pos.y<=495: count_text(value)
			if mode=="chapter":
				if not chapter_question and pos.x==124: count_text(value)
				if chapter_question and (pos.y==465 or (fuwa_snow.viewing and pos.y==577) or (_dori_notebook_open() and pos.y==576)):
					count_text(value)
		super._text(pos,value,size,color)

func check(ok: bool, label: String) -> void:
	check_count+=1
	if not ok: issues.append(active_member+" / "+label)
	super.check(ok,label)

func repaint() -> void:
	if DisplayServer.get_name()!="headless":
		await super.repaint()
		return
	game.queue_redraw()
	await process_frame
	await process_frame

func elapse(seconds: float) -> void:
	if realtime:
		var end: float=game.clock+seconds
		# Let ordinary 60 Hz walking advance a frame, even when the render frame is shorter.
		if seconds<=1.0/60.0+.00001:
			await process_frame
			return
		while game.clock+0.00001<end: await process_frame
	else:
		await super.elapse(seconds)

func tap(p: Vector2) -> void:
	inputs+=1
	await super.tap(p)

func reader_key(key: Key) -> void:
	inputs+=1
	await super.reader_key(key)

func hold_arrow(key: Key,seconds: float) -> void:
	inputs+=1
	await super.hold_arrow(key,seconds)

func swipe(a: Vector2,b: Vector2) -> void:
	inputs+=1
	await super.swipe(a,b)

func dream_press(down: bool,mouse: bool) -> void:
	if down: inputs+=1
	super.dream_press(down,mouse)

func inspect_field_site(id: String) -> void:
	var obj: Dictionary=game._find_object(id)
	if probe_signs and not obj.is_empty() and obj.type in ["yato_site","danming_site","kubby_site","fuwa_site"]:
		var width: float=game.font.get_string_size(obj.label,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x+18
		var offset:=Vector2(width/2-5,25 if obj.type=="fuwa_site" else 22)
		await tap(game.WORLD_OFFSET+(obj.pos+offset)*game.WORLD_SCALE)
		# An accepted click either queues a named interaction or completes it immediately.
		if game.pending_object!=id and not game.route.is_empty():
			check(false,"click on visible nameplate only walks to the ground: "+id)
			return
		await finish_walk()
		return
	await super.inspect_field_site(id)

func dialogue() -> void:
	for i in range(8):
		if game.mode!="dialog": return
		await button("next")
	check(false,"dialogue did not finish")

func play_scene(id: String,scene: int) -> void:
	match id:
		"yato": await explore_yato(scene)
		"danming": await explore_danming(scene)
		"kubby": await explore_kubby(scene)
		"yune": await explore_yune(scene)
		"dori": await investigate_dori(scene)
		"fuwa": await explore_fuwa(scene)

func snapshot() -> Dictionary:
	return {"seconds":game.clock,"walking":game.walk_time,"inputs":inputs,"chars":game.story_chars,"comic":comic_seconds}

func measured(start: Dictionary) -> Dictionary:
	var results:=snapshot()
	for key in results:
		results[key]-=start[key]
		if results[key] is float: results[key]=snappedf(results[key],.01)
	return results

func play_book(index: int) -> void:
	var id: String=game.MEMBERS[index].id
	active_member=id
	var start:=snapshot()
	var book: Dictionary=game.Chapters.BOOKS[id]
	await button("goto_ete")
	await finish_walk()
	check(game.mode=="missions", "reach Ete at the worktable")
	await button("offer_%d"%index)
	await button("take_mission")
	check(game.mode=="story" and game.state.active_mission==id,"accept the selected assignment")
	await button("story_next")
	check(game.mode=="chapter" and game.state.debut_scene(id)==0,"enter as "+book.fan)
	var scenes: Array=[]
	for scene in range(4):
		var begin:=snapshot()
		await play_scene(id,scene)
		check(game.chapter_question and game.buttons.any(func(b): return b.id=="chapter_remember"),"read the official record for scene %d"%(scene+1))
		if failures: return
		await button("chapter_remember")
		check(game.mode==("rescue" if scene==3 else "chapter"),"confirm scene %d"%(scene+1))
		var restore=game.State.new()
		var original: Array=game.state.get(id+"_notes").duplicate()
		var load_ok: bool=restore.apply_data(JSON.parse_string(JSON.stringify(game.saved)))
		var loaded: Array=restore.get(id+"_notes").duplicate()
		original.sort()
		loaded.sort()
		check(load_ok and restore.debut_scene(id)==game.state.debut_scene(id) and restore.page_complete==game.state.page_complete and loaded==original,"round-trip bookmark %d"%(scene+1))
		saves_checked+=1
		scenes.append(measured(begin))

	await button("comic_play")
	check(game.comic_started>=0,"open the comic from the sealed book")
	var duration: float=game.Comics.duration(id)
	await elapse(duration)
	comic_seconds+=duration
	await button("comic_close")
	await button("rescue_return")
	check(game.mode=="dialog" and game.state.residents.size()==books.size()+1 and game.state.residents.has(id),"return with "+id)
	await dialogue()
	var result:=measured(start)
	result.id=id
	result.name=game.MEMBERS[index].name
	result.scenes=scenes
	result.estimated_minutes=reading_range(result.seconds,result.chars,result.inputs)
	books.append(result)
	print("BOOK ",JSON.stringify(result))

func reading_range(seconds: float,chars: int,actions: int) -> Array:
	return [snappedf((seconds+chars/FAST_CPS+actions*.5)/60,.1),snappedf((seconds+chars/SLOW_CPS+actions)/60,.1)]

func run() -> void:
	root.size=Vector2i(1280,800)
	game=MeasuredGame.new()
	root.add_child(game)
	await process_frame
	game.audio_enabled=false
	game.save_available=false
	realtime="--realtime" in OS.get_cmdline_user_args()
	probe_signs="--signs" in OS.get_cmdline_user_args()
	game.set_process(realtime)
	await repaint()
	var start:=snapshot()
	started_ms=Time.get_ticks_msec()
	await button("new")
	check(game.mode=="dialog" and game.state.residents.is_empty(),"new game opens in the empty library with Ete")
	await dialogue()
	check(game.mode=="play","first commission is accessible")
	var intro:=measured(start)
	for index in [0,1,2,3,4,5]:
		await play_book(index)
		if failures: break
	check(game.mode=="ending" and game.state.opening_pending and game.state.rebuild_stage()==6,"sixth arrival triggers reopening")
	var before_close:=snapshot()
	if game.mode=="ending":
		await button("close")
		check(game.mode=="play" and game.split_view() and not game.state.opening_pending,"public library and six rooms open on one screen")
	var ending:=measured(before_close)
	var wall: float=(Time.get_ticks_msec()-started_ms)/1000.0
	var total:=measured(start)
	if not failures and DisplayServer.get_name()!="headless": await capture("campaign_reopened")
	var baseline: float=wall if realtime else total.seconds
	var report: Dictionary={
		"method":"새 게임에서 실제 마우스·키 입력, 보통 걸음, 매 권의 네 컷 전체 재생. 실시간 실행은 시작 버튼부터 재개관 안내를 닫기까지 벽시계로 측정. 독서 예상은 화면에 나온 중복 제외 본문·안내 글자(공백 포함)에 초당 6~10자, 입력당 탐색 0.5~1초를 가정. 만화 자막은 재생 시간에 포함.",
		"realtime":realtime,"wall_seconds":snappedf(wall,.01),"total":total,"intro":intro,"reopening":ending,"books":books,
		"estimated_reading_run_minutes":reading_range(baseline,game.story_chars,inputs),
		"residents":game.state.residents,"stage":game.state.rebuild_stage(),"checks":check_count,"restored_bookmarks":saves_checked,"failures":issues}
	var file_name: String="playtime_audit.json" if realtime else "playtime_audit_fast.json"
	if failures: file_name="playtime_audit_failed.json"
	var file:=FileAccess.open("res://artifacts/"+file_name,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("CAMPAIGN FINISHED ",game.mode," ",total," wall=",wall," issues=",issues)
	quit(1 if failures else 0)
