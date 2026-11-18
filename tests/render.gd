extends SceneTree
const DiscoveryActions = preload("res://tests/discovery_actions.gd")

class PreviewGame:
	extends "res://scripts/main.gd"
	func _save() -> void:
		pass

var game: Node2D

func _initialize() -> void:
	call_deferred("run")

func capture(name: String) -> void:
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png("res://artifacts/" + name + ".png")
	assert(result == OK,"Screenshot failed: " + name)

func run() -> void:
	root.size = Vector2i(1280,800)
	game = PreviewGame.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.audio_enabled = false
	game.save_available = false
	check_field_proportions()
	if "--story-trail-preview" in OS.get_cmdline_user_args():
		game.state=game.State.new()
		game.state.accept_mission("danming")
		game._open_story(1,"journal")
		game._turn_story()
		await capture("story_trail_20261114/01_question")
		await inspect_field_site("bee_voice")
		check("voice" in game.state.danming_notes and not game._find_object("bee_reply").is_empty(),"first discovery reveals the reply")
		await capture("story_trail_20261114/02_discovery")
		await inspect_field_site("bee_reply")
		await capture("story_trail_20261114/03_next_goal")
		await inspect_field_site("bee_notice")
		await capture("story_trail_20261114/04_connection")
		await finish_story_record()
		check(game.state.debut_scene("danming")==1,"discovery reaches the next memory without an exit chore")
		await capture("story_trail_20261114/06_arrival")
		print("STORY TRAIL PREVIEW: observation, discovery and automatic arrival; failures: ",failures)
		quit(1 if failures else 0)
		return
	if "--story-trail" in OS.get_cmdline_user_args():
		DirAccess.make_dir_recursive_absolute("res://artifacts/story_trail_20261114")
		game.save_available=false
		game.mode="title"
		await repaint()
		await button("new")
		while game.mode=="dialog": await button("next")
		for index in [0,3,4,1,2,5]:
			await button("journal")
			await experience(index)
		check(game.state.rebuild_stage()==6 and not game.state.opening_pending,"all linked books reach the reopened library")
		await capture("story_trail_20261114/reopened")
		print("STORY TRAIL: six books, 24 scenes, 21 automatic discoveries, 2 remaining Dori links, reopening; failures: ",failures)
		quit(1 if failures else 0)
		return
	if "--fuwa-snow" in OS.get_cmdline_user_args():
		game.state=game.State.new()
		game.state.accept_mission("fuwa")
		game._open_story(5,"journal")
		game._turn_story()
		for scene in range(4):
			await explore_fuwa(scene,true)
			check(game.chapter_question and game.FuwaSnow.ready(scene,game.state.fuwa_notes),"Tenbi completes memory %d"%scene)
			await finish_story_record()
		check(game.mode=="rescue","Fuwa's book reaches the return page")
		game._return_with_stella()
		check(game.state.residents==["fuwa"],"Fuwa returns to the public library")
		print("FUWA SNOW: shrine practice, mountain crossing, reunion, return spell, waking library and recruitment; failures: ",failures)
		quit(1 if failures else 0)
		return
	if "--yato-forest" in OS.get_cmdline_user_args():
		game.state=game.State.new()
		game.state.accept_mission("yato")
		game._open_story(0,"journal")
		game._turn_story()
		for scene in range(4):
			await explore_yato(scene,true)
			check(game.chapter_question and game.YatoForest.ready(scene,game.state.yato_notes),"Mato completes memory %d"%scene)
			await finish_story_record()
		check(game.mode=="rescue","the light seals Yato's last page")
		game._return_with_stella()
		check(game.state.residents==["yato"],"Yato returns to the library")
		print("YATO FOREST: rabbits, stores, mountain to village, quiet light and return; failures: ",failures)
		quit(1 if failures else 0)
		return
	if "--kubby-embers" in OS.get_cmdline_user_args():
		game.state=game.State.new()
		game.state.accept_mission("kubby")
		game._open_story(2,"journal")
		game._turn_story()
		for scene in range(4):
			await explore_kubby(scene,true)
			check(game.chapter_question and game.KubbyEmbers.ready(scene,game.state.kubby_notes),"Hamnim opens the official memory %d"%scene)
			await finish_story_record()
		check(game.mode=="rescue","Kubby's book reaches the return page")
		game._return_with_stella()
		check(game.state.residents==["kubby"],"Kubby joins the library")
		print("KUBBY EMBERS: village, hamster, walk-driven transformation, bookmark, night trail and return; failures: ",failures)
		quit(1 if failures else 0)
		return
	if "--danming-workshop" in OS.get_cmdline_user_args():
		game.state=game.State.new()
		game.state.accept_mission("danming")
		game._open_story(1,"journal")
		game._turn_story()
		for scene in range(4):
			await explore_danming(scene,true)
			check(game.chapter_question and game.DanmingWorkshop.ready(scene,game.state.danming_notes),"Beori observes the verified memory %d"%scene)
			await finish_story_record()
		check(game.mode=="rescue","last memory seals Danming's book")
		game._return_with_stella()
		check(game.state.residents==["danming"],"Danming comes back as the first resident")
		print("DANMING WORKSHOP: four playable scenes, mouse and keyboard, bookmark and return; failures: ",failures)
		quit(1 if failures else 0)
		return
	if "--yune-dream" in OS.get_cmdline_user_args():
		game.state=game.State.new()
		game.state.accept_mission("yune")
		game._open_story(3,"journal")
		game._turn_story()
		for scene in range(4):
			await explore_yune(scene,true)
			check(game.chapter_question and game.YuneDream.ready(scene,game.state.yune_notes),"Mongchi completes memory %d"%scene)
			await finish_story_record()
		check(game.mode=="rescue","all four dream memories seal the page")
		game._return_with_stella()
		check(game.state.residents==["yune"],"Yune returns to the library")
		print("YUNE DREAM: four memories, controls, pause, bookmark and return; failures: ",failures)
		quit(1 if failures else 0)
		return
	if "--dori-investigation" in OS.get_cmdline_user_args():
		game.state=game.State.new()
		game.state.accept_mission("dori")
		game._open_story(4,"journal")
		game._turn_story()
		for scene in range(4):
			await investigate_dori(scene,true)
			if scene==2:
				check(game.state.debut_scene("dori")==3,"rubbing continues without a record window")
				continue
			check(game.chapter_question and game.DoriCase.ready(scene,game.state.dori_notes),"Dori evidence opens memory %d"%scene)
			await finish_story_record()
		check(game.mode=="rescue","Dori's verified sequence seals the last page")
		game._return_with_stella()
		check(game.state.residents==["dori"],"Dori returns after the field investigation")
		print("DORI INVESTIGATION: four playable scenes, save/resume, mouse and keyboard; failures: ",failures)
		quit(1 if failures else 0)
		return
	if "--ete-lobby-review" in OS.get_cmdline_user_args():
		prepare_stella_review()
		game.state.fan_form=""
		game.clock=1.8
		game.player_pos=Vector2(640,620)
		await capture("ete_rebuild/library")
		for id in game.state.residents:
			game.character_touch.react(game,id)
			game.character_touch.reactions[id].elapsed=1.03
		await capture("ete_rebuild/library_reactions")
		print("Library idle and personal reactions rendered. Failures: ",failures)
		quit(1 if failures else 0)
		return
	if "--field-face-review" in OS.get_cmdline_user_args():
		await field_face_review()
		if "--outline-review" in OS.get_cmdline_user_args():
			await field_outline_review()
		print("Compared six real idle, reading and weight-training poses. Failures: ",failures)
		quit(1 if failures else 0)
		return
	if "--exhibit-pixels" in OS.get_cmdline_user_args():
		prepare_stella_review()
		game.player_pos=Vector2(450,525)
		await capture("reading_room_reopened")
		game.player_pos=Vector2(455,620)
		await capture("reading_room_passing_display")
		game.state.begin_yard_session("kubby","gym")
		game._process(.08)
		await capture("reading_room_weights")
		print("Reading room previews completed. Failures: ",failures)
		quit(1 if failures else 0)
		return
	if "--canon-records-preview" in OS.get_cmdline_user_args():
		game._new_game()
		await capture("canon_ete_intro")
		while game.mode=="dialog": game._advance_dialogue()
		for index in range(game.MEMBERS.size()):
			var id: String = game.MEMBERS[index].id
			game.state.accept_mission(id)
			game._open_story(index,"journal")
			game._turn_story()
			for scene in range(4):
				if id=="dori": await investigate_dori(scene)
				elif id=="yune": await explore_yune(scene)
				elif id=="danming": await explore_danming(scene)
				elif id=="kubby": await explore_kubby(scene)
				elif id=="yato": await explore_yato(scene)
				elif id=="fuwa": await explore_fuwa(scene)
				else: game._inspect_chapter(scene)
				await capture("canon_"+id+"_"+str(scene))
				if id=="dori" and scene==2: continue
				await finish_story_record()
			await capture("canon_"+id+"_complete")
			game._return_with_stella()
			while game.mode=="dialog": game._advance_dialogue()
		await capture("canon_reopening")
		print("CANON PREVIEW: 24 official record panels, 6 returns, introduction and reopening. Player save untouched.")
		quit()
		return
	if "--fan-forms-preview" in OS.get_cmdline_user_args() or "--fan-turns-preview" in OS.get_cmdline_user_args():
		var turns := "--fan-turns-preview" in OS.get_cmdline_user_args()
		var prefix := "fan_direction_" if turns else "fan_cleanup_"
		game.state=game.State.new()
		game.state.residents=["yato","danming","kubby","yune","dori","fuwa"]
		for id in game.state.residents: game.state.chapter_steps[id]=3
		game.state.scene="library"
		game.clock=1.0
		game.player_pos=Vector2(490,620)
		game._setup_map()
		game.toast_time=0
		game.mode="fan_forms"
		await capture(prefix+"cards")
		for index in range(game.MEMBERS.size()):
			var id: String=game.MEMBERS[index].id
			game.state.fan_form=id
			game.mode="play"
			game.player_pos=Vector2(620,440)
			game._setup_map()
			if turns:
				var vector: Vector2 = [Vector2.UP,Vector2.LEFT,Vector2.RIGHT,Vector2.DOWN][index%4]
				for tick in range(12): game.fan_motion.advance(id,"library",0.016,2.72,false,true,vector*2.72)
				game.moving=true
			await capture(prefix+"library_"+id)
			game.story_member=index
			game.state.active_mission=id
			game.state.chapter_steps[id]=0
			game.mode="chapter"
			game.comic_started=-1
			game.chapter_question=false
			game.player_pos=Vector2(430,560)
			game._setup_map()
			if turns:
				var vector: Vector2 = [Vector2.RIGHT,Vector2.UP,Vector2.LEFT,Vector2.DOWN][index%4]
				for tick in range(12): game.fan_motion.advance(id,"book:"+id,0.016,3.84,true,true,vector*3.84)
				game.moving=true
			await capture(prefix+"story_"+id)
			game.state.chapter_steps[id]=3
		print("Fan cleanup: six Ete cards, six library forms and six book roles captured. Player save untouched.")
		quit()
		return
	if "--visual-detail" in OS.get_cmdline_user_args():
		game.state=game.State.new()
		game.mode="play"
		game.state.scene="garden"
		game.player_pos=Vector2(300,540)
		game.clock=2.0
		game._setup_map()
		await capture("visual_garden")
		game.state.scene="library"
		for index in range(game.MEMBERS.size()):
			var id: String=game.MEMBERS[index].id
			game.story_member=index
			game.state.active_mission=id
			game.mode="chapter"
			for scene in range(4):
				game.state.chapter_steps[id]=[0,1,1,2][scene]
				game.state.marked_actions=[id] if scene==2 else []
				game.clock=3.8
				game.scene_started=0
				game.player_pos=Vector2(430,560)
				game._setup_map()
				game.toast_time=0
				await capture("visual_"+id+"_"+str(scene))
			game.comic_started=0
			game.clock=game.Comics.duration(id)
			await capture("visual_comic_"+id)
			game.comic_started=-1
		print("Visual detail: garden, all 24 chapter scenes and six comic pages captured. Player save untouched.")
		quit()
		return
	if "--library-detail" in OS.get_cmdline_user_args():
		for stage in [0,3,6]:
			game.state=game.State.new()
			game.state.residents=["yato","danming","kubby","yune","dori","fuwa"].slice(0,stage)
			for id in game.state.residents: game.state.chapter_steps[id]=3
			if stage>0:
				game.state.fan_form="yato"
				for i in range(4): game.state.place_furniture(game.Furniture.ORDER[i],game.Furniture.DEFAULTS[i])
			game.mode="play"
			game.clock=2.0
			game.player_pos=Vector2(490,620)
			game._setup_map()
			game.toast_time=0
			await capture("library_detail_stage_"+str(stage))
		for screen in ["bag","restore","encounter_shelf","title"]:
			game.mode=screen
			await capture("library_detail_"+screen)
		if "--materials-motion" in OS.get_cmdline_user_args(): await materials_motion()
		print("Library detail captures complete. Player save untouched.")
		quit(1 if failures else 0)
		return
	if "--ete-interactions-preview" in OS.get_cmdline_user_args():
		await ete_interaction_walkthrough()
		print("Ete interaction UI failures: ",failures,". Player save untouched.")
		quit(1 if failures else 0)
		return
	if "--character-touch-preview" in OS.get_cmdline_user_args():
		await character_touch_walkthrough()
		print("Character touch UI failures: ",failures,". Player save untouched.")
		quit(1 if failures else 0)
		return
	if "--stella-interactions-preview" in OS.get_cmdline_user_args():
		await stella_interactions_walkthrough()
		print("Stella authored interaction UI failures: ",failures,". Player save untouched.")
		quit(1 if failures else 0)
		return
	if "--ete-preview" in OS.get_cmdline_user_args():
		await ete_walkthrough()
		print("Ete field preview failures: ",failures,". Player save untouched.")
		quit(1 if failures else 0)
		return
	if "--furniture-only" in OS.get_cmdline_user_args():
		await furniture_walkthrough()
		print("Furniture UI walkthrough failures: ",failures,". Player save untouched.")
		quit(1 if failures else 0)
		return
	await capture("title")
	game.mode = "play"
	await capture("library")
	game.state.scene = "garden"
	game.player_pos = Vector2(300,540)
	game._setup_map()
	await capture("garden")
	game.state.scene = "library"
	game._setup_map()
	game.mode = "restore"
	await capture("restoration")
	game.mode = "help"
	await capture("help")
	game._show_dialogue(game.MEMBERS[3].name,game.MEMBERS[3].lines,Color(game.MEMBERS[3].color),3)
	await capture("dialogue")
	game.mode = "ending"
	await capture("ending")
	game.state.restored = ["yato"]
	game.state.bookmarks = 40
	game.state.energy = 68
	for screen in ["requests","loans","bag","sleep","pause","new_confirm"]:
		game.mode = screen
		await capture(screen)
	await walkthrough()
	await story_walkthrough()
	await face_walkthrough()
	await activity_walkthrough()
	await review_motion()
	await furniture_walkthrough()
	await ete_walkthrough()
	await ete_interaction_walkthrough()
	await character_touch_walkthrough()
	await stella_interactions_walkthrough()
	print("Played all six book investigations, arrivals, reopening, lending, friendship and Stella activities. Walkthrough failures: ", failures, ". Player save untouched.")
	quit(1 if failures else 0)

