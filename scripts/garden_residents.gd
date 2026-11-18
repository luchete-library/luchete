extends RefCounted

const Furniture = preload("res://scripts/garden_furniture.gd")
const Field = preload("res://scripts/field_sprites.gd")
const Studios = preload("res://scripts/stella_studios.gd")
const WALK_SPEED := 66.0
var agents := {}
var reservations := {}
var rng := RandomNumberGenerator.new()

func _init() -> void:
	rng.randomize()

func reset(g) -> void:
	agents.clear()
	reservations.clear()
	for obj in g.objects:
		if obj.type!="npc": continue
		agents[obj.id] = {"phase":"idle","timer":rng.randf_range(.6,1.4)+obj.slot*.35,"kind":"","path":PackedVector2Array(),"visits":0,"elapsed":0.0}
		obj.yard_action = ""
		obj.yard_seconds = 0.0
		obj.walk_distance = 0.0
		obj.facing = "down"
		obj.in_studio=false
		if g.studios_open and g.state.yard_session.get("member","")!=obj.id:
			enter_studio(obj)

func enter_studio(obj: Dictionary) -> void:
	release(obj.id)
	var a: Dictionary=agents[obj.id]
	obj.in_studio=true
	obj.pos=Studios.feet(obj.index)
	obj.facing="down"
	obj.yard_action="idle"
	obj.yard_seconds=0.0
	a.phase="studio"
	a.elapsed=0.0
	a.timer=rng.randf_range(20,29)+4*obj.index

func lobby_door(g) -> Vector2:
	return g.navigation.get_point_position(g._grid_at(Studios.DOOR))

func leave_studio(g, obj: Dictionary) -> void:
	release(obj.id)
	obj.in_studio=false
	obj.pos=lobby_door(g)
	obj.facing="left"
	agents[obj.id].public_time=rng.randf_range(24,42)

func update_studio(g, obj: Dictionary, a: Dictionary, delta: float) -> bool:
	var promotion=g.state.ink_visits
	var promoting: bool=promotion.promoting(obj.id)
	var on_air: bool=g.state.yard_host==obj.id or (promoting and promotion.topic==0)
	if on_air:
		if a.phase!="studio_air":
			enter_studio(obj)
			a.phase="studio_air"
			obj.pos=Studios.feet(obj.index,true)
		obj.promo_ready=promoting
		obj.promo_away=false
		obj.yard_action="stream"
		a.elapsed+=delta
		obj.yard_seconds=a.elapsed
		return true
	if a.phase=="studio_air":
		enter_studio(obj)
		obj.promo_ready=false
	var assigned: bool=promoting or g.state.yard_session.get("member","")==obj.id
	if obj.in_studio:
		a.timer-=delta
		if a.timer>0 and not assigned: return true
		leave_studio(g,obj)
	elif not assigned and g.pending_object!=obj.id:
		a.public_time=a.get("public_time",32.0)-delta
		if a.phase=="idle" and a.public_time<=0:
			a.path=path_between(g,obj.pos,lobby_door(g))
			if not a.path.is_empty(): a.phase="homeward"
	return false

func release(id: String) -> void:
	if not agents.has(id): return
	var a: Dictionary = agents[id]
	if reservations.get(a.kind,"")==id: reservations.erase(a.kind)
	a.kind=""
	a.phase="idle"
	a.timer=3.0
	a.path=PackedVector2Array()

func home_spot(_g,obj: Dictionary) -> Vector2:
	return Furniture.HOME_SPOTS[obj.slot]

func path_between(g, start: Vector2, target: Vector2) -> PackedVector2Array:
	var a := Furniture.nearby_cell(g.navigation,start)
	var b := Furniture.nearby_cell(g.navigation,target)
	if a.x<0 or b.x<0: return PackedVector2Array()
	var path: PackedVector2Array = g.navigation.get_point_path(a,b)
	if not path.is_empty(): path.append(target)
	return path

