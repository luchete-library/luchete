extends "res://tests/library_day_flow.gd"
func snap(name: String) -> void:
	g.toast_time=0;g.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png")
func run() -> void:
	root.size=Vector2i(1280,800)
	fresh();g.growth.reward("visual",500,250)
	g.mode="promotion"
	await snap("01_promotion")
	g._action("day_direct")
	await snap("02_control_dori")
	reach_station();g._action("day_pick_0");reach_station();step(1.3)
	await snap("03_book_motion")
	step(2);reach_station()
	await snap("04_chat")
	root.size=Vector2i(960,600)
	await snap("04_chat_960")
	root.size=Vector2i(1280,800)
	g._action("day_pick_0");step(3.2)
	var request: Dictionary={}
	for i in range(1800):
		g._process(.1)
		for v in g.state.ink_visits.guests:
			if v.phase=="browse" and v.get("request",false): request=v;break
		if not request.is_empty(): break
	if not request.is_empty():
		g.player_pos=request.pos+Vector2(0,50);g.library_day_flow.sync_targets(g)
		await snap("05_visitor_request")
		g._interact(g._find_object("day_ink_%d"%request.uid))
		await snap("06_recommend")
		g._action("day_pick_0");step(80)
	g.state.library_day.returned.assign([0,0,0,1]);g.library_day_flow.sync_targets(g)
	g._go_to(g._find_object("day_cart"));step(60)
	await snap("07_carried_books")
	g._go_to(g._find_object("day_shelf"))
	for i in range(1000):
		g._process(.1)
		if g.mode=="day_action": break
	step(1)
	await snap("08_shelving")
	step(3)
	var host: Dictionary=g._find_object("dori")
	host.in_studio=false;host.pos=Vector2(840,688);g.player_pos=host.pos+Vector2(48,0)
	g._interact(host)
	await snap("09_ordinary_dialogue")
	while g.mode=="dialog": g._action("next")
	g.state.library_day.dirty.assign([0]);g.library_day_flow.sync_targets(g)
	g._go_to(g._find_object("day_seat_0"))
	for i in range(1000):
		g._process(.1)
		if g.mode=="day_action": break
	step(1);await snap("10_tidy")
	fresh();select_topic(5,1);reach_station();g._action("day_pick_1");reach_station();g._action("day_pick_0");step(1)
	await snap("11_leaflet")
	fresh();select_topic(2,2);reach_station();g._action("day_pick_1");reach_station();step(1)
	await snap("12_performance")
	for i in range(6):
		fresh();select_topic(i,0);reach_station();g._action("day_pick_0");reach_station();step(1.3)
		await snap("member_"+g.MEMBERS[i].id)
	print("LIBRARY_DAY_VISUAL_COMPLETE")
	quit()
