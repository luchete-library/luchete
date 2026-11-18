extends SceneTree
const Game=preload("res://scripts/growth_game.gd")
const Driver=preload("res://tests/stella_play_driver.gd")
const Markers=preload("res://scripts/story_markers.gd")
const OUT="res://artifacts/tester_feedback_20261119/"
var failures:=0
var checks: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks.append({"check":label,"passed":ok})
	if not ok: failures+=1;push_error(label)
func spawn(id: String):
	var g=Game.new();g.persist=false;root.add_child(g);g.set_process(false);g.audio_enabled=false;g.background_paused=false
	g.state.accept_mission(id);g._enter_chapter(id)
	return g
func click(g,p: Vector2) -> void:
	var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true;e.position=p
	g._unhandled_input(e);e.pressed=false;g._unhandled_input(e)
func caption(book,marker: Dictionary) -> Vector2:
	var rect:=Markers.label_rect(book.font,book.screen_world(marker.point),marker.label)
	return Vector2(rect.end.x-4,rect.get_center().y)

func complete_with_pointer(g) -> bool:
	var b=g.stella_book
	for attempt in range(40):
		if b.phase=="arrived": return b.completed
		if b.intro or b.kind()=="called": click(g,b.CONTINUE.get_center())
		elif not b.story_markers().is_empty(): click(g,caption(b,b.story_markers()[0]))
		Driver.step(g,7)
		if b.working and b.kind() in ["arrows","weary"]:
			var stage: int=b.stage
			var down:=InputEventMouseButton.new();down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true;down.position=b.screen_world(Vector2(400,285));g._unhandled_input(down)
			for stroke in range(40):
				if b.stage!=stage: break
				var motion:=InputEventMouseMotion.new();motion.position=b.screen_world(Vector2(400+(stroke%2)*80,285));g._unhandled_input(motion)
			down.pressed=false;g._unhandled_input(down)
	return false
func run() -> void:
	for id in Game.StellaAdventure.Chapters.CHAPTERS:
		var g=spawn(id);var b=g.stella_book;b.pause_on_focus_loss=false
		for stage in range(b.Chapters.CHAPTERS[id].size()):
			b.enter_stage(stage);b.intro=false;b.phase="play"
			var markers: Array=b.story_markers()
			check(not markers.is_empty() or b.points().is_empty(),id+": interactive stage has visible marker "+b.kind())
			for marker in markers:
				var point:=caption(b,marker)
				check(point.y>95 and point.y<735,id+": caption stays in playable vertical region "+marker.label)
				click(g,point)
				check(not b.route.is_empty() and b.route[-1].distance_to(marker.point)<.1 and b.pending,id+": label edge routes to actual action, not label floor "+marker.label)
				b.clear_controls()
			b.intro=true;check(b.story_markers().is_empty(),id+": no active target during entry text")
			b.intro=false;b.paused=true;check(b.story_markers().is_empty(),id+": no active target during pause");b.paused=false
		g.free()
	# Arrow bits belong to the same workbench throughout the three-part job.
	var g=spawn("danming");var b=g.stella_book;b.pause_on_focus_loss=false;b.enter_stage(1);b.intro=false
	for done in [1,3]:
		b.done=done;b.player_pos=b.target(0)
		var markers: Array=b.story_markers()
		check(markers.size()==1,"partially polished arrow retains workbench marker")
		click(g,caption(b,markers[0]));check(b.working,"partially polished arrow resumes from caption")
		b.clear_controls()
	b.enter_stage(3);b.intro=false
	click(g,b.CONTINUE.get_center());check(b.kind()=="ending","Danming call can continue without keyboard")
	g.free()
	# Sequential reveal respects food -> family and companion -> journey.
	for spec in [["yato",1],["kubby",2],["danming",2],["yune",3]]:
		g=spawn(spec[0]);b=g.stella_book;b.enter_stage(spec[1]);b.intro=false
		check(b.story_markers().size()==1 and b.story_markers()[0].index==0,spec[0]+": later action initially hidden")
		b.mark(0);check(b.story_markers().size()==1 and b.story_markers()[0].index==1,spec[0]+": next action revealed after discovery")
		g.free()
	g=spawn("dori");b=g.stella_book;b.enter_stage(1);b.intro=false;b.stone=true;b.mark(0)
	check(b.story_markers()[0].label=="둔갑 풀기","completed stone watch has visible release action")
	click(g,caption(b,b.story_markers()[0]));check(not b.stone,"stone form releases by label tap")
	g.free()
	# Real input covers each Fuwa marker, without making hidden Tenbi visible.
	g=spawn("fuwa");b=g.fuwa_book;b.pause_on_focus_loss=false
	click(g,caption(b,b.story_markers()[0]));check(b.pending=="pass" and b.route[-1]==b.PASS,"Fuwa pass caption routes to pass")
	b.enter_clearing();b.clock=0
	check(not b.tenbi_visible() and b.story_markers().is_empty(),"no marker leaks hidden Tenbi")
	for spot in range(3):
		b.encounter=spot;b.reset();b.enter_clearing();b.discovered=true
		click(g,caption(b,b.story_markers()[0]));check(b.pending=="tenbi" and not b.route.is_empty(),"Tenbi caption has reachable approach for spot "+str(spot))
	b.start_return_preview();click(g,caption(b,b.story_markers()[0]))
	check(b.phase=="casting" and b.return_flow.cast_count==1,"spell caption starts existing return sequence once")
	check(b.story_markers().is_empty(),"return animation hides active marker")
	g.free()
	for id in Game.StellaAdventure.Chapters.CHAPTERS:
		g=spawn(id);g.stella_book.pause_on_focus_loss=false
		check(complete_with_pointer(g),id+": full book completed via caption clicks and authored mouse interaction")
		check(id in g.state.residents,id+": pointer completion unlocks resident only on arrival")
		g.free()
	FileAccess.open(OUT+"marker_results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	print("STORY MARKERS: ",checks.size()," checks; failures=",failures);quit(1 if failures else 0)
