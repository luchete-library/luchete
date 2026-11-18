extends RefCounted

const Field = preload("res://scripts/field_sprites.gd")
const SHEET = preload("res://assets/characters/visitors/ink.png")
const TOPICS := [
	{"title":"잉크에게 권하는 첫 책","method":"추천 방송","arrival":"방송에서 소개한 책을 찾으러 왔어요."},
	{"title":"이번 호의 숨은 이야기","method":"잡지 배포","arrival":"잡지에 실린 서가를 보러 왔어요."},
	{"title":"루체테의 개관 축제","method":"거리 공연","arrival":"거리 공연에서 듣고 찾아왔어요."}
]
const DOOR := Vector2(504,680)
const SHELF := [Vector2(424,280),Vector2(520,280),Vector2(584,280),Vector2(380,280),Vector2(456,280)]
const READING := [Vector2(288,402),Vector2(606,493),Vector2(373,510),Vector2(746,363),Vector2(245,574)]
const DIRECTIONS := ["down","left","right","up"]
const PHASES := ["shelf","browse","to_read","read","leave"]
const SPEED := 86.0
var campaigns := 0
var total := 0
var topic := -1
var host := ""
var live_recommendation := false
var pending := 0
var delay := 0.0
var guests: Array[Dictionary] = []
# Routes depend on the current furniture. Only the pose and destination survive a map rebuild.
var paths := {}
var texture: CanvasTexture

func door_position() -> Vector2:
	return DOOR

func group_size() -> int:
	return mini(campaigns+1,READING.size())

func promoting(id: String) -> bool:
	return topic>=0 and host==id and (live_recommendation if topic==0 else pending==group_size())

func _resolve_host(state, member: String="") -> String:
	# Explicit hosts are also used when an existing daily broadcast signs off.
	# Only automatic assignment excludes the current broadcast/workout hosts.
	if member!="": return member
	for i in range(state.residents.size()):
		var candidate: String=state.residents[(campaigns+i)%state.residents.size()]
		if candidate!=state.yard_host and candidate!=state.yard_session.get("member",""):
			return candidate
	return ""

func start_error(state, choice: int, member: String="") -> String:
	if state.scene!="library": return "홍보는 공용 도서관에서 맡겨 주세요."
	if state.opening_pending or state.rebuild_stage()!=6: return "도서관을 재개관한 뒤 홍보할 수 있어요."
	if topic!=-1: return "진행 중인 홍보와 방문을 먼저 마무리해 주세요."
	if choice<0 or choice>=TOPICS.size(): return "홍보 주제를 다시 골라 주세요."
	if _resolve_host(state,member) not in state.residents: return "방송이나 운동을 마친 스텔라에게 홍보를 맡길 수 있어요."
	return ""

func start(state, choice: int, member: String = "") -> bool:
	if start_error(state,choice,member)!="": return false
	var assigned_show:=choice==0 and member==""
	member=_resolve_host(state,member)
	campaigns+=1
	topic=choice
	host=member
	live_recommendation=assigned_show
	pending=group_size()
	delay=2.4
	return true

func next_stop(v: Dictionary) -> Vector2:
	match v.phase:
		"shelf": return SHELF[v.slot]
		"to_read": return READING[v.slot]
	return DOOR

func walk(g, v: Dictionary, dt: float) -> bool:
	var slot: int=v.slot
	if not paths.has(slot):
		var start: Vector2i=g._grid_at(v.pos)
		var end: Vector2i=g._grid_at(next_stop(v))
		if start.x<0 or end.x<0: return false
		var path: PackedVector2Array=g.navigation.get_point_path(start,end)
		if path.is_empty(): return false
		paths[slot]=path
	var route: PackedVector2Array=paths[slot]
	var budget := SPEED*dt
	while budget>0 and not route.is_empty():
		var delta: Vector2=route[0]-v.pos
		var length:=delta.length()
		var stride:=minf(length,budget)
		if stride>0.001:
			v.facing=Field.direction_for(delta.normalized()*8.0,v.facing)
			v.distance+=stride
			v.pos=v.pos.move_toward(route[0],stride)
		budget-=stride
		if length<=stride: route.remove_at(0)
		else: break
	paths[slot]=route
	if not route.is_empty(): return false
	paths.erase(slot)
	return true

func refresh_map(g) -> void:
	paths.clear()
	if g.state.scene!="library" or g.mode in ["chapter","rescue"]: return
	for v in guests:
		if not g._walkable(v.pos):
			var cell: Vector2i=g._grid_at(v.pos)
			if cell.x>=0: v.pos=g.navigation.get_point_position(cell)

