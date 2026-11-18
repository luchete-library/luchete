extends SceneTree
const Game = preload("res://scripts/growth_game.gd")
const Adapter = preload("res://scripts/growth_state_adapter.gd")
const Layout = preload("res://scripts/library_world_layout.gd")
const OUT = "res://artifacts/library_day_20261118/"
var g
var count := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	count+=1
	if not ok: failures+=1;push_error(label)
func step(seconds: float) -> void:
	for i in range(ceili(seconds/.1)): g._process(.1)
func fresh() -> void:
	if is_instance_valid(g): g.free()
	g=Game.new();g.persist=false;g.save_path=OUT+"isolated.json";g.legacy_save_path=OUT+"absent.json"
	root.add_child(g);g.set_process(false);g.audio_enabled=false;g.background_paused=false
	g.mode="play";g.state.intro_seen=true
	for m in g.MEMBERS:
		g.state.active_mission=m.id;g.state.chapter_steps[m.id]=2;g.state.page_complete=true;g.state.record_chapter_step(m.id,2)
	for task in ["corridor","shelves","reading"]: g.state.complete_reconstruction_task(task)
	g._setup_map();g._action("growth_open");g._action("close")
	# This fixture begins after Ete's first-opening tutorial. Its rendered
	# dialogue-to-promotion transition is covered separately by outreach tests.
	g.mode="play"
	g.state.minutes=600;g.state.operating.begin(g.state)
	# Isolate the 18 member/topic action cases from ambient walk-ins.
	# Full-day/outreach tests explicitly restore the normal daily schedule.
	g.state.ink_visits.appointments.clear()
	g.state.fan_form="dori";g.state.library_day.ensure(g.state.day)
func reach_station() -> void:
	var flow=g.library_day_flow
	var target: Dictionary=g._find_object("day_station")
	check(not target.is_empty(),"promotion stage has target")
	var path: PackedVector2Array=Layout.path(g.navigation,g.player_pos,target.pos)
	check(not path.is_empty() and path[-1].distance_to(target.pos)<62,"promotion target walkable")
	g._go_to(target)
	for i in range(700):
		g._process(.1)
		if g.mode!="day_promotion": break
	check(g.mode in ["day_choice","day_action"],"walking reaches stage without teleport")
