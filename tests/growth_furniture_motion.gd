extends SceneTree

# Uses the real growth purchase gate, lobby navigation, drag/drop handlers and
# animation sampler. No normal player save or generated sprite file is changed.
const Adapter=preload("res://scripts/growth_state_adapter.gd")
const Furniture=preload("res://scripts/garden_furniture.gd")
class Preview:
	extends "res://scripts/main.gd"
	func _save() -> void: pass

var game:=Preview.new()
var checks:=0
var failures:=0
var atlases: Dictionary={}
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(label)
func _initialize() -> void: call_deferred("run")

func open_state():
	var state:=Adapter.new()
	for book in state.BOOKS:
		state.residents.append(book.id)
		state.chapter_steps[book.id]=3
	state.opening_pending=false
	check(state.growth.begin_rebuild(6),"fixture starts first reconstruction")
	for task in ["corridor","shelves","reading"]: state.growth.complete_task(task)
	check(state.growth.open_library(),"fixture opens after all first works")
	state.growth.reward("furniture-motion:fixture",1000,45)
	for index in range(Furniture.ORDER.size()):
		var kind: String=Furniture.ORDER[index]
		if kind!="chair": check(state.growth.purchase("furniture",kind)=="","purchase animated furniture: "+kind)
		check(state.place_furniture(kind,Furniture.DEFAULTS[index])=="","place owned furniture: "+kind)
	return state

func reset_map(active_kind: String="") -> void:
	for item in game.state.furniture: item.enabled=active_kind=="" or item.kind==active_kind
	game.mode="play"
	game.player_pos=Furniture.ENTRANCE
	game.garden_residents.rng.seed=278
	game._setup_map()
	game.ui_regions.clear();game.buttons.clear()
	for agent in game.garden_residents.agents.values(): agent.timer=10000.0

func screen(world: Vector2) -> Vector2:
	return game.WORLD_OFFSET+world*game.WORLD_SCALE
func mouse(point: Vector2,pressed: bool) -> void:
	var event:=InputEventMouseButton.new()
	event.position=point;event.pressed=pressed;event.button_index=MOUSE_BUTTON_LEFT
	game._unhandled_input(event)
func drag_to(id: String,world: Vector2) -> void:
	mouse(screen(game._find_object(id).pos+Vector2(0,-44)),true)
	check(game.character_touch.held==id,"actual pointer grabs member from studio: "+id)
	var event:=InputEventMouseMotion.new()
	event.position=screen(world);event.relative=event.position-game.character_touch.pointer_screen
	game._unhandled_input(event)
	mouse(screen(world),false)

func check_art(id: String,kind: String) -> void:
	var sprites=game.StellaInteractions
	var action: String=Furniture.ITEMS[kind].action
	var definition: Dictionary=sprites.definition(id,action)
	check(sprites.supports(game,id) and not definition.is_empty(),"owned furniture has authored member action: "+id+"/"+kind)
	if definition.is_empty(): return
	var costume: String=game._costume_key(id)
	if not atlases.has(costume): atlases[costume]=sprites.sheet_for(id,costume).get_image()
	var atlas: Image=atlases[costume]
	var row: int=int(definition.row)
	var unique: Dictionary={};var safe:=true
	# Check every reachable column, not just the old key poses.
	for column in range(41):
		var cel:=atlas.get_region(Rect2i(column*96,row*112,96,112))
		var bounds:=cel.get_used_rect()
		safe=safe and bounds.has_area() and bounds.position.x>0 and bounds.position.y>0 and bounds.end.x<96 and bounds.end.y==104
		unique[hash(cel.get_data())]=true
	check(safe,"all 41 motion cels remain inside the shared frame and floor: "+id+"/"+kind)
	check(unique.size()>=12,"full transition frames animate instead of repeating two poses: "+id+"/"+kind)
	var neutral: Image=game.Field.IDLE.get_image().get_region(Rect2i(0,game.Field.COSTUMES.find(costume)*112,96,112))
	check(atlas.get_region(Rect2i(40*96,row*112,96,112)).get_data()==neutral.get_data(),"recovery matches the currently equipped idle exactly: "+id+"/"+kind)

