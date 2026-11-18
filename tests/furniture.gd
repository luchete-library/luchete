extends SceneTree

const State = preload("res://scripts/game_state.gd")
const Furniture = preload("res://scripts/garden_furniture.gd")
const Editor = preload("res://scripts/furniture_editor.gd")
class TestGame:
	extends "res://scripts/main.gd"
	func _save() -> void: pass

var checks := 0
var failures := 0
func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",description)

func _initialize() -> void: call_deferred("run")

func check_empty_room(g) -> void:
	g.state=State.new()
	g.state.residents=["yato","danming","kubby","yune","dori","fuwa"]
	g.mode="play"
	g.player_pos=Furniture.ENTRANCE
	for value in [11,81,2703]:
		g.garden_residents.rng.seed=value
		g._setup_map()
		var destinations: Dictionary={}
		var rested: Dictionary={}
		var directions: Dictionary={}
		var safe:=true
		for i in range(60*28):
			g._process(1.0/60.0)
			for obj in g.objects:
				if obj.type!="npc": continue
				var agent: Dictionary=g.garden_residents.agents[obj.id]
				if obj.yard_action=="walk": directions[obj.facing]=true
				if agent.phase=="stroll":
					var path: PackedVector2Array=agent.path
					if not destinations.has(obj.id): destinations[obj.id]={}
					destinations[obj.id][path[-1]]=true
					safe=safe and g._walkable(obj.pos)
				elif agent.phase=="idle" and destinations.has(obj.id):
					rested[obj.id]=true
		check(directions.size()==4,"residents turn to all four directions on actual routes")
		check(safe,"strollers stay on walkable floor")
		check(rested.size()==6,"all six residents take a break after walking without furniture")
		for id in g.state.residents:
			check(destinations.get(id,{}).size()>=2,"chooses different destinations: "+id)
		check(g.garden_residents.reservations.is_empty() and g.state.activities.is_empty(),"free walks do not book furniture or give activity rewards")