var failures := 0

func ete_interaction_walkthrough() -> void:
	game.state=game.State.new()
	game.state.residents=["yune"]
	game.state.chapter_steps.yune=3
	game.state.fan_form="yune"
	game.mode="play"
	game.player_pos=game.AETHE_POS+Vector2(0,75)
	game._setup_map()
	game.toast_time=0.0
	await reader_key(KEY_R)
	check(game.mode=="play","no reaction-selection panel is shown")
	var before: Dictionary = game.state.to_data().duplicate(true)
	var export_frames := "--ete-interactions-preview" in OS.get_cmdline_user_args()
	var directory := OS.get_temp_dir().path_join("lucete-ete-interaction-frames")
	if export_frames: DirAccess.make_dir_recursive_absolute(directory)
	for item in game.ete_interactions.MANIFEST.data.actions:
		# Art review uses direct calls; the player never sees a pose picker.
		game.ete_interactions.start(game,item.id)
		check(game.ete_interactions.active==item.id,"review authored animation: "+str(item.id))
		for frame in range(50 if export_frames else 3):
			game._process(.1 if export_frames else .6 if frame<2 else 5.0)
			await repaint()
			if export_frames:
				var crop: Image = root.get_texture().get_image().get_region(Rect2i(404,298,124,148))
				check(crop.save_png(directory.path_join("ete_%02d_%03d.png" % [int(item.row),frame]))==OK,"export Ete interaction crop")
			if item.id=="pet" and frame==(14 if export_frames else 1): await capture("aethe_interaction_library")
		check(game.ete_interactions.active=="","animation returns to idle: "+str(item.id))
	check(game.state.to_data()==before,"visual interaction does not consume items or advance story")
	check(game.mode=="play","art review leaves gameplay mode intact")
	game._process(1.1) # A fresh gesture starts after the previous reaction's cooldown.
	for side in [1,-1,1,-1]:
		var event := InputEventMouseMotion.new()
		event.position=game.WORLD_OFFSET+(game.Field.head_hit_rect("aethe",game.AETHE_POS).get_center()+Vector2(side*9,0))*game.WORLD_SCALE
		event.relative=Vector2(side*18*game.WORLD_SCALE,0)
		game._unhandled_input(event)
	check(game.ete_interactions.active=="pet","head strokes through real input start petting")
	game._process(.95)
	await capture("aethe_cursor_pet")
	await reader_key(KEY_E)
	check(game.mode=="missions" and game.ete_interactions.active=="","existing Ete missions still work during a reaction")

