extends "res://tests/render.gd"

const OUTPUT := "book_discovery_20261115/"
const SCENES := [["danming",2],["yune",2],["kubby",1],["yato",1],["fuwa",0]]
var cases := 0

func start_scene(id: String,scene: int) -> void:
	game.replay_progress=null
	game.state=game.State.new()
	game.state.accept_mission(id)
	if scene>=1: game.state.record_chapter_step(id,0)
	if scene>=2: game.state.mark_first_action(id)
	if scene>=3: game.state.record_chapter_step(id,1)
	game._open_story(game._mission_index_for(id),"journal")
	game._turn_story()
	await repaint()

func check_case(ok: bool,label: String) -> void:
	cases+=1
	check(ok,label)

func return_to_book(id: String) -> void:
	var restored=game.State.new()
	check_case(restored.apply_data(JSON.parse_string(JSON.stringify(game.state.to_data()))),id+" bookmark survives JSON save/load")
	game.state=restored
	game._open_story(game._mission_index_for(id),"journal")
	game._turn_story()
	await elapse(.01)
	await repaint()

func pause_and_resume() -> void:
	await button("discovery_pause")
	var elapsed: float=game.book_discovery.elapsed
	var clock_before: float=game.clock
	var feet: Vector2=game.player_pos
	await DiscoveryActions.held(self,KEY_D,1)
	await elapse(12)
	check_case(game.book_discovery.paused and game.book_discovery.elapsed==elapsed and game.clock==clock_before and game.player_pos==feet,"menu freezes the result, actors and movement")
	await reader_key(KEY_E)
	check_case(not game.book_discovery.paused,"E resumes the same scene")

func partial_observation(id: String,scene: int) -> void:
	await start_scene(id,scene)
	match id:
		"danming":
			await inspect_field_site("bee_album")
			await elapse(.5)
			var lens=game.danming_workshop.lens
			var event:=InputEventMouseMotion.new()
			event.position=game.WORLD_OFFSET+lens.POINTS[1]*game.WORLD_SCALE
			root.push_input(event,true)
			for tick in range(90): await elapse(1.0/60)
			check_case("arrow_stack" in game.state.danming_notes and not "hand_pause" in game.state.danming_notes,"one arrow discovery does not skip the other observation")
		"yune":
			await inspect_field_site("dream_nights")
			await elapse(game.yune_dream.nights.DURATION*.55)
		"kubby":
			await inspect_field_site("wisp_watch")
			await elapse(.9)
		"yato":
			await inspect_field_site("mato_basket")
			await elapse(game.yato_forest.storehouse.UNFOLD_TIME+.03)
			await inspect_field_site("mato_truth")
		"fuwa":
			await inspect_field_site("tenbi_together")
			var ward=game.fuwa_snow.practice
			await elapse(ward.join_time+.6)
			var mouse:=InputEventMouseButton.new()
			mouse.button_index=MOUSE_BUTTON_LEFT
			mouse.pressed=true
			mouse.position=game.WORLD_OFFSET+ward.DOTS[0]*game.WORLD_SCALE
			root.push_input(mouse,true)
			var move:=InputEventMouseMotion.new()
			move.button_mask=MOUSE_BUTTON_MASK_LEFT
			move.position=game.WORLD_OFFSET+ward.DOTS[0].lerp(ward.DOTS[1],.35)*game.WORLD_SCALE
			root.push_input(move,true)
			move.position+=Vector2(0,-130)
			root.push_input(move,true)
			var fraction: float=ward.fraction
			check_case(ward.needs_regrab and fraction>0 and fraction<1,"leaving the line pauses without erasing the partial stroke")
			move.position=game.WORLD_OFFSET+ward.DOTS[1]*game.WORLD_SCALE
			root.push_input(move,true)
			check_case(ward.needs_regrab and ward.fraction==fraction,"off-path movement cannot skip to the far corner")
			move.position=game.WORLD_OFFSET+ward.tip()*game.WORLD_SCALE
			root.push_input(move,true)
			check_case(not ward.needs_regrab and ward.fraction==fraction,"returning to the nib immediately reattaches the same held brush")
			move.position=game.WORLD_OFFSET+ward.DOTS[1]*game.WORLD_SCALE
			root.push_input(move,true)
			mouse.pressed=false
			mouse.position=move.position
			root.push_input(mouse,true)
			check_case(ward.step==2 and "seal" in game.state.fuwa_notes,"resumed continuous drag completes the current side")
	await repaint()
	await pause_and_resume()
	var notes: Array=game.state.get(id+"_notes").duplicate()
	await reader_key(KEY_ESCAPE)
	check_case(game.mode=="chapter" and not game.chapter_question and not game.book_discovery.tool_open(game),id+" Escape returns from the close-up to the map")
	await elapse(.65)
	check_case(not game.chapter_question and not game.book_discovery.tool_open(game),id+" the same nearby actor does not immediately reopen the tool")
	await reader_key(KEY_ESCAPE)
	await button("discovery_leave")
	await return_to_book(id)
	var resumed: Array=game.state.get(id+"_notes").duplicate()
	resumed.sort()
	notes.sort()
	check_case(resumed==notes and game.state.debut_scene(id)==scene,id+" partial discoveries remain without granting the whole memory")

