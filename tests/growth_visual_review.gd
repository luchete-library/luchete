extends SceneTree
const Game=preload("res://scripts/growth_game.gd")
const OUT="res://artifacts/growth_20261116/"
var g=Game.new()
func _initialize() -> void: call_deferred("run")
func snap(name: String) -> void:
	g.toast_time=0
	g.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png")
func run() -> void:
	g.preview_mode=true
	g.persist=false
	root.add_child(g)
	await process_frame
	g.set_process(false)
	await snap("01_first_rebuild")
	g.mode="growth_ops"
	await snap("02_work_list")
	for task in ["corridor","shelves","reading"]:
		g._start_work(task)
		g.work_elapsed=8.5
		await snap("work_"+task)
		for i in range(48):
			g.work_elapsed=i*float(g.WORKS[task].seconds)/48.0
			await snap("motion_%s_%02d" % [task,i])
		g.work_elapsed=0
		g._process(g.WORKS[task].seconds+.1)
	g._action("growth_open")
	await snap("03_opened")
	g._action("promotion")
	g._action("promote_1")
	var captured:=false
	for i in range(6000):
		g._process(.1)
		if not captured and g.state.ink_visits.guests.size()==2 and g.growth.gold>=20:
			await snap("04_visitors")
			captured=true
		if g.state.ink_visits.topic<0: break
	g.growth.reward("visual-fixture-only",900,100)
	for id in ["reading_lamp","welcome_desk","lending_desk"]: g.growth.purchase("upgrade",id)
	for id in ["tea","mat","camera"]:
		g.growth.purchase("furniture",id)
		g.state.place_furniture(id,g.Furniture.DEFAULTS[g.Furniture.ORDER.find(id)])
	g._setup_map()
	g.mode="growth_shop"
	for tab in ["upgrade","furniture","costume"]:
		g.shop_tab=tab
		await snap("shop_"+tab)
	g.mode="play"
	for s in range(4):
		g.season_override=s
		await snap("season_%d"%s)
	print("GROWTH_VISUAL_REVIEW_COMPLETE")
	quit()