func check_autonomous(id: String,kind: String) -> void:
	reset_map(kind)
	var resident: Dictionary=game._find_object(id)
	var agents=game.garden_residents
	check(game.studios_open and resident.in_studio,"reopened six-room layout starts member in own room: "+id)
	agents.leave_studio(game,resident)
	var agent: Dictionary=agents.agents[id]
	agent.public_time=1000.0
	check(agents.choose_furniture(game,resident,agent),"member can reserve a reachable purchased furnishing: "+id+"/"+kind)
	check(agent.kind==kind and agent.phase=="walk" and agents.reservations.get(kind)==id,"chosen item owns exclusive route reservation: "+id+"/"+kind)
	var phases: Dictionary={};var columns: Dictionary={};var safe:=true;var gait:=true;var correct:=true
	var reached:=false;var returned:=false;var moved:=0.0
	var previous: Vector2=resident.pos
	for tick in range(60*45):
		agents.update(game,1.0/60.0)
		phases[agent.phase]=true
		moved+=previous.distance_to(resident.pos);previous=resident.pos
		if agent.phase in ["walk","return"]:
			for barrier in Furniture.BARRIERS: safe=safe and not barrier.grow(10).has_point(resident.pos)
		if resident.yard_action=="walk":
			gait=gait and is_equal_approx(resident.yard_seconds*agents.WALK_SPEED,resident.walk_distance)
		if agent.phase=="use":
			reached=true
			correct=correct and resident.yard_action==Furniture.ITEMS[kind].action and resident.pos==Furniture.position(Furniture.find(game.state.furniture,kind)) and agents.occupant(kind)==id
			columns[game.StellaInteractions.Samples.furniture(resident.yard_action,agent.elapsed,agent.elapsed+agent.timer)]=true
		if reached and agent.phase=="idle": returned=true;break
	check(reached and correct,"actual arrival activates matching furniture pose at its anchor: "+id+"/"+kind)
	check(moved>80 and safe and gait,"real approach and return paths avoid shelves and drive gait by distance: "+id+"/"+kind)
	check(phases.has("enter") and phases.has("use") and phases.has("leave") and phases.has("return") and returned,"autonomous entry/use/exit/return completes without a stuck state: "+id+"/"+kind)
	check(columns.has(0) and columns.has(8) and columns.has(24) and columns.has(32) and columns.size()>=35,"runtime sampler reaches preparation, activity and recovery frames: "+id+"/"+kind)
	check(not agents.reservations.has(kind),"leaving releases furniture for the next resident: "+id+"/"+kind)

func check_pointer(id: String,kind: String) -> void:
	reset_map()
	drag_to(id,Furniture.position(Furniture.find(game.state.furniture,kind)))
	var resident: Dictionary=game._find_object(id)
	var agent: Dictionary=game.garden_residents.agents[id]
	check(not resident.in_studio and agent.phase=="use" and agent.kind==kind,"studio-to-furniture drag uses real contextual action: "+id+"/"+kind)
	check(resident.yard_action==Furniture.ITEMS[kind].action and game.garden_residents.occupant(kind)==id,"drag action matches autonomous action and reserves the item: "+id+"/"+kind)
	game.garden_residents.update(game,.1)
	check(agent.elapsed>0 and resident.yard_seconds==agent.elapsed,"dropped action advances its authored pose clock: "+id+"/"+kind)
	# A second actor must not replace an existing user's reservation.
	var other: String=game.state.residents[(game.state.residents.find(id)+1)%6]
	drag_to(other,Furniture.position(Furniture.find(game.state.furniture,kind)))
	check(game._find_object(other).in_studio and game.garden_residents.occupant(kind)==id,"occupied furniture rejects a second drop without moving either owner: "+id+"/"+kind)

func run() -> void:
	root.add_child(game)
	await process_frame
	game.set_process(false);game.audio_enabled=false
	game.state=open_state()
	var original_gold: int=game.state.growth.gold
	var original_light: int=game.state.growth.memory_light
	for member in game.state.residents:
		for kind in Furniture.ORDER:
			check_art(member,kind)
			check_autonomous(member,kind)
			check_pointer(member,kind)
	check(game.state.growth.gold==original_gold and game.state.growth.memory_light==original_light,"ambient/pointer furniture activity does not create unearned income or memory")
	check(game.state.activities.is_empty(),"furniture tests do not claim daily activities")
	print("GROWTH FURNITURE MOTION: ",checks," checks, ",failures," failures. 6 members x 4 owned furniture; normal save untouched.")
	game.free()
	quit(1 if failures else 0)
