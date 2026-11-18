extends "res://scripts/garden_residents.gd"

const Layout=preload("res://scripts/library_world_layout.gd")
var world_mode:=false

func reset(g) -> void:
	world_mode=g.has_method("world_map_active") and g.world_map_active()
	var saved: Dictionary={}
	if world_mode:
		for obj in g.objects:
			if obj.type=="npc" and obj.get("world_keep",false): saved[obj.id]={"pos":obj.pos,"private":Layout.private_point(obj.pos)}
	super.reset(g)
	if not world_mode: return
	for obj in g.objects:
		if obj.type!="npc": continue
		if saved.has(obj.id):
			obj.pos=saved[obj.id].pos;obj.in_studio=saved[obj.id].private
		else: obj.pos=Layout.HOMES[obj.index] if obj.in_studio else Layout.PUBLIC_SPOTS[obj.index]
		agents[obj.id].phase="studio" if obj.in_studio else "idle"
		agents[obj.id].timer=10.0+obj.index*4.0 if obj.in_studio else 2.0
		agents[obj.id].public_time=24.0+obj.index*3

func home_spot(g,obj: Dictionary) -> Vector2:
	return Layout.PUBLIC_SPOTS[obj.index] if world_mode else super.home_spot(g,obj)

func enter_studio(obj: Dictionary) -> void:
	if not world_mode: super.enter_studio(obj);return
	release(obj.id)
	obj.in_studio=true;obj.pos=Layout.HOME_DOOR;obj.facing="right"
	obj.yard_action="idle";obj.yard_seconds=0.0
	var a: Dictionary=agents[obj.id]
	a.phase="studio_arrive";a.elapsed=0.0;a.timer=24.0+obj.index*3.0
	a.path=PackedVector2Array()

func lobby_door(g) -> Vector2:
	return Layout.PUBLIC_DOOR if world_mode else super.lobby_door(g)

func path_between(g,start: Vector2,target: Vector2) -> PackedVector2Array:
	return Layout.path(g.navigation,start,target) if world_mode else super.path_between(g,start,target)

func leave_studio(g,obj: Dictionary) -> void:
	if not world_mode: super.leave_studio(g,obj);return
	release(obj.id)
	var a: Dictionary=agents[obj.id]
	a.phase="studio_leave"
	a.path=path_between(g,obj.pos,Layout.HOME_DOOR)
	a.public_time=28.0+obj.index*2.0

func _walk_private(obj: Dictionary,a: Dictionary,delta: float) -> bool:
	var before: Vector2=obj.pos
	var distance:=walk(obj,a,delta)
	obj.walk_distance+=distance
	if distance>.001: obj.facing=Field.direction_for((obj.pos-before).normalized()*8,obj.facing)
	obj.yard_action="walk" if distance>.001 else "idle"
	obj.yard_seconds=obj.walk_distance/WALK_SPEED
	return a.path.is_empty()

func update_studio(g,obj: Dictionary,a: Dictionary,delta: float) -> bool:
	if obj.get("direct_control",false): return true
	if not world_mode: return super.update_studio(g,obj,a,delta)
	var promotion=g.state.ink_visits
	var promoting: bool=promotion.promoting(obj.id)
	var on_air: bool=g.state.yard_host==obj.id or (promoting and promotion.topic==0)
	if not obj.in_studio and on_air:
		if a.phase!="air_return":
			release(obj.id);a.phase="air_return";a.path=path_between(g,obj.pos,Layout.PUBLIC_DOOR)
		if _walk_private(obj,a,delta): enter_studio(obj)
		obj.promo_ready=false
		return true
	if obj.in_studio:
		if a.phase=="studio_arrive":
			if a.path.is_empty(): a.path=path_between(g,obj.pos,Layout.HOMES[obj.index])
			if _walk_private(obj,a,delta): a.phase="studio";a.timer=24.0+obj.index*3.0
			return true
		if a.phase=="studio_leave":
			if _walk_private(obj,a,delta):
				obj.pos=Layout.PUBLIC_DOOR;obj.in_studio=false;obj.facing="left"
				a.phase="idle";a.timer=.8
			return true
		if on_air:
			a.phase="studio_air";a.elapsed+=delta
			obj.promo_ready=promoting;obj.promo_away=false
			obj.yard_action="stream";obj.yard_seconds=a.elapsed;obj.facing="down"
			return true
		if a.phase=="studio_air": a.phase="studio";a.timer=5.0;obj.promo_ready=false
		if promoting or g.state.yard_session.get("member","")==obj.id:
			leave_studio(g,obj);return true
		if a.phase=="studio_stroll":
			if _walk_private(obj,a,delta): a.phase="studio";a.timer=5.0
			return true
		a.timer-=delta;a.elapsed+=delta;obj.yard_action="idle";obj.yard_seconds=a.elapsed
		if a.timer<=0: leave_studio(g,obj)
		return true
	if not promoting and g.state.yard_session.get("member","")!=obj.id and g.pending_object!=obj.id:
		a.public_time=a.get("public_time",30.0)-delta
		if a.phase=="idle" and a.public_time<=0:
			a.path=path_between(g,obj.pos,Layout.PUBLIC_DOOR)
			if not a.path.is_empty(): a.phase="homeward"
	return false

func choose_stroll(g,obj: Dictionary,a: Dictionary) -> bool:
	if not world_mode: return super.choose_stroll(g,obj,a)
	for attempt in range(24):
		var point:=Vector2(rng.randf_range(302,1212),rng.randf_range(218,720))
		if point.distance_to(obj.pos)<65 or not has_room_to_stop(g,obj.id,point): continue
		var path:=path_between(g,obj.pos,point)
		if path.is_empty(): continue
		a.phase="stroll";a.path=path;a.elapsed=0.0
		return true
	return false
