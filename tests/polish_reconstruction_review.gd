extends SceneTree
const OUT := "res://artifacts/polish_20261118/"
class ReviewGame:
	extends "res://scripts/growth_game.gd"
	func _save() -> void: pass
var g: Node2D
var failures := 0
var checks := 0
var metadata: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func frame() -> void:
	g.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
func run() -> void:
	var keyframes_only: bool="--audit-keyframes" in OS.get_cmdline_user_args()
	g=ReviewGame.new()
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
	g._setup_map()
	g.state.fan_form="dori"
	g.toast_time=0
	root.size=Vector2i(960,600)
	for task in ["corridor","shelves","reading"]:
		var dir: String=OUT+"frames_"+task+"/"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
		g._start_work(task)
		check(g.mode=="growth_work","start production work "+task)
		var count := 0
		var phases: Array=[]
		var phase_captures := {}
		while g.mode=="growth_work" and count<450:
			g.background_paused=false
			# Native simulation ticks; output captures every sixth tick, at 10 FPS.
			for tick in range(6):
				if g.mode=="growth_work": g._process(1.0/60.0)
			await frame()
			var image := root.get_texture().get_image()
			if not keyframes_only: image.save_png(dir+"%04d.png"%count)
			var phase: String=g.work_transition.phase
			if phase not in phases: phases.append(phase)
			if phase in ["approach","work","return"] and not phase_captures.has(phase):
				var ready: bool=g.work_transition.elapsed>1.5 if phase!="work" else g.work_elapsed>6
				if ready:
					image.save_png(OUT+task+"_"+phase+"_960.png")
					phase_captures[phase]=true
			count+=1
		check(g.mode=="play","production work returns to play: "+task)
		check(g.growth.completed_tasks.count(task)==1,"work completion committed exactly once: "+task)
		check(g.state.fan_form=="dori","selected fan form preserved after "+task)
		check(phases.has("approach") and phases.has("work") and phases.has("return"),"approach, work and return rendered: "+task)
		metadata.append({"task":task,"seconds":count*.1,"frames":count,"phases":phases})
	check(g.growth.phase=="ready","three production jobs unlock reopening")
	FileAccess.open(OUT+"reconstruction_capture.json",FileAccess.WRITE).store_string(JSON.stringify(metadata,"\t"))
	print("POLISH RECONSTRUCTION: ",checks," checks, ",failures," failures. Production transitions captured at 960x600; no saves written.")
	quit(1 if failures else 0)
