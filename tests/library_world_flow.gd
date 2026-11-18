extends SceneTree
const Game=preload("res://scripts/growth_game.gd")
const Layout=preload("res://scripts/library_world_layout.gd")
const Adapter=preload("res://scripts/growth_state_adapter.gd")
const OUT="res://artifacts/world_integration_20261118/"
var g
var count:=0
var failures:=0
func check(ok: bool,label: String) -> void:
	count+=1
	if not ok: failures+=1;push_error(label)
func step(seconds: float) -> void:
	for i in range(ceili(seconds/.1)): g._process(.1)
func click(p: Vector2,pressed: bool=true) -> void:
	var event:=InputEventMouseButton.new()
	event.position=p;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
	g._unhandled_input(event)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	g=Game.new();g.persist=false;g.save_path=OUT+"world_only_test.json";g.legacy_save_path=OUT+"never_exists.json"
	root.add_child(g);g.set_process(false);g.audio_enabled=false
	await process_frame
	g.background_paused=false;g._new_game()
	while g.mode=="dialog": g._action("next")
	check(g.state.world_enabled and g.WORLD_SCALE==1,"full-screen world enabled")
	check(g.world.hit(g,Vector2(100,200)).id=="activity_archive","record shelf painted target")
	for obj in g.objects:
		if obj.pos.x>=1280: continue
		var path:=Layout.path(g.navigation,g.player_pos,obj.pos)
		check(not path.is_empty() and path[-1].distance_to(obj.pos)<78,"service reachable "+obj.id)
	click(Vector2(1190,180));check(g.pending_object=="residence_door","new right-side door hit works outside old bounds")
	step(14)
	check(g.player_pos.x<1280 and not g.studios_open,"private door stays locked before six")
	g._go_to(g._find_object("activity_archive"));step(35)
	check(g.mode=="archive_shelf","record shelf reachable before reopening")
	g.mode="play"
	for member in g.MEMBERS:
		g.state.active_mission=member.id;g.state.chapter_steps[member.id]=2;g.state.page_complete=true;g.state.record_chapter_step(member.id,2)
	g._setup_map()
	for task in ["corridor","reading","shelves"]:
		g._start_work(task);step(65)
		check(task in g.growth.completed_tasks,"rebuild "+task)
	g._action("growth_open");g._action("close")
	check(g.growth.phase=="open","opening after all works")
	g._go_to(g._find_object("activity_archive"));step(35)
	check(g.mode=="archive_shelf","record shelf reachable after reopening")
	g.mode="play"
	var old_world_player: Vector2=g.player_pos
	g.world.change_area(g,true)
	check(g.WORLD_OFFSET==Vector2(-1280,0) and g.player_pos.x>=1280,"camera and player change together")
	var pose: Vector2=g.player_pos
	var encoded: Dictionary=g.state.to_data()
	var restored:=Adapter.new()
	check(restored.apply_data(encoded) and restored.world_player==pose,"private coordinates load without legacy clamp")
	var corrupted: Dictionary=encoded.duplicate(true)
	corrupted.library_world.furniture.clear()
	check(not restored.apply_data(corrupted),"reject mismatched placement metadata")
	check(restored.world_player==pose,"invalid save leaves live state intact")
	var roundtrips: Dictionary={}
	for i in range(1600):
		g._process(.1)
		for obj in g.objects:
			if obj.type=="npc":
				if not roundtrips.has(obj.id): roundtrips[obj.id]={}
				roundtrips[obj.id]["private" if obj.in_studio else "public"]=true
	for member in g.MEMBERS: check(roundtrips[member.id].size()==2,"autonomous public/private trip "+member.id)
	g.state.minutes=600;g.state.operating.begin(g.state)
	check(g.state.ink_visits.start(g.state,0),"broadcast assigned while player in personal space")
	var broadcast_host: String=g.state.ink_visits.host
	var phases: Dictionary={}
	var chat_seen:=false
	var save_during_visit:=false
	for i in range(3600):
		g._process(.1)
		var host: Dictionary=g._find_object(broadcast_host)
		if host.in_studio and host.get("yard_action","")=="stream" and not chat_seen:
			g._studio_interact(host)
			chat_seen=g.mode=="stella_life" and g.life.phase=="promo_chat"
			g.mode="play"
		for visitor in g.state.ink_visits.guests:
			phases[visitor.phase]=true
			if not save_during_visit:
				var loaded:=Adapter.new()
				check(loaded.apply_data(g.state.to_data()),"live visitor save loads while camera private")
				save_during_visit=true
		if g.state.ink_visits.total==3 and g.state.ink_visits.guests.is_empty() and g.state.ink_visits.topic<0: break
	check(chat_seen,"room broadcast chat remains available")
	check(phases.has("read") and phases.has("checkout"),"offscreen library guests read and borrow")
	check(g.growth.gold==45 and g.growth.memory_light==10,"offscreen visits settle once")
	g.world.change_area(g,false)
	check(g.player_pos.x<1280 and g.WORLD_OFFSET==Vector2.ZERO,"return to common library")
	g.growth.reward("test_budget",500,100)
	g._interact(g._find_object("ete"));check(g.mode=="world_ete","Ete service menu")
	g._action("world_upgrades");g._action("growth_tab_furniture")
	check(g.shop_tab=="upgrade","Ete only handles facility upgrades")
	g.mode="play";g._interact(g._find_object("table"));check(g.mode=="world_artisan","artisan menu")
	g._action("world_furniture_shop")
	g._action("growth_buy_tea")
	check(g.mode=="furniture" and "tea" in g.growth.owned_furniture,"artisan purchases a usable table")
	check(g.furniture_editor.error(g)=="","default furniture placement is reachable")
	g._action("furn_done")
	var npc: Dictionary=g._find_object("yune")
	g.garden_residents.release(npc.id);npc.in_studio=false;npc.pos=Layout.PUBLIC_SPOTS[3]
	g.character_touch.held=npc.id;g.character_touch.pointer_screen=Layout.FURNITURE.tea
	g.character_touch.grab_offset=Vector2.ZERO
	check(g.character_touch.target(g).kind=="tea","drag targets new furniture coordinates")
	g.character_touch.drop(g);g.character_touch.cancel()
	check(g.garden_residents.occupant("tea")=="yune","drop starts authored furniture interaction")
	g.player_pos=Layout.FURNITURE.tea+Vector2(50,16)
	g.shared.begin(g,"yune");check(g.mode=="together","shared tea stays in public library")
	step(12);check(g.mode=="play","shared activity returns control")
	g.persist=true;g._save();g.persist=false
	check(not g.save_failed,"world layout writes isolated test slot")
	var reload:=Adapter.new();check(reload.load_from(g.save_path),"world placement and economy reload together")
	print("WORLD_FLOW: ",count," checks; failures=",failures)
	g.free();quit(1 if failures else 0)
