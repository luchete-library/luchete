extends "res://tests/growth_production_flow.gd"

var shot := 0

func repaint() -> void:
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw

func capture(name: String) -> void:
	await repaint()
	var path := "res://artifacts/polish_20261118/story_%02d_%s.png" % [shot,name]
	shot+=1
	check(root.get_texture().get_image().save_png(path)==OK,"capture "+name)

func button(id: String) -> void:
	if id=="journal":
		await reader_key(KEY_J)
		return
	await repaint()
	for item in game.buttons:
		if item.id==id:
			await tap(item.rect.get_center())
			return
	check(false,"real rendered control missing: "+id+" mode="+game.mode)

func inspect_field_site(id: String) -> void:
	var obj: Dictionary=game._find_object(id)
	check(not obj.is_empty(),"visible object "+id)
	if obj.is_empty(): return
	await repaint()
	await tap(game.WORLD_OFFSET+(obj.pos-Vector2(0,10))*game.WORLD_SCALE)
	await finish_walk()
	if id in ["bee_album","dream_nights","wisp_watch","mato_truth","tenbi_together"]:
		await capture(id)

func play_book(index: int) -> void:
	var member: Dictionary=game.MEMBERS[index]
	await button("journal")
	await button("memory_%d"%index)
	await button("story_next")
	await finish_walk()
	check(game.mode=="missions","rendered book points to Ete for "+member.id)
	await button("offer_%d"%index)
	await button("take_mission")
	await button("story_next")
	check(game.mode=="chapter","rendered commission starts "+member.id)
	for scene in range(4):
		await capture("%s_%d_entry"%[member.id,scene+1])
		match member.id:
			"dori": await investigate_dori(scene)
			"yune": await explore_yune(scene)
			"danming": await explore_danming(scene)
			"kubby": await explore_kubby(scene)
			"yato": await explore_yato(scene)
			"fuwa": await explore_fuwa(scene)
		await capture("%s_%d_result"%[member.id,scene+1])
		if member.id=="dori" and scene==2: continue
		var discovery=game.book_discovery
		check(discovery.result_scene==scene,"manual result exists for "+member.id)
		await elapse(30)
		check(game.state.debut_scene(member.id)==scene,"record never expires before reader chooses for "+member.id)
		await button("discovery_review")
		check(discovery.reviewing and not game.chapter_question,"return to field keeps the completed memory")
		await button("discovery_review")
		check(not discovery.reviewing and game.chapter_question,"return to record restores the reader")
		var saved:=JSON.stringify(game.state.to_data())
		var loaded=Adapter.new()
		check(loaded.apply_data(JSON.parse_string(saved)),"complete observation reloads from JSON")
		game.state=loaded
		game.growth=loaded.growth
		game._enter_chapter(member.id)
		await elapse(.01)
		check(discovery.result_scene==scene and game._find_object("story_path").is_empty(),"resume keeps completed record without a repeated waypoint")
		await finish_story_record()
	check(game.mode=="rescue","all visible chapter inputs reach rescue "+member.id)
	await button("rescue_return")
	for line in range(12):
		if game.mode!="dialog": break
		await button("next")
	print("REAL STORY UI COMPLETE ",member.id," failures=",failures)

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts/polish_20261118")
	var normal_before:=snapshot_file(Production.State.SAVE_PATH)
	var production_before:=snapshot_file(Production.PRODUCTION_SAVE)
	var preview_before:=snapshot_file(Production.PREVIEW_SAVE)
	root.size=Vector2i(1280,800)
	game=Production.new()
	game.persist=false
	game.save_path="res://artifacts/polish_20261118/story_ui_unused.json"
	game.legacy_save_path="res://artifacts/polish_20261118/story_ui_legacy_unused.json"
	root.add_child(game)
	game.set_process(false)
	game.audio_enabled=false
	await repaint()
	await button("new")
	await capture("intro")
	for line in range(12):
		if game.mode!="dialog": break
		await button("next")
	for index in [4,3,1,2,0,5]:
		await play_book(index)
		if failures>0: break
	await capture("end")
	check(snapshot_file(Production.State.SAVE_PATH)==normal_before,"normal user save unchanged")
	check(snapshot_file(Production.PRODUCTION_SAVE)==production_before,"production user save unchanged")
	check(snapshot_file(Production.PREVIEW_SAVE)==preview_before,"preview user save unchanged")
	print("STORY REAL INPUT AUDIT ",checks," checks; ",failures," failures; ",shot," images")
	game.free()
	quit(1 if failures else 0)