func choose_furniture(g, obj: Dictionary, a: Dictionary) -> bool:
	for offset in range(Furniture.ORDER.size()):
		var kind: String = Furniture.ORDER[(obj.slot+a.visits+offset)%Furniture.ORDER.size()]
		if Furniture.reserved_for_activity(g.state,kind): continue
		var item := Furniture.find(g.state.furniture,kind)
		if item.is_empty() or reservations.has(kind) or not Furniture.compatible(item,obj.id): continue
		var path := path_between(g,obj.pos,Furniture.approach(item))
		if path.is_empty(): continue
		reservations[kind]=obj.id
		a.kind=kind
		a.phase="walk"
		a.path=path
		a.elapsed=0.0
		return true
	return false

func has_room_to_stop(g, id: String, point: Vector2) -> bool:
	if point.distance_to(g.player_pos)<45: return false
	for other in g.objects:
		if other.id==id: continue
		if other.type=="furniture" and Furniture.zone(other.pos).has_point(point): return false
		if other.type not in ["npc","librarian"]:
			if point.distance_to(other.pos)<30: return false
			continue
		if point.distance_to(other.pos)<56: return false
		var route: PackedVector2Array=agents.get(other.id,{}).get("path",PackedVector2Array())
		if not route.is_empty() and point.distance_to(route[-1])<56: return false
	return true

func choose_stroll(g, obj: Dictionary, a: Dictionary) -> bool:
	var nav: AStarGrid2D=g.navigation
	var start:=Furniture.nearby_cell(nav,obj.pos)
	if start.x<0: return false
	for attempt in range(24):
		var cell:=start+Vector2i(rng.randi_range(-11,11),rng.randi_range(-9,9))
		if not nav.is_in_boundsv(cell) or nav.is_point_solid(cell): continue
		var point:=nav.get_point_position(cell)
		if not Furniture.AREA.has_point(point) or point.distance_to(obj.pos)<70: continue
		if not has_room_to_stop(g,obj.id,point): continue
		var path:=nav.get_point_path(start,cell)
		if path.is_empty(): continue
		a.phase="stroll"
		a.path=path
		a.elapsed=0.0
		return true
	return false

func choose(g, obj: Dictionary, a: Dictionary) -> bool:
	if rng.randf()<.35:
		return choose_stroll(g,obj,a) or choose_furniture(g,obj,a)
	return choose_furniture(g,obj,a) or choose_stroll(g,obj,a)

func walk(obj: Dictionary, a: Dictionary, delta: float) -> float:
	var path: PackedVector2Array = a.path
	var budget := WALK_SPEED*minf(delta,.15)
	var distance := budget
	while not path.is_empty() and distance>0:
		var remaining: float = obj.pos.distance_to(path[0])
		if remaining<=distance:
			obj.pos=path[0]
			path.remove_at(0)
			distance-=remaining
		else:
			obj.pos=obj.pos.move_toward(path[0],distance)
			distance=0
	a.path=path
	return budget-distance

func promote(g, obj: Dictionary, a: Dictionary, delta: float) -> void:
	var visits=g.state.ink_visits
	if a.phase!="promotion":
		release(obj.id)
		var target: Vector2=visits.door_position()
		var start: Vector2i=g._grid_at(obj.pos)
		var end: Vector2i=g._grid_at(target)
		a.path=g.navigation.get_point_path(start,end)
		a.phase="promotion"
		a.elapsed=0.0
		obj.walk_distance=0.0
	var before: Vector2=obj.pos
	var distance:=walk(obj,a,delta)
	obj.promo_ready=a.path.is_empty()
	obj.promo_away=obj.promo_ready and visits.topic!=0
	if not obj.promo_ready:
		obj.yard_action="walk"
		obj.walk_distance+=distance
		obj.facing=Field.direction_for((obj.pos-before).normalized()*8.0,obj.facing)
		obj.yard_seconds=obj.walk_distance/WALK_SPEED
	else:
		obj.facing="down"
		obj.yard_action="stream" if visits.topic==0 else "idle"
		a.elapsed+=delta
		obj.yard_seconds=a.elapsed
	obj.label=g.MEMBERS[obj.index].short+" · "+visits.TOPICS[visits.topic].method