func select_topic(member: int, topic: int) -> void:
	g.mode="promotion";g._action("day_member_%d"%member);g._action("day_topic_%d"%topic);g._action("day_direct")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for member in range(6):
		for topic in range(3):
			fresh()
			var origin: Vector2=g.player_pos
			select_topic(member,topic)
			check(g.mode=="day_promotion" and g.state.operating.used_slots.size()==1,"one shared slot for direct %s/%d"%[g.MEMBERS[member].id,topic])
			var host: Dictionary=g._find_object(g.MEMBERS[member].id)
			check(host.get("direct_control",false),"host movement claimed")
			step(7)
			check(g.state.ink_visits.topic==topic,"direct campaign does not autocomplete")
			reach_station();g._action("day_pick_1")
			check(g.state.library_day.direct.book==1 and g.state.library_day.direct.stage==1,"book selection changes stage and source")
			g._save()
			var saved: Dictionary=JSON.parse_string(JSON.stringify(g.state.to_data()))
			var loaded:=Adapter.new()
			check(loaded.apply_data(saved),"direct intermediate save accepts JSON roundtrip")
			check(loaded.fan_form=="dori" and loaded.library_day.direct.member==g.MEMBERS[member].id,"player identity independent of controlled host")
			reach_station()
			if g.mode=="day_choice": g._action("day_pick_0")
			step(3.2)
			check(g.mode=="day_promotion" and g.state.library_day.direct.stage==2,"first visible action leads to next task")
			reach_station();g._action("day_pick_1");step(3.2)
			check(g.mode=="play" and g.state.library_day.direct.is_empty() and g.state.ink_visits.topic==-1,"direct finished")
			check(g.state.fan_form=="dori" and g.player_pos.distance_to(origin)<24,"returns original fan and origin")
			check(not host.get("direct_control",false),"host autonomy released")
			var unadmitted: int=g.state.ink_visits.guests.filter(func(v): return not v.admitted).size()
			check(g.state.ink_visits.appointments.size()+g.state.ink_visits.total+unadmitted==[3,4,5][topic],"same invited guests as assigned")
			for a in g.state.ink_visits.appointments:
				check(a.feature==1 and a.source_host==host.id,"featured book and host reach reservations")
			check(g.growth.memory_light==(3 if topic==0 else 0),"only broadcast completion light")
			g.library_day_flow.end_direct(g,false)
			check(g.growth.memory_light==(3 if topic==0 else 0),"finish cannot pay twice")
			var decoder:=Adapter.new();check(decoder.apply_data(g.state.to_data()),"finished state reload")
	fresh();select_topic(4,0);reach_station();g._action("day_pick_0")
	g.persist=true;g._save();g.persist=false
	check(not g.save_failed,"isolated mid-broadcast file saved")
	g._continue_game()
	check(g.mode=="day_promotion" and g.state.library_day.direct.stage==1,"continue resumes stage and control")
	g._action("day_handback")
	check(g.mode=="play" and g.state.ink_visits.topic==0 and not g.state.ink_visits.direct_campaign,"handoff preserves same campaign")
	step(180)
	check(g.state.ink_visits.topic<0 and g.state.ink_visits.total==3,"assigned continuation completes and visitors self serve")
	check(g.growth.gold==45 and g.growth.memory_light==10,"optional events do not change normal economy")
	check(not g.state.library_day.returned.is_empty() and not g.state.library_day.dirty.is_empty(),"actual reading creates bounded housework")
	check(not g.state.library_day.data().has("memories"),"completed visit does not create follow-up dialogue records")
	g.state.minutes=840
	g.mode="promotion";g._action("day_topic_1");g._action("day_assign")
	check(g.state.operating.used_slots.size()==2,"assignment shares second slot")
	step(150);g.mode="promotion"
	check(g.library_day_flow.error(g)!="","third promotion rejected")
	g.mode="play"
	var before_gold: int=g.growth.gold
	var before_light: int=g.growth.memory_light
	g.state.library_day.returned.assign([0,0,0,1,1]);g.library_day_flow.sync_targets(g)
	g._go_to(g._find_object("day_cart"));step(60)
	check(g.state.library_day.carried.size()==3 and g.state.library_day.returned.size()==2,"batch pickup matches marks")
	g._go_to(g._find_object("day_shelf"));step(60)
	check(g.state.library_day.carried.is_empty() and g.state.library_day.tidied>=3,"walk then shelve visible action")
	g.state.library_day.dirty.assign([0]);g.library_day_flow.sync_targets(g)
	g._go_to(g._find_object("day_seat_0"));step(60)
	check(g.state.library_day.dirty.is_empty(),"walk then tidy used seat")
	check(g.growth.gold==before_gold and g.growth.memory_light==before_light,"chores do not mint gold or light")
	for m in g.MEMBERS:
		var n: Dictionary=g._find_object(m.id)
		n.in_studio=false;n.pos=Vector2(840,688)
		g.state.fan_form=m.id
		g._interact(n)
		check(g.mode=="dialog","ordinary member dialogue opens directly: "+m.id)
		while g.mode=="dialog": g._action("next")
	var previous: Dictionary=g.state.to_data()
	previous.library_day.memories={"dori":{"book":0,"day":g.state.day,"helped":true,"seen":false}}
	var old_dialogue_save:=Adapter.new()
	check(old_dialogue_save.apply_data(previous),"saves with removed follow-up records still load")
	check(not old_dialogue_save.to_data().library_day.has("memories"),"old follow-up records are dropped on resave")
	check(old_dialogue_save.growth.gold==g.growth.gold and old_dialogue_save.growth.memory_light==g.growth.memory_light and old_dialogue_save.friendship==g.state.friendship,"old follow-up migration preserves economy and bonds")
	# Both forms of quiet guidance resolve an actual visitor without a fee.
	for pick in range(2):
		fresh()
		var v: Dictionary=g.state.ink_visits._guest(0,"read","dori")
		v.phase="browse";v.pos=Vector2(376,328);v.noisy=true;v.admitted=true
		g.state.ink_visits.guests.append(v);g.library_day_flow.sync_targets(g)
		g.player_pos=v.pos+Vector2(0,30)
		g._interact(g._find_object("day_ink_%d"%v.uid));g._action("day_pick_%d"%pick)
		check(not v.noisy and g.state.library_day.guided==1,"quiet incident resolved by choice %d"%pick)
		check(g.growth.gold==0 and g.growth.memory_light==0,"quiet guidance has no farmable payout")
		step(50)
		check(v.completed,"guided visitor continues ordinary reading")
	fresh();select_topic(4,0)
	# Resolved direction drives the same four-direction atlas as autonomous NPCs.
	for direction in {"left":Vector2(-1,0),"right":Vector2(1,0),"up":Vector2(0,-1),"down":Vector2(0,1)}:
		g.library_day_flow.previous_position=g.player_pos-{"left":Vector2(-8,0),"right":Vector2(8,0),"up":Vector2(0,-8),"down":Vector2(0,8)}[direction]
		g.library_day_flow.update(g,.1)
		check(g.library_day_flow.facing==direction,"controlled actor facing "+direction)
	var marker: Dictionary=g._find_object("day_station")
	var mouse:=InputEventMouseButton.new();mouse.button_index=MOUSE_BUTTON_LEFT;mouse.pressed=true
	mouse.position=(marker.pos+Vector2(0,-24))*g.WORLD_SCALE+g.WORLD_OFFSET
	g._unhandled_input(mouse)
	check(g.pending_object=="day_station" or g.mode=="day_choice","zoomed station click maps back to world")
	var escape:=InputEventKey.new();escape.physical_keycode=KEY_ESCAPE;escape.pressed=true
	g._unhandled_input(escape)
	check(g.mode=="day_pause","Escape offers resume or handoff")
	var paused: int=g.state.minutes;step(10)
	check(g.state.minutes==paused,"promotion pause freezes time")
	g._action("day_resume");check(g.mode=="day_promotion","resume retains campaign")
	var keys: Dictionary={"left":KEY_LEFT,"right":KEY_RIGHT,"up":KEY_UP,"down":KEY_DOWN}
	for direction in keys:
		g.player_pos=g.library_day_flow.safe_point(g,Layout.HOMES[4]);g.library_day_flow.previous_position=g.player_pos
		g.route.clear();g.pending_object=""
		var before: Vector2=g.player_pos
		var press:=InputEventKey.new();press.keycode=keys[direction];press.physical_keycode=keys[direction];press.pressed=true
		Input.parse_input_event(press);Input.flush_buffered_events()
		for frame in range(4): g._process(.04)
		var release:=InputEventKey.new();release.keycode=keys[direction];release.physical_keycode=keys[direction];release.pressed=false
		Input.parse_input_event(release);Input.flush_buffered_events()
		check(g.player_pos.distance_to(before)>8 and g.library_day_flow.facing==direction,"physical arrow moves controlled host "+direction)
	var mid: Dictionary=g.state.to_data();mid.library_day.direct.member="fuwa"
	check(not Adapter.new().apply_data(mid),"mismatched saved campaign host rejected")
	g._action("day_handback")
	fresh();select_topic(4,0);reach_station();g._action("day_pick_0");reach_station();step(3.2);reach_station();g._action("day_pick_0");step(3.2)
	var request: Dictionary={}
	for i in range(900):
		g._process(.1)
		for v in g.state.ink_visits.guests:
			if v.phase=="browse" and v.get("request",false): request=v;break
		if not request.is_empty(): break
	check(not request.is_empty(),"invited visitor visibly asks for book")
	if not request.is_empty():
		g.player_pos=request.pos+Vector2(0,40);g.library_day_flow.sync_targets(g)
		g._interact(g._find_object("day_ink_%d"%request.uid))
		var minutes: int=g.state.minutes;var elapsed: float=request.elapsed
		step(10)
		check(g.state.minutes==minutes and request.elapsed==elapsed,"request menu pauses clock and visitor")
		g._action("day_pick_1")
		check(request.feature==1 and request.helped and request.phase=="to_read","either book accepted and visitor walks to read")
		step(90)
		check(request.completed and not g.state.library_day.data().has("memories"),"recommended book use completes without follow-up dialogue")
	var modern: Dictionary=g.state.to_data()
	modern.erase("library_day");modern.growth_visitors.erase("direct_campaign");modern.growth_visitors.erase("featured_book")
	var legacy:=Adapter.new();check(legacy.apply_data(modern),"pre-feature save remains readable")
	var corrupt: Dictionary=g.state.to_data();corrupt.library_day.carried=[0,1]
	var guard:=Adapter.new();check(guard.apply_data(g.state.to_data()),"valid state guard")
	var old: String=JSON.stringify(guard.to_data())
	check(not guard.apply_data(corrupt) and old==JSON.stringify(guard.to_data()),"invalid activity section rejected atomically")
	var remaining_books: Array=g.state.library_day.returned.duplicate()
	var remaining_seats: Array=g.state.library_day.dirty.duplicate()
	g.state.library_day.ensure(g.state.day+1)
	check(g.state.library_day.returned==remaining_books and g.state.library_day.dirty==remaining_seats,"neglected chores persist overnight within their caps")
	# Three operating days with optional events ignored must still close cleanly.
	fresh()
	for operating_day in range(3):
		g.state.minutes=600
		select_topic(operating_day,0)
		reach_station();g._action("day_pick_%d"%(operating_day%2));reach_station();step(3.2)
		reach_station();g._action("day_pick_0");step(3.2)
		step(130)
		g.state.minutes=840;g.mode="promotion";g._action("day_topic_1");g._action("day_assign");step(110)
		g.state.request_day_close();step(100)
		check(g.state.day_close_ready(),"day %d closes without doing optional chores"%(operating_day+1))
		check(g.state.finish_operating_day(),"day %d advances"%(operating_day+1))
		g.mode="play";g.player_pos=g.state.player;g._setup_map()
		check(g.state.library_day.unfiled()<=6 and g.state.library_day.dirty.size()<=2,"persistent work remains bounded after day %d"%(operating_day+1))
	print("LIBRARY_DAY_FLOW: ",count," checks; failures=",failures)
	g.free();quit(1 if failures else 0)
