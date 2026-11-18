extends SceneTree
const Game=preload("res://scripts/growth_game.gd")
const Driver=preload("res://tests/stella_play_driver.gd")
const OUT="res://artifacts/stella_adventures_20261118/"
var checks: Array=[]
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks.append({"check":label,"passed":ok})
	if not ok: failures+=1;push_error(label)
func spawn(id: String):
	var g=Game.new();g.persist=false;root.add_child(g);g.set_process(false);g.audio_enabled=false;g.background_paused=false
	g.state.accept_mission(id);g._enter_chapter(id);g.stella_book.pause_on_focus_loss=false
	return g
func run() -> void:
	for id in Game.StellaAdventure.Chapters.CHAPTERS:
		var g=spawn(id);var b=g.stella_book
		Driver.press(g)
		var start: Vector2=b.player_pos
		for pair in [[KEY_D,"right"],[KEY_A,"left"],[KEY_W,"up"],[KEY_S,"down"]]:
			Driver.key(g,pair[0]);Driver.step(g,.25);Driver.key(g,pair[0],false)
			check(b.moving and b.facing==pair[1],id+": actual keyboard walking "+pair[1])
		check(b.player_pos.distance_to(start)<1,id+": four directions preserve foot anchor")
		check(not b.set_destination(Vector2(20,20)),id+": background walls reject movement")
		b._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
		check(b.held.is_empty() and b.route.is_empty(),id+": focus loss releases all movement")
		g.free()
		# Legacy steps map to an equivalent official event, never auto-unlock.
		for old_step in [0,1,2,3]:
			g=spawn(id);g._close_stella_book()
			if old_step>=1: g.state.record_chapter_step(id,0)
			if old_step>=2: g.state.mark_first_action(id);g.state.record_chapter_step(id,1);g.state.seal_page(id)
			if old_step==3: g.state.record_chapter_step(id,2)
			var data: Dictionary=g.state.to_data();data.erase("stella_adventures")
			check(g.state.apply_data(data),id+": old save without new field loads "+str(old_step))
			if old_step<3:
				g._enter_chapter(id)
				check(g.stella_book.entry()[1]==g.state.debut_scene(id) and id not in g.state.residents,id+": legacy event resumes without early unlock "+str(old_step))
			else: check(id in g.state.residents,id+": completed legacy book preserved")
			g.free()
	# Mid-work resumes retain discrete marks, not just scene numbers.
	var g=spawn("danming");Driver.play_stage(g);Driver.press(g);Driver.walk(g,g.stella_book.target(0))
	Driver.key(g,KEY_E);Driver.step(g,1.65);Driver.key(g,KEY_E,false);g._save()
	check(g.stella_book.done==1,"one cleaned arrow part has a distinct saved mark")
	check(g.state.save_to(OUT+"partial_arrow.json")==OK,"partial arrow saved to isolated disk")
	g.free();g=spawn("danming");g._close_stella_book();g.save_path=OUT+"partial_arrow.json";g._continue_game();g._enter_chapter("danming")
	check(g.stella_book.done==1 and not g.stella_book.working,"partial work restores cleanly with no stuck drag")
	check(Driver.complete(g),"partial arrow can finish after Continue")
	g.free()
	# Any one of the five can be the sixth arrival.
	for id in Game.StellaAdventure.Chapters.CHAPTERS:
		g=spawn(id);g._close_stella_book()
		for member in g.MEMBERS:
			if member.id==id: continue
			g.state.accept_mission(member.id);g.state.record_chapter_step(member.id,0);g.state.mark_first_action(member.id);g.state.record_chapter_step(member.id,1);g.state.seal_page(member.id);g.state.record_chapter_step(member.id,2)
		g.state.accept_mission(id);g._enter_chapter(id)
		check(Driver.complete(g),id+": playable as sixth book")
		check(g.state.residents.size()==6 and g.growth.phase=="rebuilding" and g.growth.completed_tasks.is_empty() and not g.state.opening_pending,id+": sixth arrival begins construction only")
		Driver.press(g)
		check(g.after_dialogue=="growth_ops",id+": sixth arrival directs Ete to reconstruction")
		g.free()
	FileAccess.open(OUT+"edge_results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	print("STELLA EDGE CASES: ",checks.size()," checks; failures=",failures);quit(1 if failures else 0)
