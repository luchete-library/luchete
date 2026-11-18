extends "res://tests/completeness_ui.gd"
const OUTREACH_OUT:="res://artifacts/outreach_20261118/"
func snap(name: String) -> void:
	g.toast_time=0;g.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
	check(g.label_issues.is_empty(),"button labels fit: "+name)
	for b in g.buttons: check(Rect2(0,0,1280,800).encloses(b.rect),"button remains on screen: "+b.id)
	root.get_texture().get_image().save_png(OUTREACH_OUT+name+".png")
func run() -> void:
	for size in [Vector2i(1280,800),Vector2i(960,600)]:
		root.size=size;fresh()
		var suffix: String="_%d"%size.x
		check(g.mode=="dialog","first-opening Ete guidance shown")
		await snap("ete_guide"+suffix)
		for i in range(6):
			if g.mode=="dialog": g._action("next")
		check(g.mode=="promotion","guide enters promotion")
		for topic in range(3):
			g.library_day_flow.topic=topic;await snap("promotion_%d"%topic+suffix)
		g.library_day_flow.topic=0;g._action("day_assign")
		step(180)
		g._action("growth_ops");await snap("operations"+suffix)
		g.mode="play"
		var v: Dictionary=g.state.ink_visits._guest(0,"read","dori")
		v.pos=Vector2(376,328);v.origin="promotion";v.source_host="dori";v.phase="browse";v.request=true;v.admitted=true;v.feature=0;v.temperament=0;v.reading_goal=1
		g.state.ink_visits.guests.append(v)
		g.library_day_flow.selected_uid=v.uid;g.library_day_flow.choice="request";g.mode="day_choice"
		await snap("recommendation"+suffix)
		g._action("day_pick_1");step(80)
		g.mode="growth_summary";await snap("summary"+suffix)
	print("OUTREACH UI: ",count," checks; failures=",failures)
	g.free();quit(1 if failures else 0)
