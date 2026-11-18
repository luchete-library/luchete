extends SceneTree

const Game=preload("res://scripts/growth_game.gd")
const Driver=preload("res://tests/fuwa_play_driver.gd")
const OUT:="res://artifacts/fuwa_production_20261118/"
var checks: Array=[]
var failures:=0
var g
var captures:=false
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks.append({"check":label,"passed":ok})
	if not ok: failures+=1;push_error(label)
func spawn():
	var game=Game.new();game.persist=false;root.add_child(game);game.set_process(false);game.audio_enabled=false
	game.background_paused=false;return game
func enter(game) -> void:
	game.mode="missions";game.mission_index=5;game._take_mission();game._turn_story()
func shot(name: String) -> void:
	if not captures: return
	g.queue_redraw()
	if is_instance_valid(g.fuwa_book): g.fuwa_book.queue_redraw()
	await process_frame;await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUT+name+".png")==OK,"capture "+name)
func run() -> void:
	captures=DisplayServer.get_name()!="headless";root.size=Vector2i(1280,800)
	g=spawn();g._new_game();g.mode="play"
	enter(g)
	check(g.mode=="fuwa_adventure" and is_instance_valid(g.fuwa_book),"Ete assignment and story button enter direct Fuwa chapter")
	check(not g.world_map_active() and not g.fuwa_book.is_processing_unhandled_input(),"campaign has one input owner and no library updates")
	check(not g.state.wear_fan_form("fuwa"),"Tenbi transformation locked before arrival")
	var old_minutes: int=g.state.minutes;var original_form: String=g.state.fan_form
	await shot("01_book_entry")
	check(Driver.find_tenbi(g),"real movement, patrol timing and observation reach reunion")
	check("fuwa" not in g.state.residents and g.state.fuwa_adventure.stage=="reunion","reunion is checkpoint only, not unlock")
	await shot("02_reunion")
	Driver.key(g,KEY_E);Driver.key(g,KEY_E,false);Driver.step(g,1.5)
	await shot("03_spell")
	check("fuwa" not in g.state.residents,"casting never unlocks early")
	Driver.step(g,2.3);await shot("04_rift")
	Driver.key(g,KEY_F5)
	check(g.state.fuwa_adventure.stage=="reunion","mid-rift save resumes safely before spell")
	var before_pause: float=g.fuwa_book.return_flow.elapsed
	Driver.key(g,KEY_ESCAPE);Driver.step(g,2)
	check(g.fuwa_book.paused and g.fuwa_book.return_flow.elapsed==before_pause,"pause stops ending inside production")
	Driver.key(g,KEY_ESCAPE);Driver.step(g,4)
	check(g.fuwa_book.phase=="awakening" and "fuwa" not in g.state.residents,"awakening remains locked until visible arrival finishes")
	Driver.step(g,3)
	check(g.fuwa_book.phase=="arrived" and g.fuwa_book.completed,"arrival is acknowledged by production")
	check(g.state.residents==["fuwa"] and g.state.chapter_steps.fuwa==3 and g.state.active_mission=="" and not g.state.page_complete,"arrival recruits Fuwa and completes only her book")
	check(g.state.fan_form==original_form and g.state.minutes==old_minutes,"book leaves fan selection and library clock unchanged")
	check(g.state.wear_fan_form("fuwa"),"arrival unlocks Tenbi transformation")
	g.state.fan_form=original_form
	var completed: Dictionary=g.state.to_data().duplicate(true)
	g._fuwa_arrived();g._return_with_stella();Driver.step(g,1)
	check(g.state.to_data()==completed,"duplicate arrival and stale old return cannot pay or unlock twice")
	await shot("05_arrived_unlocked")
	root.size=Vector2i(960,600);await shot("05_arrived_unlocked_960");root.size=Vector2i(1280,800)
	check(g.state.save_to(OUT+"completed_slot.json")==OK,"completed book saved to isolated disk slot")
	var loaded=Game.GrowthState.new()
	check(loaded.load_from(OUT+"completed_slot.json") and loaded.residents==["fuwa"] and loaded.chapter_steps.fuwa==3,"disk reload retains unlocked Fuwa")
	Driver.key(g,KEY_E)
	check(not is_instance_valid(g.fuwa_book) and g.mode=="dialog" and not g._find_object("fuwa").is_empty(),"leave arrival returns to actual library with Fuwa NPC")
	check(g.growth.phase=="recruiting" and g.growth.gold==0 and g.growth.memory_light==0,"first recruit grants no construction or economy shortcut")
	await shot("06_library_resident")
	# Replaying a completed book uses detached progress and no campaign rewards.
	var before_replay: Dictionary=g.state.to_data().duplicate(true)
	g._open_story(5,"journal");g._replay_debut();g.fuwa_book.start_return_preview()
	Driver.key(g,KEY_E);Driver.key(g,KEY_E,false);Driver.step(g,11)
	check(g.state.to_data()==before_replay and g.fuwa_book.replay,"replay ending is read-only for campaign")
	Driver.key(g,KEY_E);check(g.mode=="story" and g.replay_progress==null,"replay returns to book view")
	g.free()
	# Resume via actual disk save/Continue, while another book remains available.
	g=spawn();enter(g);g.fuwa_book.enter_clearing();Driver.step(g,.1);g._save()
	check(g.state.save_to(OUT+"unfinished_slot.json")==OK,"unfinished checkpoint saves to disk")
	g.free();g=spawn();g.save_path=OUT+"unfinished_slot.json";g._continue_game()
	check(g.mode=="play" and g.state.active_mission=="fuwa" and g.state.residents.is_empty(),"Continue loads unfinished book without unlock")
	g._open_story(5,"journal");g._turn_story()
	check(g.fuwa_book.zone==1 and g.fuwa_book.phase=="search","book resume restores clearing")
	Driver.key(g,KEY_Q);check(g.mode=="journal" and g.state.residents.is_empty(),"closing unfinished book never unlocks")
	g.mode="missions";g.mission_index=4;g._take_mission();g._turn_story()
	check(g.mode=="stella_adventure" and g.stella_book.member=="dori","another book enters its own protagonist controller")
	g._close_stella_book();enter(g);check(g.fuwa_book.zone==1,"switching books preserves Fuwa checkpoint")
	g.free()
	# Old incomplete saves with no new field retain equivalent stage; no reset
	# or auto-unlock of completed old books is required.
	for old_step in [0,1,2,3]:
		g=spawn();g.state.accept_mission("fuwa")
		if old_step>=1: g.state.record_chapter_step("fuwa",0);g.state.mark_first_action("fuwa")
		if old_step>=2: g.state.record_chapter_step("fuwa",1);g.state.seal_page("fuwa")
		if old_step==3: g.state.record_chapter_step("fuwa",2)
		var legacy: Dictionary=g.state.to_data();legacy.erase("fuwa_adventure")
		check(g.state.apply_data(legacy),"old save without checkpoint field loads "+str(old_step))
		if old_step<3:
			g._enter_chapter("fuwa")
			check(g.fuwa_book.zone==(0 if old_step==0 else 1) and g.state.residents.is_empty(),"old incomplete stage maps without early unlock "+str(old_step))
		else: check("fuwa" in g.state.residents,"old completed Fuwa remains unlocked")
		g.free()
	# Last recruit begins construction; all tasks and reopening remain manual.
	g=spawn()
	for member in g.MEMBERS:
		if member.id=="fuwa": continue
		g.state.accept_mission(member.id);g.state.record_chapter_step(member.id,0);g.state.mark_first_action(member.id);g.state.record_chapter_step(member.id,1);g.state.seal_page(member.id);g.state.record_chapter_step(member.id,2)
	enter(g);g.fuwa_book.start_return_preview();Driver.key(g,KEY_E);Driver.key(g,KEY_E,false);Driver.step(g,11)
	check(g.state.residents.size()==6 and g.growth.phase=="rebuilding" and g.growth.completed_tasks.is_empty() and not g.state.opening_pending,"sixth arrival starts first reconstruction, never reopening")
	Driver.key(g,KEY_E);check(g.mode=="dialog" and g.after_dialogue=="growth_ops","sixth arrival routes Ete dialogue into reconstruction notebook")
	g.free()
	FileAccess.open(OUT+"integration_results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	print("FUWA PRODUCTION: ",checks.size()," checks; failures=",failures);quit(1 if failures else 0)
