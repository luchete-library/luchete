extends SceneTree
const Game=preload("res://scripts/growth_game.gd")
const OUT="res://artifacts/world_integration_20261118/"
var g
func _initialize() -> void: call_deferred("run")
func snap(name: String) -> void:
	g.toast_time=0;g.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png")
func run() -> void:
	root.size=Vector2i(1280,800)
	g=Game.new();g.persist=false
	g.save_path=OUT+"unused_visual.json";g.legacy_save_path=OUT+"unused_legacy.json"
	root.add_child(g);await process_frame
	g.set_process(false);g.background_paused=false;g.audio_enabled=false
	g._new_game()
	while g.mode=="dialog": g._action("next")
	await snap("01_abandoned")
	for member in g.MEMBERS:
		g.state.active_mission=member.id;g.state.chapter_steps[member.id]=2;g.state.page_complete=true
		g.state.record_chapter_step(member.id,2)
	g._setup_map()
	for task in ["corridor","shelves","reading"]:
		g._start_work(task)
		for step in range(1200):
			g._process(.1)
			if g.work_transition.phase=="work" and g.work_elapsed>4: break
		await snap("work_"+task)
		for step in range(1200):
			g._process(.1)
			if g.mode!="growth_work": break
		await snap("after_"+task)
	g._action("growth_open");g._action("close")
	for amount in [0,30,100,250]:
		g.growth.reward("visual_"+str(amount),0,amount-g.growth.memory_light)
		await snap("growth_"+str(amount))
	g.world.change_area(g,true)
	await snap("personal_spaces")
	root.size=Vector2i(960,600)
	await snap("personal_spaces_960")
	g.character_touch.react(g,"yune")
	await snap("personal_expression_960")
	assert(not g.character_focus.last_sample.is_empty())
	g.character_touch.reactions.clear()
	g.world.change_area(g,false)
	await snap("library_960")
	root.size=Vector2i(1280,800)
	g.state.minutes=600
	g.state.ink_visits.start(g.state,0)
	for step in range(2400):
		g._process(.1)
		if g.state.ink_visits.guests.any(func(guest): return guest.phase=="read"):
			await snap("library_in_use")
			break
	for season in range(4):
		g.state.day=season*7+1
		await snap("season_"+str(season))
	print("WORLD_VISUAL_COMPLETE")
	quit()
