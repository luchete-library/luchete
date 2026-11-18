extends "res://tests/library_day_flow.gd"

func run() -> void:
	fresh()
	# A previously saved library can have no daily activity data yet. Reading
	# or paused menus must never initialize or clear it as a side effect.
	g.state.library_day.day=0
	for modal in ["story","journal","promotion","pause","world_notebook","growth_ops"]:
		g.mode=modal
		var before: Dictionary=g.state.to_data()
		step(2)
		check(g.state.to_data()==before,"read-only or paused view preserves all saved state: "+modal)
	g.mode="story";g.story_member=0;g._action("comic_play")
	var before_comic: Dictionary=g.state.to_data()
	step(3)
	check(g.state.to_data()==before_comic,"first comic playback does not initialize daily work")
	g.comic_started=-1;g.comic_player.reset();g.mode="play"
	step(.1)
	check(g.state.library_day.day==g.state.day,"daily work initializes when live play resumes")
	for m in g.MEMBERS:
		for kind in ["chair","tea"]:
			fresh()
			var previous: Dictionary=g.state.to_data()
			previous.library_day.memories={m.id:{"book":1,"day":g.state.day,"helped":true,"seen":false}}
			check(g.state.apply_data(previous),"old follow-up save loads for "+m.id+"/"+kind)
			g.growth=g.state.growth
			if kind not in g.growth.owned_furniture: g.growth.owned_furniture.append(kind)
			g.state.place_furniture(kind,Layout.FURNITURE[kind]);g._setup_map()
			g.state.fan_form=m.id
			var npc: Dictionary=g._find_object(m.id)
			npc.in_studio=false;npc.pos=Vector2(840,688)
			g.player_pos=Layout.FURNITURE[kind]+Vector2(52,16)
			g.character_touch.held=m.id;g.character_touch.pointer_screen=Layout.FURNITURE[kind];g.character_touch.grab_offset=Vector2.ZERO
			g.character_touch.drop(g);g.character_touch.cancel()
			check(g.garden_residents.occupant(kind)==m.id,"ordinary furniture drop still reserves seat")
			g.shared.begin(g,m.id)
			check(g.mode=="together","shared activity starts after old-save migration")
			var expected: String=g.FanRecognition.line(m.id,m.id,kind,g.SharedActivity.LINES[m.id][0 if kind=="chair" else 1])
			check(g.shared.activity_line==expected,"original fan-form dialogue is used: "+m.id+"/"+kind)
			step(12)
			check(g.mode=="play","shared activity returns control")
	for topic in range(3):
		fresh();g.save_path="res://artifacts/regression_20261118/mid_action_%d.json"%topic
		g.state.library_day.carried.assign([1,1])
		select_topic(4,topic);reach_station();g._action("day_pick_1");reach_station()
		if g.mode=="day_choice": g._action("day_pick_0")
		step(1)
		check(g.mode=="day_action","save case is inside a running action")
		g.persist=true;g._save();g.persist=false
		check(not g.save_failed,"mid-action snapshot written to isolated slot")
		g._continue_game()
		check(g.mode=="day_promotion" and g.state.library_day.direct.stage==1,"reload restarts unfinished stage without granting rewards")
		check(g.state.library_day.carried==[1,1] and g.state.fan_form=="dori","carried books and original avatar survive possession reload")
		g._action("day_handback");step(180)
		check(g.state.ink_visits.topic<0 and g.state.library_day.direct.is_empty(),"resumed campaign finishes through assignment")
		check(g.state.library_day.carried==[1,1],"assignment does not consume the player's carried books")
		check(g.growth.memory_light==(10 if topic==0 else 0 if topic==1 else 10),"broadcast and usage rewards settle once after reload")
		check(g._find_object("dori").get("direct_control",false)==false,"NPC autonomy returns after reload and handoff")
	print("LIBRARY_DAY_SIDE_EFFECTS: ",count," checks; failures=",failures)
	g.free();quit(1 if failures else 0)