func run() -> void:
	var s := State.new()
	check(s.place_furniture("chair",Editor.SUGGESTED[0])!="","furniture unlock requires a resident")
	s.residents = ["yato","danming","kubby","yune","dori","fuwa"]
	for i in range(Furniture.ORDER.size()):
		var error := s.place_furniture(Furniture.ORDER[i],Editor.SUGGESTED[i])
		check(error=="","reachable suggested "+Furniture.ORDER[i]+": "+error)
	check(s.furniture.size()==4,"all four furniture records")
	for p in [Vector2(496,416),Vector2(128,624),Vector2(288,320),Vector2(16,16)]:
		check(Furniture.placement_error(s.furniture,"chair",p)!="","blocked worktable / rest chair / resident / boundary")
	check(Furniture.placement_error([],"chair",Vector2(624,304))=="","former pickup tile can host a reading chair")
	check(Furniture.placement_error(s.furniture,"chair",Editor.SUGGESTED[1])!="","furniture cannot overlap")
	check(Furniture.placement_error(s.furniture,"chair",Editor.SUGGESTED[0],Editor.SUGGESTED[0])!="","cannot place on player")
	check(s.place_furniture("chair",Editor.SUGGESTED[0])=="" and s.furniture.size()==4,"moving replaces the single owned piece")
	check(s.toggle_furniture("tea") and not Furniture.find(s.furniture,"tea").enabled,"toggle usage")
	var copy := State.new()
	check(copy.apply_data(JSON.parse_string(JSON.stringify(s.to_data()))) and copy.furniture==s.furniture,"layout and disabled state survive JSON save")
	var legacy := s.to_data()
	legacy.erase("furniture")
	check(copy.apply_data(legacy) and copy.furniture.is_empty(),"old saves open with empty furniture inventory layout")
	var garden_save := s.to_data()
	garden_save.erase("furniture_room")
	garden_save.scene="garden"
	garden_save.yard_session={"member":"yato","routine":"gym","elapsed":2.5}
	garden_save.yard_host="danming"
	var old_places := [Vector2(368,496),Vector2(736,432),Vector2(848,320),Vector2(640,288)]
	for item in garden_save.furniture:
		var old_p: Vector2 = old_places[Furniture.ORDER.find(item.kind)]
		item.x=int(old_p.x)
		item.y=int(old_p.y)
	check(copy.apply_data(JSON.parse_string(JSON.stringify(garden_save))) and copy.scene=="library" and copy.player==Furniture.ENTRANCE,"old active garden save migrates the player indoors")
	check(copy.furniture==s.furniture and not Furniture.find(copy.furniture,"tea").enabled,"migration preserves each placed item and usage setting at safe indoor positions")
	check(copy.yard_host=="danming" and copy.yard_session.elapsed==2.5,"unfinished broadcasts and workouts survive migration")
	var migrated := copy.to_data()
	check(copy.apply_data(migrated) and copy.to_data()==migrated,"indoor save round trip does not re-migrate positions or reset progress")
	var bad: Array = s.furniture.duplicate(true)
	bad.append({"kind":"unknown","x":0,"y":0})
	bad.append({"kind":"chair","x":16,"y":16})
	bad.append({"kind":"tea","x":"no","y":0})
	check(Furniture.decode(bad)==s.furniture,"invalid and duplicate optional records cannot break a save")
	check(s.store_furniture("camera") and not s.store_furniture("camera"),"store is idempotent")
	check(s.place_furniture("camera",Editor.SUGGESTED[3])=="","stored piece can be placed again")
	s.toggle_furniture("tea")
	var g := TestGame.new()
	root.add_child(g)
	g.set_process(false)
	g.audio_enabled=false
	check_empty_room(g)
	g.garden_residents.rng.seed=278
	g.state=s
	s.scene="library"
	g.mode="play"
	g.player_pos=Furniture.ENTRANCE
	g._setup_map()
	var visited := {}
	var visitors := {}
	var phases := {}
	var safe_paths := true
	var unique_users := true
	var poses_on_arrival := true
	var gait_matches_distance := true
	for tick in range(60*70):
		g._process(1.0/60.0)
		var users: Array = g.garden_residents.reservations.values()
		var distinct := {}
		for id in users: distinct[id]=true
		unique_users = unique_users and users.size()==distinct.size()
		for obj in g.objects:
			if obj.type!="npc": continue
			var a: Dictionary = g.garden_residents.agents[obj.id]
			if obj.yard_action=="walk":
				gait_matches_distance = gait_matches_distance and is_equal_approx(obj.yard_seconds*g.garden_residents.WALK_SPEED,obj.walk_distance)
			phases[a.phase]=true
			if a.phase=="use":
				poses_on_arrival = poses_on_arrival and obj.yard_action==Furniture.ITEMS[a.kind].action
				visited[a.kind]=true
				visitors[obj.id]=true
				unique_users = unique_users and g.garden_residents.reservations.get(a.kind)==obj.id
			if a.phase in ["walk","return"]:
				# AStar cell edges can approach the rounded collision boundary by 1 pixel.
				for barrier in Furniture.BARRIERS: safe_paths = safe_paths and not barrier.grow(10).has_point(obj.pos)
	check(unique_users,"reservations prevent double booking and release cleanly")
	check(poses_on_arrival,"arriving residents begin the seated or standing furniture pose on the arrival frame")
	check(gait_matches_distance,"walking cels track distance along the path")
	check(visited.size()==4 and phases.has("return") and phases.has("leave"),"autonomous walking, all four interactions, departure and return")
	check(visitors.size()==6,"every recruited member can use the furniture")
	check(safe_paths,"resident routes avoid shelves and service furniture")
	check(s.activities.is_empty() and s.friendship.yato==0,"ambient interactions do not farm daily rewards")
	g._go_to(g._find_object("yato"))
	for tick in range(1200):
		g._process(1.0/60.0)
		if g.mode=="dialog": break
	check(g.mode=="dialog" and g.dialogue_member==0 and s.friendship.yato==1,"approach a moving indoor resident and retain normal daily conversation")
	while g.mode=="dialog": g._advance_dialogue()
	var before: Dictionary = g.garden_residents.agents.duplicate(true)
	g.mode="furniture"
	g._process(4.0)
	check(before==g.garden_residents.agents,"editing pauses resident decisions and pose time")
	g.mode="play"
	check(s.begin_yard_session("yato","gym"),"explicit workout can interrupt free furniture use")
	g._process(.1)
	check(g._find_object("yato").pos==Furniture.activity_position(s,"yato") and not "yato" in g.garden_residents.reservations.values(),"assigned workout has priority")
	s.yard_session={}
	s.yard_host="danming"
	g._process(.1)
	check(g._find_object("danming").pos==Furniture.activity_position(s,"danming") and not "danming" in g.garden_residents.reservations.values(),"assigned stream has priority")
	g.furniture_editor.open(g,"chair")
	g.furniture_editor.action(g,"toggle")
	check(g.garden_residents.reservations.is_empty() and not Furniture.find(s.furniture,"chair").enabled,"editing an occupied layout clears stale reservations")
	g.furniture_editor.action(g,"store")
	check(Furniture.find(s.furniture,"chair").is_empty() and g._find_object("furniture_chair").is_empty(),"stored furniture leaves navigation and world objects")
	g.furniture_editor.action(g,"done")
	for tick in range(60*20): g._process(1.0/60.0)
	check(not g.garden_residents.reservations.has("chair"),"removed furniture is never selected again")
	s.yard_host=""
	s.scene="garden"
	g._setup_map()
	check(g.objects.filter(func(o): return o.type in ["npc","furniture"]).is_empty(),"garden contains no duplicate residents or indoor furniture")
	g.furniture_editor.open(g)
	check(g.mode=="play","furniture editing is only available indoors")
	g._begin_yard_workout(0,"yoga")
	check(s.scene=="library" and s.yard_session.get("routine","")=="yoga" and not g._find_object("yato").is_empty(),"activity selected outside brings player and Stella into library")
	print("Furniture checks: ",checks,", failures: ",failures,". Player save untouched.")
	g.free()
	quit(1 if failures else 0)
