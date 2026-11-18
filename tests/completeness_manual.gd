extends SceneTree
const Game=preload("res://scripts/growth_game.gd")
const OUT:="res://artifacts/completeness_20261118/"
var g
var elapsed:=0.0
var interval:=0.0
var frames:=0
var slow_frames:=0
var events: Array=[]
var last_mode:=""

func _initialize() -> void: call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	g=Game.new();g.persist=true
	g.save_path=OUT+"manual_session.json";g.legacy_save_path=OUT+"no_legacy.json"
	root.add_child(g)
	root.title="루체테 · 전체 완성도 점검 · 별도 저장"
	root.size=Vector2i(960,600);root.position=Vector2i(160,90)
	root.show()
	if "--reopened" in OS.get_cmdline_user_args():
		g.persist=false;g._new_game();g.state.intro_seen=true
		for m in g.MEMBERS:
			g.state.active_mission=m.id;g.state.chapter_steps[m.id]=2;g.state.page_complete=true;g.state.record_chapter_step(m.id,2)
		for task in ["corridor","shelves","reading"]: g.state.complete_reconstruction_task(task)
		g.state.growth.open_library();g.state.minutes=540;g.state.day=1;g.state.operating.begin(g.state)
		g.state.opening_pending=false;g.mode="play";g._setup_map();g.persist=true
		g.save_path=OUT+"manual_reopened.json";g._save()

func _process(delta: float) -> bool:
	if not is_instance_valid(g): return false
	elapsed+=delta;interval+=delta;frames+=1
	if delta>.05: slow_frames+=1
	if g.mode!=last_mode:
		last_mode=g.mode
		events.append({"elapsed":snappedf(elapsed,.1),"mode":g.mode,"day":g.state.day,"minutes":g.state.minutes,"position":[g.player_pos.x,g.player_pos.y]})
		call_deferred("snap")
	if interval>=2.0:
		interval=0.0
		var file:=FileAccess.open(OUT+"manual_observation.json",FileAccess.WRITE)
		file.store_string(JSON.stringify({"elapsed":elapsed,"frames":frames,"slow_frames_over_50ms":slow_frames,"events":events,"mode":g.mode,"day":g.state.day,"minutes":g.state.minutes,"gold":g.growth.gold,"light":g.growth.memory_light,"residents":g.state.residents},"\t"))
	return false

func snap() -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"manual_%03d_%s.png"%[events.size(),g.mode])
