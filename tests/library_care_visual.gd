extends "res://tests/library_day_flow.gd"
const DEST:="res://artifacts/library_care_20261118/"
func snap(name: String,crop: Rect2i=Rect2i()) -> void:
	g.toast_time=0;g.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var frame:=root.get_texture().get_image()
	if crop.has_area(): frame=frame.get_region(crop)
	frame.save_png(DEST+name+".png")
func run() -> void:
	root.size=Vector2i(1280,800)
	fresh();g.growth.reward("visual",500,250);g.player_pos=Vector2(560,648)
	await snap("01_clean")
	g.state.library_day.returned.assign([0,0,0,1,1,1]);g.state.library_day.dirty.assign([0,1])
	g.state.library_day.grime.assign([1,1,1,1,1,1,1,1]);g.library_day_flow.sync_targets(g)
	await snap("02_dust")
	g.state.library_day.grime.assign([3,3,3,3,3,3,3,3]);g.library_day_flow.sync_targets(g)
	await snap("03_neglected")
	g.player_pos=Vector2(552,432);g._interact(g._find_object("day_floor_1"));step(1.1)
	await snap("04_mopping")
	step(2.5);g.player_pos=Vector2(296,560)
	g.state.library_day.neglect_seconds=120;g.state.library_day.ete_warned=false
	g.library_day_flow.update(g,.1);g.library_day_flow.ete_elapsed=1.2
	print("ETE_REACTION_STATE: ",g.ete_interactions.active," / ",g.character_touch.ete_visit," / ",g.character_touch.held," / ",g.library_day_flow.enabled(g))
	await snap("05_ete_warning")
	await snap("05_ete_detail",Rect2i(164,384,144,164))
	for i in range(4):
		g.library_day_flow.ete_elapsed=.5+i*.65
		await snap("ete_frame_%d"%i,Rect2i(164,384,144,164))
	fresh();g.growth.reward("visual",500,250)
	var guest: Dictionary=g.state.ink_visits._guest(0,"read","dori")
	guest.temperament=0;guest.request=true;guest.admitted=true;guest.phase="browse";guest.pos=Vector2(376,328);guest.source_host="dori";guest.feature=1
	g.state.ink_visits.guests.append(guest);g.player_pos=Vector2(376,368);g.library_day_flow.sync_targets(g)
	g._interact(g._find_object("day_ink_%d"%guest.uid))
	await snap("06_reader_clue")
	root.size=Vector2i(960,600)
	await snap("06_reader_clue_960")
	root.size=Vector2i(1280,800)
	g._action("day_pick_0");step(80)
	await snap("07_recommended")
	# Characters deliberately overlap shelf/table silhouettes for the review.
	fresh();g.growth.reward("visual",500,250)
	for i in range(6):
		var npc: Dictionary=g._find_object(g.MEMBERS[i].id)
		npc.in_studio=false;npc.pos=[Vector2(376,278),Vector2(672,276),Vector2(416,408),Vector2(720,408),Vector2(432,520),Vector2(992,392)][i]
		npc.yard_action="idle";npc.facing="down"
	g.player_pos=Vector2(560,648)
	await snap("08_characters_first")
	root.size=Vector2i(960,600)
	await snap("08_characters_first_960")
	print("LIBRARY_CARE_VISUAL_COMPLETE")
	g.free();quit()
