extends SceneTree

const State = preload("res://scripts/game_state.gd")
const Trail = preload("res://scripts/story_trail.gd")
var failures:=0
var checks:=0

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",message)

func _initialize() -> void:
	for id in Trail.DATA.data.books:
		var state:=State.new()
		state.accept_mission(id)
		var notes: Array=state.get(id+"_notes")
		for scene in range(4):
			var entry:=Trail.entry(id,scene)
			check(not entry.question.is_empty() and not entry.beats.is_empty(),"each scene has an exploratory question")
			check(not state.open_chapter_route(id),"unobserved memories cannot open a continuation")
			for beat in entry.beats: notes.append(beat[0])
			# Fuwa's successful shared practice is the legacy-compatible completion.
			check(state.chapter_ready(id,scene),"the advertised observations finish the real activity")
			check(Trail.status(state,id,scene).ready,"tracker reads the actual activity notes")
			if scene==3:
				check(not state.open_chapter_route(id),"the final memory uses the existing rescue, not another route")
				continue
			check(state.open_chapter_route(id) and state.debut_scene(id)==scene,"reading marks a route without advancing history")
			var saved:=state.to_data()
			var loaded:=State.new()
			check(loaded.apply_data(JSON.parse_string(JSON.stringify(saved))) and loaded.route_pending(id),"route checkpoint survives actual JSON serialization")
			var restored_notes: Array=loaded.get(id+"_notes").duplicate()
			var expected_notes: Array=notes.duplicate()
			restored_notes.sort()
			expected_notes.sort()
			check(restored_notes==expected_notes,"route loading preserves earlier discoveries: "+id)
			check(loaded.accept_mission("danming" if id!="danming" else "dori") and loaded.accept_mission(id) and loaded.route_pending(id),"switching books retains the bookmarked continuation")
			if scene==0: state.record_chapter_step(id,0)
			elif scene==1: state.mark_first_action(id)
			else: state.record_chapter_step(id,1)
			check(not state.route_pending(id) and not state.chapter_routes.has(id),"advancing consumes a route once")
	var old:=State.new().to_data()
	old.version=6
	old.dori_notes=["sleeper"]
	old.yune_notes=["eaten"]
	old.erase("chapter_routes")
	var migrated:=State.new()
	check(migrated.apply_data(old),"version 6 saves remain readable")
	check(migrated.chapter_ready("dori",1) and migrated.chapter_ready("yune",1),"new comparisons do not revoke completed legacy scenes")
	var modern:=State.new().to_data()
	modern.dori_notes=["sleeper"]
	modern.yune_notes=["eaten"]
	modern.chapter_routes={"dori":0,"yune":"0","unknown":0,"fuwa":2}
	check(migrated.apply_data(modern) and migrated.chapter_routes.is_empty(),"invalid or unearned route checkpoints are ignored")
	check(not migrated.chapter_ready("dori",1) and not migrated.chapter_ready("yune",1),"new games still require the actual comparison")
	print("STORY TRAIL STATE: ",checks," checks, ",failures," failures. Player save untouched.")
	quit(1 if failures else 0)