func run() -> void:
	root.size=Vector2i(1280,800)
	game=PreviewGame.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.audio_enabled=false
	game.save_available=false
	for entry in SCENES:
		var id: String=entry[0]
		var scene: int=entry[1]
		await partial_observation(id,scene)
		await start_scene(id,scene)
		check_case(game.ui_regions.size()==2 and game.buttons.size()<=2,id+" field has question, observation, menu and at most one optional visual detail")
		await capture(OUTPUT+id+"_field")
		await DiscoveryActions.play(self,scene,true)
		await capture(OUTPUT+id+"_discovery")
		await pause_and_resume()
		var complete: Dictionary=game.state.to_data().duplicate(true)
		await reader_key(KEY_ESCAPE)
		await button("discovery_leave")
		await return_to_book(id)
		check_case(game.book_discovery.result_scene==scene and game._find_object("story_path").is_empty(),id+" completed observations resume automatically without the removed waypoint")
		if id=="danming":
			await reader_key(KEY_E)
			await elapse(game.book_discovery.FADE+.1)
			await repaint()
			await reader_key(KEY_ESCAPE)
			await capture(OUTPUT+"arrival_pause")
			var menu_pixel: Color=root.get_texture().get_image().get_pixel(500,300)
			check_case(game.book_discovery.paused and game.book_discovery.arrival_fade>0 and menu_pixel.v>.4,"opening the menu during the arrival fade does not hide it behind a dark screen")
			await reader_key(KEY_E)
			await elapse(game.book_discovery.FADE)
		else: await finish_story_record()
		await capture(OUTPUT+id+"_next")
		await elapse(20)
		check_case(game.state.debut_scene(id)==scene+1 and not game.state.page_complete,id+" one completed discovery advances exactly one scene")
		# Older saves may have already opened the now-removed continuation route.
		game.state.apply_data(complete)
		game.state.open_chapter_route(id)
		game._enter_chapter(id)
		await elapse(.01)
		await finish_story_record()
		check_case(not game.state.chapter_routes.has(id) and game.state.debut_scene(id)==scene+1,id+" legacy route is consumed rather than blocking the book")
		# Rereading changes only the isolated memory, not friendship or campaign progression.
		var campaign: Dictionary=game.state.to_data().duplicate(true)
		game.replay_progress=game.State.new()
		game.replay_progress.apply_data(complete)
		game._enter_chapter(id)
		await elapse(.01)
		await finish_story_record()
		check_case(game.state.to_data()==campaign and game.replay_progress.debut_scene(id)==scene+1,id+" replay cannot modify the campaign")
		game.replay_progress=null
	# Check the actual scene selector entry point, not only the main-game fixture.
	game.queue_free()
	await process_frame
	game=load("res://tests/story_scene_playtest.gd").new()
	root.add_child(game)
	game.set_process(false)
	game.audio_enabled=false
	for slot in [0,2,3,4,5]:
		game.start_scene(slot)
		await repaint()
		check_case(game.buttons.size()<=2 and game.buttons[0].id=="discovery_pause","scene picker does not cover or intercept the common menu")
		await pause_and_resume()
		await DiscoveryActions.play(self,game.state.debut_scene(game.MEMBERS[game.story_member].id))
		await finish_story_record()
		check_case(game.mode=="chapter","scene test continues to the next actual memory")
		await reader_key(KEY_F2)
		check_case(game.mode==game.PICKER and game.book_discovery.result_scene<0,"F2 clears the pending discovery and returns to the selector")
	print("BOOK DISCOVERY: ",cases," focused checks; five books, both controls, partial resume, pause, legacy saves, replay and scene selector; failures: ",failures)
	quit(1 if failures else 0)
