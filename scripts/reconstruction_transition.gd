extends RefCounted

# Work time is owned by the caller. This helper only owns approach/return time.
# advance() never completes a reconstruction task or writes a save.
const Work = preload("res://scripts/growth_work_sprites.gd")
const Furniture = preload("res://scripts/garden_furniture.gd")
const Field = preload("res://scripts/field_sprites.gd")
const SPEED := 150.0
const Layout = preload("res://scripts/library_world_layout.gd")
var phase := "idle" # approach -> work -> return -> done
var task := ""
var actors: Array = []
var player_home := Vector2.ZERO
var fan_form := ""
var elapsed := 0.0
var fade := 0.0
var fallback := false

func reset() -> void:
	phase="idle"
	task=""
	actors.clear()
	elapsed=0
	fade=0
	fallback=false

func begin(g, id: String) -> void:
	reset()
	task=id
	phase="approach"
	player_home=g.player_pos
	fan_form=g.state.fan_form
	for member in Work.participants(task):
		var obj: Dictionary=g._find_object(member)
		var start: Vector2=obj.get("pos",Work.FEET.get(member,Vector2(558,658)))
		var from_studio: bool=obj.get("in_studio",false)
		if from_studio: start=g.garden_residents.lobby_door(g)
		var target: Vector2=Vector2(558,658) if member=="fuwa" else Work.FEET[member]
		if g.world_map_active(): target=Layout.work_point(task,target)
		_add(g,member,start,target,from_studio)
		actors.back()["room_pos"]=obj.get("pos",start)
	if task=="corridor": _add(g,"player",player_home,Layout.work_point(task,Vector2(445,645)) if g.world_map_active() else Vector2(445,645),false)

func _add(g,id: String,start: Vector2,target: Vector2,from_studio: bool) -> void:
	var path: PackedVector2Array=g.garden_residents.path_between(g,start,target)
	var bad := path.is_empty()
	fallback=fallback or bad or from_studio
	actors.append({"id":id,"pos":start,"home":start,"target":target,"path":path,"facing":"down","distance":0.0,"walking":false,"fallback":bad,"studio":from_studio,"delay":actors.size()*.32 if from_studio else 0.0})

func advance(g, delta: float) -> void:
	if phase not in ["approach","return","return_fade"]: return
	var dt := maxf(0,delta)
	elapsed+=dt
	if phase=="return_fade":
		fade=sin(PI*minf(elapsed/.8,1.0))
		if elapsed>=.8: phase="done"; fade=0
		return
	# A disconnected private room (or a blocked endpoint after layout edits) is
	# bridged by a short, explicit page fade; never walk through furniture.
	if fallback and elapsed<.8:
		fade=sin(PI*elapsed/.8)
		if elapsed>=.4:
			for actor in actors:
				if actor.fallback: actor.pos=actor.target; actor.path.clear(); actor.walking=false
		return
	fade=0
	var moving := false
	for actor in actors:
		if phase=="approach" and actor.studio and elapsed<.8+actor.delay:
			moving=true
			continue
		var before: Vector2=actor.pos
		var remaining := SPEED*dt
		while remaining>0 and not actor.path.is_empty():
			var target: Vector2=actor.path[0]
			var distance: float=actor.pos.distance_to(target)
			if distance<=remaining:
				actor.pos=target
				actor.path.remove_at(0)
				remaining-=distance
			else:
				actor.pos=actor.pos.move_toward(target,remaining)
				remaining=0
		var displacement: Vector2=actor.pos-before
		var travelled := displacement.length()
		actor.distance+=travelled
		actor.walking=travelled>.001
		if actor.walking: actor.facing=Field.direction_for(displacement.normalized()*8,actor.facing)
		moving=moving or not actor.path.is_empty()
		if actor.id=="player" and not fan_form.is_empty(): g.fan_motion.advance(fan_form,"reconstruction",dt,travelled,false,true,displacement)
	if not moving:
		if phase=="approach": phase="work"
		elif actors.any(func(actor): return actor.studio): phase="return_fade"; elapsed=0
		else: phase="done"
		for actor in actors: actor.walking=false; actor.facing="down"

func begin_return(g) -> void:
	if phase!="work": return
	phase="return"
	elapsed=0
	fallback=false
	for actor in actors:
		if task=="corridor":
			if actor.id=="fuwa": actor.pos=Vector2(838,658)
			elif actor.id=="player": actor.pos=Vector2(725,645)
			if g.world_map_active() and actor.id in ["fuwa","player"]: actor.pos=Layout.work_point(task,actor.pos)
		actor.target=actor.home
		actor.path=g.garden_residents.path_between(g,actor.pos,actor.home)
		actor.fallback=actor.path.is_empty()
		fallback=fallback or actor.fallback
		actor.walking=not actor.path.is_empty()

func draw_world(g) -> void:
	if phase not in ["approach","return","return_fade","done"]: return
	if task=="corridor":
		var crate: Vector2=Work.BOX_START if phase=="approach" else Work.BOX_END
		Work._crate(g,Layout.work_point(task,crate) if g.world_map_active() else crate)
	var ordered := actors.duplicate()
	ordered.sort_custom(func(a,b): return a.pos.y<b.pos.y)
	for actor in ordered:
		var pos: Vector2=actor.pos
		if actor.studio and ((phase=="approach" and elapsed<.4) or (phase=="return_fade" and elapsed>=.4) or phase=="done"):
			pos=actor.room_pos
		if actor.id=="player":
			if fan_form.is_empty(): g._draw_player(pos,actor.walking)
			else: g.FanForms.draw(g,fan_form,pos,actor.walking)
		else:
			var member: Dictionary=g.MEMBERS[g._mission_index_for(actor.id)]
			g.Yard.draw_actor(g,member,pos,"walk" if actor.walking else "idle",actor.distance/66.0,actor.facing,actor.distance)

func draw_overlay(g) -> void:
	if fade<=0: return
	g.draw_rect(Rect2(0,140,1280,474),Color(.13,.15,.13,fade*.93))
	g._center(365,"작업할 곳으로 모이고 있어요" if phase=="approach" else "함께 정리를 마치고 돌아가요",23,Color(1,.93,.78,fade))

func label() -> String:
	return "작업 자리로 모이는 중" if phase=="approach" else "정리를 마치고 돌아가는 중" if phase in ["return","return_fade"] else "함께 작업 중"
