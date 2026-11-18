extends "res://tests/book_discovery.gd"

func run() -> void:
	root.size=Vector2i(1280,800)
	game=PreviewGame.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.audio_enabled=false
	game.save_available=false
	for entry in [["yune",1],["yune",2],["kubby",1],["yato",1],["yato",3],["fuwa",2]]:
		var id: String=entry[0]
		game._leave_chapter()
		await start_scene(id,entry[1])
		match id+str(entry[1]):
			"yune1":
				await inspect_field_site("dream_gold")
				await inspect_field_site("dream_shadow")
				await elapse(.2)
			"yune2":
				await inspect_field_site("dream_nights")
				await elapse(1)
			"kubby1":
				await inspect_field_site("wisp_watch")
				await elapse(.9)
			"yato1":
				await inspect_field_site("mato_basket")
				await elapse(game.yato_forest.storehouse.UNFOLD_TIME+.03)
				await inspect_field_site("mato_truth")
			"yato3": await inspect_field_site("mato_beside")
			"fuwa2":
				await inspect_field_site("tenbi_clearing")
				await inspect_field_site("tenbi_wait")
		var before: Array=game.state.get(id+"_notes").duplicate()
		await button("discovery_detail")
		check_case(game.book_discovery.detail_time>0,"optional observation immediately highlights the existing visual: "+id)
		check_case(game.state.get(id+"_notes")==before,"optional looking creates no mandatory objective or invented outcome: "+id)
		await capture("polish_20261118/optional_"+id+str(entry[1]+1))
		await elapse(7)
		check_case(game.book_discovery.detail_time==0,"optional description releases the normal narration")
	game._leave_chapter()
	await start_scene("danming",0)
	await DiscoveryActions.play(self,0)
	check_case(not game.book_discovery.automatic,"manual next is the session default")
	await button("discovery_auto")
	await elapse(game.book_discovery.duration+.01)
	await elapse(game.book_discovery.FADE+.01)
	check_case(game.state.debut_scene("danming")==1 and game.book_discovery.automatic,"optional auto advance remains chosen for later chapters")
	game.book_discovery.automatic=false
	print("STORY OBSERVATION POLISH: ",cases," checks; ",failures," failures; six optional observations and session-only auto advance")
	game.free()
	quit(1 if failures else 0)