func update(g, delta: float) -> void:
	for obj in g.objects:
		if obj.type!="npc": continue
		if not agents.has(obj.id): continue
		if g.mode=="together" and g.shared.member==obj.id: continue
		if g.character_touch.frozen(obj.id): continue
		var a: Dictionary = agents[obj.id]
		if g.studios_open and update_studio(g,obj,a,delta): continue
		if g.state.ink_visits.promoting(obj.id):
			promote(g,obj,a,delta)
			continue
		if a.phase=="promotion":
			obj.promo_ready=false
			obj.promo_away=false
			a.phase="assigned"
		if g.pending_object==obj.id: continue # Hold the current pose while the player approaches.
		var was_walking: bool = obj.yard_action=="walk"
		obj.yard_action=""
		if g.state.yard_session.get("member","")==obj.id or g.state.yard_host==obj.id:
			release(obj.id)
			a.phase="assigned"
			obj.facing="down"
			obj.pos=Furniture.activity_position(g.state,obj.id)
			continue
		if a.phase=="assigned":
			a.phase="return"
			a.path=path_between(g,obj.pos,home_spot(g,obj))
		a.elapsed+=delta
		var item := Furniture.find(g.state.furniture,a.kind)
		if a.kind!="" and (item.is_empty() or not item.enabled or Furniture.reserved_for_activity(g.state,a.kind)):
			release(obj.id)
			obj.pos=home_spot(g,obj)
			a=agents[obj.id]
		match a.phase:
			"idle":
				a.timer-=delta
				if a.timer<=0 and not choose(g,obj,a): a.timer=2.0
			"stroll","walk","enter","leave","return","homeward":
				if not was_walking: obj.walk_distance=0.0
				var before: Vector2=obj.pos
				var travelled := walk(obj,a,delta)
				var displacement: Vector2=obj.pos-before
				if displacement.length_squared()>.000001:
					obj.facing=Field.direction_for(displacement.normalized()*8.,obj.facing)
				obj.walk_distance+=travelled
				if a.path.is_empty():
					match a.phase:
						"homeward":
							enter_studio(obj)
						"walk":
							a.phase="enter"
							a.path=PackedVector2Array([Furniture.position(item)])
						"enter":
							a.phase="use"
							obj.facing="down"
							a.timer=8.0+obj.slot%3
							a.elapsed=0.0
							obj.yard_action=Furniture.ITEMS[a.kind].action
						"leave":
							reservations.erase(a.kind)
							a.kind=""
							a.phase="return"
							a.path=path_between(g,obj.pos,home_spot(g,obj))
						"return","stroll":
							a.phase="idle"
							a.timer=rng.randf_range(2.0,4.5)
				if travelled>0.001 and a.phase in ["stroll","walk","enter","leave","return","homeward"]:
					obj.yard_action="walk"
			"use":
				obj.yard_action=Furniture.ITEMS[a.kind].action
				a.timer-=delta
				if a.timer<=0:
					obj.yard_action=""
					a.phase="leave"
					a.path=PackedVector2Array([Furniture.approach(item)])
					a.visits+=1
		obj.yard_seconds=obj.walk_distance/WALK_SPEED if obj.yard_action=="walk" else a.elapsed
		var verb := "대화"
		if obj.yard_action=="walk": verb="이동 중 · 대화"
		elif a.phase=="use": verb=Furniture.ITEMS[a.kind].verb
		obj.label=g.MEMBERS[obj.index].short+" · "+verb

func occupant(kind: String) -> String:
	var id: String = reservations.get(kind,"")
	return id if id=="ete" or (agents.has(id) and agents[id].phase=="use") else ""
