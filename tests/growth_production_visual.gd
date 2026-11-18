extends SceneTree

const Scene=preload("res://main.tscn")
const OUT="res://artifacts/growth_rollout_20261117/"
var g: Node2D

func _initialize() -> void: call_deferred("run")

func snap(name: String) -> void:
	g.toast_time=0
	g.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png")

func run() -> void:
	g=Scene.instantiate()
	assert(g.get_script().resource_path=="res://scripts/growth_game.gd")
	g.persist=false
	g.save_path=OUT+"visual_readonly_slot.json"
	g.legacy_save_path=OUT+"legacy_save_before.json"
	root.add_child(g)
	await process_frame
	g.set_process(false)
	g.audio_enabled=false
	assert(not g.preview_mode and g.mode=="title")
	await snap("01_main_title")
	g._action("continue")
	assert(g.state.residents.size()==2 and g.growth.phase=="recruiting")
	await snap("02_legacy_two_residents")
	g._action("growth_ops")
	await snap("03_ete_missions")
	g._new_game()
	await snap("04_new_intro")
	while g.mode=="dialog": g._action("next")
	await snap("05_new_empty_library")
	for member in g.MEMBERS:
		g.state.active_mission=member.id
		g.state.chapter_steps[member.id]=2
		g.state.page_complete=true
		g.state.record_chapter_step(member.id,2)
	g._setup_map()
	g._action("growth_ops")
	await snap("06_reconstruction_list")
	for task in ["corridor","reading","shelves"]:
		g._start_work(task)
		g.work_elapsed=8.5
		await snap("work_"+task)
		g.work_elapsed=0
		g._process(g.WORKS[task].seconds+.1)
		await snap("after_"+task)
	g._action("growth_open")
	assert(g.mode=="ending")
	await snap("07_opening")
	g._action("close")
	g._action("promotion")
	g._action("promote_2")
	var captured:=false
	for tick in range(2400):
		g._process(.1)
		for guest in g.state.ink_visits.guests:
			if not captured and guest.phase in ["read","checkout"]:
				await snap("08_visitors_read_and_borrow")
				captured=true
		if g.state.ink_visits.topic<0: break
	g._action("growth_ledger")
	await snap("09_ledger")
	# Rendering fixtures only; no player save or actual balance is changed.
	g.growth.reward("render-only",900,100)
	g.mode="growth_shop"
	for tab in ["upgrade","furniture","costume"]:
		g.shop_tab=tab
		await snap("shop_"+tab)
	for kind in ["tea","mat","camera"]:
		g.growth.purchase("furniture",kind)
		g.state.place_furniture(kind,g.Furniture.DEFAULTS[g.Furniture.ORDER.find(kind)])
	g.mode="play"
	g._setup_map()
	for season in range(4):
		g.state.day=season*7+1
		await snap("season_%d"%season)
	g._action("growth_ops")
	await snap("10_operating_notebook")
	assert(not g.preview_mode)
	g._action("growth_season_0")
	assert(g.season_override==-1)
	print("PRODUCTION_VISUAL_COMPLETE: main scene, initial/migrated library, reverse-order construction, opening, visitors, shop, four actual calendar seasons. No player saves written.")
	quit()