func advance(g, dt: float) -> void:
	if topic==-1: return
	dt=minf(dt,0.15)
	var changed:=false
	if pending>0:
		if promoting(host) and not g._find_object(host).get("promo_ready",false): return
		delay-=dt
		if delay<=0:
			var slot:=group_size()-pending
			guests.append({"slot":slot,"phase":"shelf","pos":DOOR,"facing":"up","distance":0.0,"elapsed":0.0})
			pending-=1
			total+=1
			delay=3.2 if pending>0 else 0.0
			if slot==0: g._notify("잉크가 찾아왔어요!  “%s”" % TOPICS[topic].arrival)
			changed=true
	for i in range(guests.size()-1,-1,-1):
		var v:=guests[i]
		v.elapsed+=dt
		match v.phase:
			"browse":
				if v.elapsed>=1.6: v.phase="to_read"; v.elapsed=0.0
			"read":
				if v.elapsed>=13.0+v.slot: v.phase="leave"; v.elapsed=0.0
			_:
				if not walk(g,v,dt): continue
				match v.phase:
					"shelf": v.phase="browse"; v.facing="up"
					"to_read": v.phase="read"; v.facing="down"
					"leave": guests.remove_at(i); changed=true
				v.elapsed=0.0
	if pending==0 and guests.is_empty():
		topic=-1
		host=""
		live_recommendation=false
		g._notify("마지막 잉크가 책을 덮고 돌아갔어요. 새 홍보 주제를 맡길 수 있어요.")
	if changed: g._save()

func draw_guest(g, v: Dictionary) -> void:
	if texture==null:
		texture=CanvasTexture.new()
		texture.diffuse_texture=SHEET
		texture.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var row:=DIRECTIONS.find(v.facing)
	var frame:=floori(v.distance/4.5)%16
	if v.phase=="browse": frame=0
	if v.phase=="read":
		row=4
		frame=floori(v.elapsed*9.0)%32
	var p: Vector2=v.pos.round()
	var visibility:=1.0
	if v.phase=="shelf": visibility=smoothstep(0,23,v.distance)
	elif v.phase=="leave": visibility=smoothstep(0,23,p.distance_to(door_position()))
	if visibility>0.2: g.draw_ellipse_shadow(p+Vector2(0,2),Vector2(13,3)*visibility)
	var anchor_x:=34 if v.facing in ["up","right"] else 29
	g.draw_texture_rect_region(texture,Rect2(p-Vector2(anchor_x,57),Vector2(64,64)),Rect2(frame*64,row*64,64,64),Color(1,1,1,visibility))

func data() -> Dictionary:
	var visible: Array=[]
	for v in guests:
		visible.append({"slot":v.slot,"phase":v.phase,"x":v.pos.x,"y":v.pos.y,"facing":v.facing,"distance":v.distance,"elapsed":v.elapsed})
	return {"campaigns":campaigns,"total":total,"topic":topic,"host":host,"pending":pending,"delay":delay,"guests":visible,"live_recommendation":live_recommendation}

static func number(v: Variant, low: float, high: float, whole:=false) -> bool:
	return (v is int or v is float) and v>=low and v<=high and (not whole or v==floor(v))

func restore(raw: Variant, residents: Array) -> bool:
	if not raw is Dictionary or not raw.get("guests") is Array: return false
	if not number(raw.get("campaigns"),0,1e9,true) or not number(raw.get("total"),0,5e9,true): return false
	if not number(raw.get("topic"),-1,TOPICS.size()-1,true) or not number(raw.get("pending"),0,READING.size(),true) or not number(raw.get("delay"),0,3.2): return false
	campaigns=int(raw.campaigns)
	total=int(raw.total)
	topic=int(raw.topic)
	pending=int(raw.pending)
	if not raw.get("live_recommendation",false) is bool: return false
	live_recommendation=topic==0 and raw.get("live_recommendation",pending==group_size())
	delay=float(raw.delay)
	if not raw.get("host") is String: return false
	host=raw.host
	if topic==-1: return host=="" and pending==0 and raw.guests.is_empty()
	if campaigns==0 or host not in residents or pending+raw.guests.size()>group_size(): return false
	if pending==0 and raw.guests.is_empty(): return false
	var slots: Array=[]
	for v in raw.guests:
		if not v is Dictionary or not number(v.get("slot"),0,group_size()-pending-1,true) or int(v.slot) in slots: return false
		if v.get("phase") not in PHASES or v.get("facing") not in DIRECTIONS: return false
		if not number(v.get("x"),72,908) or not number(v.get("y"),252,685) or not number(v.get("distance"),0,1e7) or not number(v.get("elapsed"),0,1e7): return false
		slots.append(int(v.slot))
		guests.append({"slot":int(v.slot),"phase":v.phase,"pos":Vector2(v.x,v.y),"facing":v.facing,"distance":float(v.distance),"elapsed":float(v.elapsed)})
	return true