func touch_button(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position=game.WORLD_OFFSET+point*game.WORLD_SCALE
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=pressed
	root.push_input(event,true)
	await repaint()

func touch_motion(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position=game.WORLD_OFFSET+point*game.WORLD_SCALE
	event.relative=event.position-game.character_touch.pointer_screen
	root.push_input(event,true)
	await repaint()

func character_touch_walkthrough() -> void:
	game.state=game.State.new()
	game.state.residents=["yato","danming","kubby","yune","dori","fuwa"]
	for id in game.state.residents: game.state.chapter_steps[id]=3
	game.state.fan_form="yune"
	for i in range(4): game.state.place_furniture(game.Furniture.ORDER[i],game.Furniture.DEFAULTS[i])
	game.mode="play"
	game.player_pos=game.AETHE_POS+Vector2(0,75)
	game._setup_map()
	for agent in game.garden_residents.agents.values(): agent.timer=1000.0
	game.toast_time=0.0
	await repaint()
	var before: Dictionary = game.state.to_data().duplicate(true)
	var source: Vector2 = game._find_object("ete").pos+Vector2(0,-44)
	await touch_button(source,true)
	check(game.ete_interactions.active=="","press waits for click versus drag")
	await touch_button(source,false)
	check(game.mode=="play" and game.ete_interactions.active!="","world click starts random reaction without menu")
	game._process(.95)
	await capture("character_click_reaction")
	game._process(6.0)
	await touch_button(source,true)
	var target: Vector2 = game.Furniture.DEFAULTS[1]
	await touch_motion(target)
	check(game.character_touch.dragging and game.character_touch.target(game).kind=="tea","real pointer drag targets tea furniture")
	await capture("character_drag_preview")
	await touch_button(target,false)
	check(game.ete_interactions.active=="tea" and game.garden_residents.reservations.get("tea")=="ete","drop starts contextual Ete reaction")
	game._process(1.2)
	await capture("character_drop_tea")
	for i in range(600): game._process(1.0/60.0)
	check(game.character_touch.ete_visit.is_empty(),"Ete walks back after furniture use")
	var yune: Dictionary = game._find_object("yune")
	await touch_button(yune.pos+Vector2(0,-44),true)
	await touch_motion(game.Furniture.DEFAULTS[2])
	await touch_button(game.Furniture.DEFAULTS[2],false)
	check(game.garden_residents.agents.yune.phase=="use" and yune.yard_action=="yoga","Stella dragged onto mat starts yoga")
	game._process(1.5)
	await capture("character_drop_yoga")
	check(game.state.to_data()==before,"direct controls do not grant daily rewards or alter story")

func prepare_stella_review() -> void:
	game.state=game.State.new()
	game.state.residents=["yato","danming","kubby","yune","dori","fuwa"]
	for id in game.state.residents: game.state.chapter_steps[id]=3
	for i in range(4): game.state.place_furniture(game.Furniture.ORDER[i],game.Furniture.DEFAULTS[i])
	game.state.fan_form="yune"
	game.mode="play"
	game.player_pos=Vector2(490,620)
	game._setup_map()
	for a in game.garden_residents.agents.values(): a.timer=10000.0
	game.toast_time=0.0

const REVIEW_TILE:=Vector2i(132,156)

func review_region(screen_feet: Vector2) -> Rect2i:
	return Rect2i(Vector2i(screen_feet.round())-Vector2i(66,144),REVIEW_TILE)

func field_face_review() -> void:
	var board := Image.create_empty(6*REVIEW_TILE.x,3*REVIEW_TILE.y,false,Image.FORMAT_RGB8)
	var broadcast := Image.create_empty(3*395,2*320,false,Image.FORMAT_RGB8)
	var blinks: Image
	var emotions: Image
	if "--emotion-fit" in OS.get_cmdline_user_args():
		emotions=Image.create_empty(6*REVIEW_TILE.x,5*REVIEW_TILE.y,false,Image.FORMAT_RGB8)
		seed(19047)
	if "--blink-review" in OS.get_cmdline_user_args():
		blinks=Image.create_empty(6*REVIEW_TILE.x,5*REVIEW_TILE.y,false,Image.FORMAT_RGB8)
	var chair: Vector2=game.Furniture.DEFAULTS[0]
	for i in range(game.MEMBERS.size()):
		var id: String=game.MEMBERS[i].id
		prepare_stella_review()
		game.state.residents=[id]
		game._setup_map()
		game.garden_residents.agents[id].timer=1000.0
		var obj: Dictionary=game._find_object(id)
		if emotions!=null:
			# Studio greetings intentionally offer only two actions. Exercise all
			# four public-library reactions in their actual interaction context.
			game.garden_residents.leave_studio(game,obj)
			obj.pos=Vector2(550,580)
			obj.facing="down"
			obj.yard_action=""
			game.player_pos=Vector2(200,620)
			game.garden_residents.agents[id].timer=10000.0
			game.garden_residents.agents[id].public_time=10000.0
			await repaint()
			var at: Vector2=game.WORLD_OFFSET+obj.pos*game.WORLD_SCALE
			var box:=review_region(at)
			var still:=root.get_texture().get_image()
			still.convert(Image.FORMAT_RGB8)
			emotions.blit_rect(still,box,Vector2i(i*REVIEW_TILE.x,0))
			var seen: Array=[]
			var reactions: Array=game.StellaInteractions.click_actions(id)
			for attempt in range(48):
				game.character_touch.react(game,id)
				var reaction: Dictionary=game.character_touch.reactions[id]
				var name: String=reaction.id
				var action: Dictionary=game.StellaInteractions.definition(id,name)
				var peak_hold: float=(float(action.travel_seconds[2])+float(action.durations[2]))*.5
				game._process(float(action.durations[0])+float(action.durations[1])+peak_hold)
				if name not in seen:
					await repaint()
					var screen:=root.get_texture().get_image()
					screen.convert(Image.FORMAT_RGB8)
					emotions.blit_rect(screen,box,Vector2i(i*REVIEW_TILE.x,(1+reactions.find(name))*REVIEW_TILE.y))
					seen.append(name)
				game._process(3.)
				game._process(1.)
				if seen.size()==reactions.size(): break
			check(seen.size()==4,"four distinct click reactions shown: "+id)
		for pose in range(3):
			if pose==1:
				await touch_button(obj.pos+Vector2(0,-44),true)
				await touch_motion(chair)
				await touch_button(chair,false)
				check(game.garden_residents.agents[id].phase=="use","reading the placed book: "+id)
				game._process(1.35)
			elif pose==2:
				check(game.state.begin_yard_session(id,"gym"),"start field weight training: "+id)
				game._process(.5)
			await repaint()
			var view:=root.get_texture().get_image()
			view.convert(Image.FORMAT_RGB8)
			var feet: Vector2 = game.WORLD_OFFSET+obj.pos*game.WORLD_SCALE
			var area:=review_region(feet)
			board.blit_rect(view,area,Vector2i(i*REVIEW_TILE.x,pose*REVIEW_TILE.y))
		if blinks!=null:
			var beat: Array=[48,52,55,58,61]
			for n in range(beat.size()):
				var time: float=(beat[n]+.25)/game.Yard.FPS.gym
				game._process(time-float(game.state.yard_session.elapsed))
				await repaint()
				var view:=root.get_texture().get_image()
				view.convert(Image.FORMAT_RGB8)
				var feet: Vector2=game.WORLD_OFFSET+obj.pos*game.WORLD_SCALE
				blinks.blit_rect(view,review_region(feet),Vector2i(i*REVIEW_TILE.x,n*REVIEW_TILE.y))
		game.life.member_index=i
		game.life.open_chat(game)
		game.mode="stella_life"
		game.life.reply=i%2
		game.clock+=.65
		await repaint()
		var view:=root.get_texture().get_image()
		view.convert(Image.FORMAT_RGB8)
		broadcast.blit_rect(view,Rect2i(145,222,395,320),Vector2i((i%3)*395,floori(i/3.0)*320))
	check(board.save_png("res://artifacts/field_faces_game.png")==OK,"face comparison screenshot")
	if emotions!=null:
		check(emotions.save_png("res://artifacts/field_emotion_review.png")==OK,"standing emotion comparison")
	if blinks!=null:
		check(blinks.save_png("res://artifacts/field_blink_review.png")==OK,"in-game blink sequence")
	check(broadcast.save_png("res://artifacts/field_faces_broadcast.png")==OK,"broadcast face comparison screenshot")

func field_outline_review() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/stella_outline_review"))
	var strip:=Image.create_empty(5*REVIEW_TILE.x,3*REVIEW_TILE.y,false,Image.FORMAT_RGB8)
	var cases: Array=[
		["kubby","mat","hamkubby_idle",[7.00,7.15,7.30,7.45,7.59]],
		["dori","chair","shokoko_dori_idle",[.03,.12,.225,.33,.44]],
		["danming","mat","danming_origin",[0.0,.31,.67,1.04,1.46]]
	]
	for row in range(cases.size()):
		var item: Array=cases[row]
		prepare_stella_review()
		game.state.residents=[item[0]]
		game.state.costumes[item[0]]=item[2]
		game._setup_map()
		var actor: Dictionary=game._find_object(item[0])
		var station: Vector2=game.Furniture.DEFAULTS[game.Furniture.ORDER.find(item[1])]
		await repaint()
		await touch_button(actor.pos+Vector2(0,-44),true)
		await touch_motion(station)
		await touch_button(station,false)
		check(game.garden_residents.agents[item[0]].phase=="use","outline sample uses the actual furniture")
		var previous:=0.0
		for col in range(item[3].size()):
			var time: float=item[3][col]
			game._process(time-previous)
			previous=time
			await repaint()
			var view:=root.get_texture().get_image()
			view.convert(Image.FORMAT_RGB8)
			var feet: Vector2=game.WORLD_OFFSET+actor.pos*game.WORLD_SCALE
			strip.blit_rect(view,review_region(feet),Vector2i(col*REVIEW_TILE.x,row*REVIEW_TILE.y))
	check(strip.save_png("res://artifacts/stella_outline_review/in_game.png")==OK,"outline transition samples")

func materials_motion() -> void:
	prepare_stella_review()
	await repaint()
	var chair: Vector2 = game.Furniture.DEFAULTS[0]
	var mat: Vector2 = game.Furniture.DEFAULTS[2]
	var obj: Dictionary = game._find_object("dori")
	await touch_button(obj.pos+Vector2(0,-44),true)
	await touch_motion(chair)
	await touch_button(chair,false)
	check(game.garden_residents.agents.dori.phase=="use","reading on the placed chair")
	check(game.state.begin_yard_session("kubby","gym"),"weight training on the exercise mat")
	var directory := "res://artifacts/materials_motion_frames"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var panels: Array[Image] = []
	for tick in range(96):
		game._process(1.0/24.0)
		await repaint()
		var source := root.get_texture().get_image()
		var panel := Image.create_empty(480,152,false,source.get_format())
		var targets := [chair,mat]
		for i in range(targets.size()):
			var origin: Vector2 = game.WORLD_OFFSET+targets[i]*game.WORLD_SCALE-Vector2(80,103)
			panel.blit_rect(source,Rect2i(Vector2i(origin),Vector2i(160,152)),Vector2i(i*160,0))
		panels.append(panel)
	game.state.scene="garden"
	game.player_pos=Vector2(366,495)
	game._setup_map()
	game._path_to(Vector2(682,495))
	for tick in range(panels.size()):
		if tick==48: game._path_to(Vector2(366,495))
		game._process(1.0/24.0)
		await repaint()
		var source := root.get_texture().get_image()
		var origin: Vector2 = game.WORLD_OFFSET+game.player_pos*game.WORLD_SCALE-Vector2(80,103)
		panels[tick].blit_rect(source,Rect2i(Vector2i(origin),Vector2i(160,152)),Vector2i(320,0))
		check(panels[tick].save_png(directory.path_join("%03d.png" % tick))==OK,"native animation capture")

func stella_interactions_walkthrough() -> void:
	var exporting := "--stella-interactions-preview" in OS.get_cmdline_user_args()
	var directory := OS.get_temp_dir().path_join("lucete-stella-interaction-frames")
	if exporting: DirAccess.make_dir_recursive_absolute(directory)
	for index in range(6):
		var member: Dictionary = game.MEMBERS[index]
		prepare_stella_review()
		await repaint()
		var obj: Dictionary = game._find_object(member.id)
		await touch_button(obj.pos+Vector2(0,-44),true)
		await touch_button(obj.pos+Vector2(0,-44),false)
		check(game.character_touch.reactions.get(member.id,{}).get("authored",false),"real click selects personal sprite row: "+member.id)
		game._process(1.0)
		await capture("stella_click_"+member.id)
		for action_index in range(4):
			prepare_stella_review()
			await repaint()
			obj=game._find_object(member.id)
			var kind: String = game.Furniture.ORDER[action_index]
			var target: Vector2 = game.Furniture.DEFAULTS[action_index]
			await touch_button(obj.pos+Vector2(0,-44),true)
			await touch_motion(target)
			await touch_button(target,false)
			check(game.garden_residents.agents[member.id].phase=="use" and obj.yard_action==game.Furniture.ITEMS[kind].action,"real drag uses personal furniture art: "+member.id+"/"+kind)
			var source_state: Dictionary = game.state.to_data().duplicate(true)
			for frame in range(80 if exporting else 3):
				game._process(.1 if exporting else 1.3 if frame==0 else 3.3)
				await repaint()
				if frame==(13 if exporting else 0): await capture("stella_"+member.id+"_"+kind)
				if exporting:
					var origin: Vector2 = game.WORLD_OFFSET+target*game.WORLD_SCALE-Vector2(76,116)
					var crop: Image = root.get_texture().get_image().get_region(Rect2i(Vector2i(origin),Vector2i(152,160)))
					check(crop.save_png(directory.path_join("%s_%s_%02d.png" % [member.id,kind,frame]))==OK,"export actual game furniture frame")
			check(game.state.to_data()==source_state,"furniture visuals do not mutate progress: "+member.id+"/"+kind)

func ete_walkthrough() -> void:
	game.state=game.State.new()
	game.mode="play"
	game.player_pos=game.AETHE_POS+Vector2(-90,0)
	game._setup_map()
	game._update_ete_facing()
	check(game._ete_field_pose().direction=="left","Ete turns toward the player in the library")
	await capture("ete_library_facing")
	game.mode="chapter"
	game.story_member=4
	game.state.active_mission="dori"
	game.state.chapter_steps.dori=1
	game.state.marked_actions.append("dori")
	game.state.dori_notes.append("print1")
	game.dori_rubbing.lifted_at=0.0
	game.player_pos=Vector2(610,415)
	game.scene_started=0.0
	game.clock=0.0
	game._setup_map()
	var directory := OS.get_temp_dir().path_join("lucete-ete-frames")
	var export_frames := "--ete-preview" in OS.get_cmdline_user_args()
	if export_frames: DirAccess.make_dir_recursive_absolute(directory)
	for frame in range(49 if export_frames else 2):
		game.clock=frame/12.0 if export_frames else 2.1+frame*2.0
		await repaint()
		if export_frames:
			check(root.get_texture().get_image().save_png(directory.path_join("ete_%03d.png" % frame))==OK,"export Ete story motion")
		if frame==(19 if export_frames else 0): await capture("ete_story_walk")
	check(not game._ete_field_pose().walking,"Ete settles into idle after the story path")

func check_field_proportions() -> void:
	var idle: Image = game.Field.IDLE.get_image()
	var walk: Image = game.Yard.SHEETS.walk.get_image()
	var presenters: Image = game.life.stage.actor.PRESENTER_ATLAS.get_image()
	var cell: Vector2i = game.Field.CELL
	check(idle.get_size()==Vector2i(cell.x,cell.y*16),"all fifteen costumes and Ete use the same neutral cel size")
	check(game.Yard.PIXEL_SCALE==game.Field.STELLA_HEIGHT/game.Field.BODY_HEIGHT,"idle and movement share the same field pixel scale")
	for row in range(game.Field.COSTUMES.size()):
		var key: String=game.Field.COSTUMES[row]
		var chin:=int(game.life.stage.actor.PRESENTER_JOINTS.data[key].chin_y)
		var head := Rect2i(0,row*cell.y,cell.x,chin-1)
		check(idle.get_region(head).get_data()==walk.get_region(Rect2i(0,row*cell.y*2,cell.x,chin-1)).get_data(),"same fitted head when idle and starting a walk: "+game.Field.COSTUMES[row])
		var desk_row:=int(game.life.stage.actor.PRESENTER_JOINTS.data[key].row)
		var face:=Rect2i(32,row*cell.y,32,chin-1)
		var desk_face:=Rect2i(face.position+Vector2i(0,(desk_row-row)*cell.y),face.size)
		check(idle.get_region(face).get_data()==presenters.get_region(desk_face).get_data(),"broadcast uses the equipped field face pixels: "+key)
		check(idle.get_region(Rect2i(0,row*cell.y,cell.x,cell.y)).get_used_rect().has_area(),"neutral outfit pixels exist")
	var ete := idle.get_region(Rect2i(0,15*cell.y,cell.x,cell.y)).get_used_rect()
	check(ete.has_area() and ete.size.y<=90 and ete.size.x<=64 and ete.end.y<=104,"Ete fits the shared body grid and foot baseline")

func furniture_walkthrough() -> void:
	game.state = game.State.new()
	game.state.residents = ["yato","danming","kubby","yune","dori","fuwa"]
	for id in game.state.residents: game.state.chapter_steps[id]=3
	game.state.fan_form = "dori"
	game.state.scene = "library"
	game.mode = "play"
	game.player_pos = Vector2(400,580)
	game._setup_map()
	await repaint()
	await reader_key(KEY_F)
	check(game.mode=="furniture","F opens library furniture placement")
	await button("furn_suggest")
	check(game.state.furniture.size()==4,"recommended layout places four usable pieces")
	game.toast_time=0
	await capture("furniture_editor")
	await reader_key(KEY_2)
	await button("furn_toggle")
	check(not game.Furniture.find(game.state.furniture,"tea").enabled,"visible usage switch disables tea")
	await reader_key(KEY_T)
	var original: Array = game.state.furniture.duplicate(true)
	await tap(game.WORLD_OFFSET+Vector2(496,416)*game.WORLD_SCALE)
	check(original==game.state.furniture,"worktable placement rejected without losing furniture")
	await reader_key(KEY_1)
	await tap(game.WORLD_OFFSET+Vector2(192,368)*game.WORLD_SCALE)
	check(game.Furniture.find(game.state.furniture,"chair").y==368,"mouse click moves selected furniture")
	await reader_key(KEY_DELETE)
	check(game.state.furniture.size()==3,"Delete stores selected chair")
	await button("furn_suggest")
	await reader_key(KEY_ESCAPE)
	check(game.mode=="play" and game.state.furniture.size()==4,"finish returns to playable map")
	game.toast_time=0
	var directory := OS.get_temp_dir().path_join("lucete-furniture-frames")
	var export_frames := "--furniture-preview" in OS.get_cmdline_user_args()
	if export_frames: DirAccess.make_dir_recursive_absolute(directory)
	var visited := {}
	for frame in range(192):
		for tick in range(15): game._process(1.0/120.0)
		for kind in game.Furniture.ORDER:
			if game.garden_residents.occupant(kind)!="": visited[kind]=true
		if export_frames:
			await repaint()
			check(root.get_texture().get_image().save_png(directory.path_join("furniture_%03d.png" % frame))==OK,"export furniture animation")
		if frame==80: await capture("furniture_interactions")
	check(visited.size()==4,"all placed furniture receives an autonomous visitor")
	check(game.state.activities.is_empty(),"free furniture loop does not grant daily rewards")
	await reader_key(KEY_F)
	await reader_key(KEY_2)
	await reader_key(KEY_DELETE)
	await reader_key(KEY_ESCAPE)
	check(game._find_object("furniture_tea").is_empty() and not game.garden_residents.reservations.has("tea"),"removing furniture releases its occupant")
	await button("goto_portal")
	await finish_walk()
	check(game.state.scene=="garden","placed furniture leaves the garden exit reachable")

func review_motion() -> void:
	game.state = game.State.new()
	game.state.residents = ["yato","danming","kubby","yune","dori","fuwa"]
	game.state.fan_form = "yune"
	game.mode = "play"
	game.player_pos = Vector2(810,300)
	game._setup_map()
	await repaint()
	await button("goto_ete")
	await finish_walk()
	await reader_key(KEY_ESCAPE)
	check(game.mode == "play" and game.state.scene == "library","activities share the library with Ete")
	check(game.objects.filter(func(o): return o.type == "npc").size() == 6,"six unlocked field residents")
	game.toast_time = 0.0
	game._path_to(Vector2(548,530))
	var export_frames := "--yard-preview" in OS.get_cmdline_user_args()
	var directory := OS.get_temp_dir().path_join("lucete-yard-frames")
	if export_frames: DirAccess.make_dir_recursive_absolute(directory)
	var start: Vector2 = game.player_pos
	for frame in range(48 if export_frames else 8):
		for tick in range(6): game._process(1.0/48.0)
		await repaint()
		if frame == 6: await capture("garden_activities")
		if export_frames: check(root.get_texture().get_image().save_png(directory.path_join("yard_%02d.png" % frame)) == OK,"export field view")
	check(start.distance_to(game.player_pos) > 30 and game.state.activities.is_empty(),"ambient exercise allows walking and never pays daily bonuses")
	for member in game.MEMBERS:
		for key in game.Wardrobe.COSTUMES[member.id]:
			check(key in game.Yard.COSTUMES,"field frames for "+key)
	for act in game.Yard.SHEETS:
		var sheet: Image = game.Yard.SHEETS[act].get_image()
		for row in range(game.Yard.COSTUMES.size()):
			var cell: Vector2i = game.Yard.CELL
			var first := sheet.get_region(Rect2i(Vector2i(0,row*2*cell.y),cell))
			check(first.get_used_rect().has_area() and first.get_data() != sheet.get_region(Rect2i(Vector2i(18*cell.x,row*2*cell.y),cell)).get_data(),"distinct field cels for "+game.Yard.COSTUMES[row]+"/"+act)

func activity_walkthrough() -> void:
	game.state = game.State.new()
	game.mode = "play"
	game.toast_time = 0
	game._setup_map()
	await reader_key(KEY_L)
	check(game.mode == "play","activity room is closed before first return")
	await button("goto_ete")
	await finish_walk()
	await reader_key(KEY_F)
	check(game.mode == "missions","Ete's transformation service requires a return")
	await reader_key(KEY_ESCAPE)
	game.state.residents.append("dori")
	game._setup_map()
	await repaint()
	await button("goto_ete")
	await finish_walk()
	await button("fan_forms")
	await reader_key(KEY_1)
	check(game.mode == "fan_forms" and game.state.fan_form == "","locked cards cannot equip")
	await capture("ete_fan_bookmarks")
	await button("form_dori")
	check(game.mode == "play" and game.state.fan_form == "dori","equip Doldori at Ete")
	var saved_position: Vector2 = game.player_pos
	game.player_pos = Vector2(530,493)
	game.toast_time = 0
	await capture("doldori_in_library")
	game.player_pos = saved_position
	await reader_key(KEY_F)
	check(game.mode == "furniture","F opens library decorating after recruitment")
	await reader_key(KEY_ESCAPE)
	await button("goto_portal")
	await finish_walk()
	check(game.state.scene == "garden" and game.state.fan_form == "dori","chosen form travels into the garden")
	await button("goto_portal")
	await finish_walk()
	await button("goto_ete")
	await finish_walk()
	await button("offer_3")
	await button("take_mission")
	await button("story_next")
	check(game.mode == "chapter" and game.MEMBERS[game.story_member].id == "yune" and game.state.fan_form == "dori","another book uses its own fan role while retaining the equipped appearance")
	await button("chapter_leave")
	await button("close")
	check(game.mode == "play" and game.state.fan_form == "dori","on leaving the book the chosen Doldori form returns")
	await button("life_open")
	check(game.mode == "stella_life" and game.life.member_index == 4,"select first return regardless of book order")
	await reader_key(KEY_1)
	check(game.life.member_index == 4,"unrecruited Stella cannot be selected")
	await capture("stella_activity_room")
	await reader_key(KEY_T)
	await capture("workout_choices")
	await reader_key(KEY_4)
	await watch_workout("rope","stella_exercise")
	check(game.state.activity_record("dori").prepared,"field workout prepares the next broadcast")
	await reader_key(KEY_L)
	await button("life_stream")
	check(game.mode == "play" and game.state.yard_host == "dori","starting the stream places the host on the field")
	await approach_character("dori")
	check(game.life.phase == "stream","interact with field broadcaster to view chat")
	await button("life_reply_1")
	await capture("stella_broadcast")
	await button("life_signoff")
	check(game.life.phase == "result" and game.state.activity_record("dori").memory == 4,"field workout and broadcast give four memories")
	await reader_key(KEY_ESCAPE)
	await reader_key(KEY_T)
	check(game.life.phase == "roster","finished member cannot repeat a paid workout")
	await reader_key(KEY_ESCAPE)
	for routine in ["pilates","yoga","gym"]:
		game.state.sleep()
		game.player_pos = game.state.player
		game._setup_map()
		await reader_key(KEY_L)
		await reader_key(KEY_T)
		await button("life_"+routine)
		if routine == "yoga":
			game._process(4.5)
			await button("yard_cancel")
			check(game.mode == "play" and game.state.can_do_activity("dori","workout"),"cancelling on the field leaves the day's slot free")
			await reader_key(KEY_L)
			await reader_key(KEY_T)
			await button("life_yoga")
		await watch_workout(routine,"workout_"+routine)
	check(game.state.friendship.dori == 4,"four field sessions give four friendship points")
	await approach_character("ete")
	await reader_key(KEY_F)
	await reader_key(KEY_0)
	check(game.mode == "play" and game.state.fan_form == "","Ete restores traveler form")

func watch_workout(routine: String, screenshot: String) -> void:
	check(game.mode == "play" and game.state.scene == "library" and game.state.yard_session.get("routine","") == routine,"choosing "+routine+" stays inside the playable library")
	var before: Vector2 = game.player_pos
	await tap(game.WORLD_OFFSET+Vector2(600,500)*game.WORLD_SCALE)
	for tick in range(60): game._process(1.0/60.0)
	check(before.distance_to(game.player_pos)>15,"walk freely during "+routine)
	await capture(screenshot)
	await reader_key(KEY_ESCAPE)
	game._process(9.0)
	check(game.mode == "pause" and not game.state.yard_session.is_empty(),"pause suspends the session")
	await reader_key(KEY_ESCAPE)
	game._process(5.1)
	check(game.mode == "play" and game.state.yard_session.is_empty() and game.state.activity_record("dori").last_workout == routine,"finish on the map without opening a result panel")
	var record: Dictionary = game.state.activity_record("dori").duplicate()
	game._process(7.0)
	check(record == game.state.activity_record("dori"),"field practice does not repeat rewards")
	await repaint()

func face_walkthrough() -> void:
	game.state = game.State.new()
	game.state.residents = game.state.friendship.keys()
	game._setup_map()
	var tile := Rect2i(168,569,156,145)
	for i in range(game.MEMBERS.size()):
		var npc: Dictionary = game.MEMBERS[i]
		game.state.friendship[npc.id] = 7
		var obj: Dictionary = game._find_object(npc.id)
		game._interact(obj)
		await repaint()
		var neutral := root.get_texture().get_image().get_region(tile).get_data()
		await button("next")
		await button("next")
		check(game.state.read_bonds[npc.id] == 1,"first friendship scene completes for "+npc.id)
		game._interact(obj)
		await repaint()
		check(root.get_texture().get_image().get_region(tile).get_data() == neutral,"same everyday face at eight points for "+npc.id)
		await button("next")
		check(root.get_texture().get_image().get_region(tile).get_data() != neutral,"warmth belongs to the personal line for "+npc.id)
		if npc.id == "dori":
			await capture("affinity_faces")
		await button("next")
		game._interact(obj)
		await repaint()
		check(game.state.read_bonds[npc.id] == 2 and root.get_texture().get_image().get_region(tile).get_data() == neutral,"ordinary talk resumes after both scenes for "+npc.id)
	game.mode = "journal"
	game.toast_time = 0
	await capture("journal")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", label)

func repaint() -> void:
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw

func tap(point: Vector2) -> void:
	var click := InputEventMouseButton.new()
	click.position = point
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	root.push_input(click,true)
	click.pressed = false
	root.push_input(click,true)
	await repaint()

func button(id: String) -> void:
	for item in game.buttons:
		if item.id == id:
			await tap(item.rect.get_center())
			return
	check(false,"missing enabled control " + id)

func finish_story_record() -> void:
	var id: String=game.MEMBERS[game.story_member].id
	var scene: int=game._chapter_progress().debut_scene(id)
	if game.book_discovery.active(game):
		check(game.book_discovery.result_scene==scene,"the visible discovery is ready to continue")
		await reader_key(KEY_E)
		await elapse(game.book_discovery.FADE+.1)
		await elapse(game.book_discovery.FADE)
		await repaint()
		check(game.mode=="rescue" if scene==3 else game._chapter_progress().debut_scene(id)==scene+1,"discovery continues without a record or waypoint")
		return
	await button("chapter_remember")
	if scene==3: return
	check(game._chapter_progress().route_pending(id) and game._chapter_progress().debut_scene(id)==scene,"record reveals a walkable continuation")
	if "--story-trail" in OS.get_cmdline_user_args():
		await capture("story_trail_20261114/"+id+"_path_"+str(scene))
		if scene==0:
			await button("chapter_leave")
			var loaded=game.State.new()
			check(loaded.apply_data(JSON.parse_string(JSON.stringify(game.state.to_data()))),"route bookmark loads")
			game.state=loaded
			game._open_story(game.story_member,"journal")
			game._turn_story()
			await repaint()
			check(game.state.route_pending(id) and not game.chapter_question,"route resumes without replaying the fieldwork or record")
	await inspect_field_site("story_path")
	check(game._chapter_progress().debut_scene(id)==scene+1,"physical travel opens the next scene")

func elapse(seconds: float) -> void:
	game._process(seconds)

func finish_walk() -> void:
	for tick in range(1400):
		if game.pending_object == "": break
		await elapse(1.0/60.0)
	check(game.pending_object == "","automatic route finishes")
	await repaint()

func inspect_field_site(id: String) -> void:
	var obj: Dictionary=game._find_object(id)
	check(not obj.is_empty(),"visible investigation object "+id)
	if obj.is_empty(): return
	await tap(game.WORLD_OFFSET+(obj.pos-Vector2(0,10))*game.WORLD_SCALE)
	await finish_walk()

func swipe(from: Vector2,to: Vector2) -> void:
	var press:=InputEventMouseButton.new()
	press.button_index=MOUSE_BUTTON_LEFT
	press.position=from
	press.pressed=true
	root.push_input(press,true)
	var motion:=InputEventMouseMotion.new()
	motion.button_mask=MOUSE_BUTTON_MASK_LEFT
	for i in range(1,9):
		motion.position=from.lerp(to,i/8.0)
		root.push_input(motion,true)
	press.position=to
	press.pressed=false
	root.push_input(press,true)
	await repaint()

func hold_arrow(key: Key,seconds: float) -> void:
	var event:=InputEventKey.new()
	event.physical_keycode=key
	event.pressed=true
	root.push_input(event,true)
	await elapse(seconds)
	event.pressed=false
	root.push_input(event,true)
	await repaint()

func explore_fuwa(scene: int,demo: bool=false) -> void:
	if game.book_discovery.active(game):
		await DiscoveryActions.play(self,scene,demo)
		return
	await repaint()
	match scene:
		0:
			var ward=game.fuwa_snow.practice
			var start: Vector2=game.player_pos
			await tap(game.WORLD_OFFSET+(ward.FUWA-Vector2(0,43))*game.WORLD_SCALE)
			check(game.pending_object=="tenbi_together" and not game.chapter_question,"clicking Fuwa from the torii sets a walking route")
			await finish_walk()
			await elapse(ward.join_time+.05)
			await repaint()
			check(ward.phase==ward.Phase.TRACE and start.distance_to(game.player_pos)>200 and game.book_activity==null,"Tenbi reaches the on-map practice area")
			var drawn: Array=[]
			for corner in ward.DOTS: drawn.append(game.WORLD_OFFSET+corner*game.WORLD_SCALE)
			await tap(drawn[2])
			check(ward.step==0,"clicking another stone cannot start the ward")
			await swipe(drawn[0],drawn[2])
			check(ward.step==1 and ward.fraction<.15 and ward.needs_regrab,"leaving the line shows the brush-tip hint even after releasing")
			await tap(drawn[2])
			check(ward.needs_regrab,"clicking away from the brush keeps the recovery hint")
			if demo: await capture("fuwa_ward_regrab")
			await swipe(drawn[0],drawn[1])
			check(ward.step==2 and not ward.needs_regrab and game.player_pos.distance_to(ward.DOTS[1]-ward.TIP_OFFSET)<1,"re-grabbing the brush clears the hint and continues to the right corner")
			var halfway: Vector2=drawn[1].lerp(drawn[2],.52)
			await swipe(drawn[1],halfway)
			check(ward.step==2 and ward.fraction>.45 and ward.fraction<.6,"the floor line stops exactly where the player releases")
			if demo: await capture("fuwa_shrine_tracing")
			await swipe(halfway,drawn[2])
			if demo:
				await reader_key(KEY_ESCAPE)
				var restored=game.State.new()
				check(restored.apply_data(JSON.parse_string(JSON.stringify(game.state.to_data()))),"reload the painted shrine stones")
				game.state=restored
				game._open_story(5,"journal")
				game._turn_story()
				await elapse(.02)
				await elapse(ward.join_time+.03)
				check(ward.step==3 and game.player_pos==ward.tenbi_feet() and ward.tip()==ward.DOTS[2],"completed strokes and brush position return on re-entry")
			await hold_arrow(KEY_LEFT,.92)
			check(ward.phase==ward.Phase.TRACE and ward.step==4,"the ward remains open until the last stroke")
			await swipe(drawn[3],drawn[0])
			check(ward.phase==ward.Phase.BLOOM and not game.FuwaSnow.ready(0,game.state.fuwa_notes),"closing the floor mark starts Fuwa and Tenbi's shared effect")
			await elapse(1.2)
			if demo: await capture("fuwa_shrine_training")
			await elapse(1.0)
			await repaint()
			await button("ward_read")
		1:
			check(game._find_object("tenbi_pass").is_empty(),"start at Tenbi's empty place in the shrine")
			await inspect_field_site("tenbi_empty")
			await tap(game.WORLD_OFFSET+Vector2(134,218)*game.WORLD_SCALE)
			await finish_walk()
			check(game.player_pos.distance_to(game.FuwaSnow.SNOW_ENTRANCE)<1,"walking through the painted gate enters the snowy trail")
			if demo:
				await reader_key(KEY_ESCAPE)
				var restored=game.State.new()
				check(restored.apply_data(JSON.parse_string(JSON.stringify(game.state.to_data()))),"restore the mountain bookmark")
				game.state=restored
				game._open_story(5,"journal")
				game._turn_story()
				check(not game._find_object("tenbi_overlook").is_empty() and game.player_pos==game.FuwaSnow.SNOW_ENTRANCE,"the mountain is still open after re-entry")
				await repaint()
			await inspect_field_site("tenbi_overlook")
			if demo:
				await elapse(.85)
				await capture("fuwa_snow_pass")
			await inspect_field_site("tenbi_pass")
			check(game.player_pos.distance_to(game.FuwaSnow.SNOW_ENTRANCE)>400,"Tenbi walks uphill to the pass")
		2:
			await inspect_field_site("tenbi_clearing")
			await inspect_field_site("tenbi_wait")
			check("wait" in game.state.fuwa_notes and "reunited" not in game.state.fuwa_notes,"Tenbi waits and Fuwa comes to find her friend")
			var waiting_pos: Vector2=game.player_pos
			await elapse(game.FuwaSnow.REUNION_TIME*.64)
			check(game.fuwa_snow.feet(2,game.state.fuwa_notes).distance_to(waiting_pos)>70,"Fuwa approaches across the clearing")
			await elapse(game.FuwaSnow.REUNION_TIME*.45)
			check(game.player_pos==waiting_pos and game.fuwa_snow.feet(2,game.state.fuwa_notes).distance_to(waiting_pos)<70,"the reunion happens at Tenbi's actual position")
			if demo: await capture("fuwa_snow_reunion")
			await reader_key(KEY_E)
		3:
			await inspect_field_site("tenbi_spell")
			check(game.fuwa_snow.viewing and game._find_object("tenbi_shelves").is_empty(),"the hall does not exist before the spell")
			await elapse(2.0)
			check(game.fuwa_snow.frame(game)==game.FuwaSnow.RIFT_FRAME,"the animation pauses at the unexpected rift")
			await repaint()
			if demo:
				await capture("fuwa_return_rift")
				await reader_key(KEY_ESCAPE)
				await reader_key(KEY_ESCAPE)
				game._open_story(5,"journal")
				game._turn_story()
				await inspect_field_site("tenbi_spell")
				check(game.fuwa_snow.frame(game)==game.FuwaSnow.RIFT_FRAME,"the rift opens at the bookmarked moment")
			await button("fuwa_turn")
			await elapse(2.0)
			await reader_key(KEY_E)
			check(game.player_pos==game.FuwaSnow.HALL_ENTRANCE and not game.fuwa_snow.viewing,"the fourth panel becomes a walkable library")
			if demo: await capture("fuwa_waking_library")
			await inspect_field_site("tenbi_shelves")
	await repaint()

func explore_yato(scene: int,demo: bool=false) -> void:
	if game.book_discovery.active(game):
		await DiscoveryActions.play(self,scene,demo)
		return
	await repaint()
	match scene:
		0:
			await tap(game.WORLD_OFFSET+Vector2(259,478)*game.WORLD_SCALE)
			await finish_walk()
			check("trail" in game.state.yato_notes,"click a rabbit to follow it")
			if demo:
				await elapse(1.35)
				await capture("yato_rabbit_nest")
			await inspect_field_site("mato_nest")
			await inspect_field_site("mato_family")
		1:
			var room=game.yato_forest.storehouse
			check(game.player_pos==room.ENTRANCE and game._find_object("mato_truth").is_empty(),"Mato enters on foot with the family still waiting")
			await tap(game.WORLD_OFFSET+(room.BASKET-Vector2(0,29))*game.WORLD_SCALE)
			await finish_walk()
			check(room.phase==room.Phase.INSPECT and game.player_pos.distance_to(room.BASKET_SIDE)<15,"the painted basket routes Mato beside it")
			await elapse(1.14)
			if demo: await capture("yato_storehouse_supplies")
			await elapse(.55)
			check("basket" in game.state.yato_notes and not game.chapter_question,"Mato uncovers the remaining supplies on the map")
			if demo:
				await reader_key(KEY_ESCAPE)
				var restored=game.State.new()
				check(restored.apply_data(JSON.parse_string(JSON.stringify(game.state.to_data()))),"reload the inspected stores")
				game.state=restored
				game._open_story(0,"journal")
				game._turn_story()
				check(game.player_pos==room.BASKET_SIDE and not game._find_object("mato_truth").is_empty(),"the bookmark returns Mato to the open basket")
			await elapse(.75)
			await repaint()
			await tap(game.WORLD_OFFSET+(room.SPEAKER-Vector2(0,19))*game.WORLD_SCALE)
			await finish_walk()
			check(room.phase==room.Phase.FAMILY and game.book_activity==null,"clicking the rabbit brings Mato to the family on the same map")
			await elapse(room.CONFESSION+.1-room.elapsed)
			check(room.feet()==room.YATO and "truth" not in game.state.yato_notes,"the rabbit speaks before Yato steps back")
			await elapse(room.SHOCK+.45-room.elapsed)
			check(room.feet().x>room.YATO.x+6,"Yato visibly draws back on hearing the truth")
			if demo: await capture("yato_storehouse")
			await elapse(room.END)
			await repaint()
			if demo:
				await button("store_again")
				check(room.elapsed<room.CONFESSION and room.feet()==room.YATO,"replay restores Yato's listening pose")
				await elapse(room.END)
				await repaint()
				await button("store_read")
			else: await reader_key(KEY_E)
		2:
			var start: Vector2=game.player_pos
			check(game._find_object("mato_gaze").is_empty() and game._find_object("mato_village").is_empty(),"start on the mountain before the town")
			await inspect_field_site("mato_bend")
			check(game.player_pos.distance_to(start)>190 and "bend" in game.state.yato_notes,"Mato physically traverses the mountain")
			if demo: await capture("yato_mountain_walk")
			await inspect_field_site("mato_village")
			check(game.player_pos.distance_to(game.YatoForest.TOWN_START)<1 and game._find_object("mato_bend").is_empty(),"the path leads into the separate village map")
			if demo:
				await reader_key(KEY_ESCAPE)
				game._open_story(0,"journal")
				game._turn_story()
				await repaint()
				check(not game._find_object("mato_gaze").is_empty(),"the village entry survives leaving the book")
			await inspect_field_site("mato_gaze")
			if demo: await capture("yato_village_gaze")
			await reader_key(KEY_E)
		3:
			await inspect_field_site("mato_beside")
			if demo:
				await tap(game.WORLD_OFFSET+Vector2(361,580)*game.WORLD_SCALE)
				for tick in range(200): await elapse(1.0/60)
				var frozen: float=game.yato_forest.light
				await elapse(3.2)
				check(frozen<1.0 and is_equal_approx(frozen,game.yato_forest.light),"the light waits when Mato walks away")
				await inspect_field_site("mato_beside")
			for tick in range(35): await elapse(.1)
			check("light" in game.state.yato_notes and game.mode=="chapter","Yato's own light fills the field before the final record")
			if demo: await capture("yato_warm_light")
			await reader_key(KEY_E)
	await repaint()

func explore_kubby(scene: int,demo: bool=false) -> void:
	if game.book_discovery.active(game):
		await DiscoveryActions.play(self,scene,demo)
		return
	await repaint()
	match scene:
		0:
			var start: Vector2=game.player_pos
			await inspect_field_site("wisp_snow")
			await inspect_field_site("wisp_village")
			check(start.distance_to(game.player_pos)>350,"Hamnim traverses the snowy village")
		1:
			var v=game.kubby_embers.village
			check(game.player_pos==v.ENTRANCE and not v.watching,"Hamnim starts in the lower village")
			await elapse(.8)
			check(v.elapsed==0.0,"the hamster waits while Hamnim is far away")
			await tap(game.WORLD_OFFSET+(v.KUBBY-Vector2(0,46))*game.WORLD_SCALE)
			check(game.pending_object=="wisp_watch" and not v.watching,"Kubby's body click routes Hamnim through the village")
			await finish_walk()
			check(v.watching and game.book_activity==null,"arrival triggers a map event without a picture panel")
			await elapse(v.REVEAL+.4)
			check("found" in game._chapter_progress().kubby_notes and "home" not in game._chapter_progress().kubby_notes,"hamster discovery bookmarks separately")
			if demo:
				await reader_key(KEY_ESCAPE)
				var restored=game.State.new()
				check(restored.apply_data(JSON.parse_string(JSON.stringify(game.state.to_data()))),"reload the found hamster")
				game.state=restored
				game._open_story(2,"journal")
				game._turn_story()
				await elapse(.02)
				check(v.watching and v.elapsed>=v.REVEAL and v.elapsed<v.FLINCH,"the partial bookmark resumes before Kubby's reaction")
			await elapse(v.FLINCH+.25-v.elapsed)
			check(v.kubby_feet().x>v.KUBBY.x+12 and v.hamster_feet().x<v.KUBBY.x and game.player_pos.x>v.KUBBY.x,"Kubby steps away from the animal toward the witness side")
			if demo: await capture("kubby_village_hamster")
			await elapse(v.END-v.elapsed+.02)
			await repaint()
			check(game.KubbyEmbers.ready(1,game._chapter_progress().kubby_notes) and v.hamster_feet().y<v.KUBBY.y-20,"Kubby takes the same hamster")
			if demo:
				await button("village_again")
				check(v.elapsed<v.REVEAL,"the scene can be watched again before reading")
				await elapse(v.END+.01)
				await repaint()
				await button("village_read")
			else: await reader_key(KEY_E)
		2:
			await inspect_field_site("wisp_ice")
			# Follow the actual route and input loop. Keep frames for a preview of the change.
			var bank: Dictionary=game._find_object("wisp_glow")
			var frozen: float=game.kubby_embers.flow
			await elapse(.5)
			check(is_equal_approx(game.kubby_embers.flow,frozen),"a stationary reader cannot advance the transformation")
			var folder:=OS.get_temp_dir().path_join("lucete-kubby-ice-preview")
			if demo: DirAccess.make_dir_recursive_absolute(folder)
			await tap(game.WORLD_OFFSET+(bank.pos-Vector2(0,10))*game.WORLD_SCALE)
			var captured: int=-1
			var resumed:=false
			for i in range(900):
				var frame:=mini(23,floori(game.kubby_embers.flow*24))
				if demo and frame>captured:
					captured=frame
					await repaint()
					var picture:=root.get_texture().get_image()
					check(picture.save_png(folder.path_join("%02d.png"%frame))==OK,"capture playable ice trail")
					if frame==18: await capture("kubby_ice_trail")
				if demo and not resumed and frame==10:
					resumed=true
					await reader_key(KEY_ESCAPE)
					var restored=game.State.new()
					check(restored.apply_data(JSON.parse_string(JSON.stringify(game.state.to_data()))),"reload ice bookmark")
					game.state=restored
					game._open_story(2,"journal")
					game._turn_story()
					await repaint()
					check("changed" in restored.kubby_notes and "spark" not in restored.kubby_notes and is_equal_approx(game.kubby_embers.flow,game.KubbyEmbers.STOPS[1]),"Kubby changes before the hamster and reloads at that stage")
					await tap(game.WORLD_OFFSET+(bank.pos-Vector2(0,10))*game.WORLD_SCALE)
				if game.pending_object=="": break
				await elapse(1.0/60.0)
			check(game.kubby_embers.flow==1 and "glow" in game.state.kubby_notes,"walking lights the trail and transforms the hamster")
			if demo: check(resumed and captured==23,"the entire memory is played and bookmarked")
		3:
			await inspect_field_site("wisp_night")
			await elapse(1.1)
			if demo: await capture("kubby_night_trail")
			await inspect_field_site("wisp_journey")
	await repaint()

func explore_danming(scene: int,demo: bool=false) -> void:
	if game.book_discovery.active(game):
		await DiscoveryActions.play(self,scene,demo)
		return
	await repaint()
	match scene:
		0:
			check(game._field_costume_key("danming")=="danming_origin","debut uses moonlight fairy outfit")
			var start: Vector2=game.player_pos
			check(game._find_object("bee_reply").is_empty(),"reply waits for the first voice")
			await inspect_field_site("bee_voice")
			check(start.distance_to(game.player_pos)>120 and not game.chapter_question,"Beori walks across the square")
			if demo: await capture("danming_square")
			await inspect_field_site("bee_reply")
			await inspect_field_site("bee_notice")
		1:
			await tap(game.WORLD_OFFSET+Vector2(415,254)*game.WORLD_SCALE)
			await finish_walk()
			check(game.danming_workshop.view==1,"painted workbench opens by mouse")
			await swipe(Vector2(700,327),Vector2(835,327))
			check("quill" in game._chapter_progress().danming_notes and "shaft" not in game._chapter_progress().danming_notes,"cloth swipe finishes just the feathers")
			if demo:
				await reader_key(KEY_ESCAPE)
				await reader_key(KEY_ESCAPE)
				var restored=game.State.new()
				check(restored.apply_data(JSON.parse_string(JSON.stringify(game.state.to_data()))),"workbench bookmark loads")
				game.state=restored
				game._open_story(1,"journal")
				game._turn_story()
				await repaint()
				await inspect_field_site("bee_bench")
				check(is_equal_approx(game.danming_workshop.fraction,1.0/3.0),"resume at the last finished part of the arrow")
				await capture("danming_arrow")
			await hold_arrow(KEY_RIGHT,2.0)
			await reader_key(KEY_E)
		2:
			var start: Vector2=game.player_pos
			var lens=game.danming_workshop.lens
			if demo:
				await tap(game.WORLD_OFFSET+lens.POINTS[1]*game.WORLD_SCALE)
				check(game.pending_object=="bee_album" and game.danming_workshop.view<0,"the painted arrows start a walk instead of a remote inspection")
				for tick in range(31): await elapse(1.0/60.0)
				check(game.player_pos.distance_to(start)>40 and game.danming_workshop.view<0,"Beori visibly approaches through the room")
				await capture("danming_workbench_approach")
				await finish_walk()
			else: await inspect_field_site("bee_album")
			check(game.danming_workshop.view==2 and game.player_pos.distance_to(lens.STATION)<8,"only raise the loupe alongside the bench")
			await elapse(.55) # The lens is raised and the field camera has settled.
			var pointer:=InputEventMouseButton.new()
			pointer.button_index=MOUSE_BUTTON_LEFT
			pointer.position=game.WORLD_OFFSET+lens.POINTS[1]*game.WORLD_SCALE
			pointer.pressed=true
			root.push_input(pointer,true)
			for tick in range(49): await elapse(1.0/60.0)
			check("arrow_stack" not in game.state.danming_notes and lens.raised==1 and lens.studied>0,"aiming and steady observation precede the finding")
			if demo: await capture("danming_workbench_loupe")
			pointer.pressed=false
			root.push_input(pointer,true)
			check(lens.studied==0,"letting go interrupts observation")
			if demo:
				# Hold on the same arrow while the hand moves by a few pixels on every frame.
				pointer.pressed=true
				root.push_input(pointer,true)
				var jitter:=InputEventMouseMotion.new()
				jitter.button_mask=MOUSE_BUTTON_MASK_LEFT
				for tick in range(60):
					jitter.position=pointer.position+Vector2(2 if tick%2==0 else -2,1)*game.WORLD_SCALE
					root.push_input(jitter,true)
					await elapse(1.0/60)
				pointer.pressed=false
				root.push_input(pointer,true)
			else: await hold_arrow(KEY_E,1.1)
			check("arrow_stack" in game.state.danming_notes and "hand_pause" not in game.state.danming_notes,"only the inspected arrows are recorded")
			if demo:
				await reader_key(KEY_ESCAPE)
				await reader_key(KEY_ESCAPE)
				var restored=game.State.new()
				check(restored.apply_data(JSON.parse_string(JSON.stringify(game.state.to_data()))),"reload the field observation")
				game.state=restored
				game._open_story(1,"journal")
				game._turn_story()
				await repaint()
				await inspect_field_site("bee_album")
				check("arrow_stack" in restored.danming_notes and "hand_pause" not in restored.danming_notes,"the field observation survives re-entry")
			await hold_arrow(KEY_LEFT,1.0)
			await elapse(.42)
			await hold_arrow(KEY_E,1.0)
			check(game.danming_workshop.view==2 and game.DanmingWorkshop.ready(2,game.state.danming_notes),"keyboard can inspect the other end of the bench")
			if demo: await capture("danming_repeated_day")
			await button("bee_read")
		3:
			check(game._find_object("bee_threshold").is_empty(),"first inspect where Danming worked")
			await inspect_field_site("bee_empty")
			await tap(game.WORLD_OFFSET+Vector2(870,231)*game.WORLD_SCALE)
			await finish_walk()
			check(game.danming_workshop.view==3,"painted doorway opens the transition")
			await swipe(Vector2(257,334),Vector2(671,334))
			var middle: float=game.danming_workshop.fraction
			await hold_arrow(KEY_LEFT,.25)
			check(game.danming_workshop.fraction<middle and middle<1,"reader can wind the memory back")
			await hold_arrow(KEY_RIGHT,2.1)
			if demo: await capture("danming_arrival")
			await button("bee_read")

func dream_press(down: bool, mouse: bool) -> void:
	if mouse:
		var click:=InputEventMouseButton.new()
		click.position=Vector2(361,330)
		click.button_index=MOUSE_BUTTON_LEFT
		click.pressed=down
		root.push_input(click,true)
	else:
		var key:=InputEventKey.new()
		key.physical_keycode=KEY_E
		key.pressed=down
		root.push_input(key,true)

func explore_yune(scene: int, demo: bool=false) -> void:
	if game.book_discovery.active(game):
		await DiscoveryActions.play(self,scene,demo)
		return
	await repaint()
	match scene:
		0:
			await tap(game.WORLD_OFFSET+Vector2(480,215)*game.WORLD_SCALE)
			await finish_walk()
			check(game.yune_dream.view==0,"clicking the painted dreamcatcher opens the close-up")
			await tap(game.YuneDream.FEATHER)
			check("feather" not in game.state.yune_notes,"a later observation waits for the knot")
			await reader_key(KEY_1)
			if demo:
				await reader_key(KEY_ESCAPE)
				await reader_key(KEY_ESCAPE)
				var restored=game.State.new()
				check(restored.apply_data(JSON.parse_string(JSON.stringify(game.state.to_data()))),"reload dream bookmark")
				game.state=restored
				game._open_story(3,"journal")
				game._turn_story()
				await repaint()
				check("web" in restored.yune_notes and "feather" not in restored.yune_notes,"partial inspection survives leaving the book")
				await inspect_field_site("dream_loom")
			await reader_key(KEY_2)
			await elapse(1.25)
			if demo: await capture("yune_dream_birth")
			await button("dream_read")
		1:
			await inspect_field_site("dream_gold")
			check("gold" in game._chapter_progress().yune_notes and game.yune_dream.view<0,"good dream is left intact")
			await inspect_field_site("dream_shadow")
			check(game.yune_dream.view==1,"enter nightmare memory from the field")
			var directory:=OS.get_temp_dir().path_join("lucete-yune-feeding-preview")
			if demo: DirAccess.make_dir_recursive_absolute(directory)
			dream_press(true,true)
			for frame in range(34):
				if frame>0: await elapse(game.YuneDream.FEED_TIME/32.0+.0001)
				if demo and frame==12:
					dream_press(false,true)
					var frozen: float=game.yune_dream.flow
					await elapse(.4)
					check(is_equal_approx(frozen,game.yune_dream.flow) and frozen>0,"releasing pauses the interactive sequence")
					await capture("yune_dream_feeding")
					dream_press(true,false)
				if demo:
					await repaint()
					var shot:=root.get_texture().get_image().get_region(Rect2i(game.YuneDream.FRAME))
					check(shot.save_png(directory.path_join("%02d.png"%frame))==OK,"capture dream playback")
			dream_press(false,not demo)
			check("eaten" in game._chapter_progress().yune_notes and not game.yune_dream.holding,"nightmare cleared after intentional playback")
			await reader_key(KEY_E)
		2:
			var n=game.yune_dream.nights
			var notes: Array=game._chapter_progress().yune_notes
			check(game.player_pos.distance_to(n.STATION)>160 and n.fraction==0.0,"Mongchi starts in the hall")
			await elapse(1.0)
			check(n.fraction==0.0,"nights wait for Mongchi")
			await tap(game.WORLD_OFFSET+n.RING*game.WORLD_SCALE)
			check(game.pending_object=="dream_nights" and not game.chapter_question,"the painted hoop sends Mongchi through the map")
			await finish_walk()
			check(game.yune_dream.view==2 and game.book_activity==null and game.player_pos.distance_to(n.STATION)<n.REACH,"the observation starts in reach of the same hoop")
			await elapse(.75)
			if demo:
				await capture("yune_nights_first")
				await tap(game.WORLD_OFFSET+n.RING*game.WORLD_SCALE)
				var paused: float=n.fraction
				await elapse(.6)
				check(n.fraction==paused and not n.playing,"clicking the hoop pauses the nights in place")
				await reader_key(KEY_E)
			await elapse(n.DURATION*.5)
			check("bed" in notes and "window" not in notes and n.yune_tint().a<.8,"dreams and Yune fade before the final memory")
			if demo:
				await capture("yune_nights_middle")
				await reader_key(KEY_ESCAPE)
				await reader_key(KEY_ESCAPE)
				var restored=game.State.new()
				check(restored.apply_data(JSON.parse_string(JSON.stringify(game.state.to_data()))),"the night watch bookmark deserializes")
				game.state=restored
				game._open_story(3,"journal")
				game._turn_story()
				await repaint()
				check(n.fraction==.5 and game.player_pos==n.STATION and not n.playing,"midnight resumes beside the catcher")
				await reader_key(KEY_E)
				await reader_key(KEY_LEFT)
				check(n.fraction==0 and not n.playing,"Mongchi can revisit the brighter night")
				await button("night_act")
			await elapse((1.0-n.fraction)*n.DURATION+.01)
			check(n.fraction==1 and not n.playing and game.YuneDream.ready(2,game._chapter_progress().yune_notes),"the last night completes both notes and holds the scene")
			if demo:
				await capture("yune_dream_fading")
				await button("night_act")
			else: await reader_key(KEY_E)
		3:
			check(game._find_object("dream_door").is_empty(),"the light calls Yune before she walks")
			await inspect_field_site("dream_call")
			await elapse(.82)
			if demo: await capture("yune_dream_light")
			await inspect_field_site("dream_door")
			if not game.chapter_question:
				await elapse(1.9)
				await reader_key(KEY_E)

func investigate_dori(scene: int, demo: bool=false) -> void:
	await repaint()
	if scene==3:
		await inspect_field_site("leaf_3")
		if demo:
			await reader_key(KEY_2)
			check(game._dori_notebook_open() and not game.state.page_complete,"wrong memory order can be retried")
		await reader_key(KEY_3)
		if demo: await capture("dori_investigation_notebook")
		await tap(Vector2(370,403)) # Click the footprint illustration itself.
		await reader_key(KEY_2)
		return
	if scene==2:
		var r=game.dori_rubbing
		await tap(game.WORLD_OFFSET+r.rock(game)*game.WORLD_SCALE)
		check(game.pending_object=="clue_rubbing","clicking the actual sleeping stone starts the approach")
		await finish_walk()
		check(r.phase==r.Phase.RUB and game.player_pos.distance_to(r.STONE_SIDE)<r.REACH,"Doldori works beside Dori")
		await elapse(.5)
		if demo:
			var center: Vector2=game.WORLD_OFFSET+r.rock(game)*game.WORLD_SCALE
			var span:=Vector2(16,0)*float(game.WORLD_SCALE)
			await swipe(center-span,center+span)
			await capture("dori_alley_rubbing")
			await swipe(center+span,center-span)
			await swipe(center-span,center+span)
		else: await hold_arrow(KEY_E,r.RUB_TIME+.05)
		check(r.has_print(game) and r.phase==r.Phase.FIELD and not r.held_by_ete(game),"rubbing stays with Doldori while Ete approaches")
		await elapse(r.TO_STONE+r.LIFT+1.16)
		check(r.held_by_ete(game) and game._ete_field_pose().walking,"Ete carries the field stone away")
		if demo:
			await capture("dori_alley_carry")
			await reader_key(KEY_ESCAPE)
			await button("rubbing_leave")
			var restored=game.State.new()
			check(restored.apply_data(JSON.parse_string(JSON.stringify(game.state.to_data()))),"rubbing bookmark loads")
			game.state=restored
			game._open_story(4,"journal")
			game._turn_story()
			await repaint()
			check(r.has_print(game) and r.ete_feet(game)==r.ETE_END,"rubbing and held stone survive re-entry")
		await tap(game.WORLD_OFFSET+r.rock(game)*game.WORLD_SCALE)
		await finish_walk()
		await elapse(.6)
		check(r.phase==r.Phase.ALIGN,"Doldori stands beside Ete before aligning the paper")
		await reader_key(KEY_E)
		check("print3" not in game.state.dori_notes,"a misaligned impression does not match")
		if demo:
			await capture("dori_rubbing_controls")
			var initial_x: float=r.offset.x
			await hold_arrow(KEY_RIGHT,.22)
			check(r.offset.x>initial_x+5,"holding an arrow moves the rubbing beyond a single nudge")
			var target: Vector2=game.WORLD_OFFSET+r.rock(game)*game.WORLD_SCALE
			await swipe(target+r.offset*game.WORLD_SCALE,target)
		else:
			for i in range(9): await reader_key(KEY_RIGHT)
			for i in range(6): await reader_key(KEY_UP)
			await reader_key(KEY_E)
		check(r.phase==r.Phase.MATCHED,"paper outline matches the stone in Ete's arms")
		if demo: await capture("dori_alley_overlay")
		await elapse(.01)
		await finish_story_record()
		await repaint()
		check(game.state.debut_scene("dori")==3 and game._find_object("story_path").is_empty(),"matching records and advances without an extra bookmark walk")
		return
	var ids: Array=[["practice","report"],["paving","sleeper"]][scene]
	for id in ids:
		if demo and id=="practice":
			var site: Dictionary=game._find_object("clue_practice")
			await tap(game.WORLD_OFFSET+(site.pos+Vector2(0,50))*game.WORLD_SCALE)
			for tick in range(1000):
				if game.route.is_empty(): break
				await elapse(1.0/60)
			await reader_key(KEY_E)
		else: await inspect_field_site("clue_"+id)
		if demo and id=="practice":
			await capture("dori_investigation_school")
			var saved: Dictionary=game.state.to_data()
			var restored=game.State.new()
			check(restored.apply_data(JSON.parse_string(JSON.stringify(saved))) and "practice" in restored.dori_notes,"collected clue survives serialized save")
			game._leave_chapter()
			game.state=restored
			game._open_story(4,"journal")
			game._turn_story()
			await repaint()
			check("practice" in game.state.dori_notes and not "report" in game.state.dori_notes,"bookmark continues partial investigation")
		if demo and id=="paving":
			check(not game.chapter_question and not "sleeper" in game.state.dori_notes,"ordinary stone cannot unlock the record")
			game.clock=2.3
			await capture("dori_investigation_stones")

func approach_character(id: String) -> void:
	# A body click now reacts; conversation requires approaching and pressing E.
	var obj: Dictionary = game._find_object(id)
	await tap(game.WORLD_OFFSET+(obj.pos+Vector2(0,40))*game.WORLD_SCALE)
	for tick in range(1400):
		if game.route.is_empty(): break
		await elapse(1.0/60.0)
	check(game.player_pos.distance_to(obj.pos)<78,"walk to character for E interaction: "+id)
	await reader_key(KEY_E)

func experience(index: int) -> void:
	var member: Dictionary = game.MEMBERS[index]
	await button("memory_%d" % index)
	check(game.mode == "story" and game.story_page == 0,"debut page precedes "+member.id)
	await button("story_next")
	await finish_walk()
	check(game.mode == "missions" and not game._find_object("ete").is_empty(),"unassigned book leads to Aethe in the library")
	await button("offer_%d" % index)
	if index == 0: await capture("aethe_commission")
	await button("take_mission")
	check(game.mode == "story" and game.state.active_mission == member.id,"accept rescue assignment")
	await button("story_next")
	check(game.mode == "chapter","traveler enters the assigned story")
	for i in range(4):
		if "--story-trail" in OS.get_cmdline_user_args(): await capture("book_discovery_20261115/"+member.id+"_scene_"+str(i+1)+"_field")
		if member.id=="dori": await investigate_dori(i)
		elif member.id=="yune": await explore_yune(i,true)
		elif member.id=="danming": await explore_danming(i,true)
		elif member.id=="kubby": await explore_kubby(i,true)
		elif member.id=="yato": await explore_yato(i,true)
		elif member.id=="fuwa": await explore_fuwa(i,true)
		else:
			var obj: Dictionary = game._find_object("leaf_%d" % i)
			await tap(game.WORLD_OFFSET+(obj.pos-Vector2(0,10))*game.WORLD_SCALE)
			await finish_walk()
		var role: Dictionary = game.Chapters.BOOKS[member.id]
		if member.id=="dori" and i==2:
			check(game.state.debut_scene("dori")==3 and not game.chapter_question,"Dori's field discovery leads directly to the library")
			continue
		check(game.chapter_question and game.state.debut_scene(member.id)==i,"walk to each official memory for "+role.fan)
		if "--story-trail" in OS.get_cmdline_user_args(): await capture("book_discovery_20261115/"+member.id+"_scene_"+str(i+1)+"_discovery")
		if index==5 and i==1: await capture("tenbi_role")
		if index==0 and i==3:
			await reader_key(KEY_ESCAPE)
			var held_result: float=game.book_discovery.elapsed
			await elapse(10.0)
			check(game.book_discovery.paused and game.book_discovery.elapsed==held_result and not game.state.page_complete,"pausing the final discovery preserves the unsealed page")
			await reader_key(KEY_ESCAPE)
			await repaint()
			await capture("chapter_record")
		await finish_story_record()
		if i<3:
			check(not game.chapter_question and game.state.debut_scene(member.id)==i+1,"record advances for "+role.fan)
			if i==1 and index in [3,4]: await capture("debut_"+str(member.id))
		if index == 0 and i == 0:
			await capture("yato_forest")
			await button("discovery_pause")
			await button("discovery_leave")
			await button("memory_0")
			await button("story_next")
			check(game.state.chapter_steps.get("yato") == 1,"bookmark resumes at second clue")
	check(game.mode == "rescue" and game.state.page_complete and not member.id in game.state.residents,"last page restored before traveling back")
	if index == 0:
		check(game.ink_returned_at>=0,"the completed book starts its ink restoration")
		game._process(1.2)
		await capture("completed_page")
		var colored: Color = root.get_texture().get_image().get_pixel(475,511)
		check(colored.s > 0.25,"the finished page visibly restores ink to its book")
	var before_comic: Dictionary = game.state.to_data()
	await button("comic_play")
	check(game.comic_started >= 0,"comic opens for "+member.id)
	game._process(game.Comics.duration(member.id))
	await repaint()
	if index == 4: await capture("dori_comic_page")
	await button("comic_close")
	check(game.mode == "rescue" and game.comic_started < 0 and game.state.to_data() == before_comic,"reading the comic preserves the sealed page")
	await button("rescue_return")
	check(game.EncounterBooks.shelf_title(game.state,member.id) == game.EncounterBooks.VOLUMES[member.id].data.title,"completed book has its catalog title")
	check(member.id in game.state.residents and game.mode == "dialog","walk and solve unlocks "+member.id)
	check(not game._find_object("gift_"+member.id).is_empty(),"the restored room contains this book's keepsake")
	if index == 0: await capture("first_arrival")
	await button("next")
	check(game._is_ete_line(),"Aethe receives the traveler and the rescued Stella")
	if index == 0: await capture("aethe_welcome")
	await button("next")
	if game.state.residents.size() == 6:
		check(game.mode == "ending","six separate arrivals reopen the library")
		var reopened = game.State.new()
		check(reopened.apply_data(JSON.parse_string(JSON.stringify(game.state.to_data()))) and reopened.opening_pending,"reopening survives a quit during the last arrival")
		await capture("ending")
		await button("close")
		check(not game.state.opening_pending,"return to the library acknowledges reopening")
	var stage: int = game.state.rebuild_stage()
	if stage in [1,3,6]:
		game.toast_time = 0
		await capture("rebuild_%d" % stage)
	if stage == 2:
		await button("journal")
		await button("encounter_shelf")
		game._process(5.0) # Let the arrival notification clear before inspecting the shelf.
		await capture("encounter_shelf_mixed")
		var shelf_image := root.get_texture().get_image()
		for i in range(game.MEMBERS.size()):
			var spine: Dictionary = game.buttons.filter(func(b): return b.id == "encounter_%d" % i)[0]
			var sample: Vector2i = Vector2i(spine.rect.position)+Vector2i(20,51)
			var saturation := shelf_image.get_pixelv(sample).s
			var complete: bool = game.MEMBERS[i].id in game.state.residents
			check(saturation > 0.25 if complete else saturation < 0.04,"only completed spines regain color for "+game.MEMBERS[i].id)
		await button("encounter_back")
		await button("close")
	if stage == 6:
		await approach_character("ete")
		await reader_key(KEY_F)
		await capture("ete_all_fan_forms")
		await reader_key(KEY_ESCAPE)
		await reader_key(KEY_ESCAPE)
		await button("journal")
		await button("encounter_shelf")
		await capture("encounter_shelf_restored")
		await button("encounter_3")
		await capture("encounter_book_restored")
		await button("encounter_back")
		await button("encounter_back")
		await button("close")
		for npc in game.MEMBERS:
			var gift: Dictionary = game._find_object("gift_"+npc.id)
			await tap(game.WORLD_OFFSET+(gift.pos-Vector2(0,45))*game.WORLD_SCALE)
			await finish_walk()
			check(game.mode == "dialog" and game.dialogue_lines[0] == game.Chapters.BOOKS[npc.id].home,"can reach and inspect "+npc.id+"'s contribution in the full library")
			await button("next")

func story_walkthrough() -> void:
	for index in [3,4,1,2,5]:
		await button("journal")
		await experience(index)
	await button("journal")
	await button("memory_4")
	await capture("stellar_origin")
	await button("encounter_read")
	check(game.encounter_member == 4 and game.mode == "encounter_book","member debut page opens its own companion book")
	await button("encounter_back")
	check(game.mode == "story" and game.story_member == 4 and game.story_page == 0,"returns to the same debut record")
	await button("comic_play")
	await button("comic_close")
	check(game.mode == "story" and game.story_page == 0,"a completed book can reopen its comic from the shelf")
	await button("story_replay")
	check(game.mode == "chapter" and game._chapter_progress().debut_scene("dori") == 0,"completed debut reopens from the shelf")
	await button("chapter_leave")
	check(game.mode == "story" and game.state.rebuild_stage() == 6,"leaving a recollection returns to the same book")
	await button("story_sources")
	check(game.story_sources,"source notes open")
	await button("story_close")
	await button("story_next")
	await capture("stellar_scene")
	await button("story_choice_1")
	check(game.state.story_choices.get("dori",-1) == 1,"on-screen choice recorded")
	await capture("stellar_bookmark")
	await button("story_next")
	check(game.mode == "journal","return from unlocked short story to shelf")
	await button("memory_0")
	await button("costume_next")
	check(game._costume_key("yato") == "yato_idle","journal button changes the default hood to the white cape")
	var restored_state = game.State.new()
	check(restored_state.apply_data(game.state.to_data()) and restored_state.costumes.get("yato") == "yato_idle","equipped costume survives load")
	await button("story_next")
	await button("story_choice_0")
	await button("story_next")
	check(game.story_page == 3,"previously restored Yato book opens its epilogue")
	await capture("stellar_epilogue")
	await button("story_close")
	check(game.mode == "journal","journal navigation restored")

func reader_key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event,true)
	event.pressed = false
	root.push_input(event,true)
	await repaint()

func read_encounters() -> void:
	var before: Dictionary = game.state.to_data()
	await button("encounter_shelf")
	await capture("encounter_shelf")
	for index in range(game.MEMBERS.size()):
		await button("encounter_%d" % index)
		var member: Dictionary = game.MEMBERS[index]
		var volume: Dictionary = game.EncounterBooks.VOLUMES[member.id].data
		check(game.mode == "encounter_book" and game.encounter_member == index and game.encounter_page == 0,"opens "+volume.title+" before recruitment")
		await reader_key(KEY_LEFT)
		check(game.encounter_page == 0,"first leaf clamps")
		for leaf in range(volume.pages.size()):
			check(game.encounter_page == leaf,"leaf reached for "+member.id)
			if member.id == "yune" and leaf == 1:
				game._process(0.3)
				await capture("encounter_yune")
			await button("encounter_next")
		var links := 0
		for item in game.buttons:
			if item.id.begins_with("encounter_source_"): links += 1
		check(game.encounter_page == volume.pages.size() and links == volume.refs.size(),"source notes have the right references for "+member.id)
		await button("encounter_prev")
		await reader_key(KEY_E)
		await button("encounter_next")
		check(game.mode == "encounter_shelf","end returns to encounter shelf")
	await reader_key(KEY_ESCAPE)
	await reader_key(KEY_B)
	await reader_key(KEY_4)
	check(game.mode == "encounter_book" and game.MEMBERS[game.encounter_member].id == "yune","keyboard opens the selected volume")
	await reader_key(KEY_ESCAPE)
	await button("encounter_back")
	check(game.mode == "journal" and before == game.state.to_data(),"reading leaves the campaign untouched")

func walkthrough() -> void:
	game.mode = "title"
	game.save_available = false
	await repaint()
	await button("new")
	await button("next")
	check(game.mode == "dialog" and game._is_ete_line() and game.dialogue_lines[game.dialogue_index].contains("기억"),"Ete introduces the library's dependence on memory on first entry")
	await capture("ete_first_memory")
	while game.mode=="dialog": await button("next")
	check(game.mode == "play","title and intro open via mouse")
	check(game._find_object("yato").is_empty(),"empty library on first morning")
	await capture("rebuild_0")
	var shelf: Dictionary = game._find_object("shelf")
	await tap(game.WORLD_OFFSET+shelf.pos*game.WORLD_SCALE)
	await finish_walk()
	check(game.mode == "journal","physical debut bookshelf opens")
	await capture("starting_shelf")
	await read_encounters()
	await experience(0)
	await button("goto_table")
	await finish_walk()
	await button("restore")
	check(game.state.restored == ["yato"],"first book restored through visible controls")
	for i in range(2): await button("next")
	await button("requests")
	await button("claim_0")
	check(game.state.bookmarks == 40,"request paid")
	await button("close")
	await button("goto_desk")
	await finish_walk()
	await button("lend")
	check(game.state.loan_today,"loan registered at desk")
	await button("close")
	await button("bag")
	await button("tea")
	check(game.state.energy == 100 and game.state.bookmarks == 25,"tea exchanged in bag")
	await button("close")
	await button("goto_sleep")
	await finish_walk()
	await button("sleep_confirm")
	check(game.state.day == 2 and game.state.total_loans == 1 and game.state.bookmarks == 45,"first return and overnight payout")
	await button("goto_portal")
	await finish_walk()
	check(game.state.scene == "garden","portal shortcut enters garden")
	await button("goto_portal")
	await finish_walk()
	check(game.state.scene == "library","return shortcut enters library")
