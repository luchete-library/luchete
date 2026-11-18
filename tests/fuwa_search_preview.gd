extends SceneTree

const Game=preload("res://previews/fuwa_search/game.gd")
const OUT:="res://artifacts/fuwa_search_20261118/"
var g
var checks: Array=[]
var failure_count:=0
var journeys: Array=[]

func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks.append({"passed":ok,"check":label})
	if not ok: failure_count+=1;push_error(label)
func step(seconds: float) -> void:
	for i in range(ceili(seconds*60)): g.advance(1.0/60)
func key(code: int,pressed: bool=true) -> void:
	var event:=InputEventKey.new();event.physical_keycode=code;event.pressed=pressed
	g._unhandled_input(event)
func click_world(point: Vector2) -> void:
	click_screen(g.screen_world(point))
func click_screen(point: Vector2) -> void:
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true
	event.position=point;g._unhandled_input(event)
func walk(point: Vector2) -> bool:
	click_world(point)
	for i in range(1800):
		g.advance(1.0/60)
		if g.route.is_empty(): break
	return g.player_pos.distance_to(point)<8
func snap(name: String) -> void:
	g.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUT+name+".png")==OK,"capture "+name)
func run() -> void:
	root.size=Vector2i(1280,800)
	g=Game.new();root.add_child(g);g.set_process(false);g.pause_on_focus_loss=false
	g.paused=false
	await snap("01_start")
	# Keyboard movement uses the same event handler as the interactive scene.
	for code in [KEY_D,KEY_W,KEY_A,KEY_S]:
		key(code);step(.2);key(code,false)
	check(g.seen_directions.size()==4,"all four directions receive real movement")
	key(KEY_E);step(.2);key(KEY_E,false)
	check(g.phase=="search" and g.zone==0,"interact from start cannot skip mountain")
	key(KEY_ESCAPE);var before: Vector2=g.player_pos;var old_clock: float=g.clock
	key(KEY_W);step(2);key(KEY_W,false)
	check(g.player_pos==before and g.clock==old_clock,"pause freezes movement and patrols")
	key(KEY_ESCAPE)
	g.pause_on_focus_loss=true;key(KEY_D);g._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(g.paused and g.held.is_empty() and g.route.is_empty(),"focus loss clears held controls and pauses")
	g.pause_on_focus_loss=false;g.reset()
	check(not g.set_destination(Vector2(12,15)),"unwalkable ground rejects click")
	# Isolated collision and retry checks, followed by a fresh complete journey.
	g.player_pos=Vector2(345,430);g.protection=100;key(KEY_W);step(1);key(KEY_W,false)
	check(g.player_pos.y>400 and g.walkable(g.player_pos),"keyboard cannot enter solid rock")
	g.reset();g.player_pos=g.ghost_position(0);step(1.6)
	check(g.setbacks==1 and g.player_pos==g.START,"proximity returns to safe checkpoint without dead end")
	check(g.sheltered_from(Vector2(345,320),Vector2(345,420)),"rock blocks dangerous proximity from opposite side")
	key(KEY_F1);check(g.assist,"assist can be toggled by keyboard")
	g.assist=false;g.reset()
	# Full journey: no progress flags or positions are assigned after this reset.
	var passed:=true
	for point in [Vector2(325,448),Vector2(390,425),Vector2(470,384),Vector2(540,350),Vector2(590,288),Vector2(615,205)]:
		var reached:=walk(point)
		journeys.append({"point":[point.x,point.y],"reached":reached,"position":[g.player_pos.x,g.player_pos.y],"setbacks":g.setbacks,"clock":g.clock,"zone":g.zone})
		if not reached and g.zone==0: passed=false;break
		if point==Vector2(390,425):
			await snap("02_mountain_route")
			step(3.0) # Let the patrol turn back before crossing the open stretch.
	check(passed and g.zone==1,"walk actual mountain route and click pass into clearing")
	if g.zone==1:
		for point in [Vector2(330,450),Vector2(420,460),Vector2(620,465),Vector2(700,370)]:
			check(walk(point),"clear ground route "+str(point))
		# Wait until snow eases; E observes without automatically walking to target.
		while g.wind_strength()>.3: step(.05)
		key(KEY_E);step(.2);key(KEY_E,false)
		check(g.discovered and g.phase=="search","observe reveals Tenbi but does not auto-complete")
		await snap("03_found_tenbi")
		root.size=Vector2i(960,600);await snap("03_found_tenbi_960");root.size=Vector2i(1280,800)
		click_world(g.tenbi-Vector2(0,28))
		for i in range(1800):
			g.advance(1.0/60)
			if g.phase=="return_ready": break
		check(g.phase=="return_ready","click discovered Tenbi walks to reunion and offers return spell")
		await snap("04_reunion")
		step(5)
		check(g.phase=="return_ready" and g.return_flow.cast_count==0,"reunion waits for explicit spell input")
		key(KEY_E);key(KEY_E,false);step(1.5)
		check(g.phase=="casting" and g.return_flow.cast_count==1,"Fuwa starts spell once by E")
		await snap("05_return_spell")
		key(KEY_ESCAPE);var cast_age: float=g.return_flow.elapsed
		key(KEY_E);key(KEY_E,false);step(3)
		check(g.phase=="casting" and g.return_flow.elapsed==cast_age,"pause freezes spell and ignores E")
		key(KEY_ESCAPE);step(1.6)
		check(g.phase=="rift","rift follows complete spell without accuracy test")
		step(1.8);await snap("06_unexpected_rift")
		root.size=Vector2i(960,600);await snap("06_unexpected_rift_960");root.size=Vector2i(1280,800)
		# Repeated input cannot restart the spell or skip the event sequence.
		for i in range(5): key(KEY_E);key(KEY_E,false);click_screen(g.ReturnFlow.ACTION.get_center())
		check(g.phase=="rift" and g.return_flow.cast_count==1,"repeated E/click cannot skip rift or recast")
		g.pause_on_focus_loss=true;g._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
		var rift_age: float=g.return_flow.elapsed;step(3)
		check(g.paused and g.return_flow.elapsed==rift_age,"focus loss pauses ending sequence")
		g.pause_on_focus_loss=false;key(KEY_ESCAPE)
		step(1.6);check(g.phase=="crossing","rift transitions through light into blackout")
		step(1.3);check(g.phase=="awakening" and g.zone==2,"library loads only under blackout")
		step(1.3);await snap("07_awakening")
		step(2);check(g.phase=="arrived" and g.return_flow.arrivals==1,"arrival completes once and returns movement")
		check(g.return_flow.history==["return_ready","casting","rift","crossing","awakening","arrived"],"canonical event order preserved")
		await snap("08_library_arrival")
		root.size=Vector2i(960,600);await snap("08_library_arrival_960");root.size=Vector2i(1280,800)
		var library_before: Vector2=g.player_pos;key(KEY_D);step(.25);key(KEY_D,false)
		check(g.player_pos.x>library_before.x+10,"library returns direct Fuwa control")
		check(walk(Vector2(370,435)),"library mouse walking works")
		check(g.ghosts.is_empty() and g.exposure==0,"snow patrols and hazards removed after arrival")
		key(KEY_E);key(KEY_E,false);step(1)
		check(g.phase=="arrived" and g.return_flow.arrivals==1 and g.return_flow.cast_count==1,"library interaction does not repeat transition")
	# Every alternate search location must be physically accessible.
	for encounter in range(3):
		g.encounter=encounter;g.reset();g.enter_clearing();g.protection=100
		check(walk(g.tenbi+Vector2(-45,10)),"alternate Tenbi location reachable "+str(encounter))
		key(KEY_E);step(2.1);key(KEY_E,false)
		check(g.phase=="return_ready","alternate location reunion "+str(encounter))
		click_screen(g.ReturnFlow.ACTION.get_center());step(11)
		check(g.phase=="arrived" and g.return_flow.arrivals==1,"alternate location spell and arrival "+str(encounter))
		key(KEY_R)
		check(g.zone==0 and g.phase=="search" and not g.discovered and g.setbacks==0 and g.return_flow.history.is_empty(),"restart clears search and ending state")
	# Each cinematics stage can be safely abandoned with R, including blackout.
	for stage in ["casting","rift","crossing","awakening"]:
		g.return_flow.enter(g,stage);step(.1);key(KEY_R)
		check(g.phase=="search" and g.zone==0 and g.return_flow.arrivals==0 and g.return_flow.cast_count==0 and not g.paused,"restart during "+stage)
	g.start_return_preview()
	check(g.phase=="return_ready" and g.zone==1 and g.discovered and g.return_flow.cast_count==0,"ending quickstart waits for explicit spell input")
	click_screen(g.ReturnFlow.ACTION.get_center());step(11)
	check(g.phase=="arrived" and g.return_flow.arrivals==1,"ending quickstart reaches library")
	# Capture native cels in each facing for visible proportion inspection.
	g.reset();g.zone=1;g.setup_zone();g.player_pos=Vector2(420,470);g.protection=100
	for code in [KEY_D,KEY_W,KEY_A,KEY_S]:
		key(code);step(.2);await snap("facing_"+g.facing);key(code,false)
	FileAccess.open(OUT+"test_results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failure_count,"journey":journeys},"\t"))
	print("FUWA SEARCH PREVIEW: ",checks.size()," checks; failures=",failure_count)
	g.free();quit(1 if failure_count else 0)
