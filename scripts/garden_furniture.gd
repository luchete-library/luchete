extends RefCounted

const ORDER := ["chair","tea","mat","camera"]
const ITEMS := {
	"chair":{"name":"독서 의자","action":"read","verb":"독서 중","detail":"앉아서 책장을 넘겨요.","solid":true,"members":[]},
	"tea":{"name":"티 테이블","action":"tea","verb":"차 마시는 중","detail":"찻잔을 들어 한 모금 마셔요.","solid":true,"members":[]},
	"mat":{"name":"요가 매트","action":"yoga","verb":"호흡하는 중","detail":"자리에 앉아 천천히 호흡해요.","solid":false,"members":[]},
	"camera":{"name":"방송 세트","action":"stream","verb":"방송 연습 중","detail":"카메라에 인사하고 끄덕여요.","solid":true,"members":[]}
}
const Rebuild = preload("res://scripts/library_rebuild.gd")
const HOME_SPOTS := [Vector2(288,320),Vector2(352,330),Vector2(800,470),Vector2(818,580),Vector2(296,552),Vector2(560,550)]
const DEFAULTS := [Vector2(192,352),Vector2(192,512),Vector2(704,560),Vector2(704,320)]
const BARRIERS := [Rect2(90,210,200,47),Rect2(330,210,310,47),Rect2(400,397,180,54),Rect2(93,600,67,44),Rect2(76,405,55,64),Rect2(865,410,42,65),Rect2(660,397,109,44)]
const SERVICES := [Vector2(335,465),Vector2(476,275),Vector2(195,279),Vector2(490,450),Vector2(833,277),Vector2(132,649),Vector2(710,450),Vector2(95,290)]
const ENTRANCE := Vector2(490,620)
const FLOOR := Rect2(72,252,836,433)
const AREA := Rect2(112,288,752,328)

static func activity_position(state, member: String) -> Vector2:
	var kind := "mat" if state.yard_session.get("member","")==member else "camera"
	var item := find(state.furniture,kind)
	if not item.is_empty(): return position(item)
	if state.get("world_enabled")==true: return preload("res://scripts/library_world_layout.gd").FURNITURE[kind]
	return DEFAULTS[ORDER.find(kind)]

static func reserved_for_activity(state, kind: String) -> bool:
	return (kind=="mat" and not state.yard_session.is_empty()) or (kind=="camera" and state.yard_host!="" and (state.rebuild_stage()<6 or state.opening_pending))

static func position(item: Dictionary) -> Vector2:
	return Vector2(item.x,item.y)

static func approach(item: Dictionary) -> Vector2:
	return position(item)+Vector2(0,40)

static func footprint(kind: String, p: Vector2) -> Rect2:
	return Rect2(p+Vector2(-29,-22),Vector2(58,28)) if kind != "camera" else Rect2(p+Vector2(22,-24),Vector2(25,28))

static func zone(p: Vector2) -> Rect2:
	return Rect2(p-Vector2(40,25),Vector2(80,80))

static func find(layout: Array, kind: String) -> Dictionary:
	for item in layout:
		if item.kind == kind: return item
	return {}

static func compatible(item: Dictionary, member: String) -> bool:
	return item.enabled and (ITEMS[item.kind].members.is_empty() or member in ITEMS[item.kind].members)

static func obstacles(layout: Array) -> Array[Rect2]:
	var result: Array[Rect2] = []
	result.assign(BARRIERS)
	# Reserve every memory display from the start, so later arrivals cannot trap furniture.
	for p in Rebuild.PLACES.values(): result.append(Rect2(p-Vector2(22,11),Vector2(44,12)))
	for item in layout:
		if ITEMS[item.kind].solid: result.append(footprint(item.kind,position(item)))
	return result

static func walkable(p: Vector2, blocks: Array[Rect2]) -> bool:
	if not FLOOR.has_point(p): return false
	for block in blocks:
		if block.grow(12).has_point(p): return false
	return true

static func navigation(layout: Array) -> AStarGrid2D:
	var nav := AStarGrid2D.new()
	nav.region = Rect2i(0,0,58,44)
	nav.cell_size = Vector2(16,16)
	nav.offset = Vector2(8,8)
	nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	nav.update()
	var blocks := obstacles(layout)
	for x in range(58):
		for y in range(44): nav.set_point_solid(Vector2i(x,y),not walkable(Vector2(x*16+8,y*16+8),blocks))
	return nav

static func nearby_cell(nav: AStarGrid2D, p: Vector2) -> Vector2i:
	var best := Vector2i(-1,-1)
	var distance := 24.0*24.0
	var cell := Vector2i(p/16)
	for dx in range(-1,2):
		for dy in range(-1,2):
			var c := cell+Vector2i(dx,dy)
			if nav.is_in_boundsv(c) and not nav.is_point_solid(c):
				var d := p.distance_squared_to(nav.get_point_position(c))
				if d<distance:
					distance=d
					best=c
	return best

static func placement_error(layout: Array, kind: String, p: Vector2, player: Vector2 = Vector2.INF) -> String:
	if not ITEMS.has(kind): return "알 수 없는 가구예요."
	if not AREA.has_point(p): return "도서관 안쪽 바닥에 놓아 주세요."
	var space := zone(p)
	for rect in BARRIERS:
		if space.intersects(rect.grow(14)): return "서가와 업무용 가구에서 조금 떨어뜨려 주세요."
	for q in Rebuild.PLACES.values():
		if space.intersects(Rect2(q-Vector2(34,25),Vector2(68,44))): return "추억 진열대 앞은 비워 두어요."
	for q in SERVICES:
		if space.grow(12).has_point(q): return "에테·서가·데스크로 가는 자리를 비워 주세요."
	for q in HOME_SPOTS:
		if space.grow(12).has_point(q): return "스텔라가 쉬는 자리 옆에 놓아 주세요."
	for i in [2,3]:
		if kind!=ORDER[i] and space.grow(12).has_point(DEFAULTS[i]): return "운동과 방송을 준비하는 자리를 비워 주세요."
	if player.is_finite() and footprint(kind,p).grow(16).has_point(player): return "플레이어 자리에서 조금 떨어뜨려 주세요."
	var proposed: Array = []
	for item in layout:
		if item.kind==kind: continue
		if space.intersects(zone(position(item)).grow(4)): return "가구 사이에 드나들 틈을 남겨 주세요."
		proposed.append(item)
	proposed.append({"kind":kind,"x":p.x,"y":p.y,"enabled":true})
	var nav := navigation(proposed)
	var start := nearby_cell(nav,ENTRANCE)
	var destinations: Array = HOME_SPOTS+SERVICES
	for q in Rebuild.PLACES.values(): destinations.append(q+Vector2(0,-30))
	for i in [2,3]:
		if find(proposed,ORDER[i]).is_empty(): destinations.append(DEFAULTS[i])
	for item in proposed: destinations.append(approach(item))
	if player.is_finite(): destinations.append(player)
	for q in destinations:
		var end := nearby_cell(nav,q)
		if start.x<0 or end.x<0 or nav.get_id_path(start,end).is_empty(): return "지나갈 길이 막혀요. 한 칸 옆에 놓아 주세요."
	return ""

static func decode(value: Variant, from_garden: bool = false) -> Array:
	var result: Array = []
	if not value is Array: return result
	for raw in value:
		if not raw is Dictionary or not raw.get("kind") is String or not ITEMS.has(raw.kind): continue
		if not find(result,raw.kind).is_empty(): continue
		if (not raw.get("x") is float and not raw.get("x") is int) or (not raw.get("y") is float and not raw.get("y") is int): continue
		var p := Vector2(raw.x,raw.y)
		if not p.is_finite() or p!=p.snapped(Vector2(16,16)): continue
		if from_garden:
			if not FLOOR.has_point(p): continue
			p=DEFAULTS[ORDER.find(raw.kind)]
		if placement_error(result,raw.kind,p)!="": continue
		result.append({"kind":raw.kind,"x":int(p.x),"y":int(p.y),"enabled":raw.get("enabled",true)==true})
	return result

static func draw_rooms(g) -> void:
	g.Pixels.rooms(g)

static func draw_back(g, kind: String, p: Vector2) -> void:
	g.Pixels.furniture(g,kind,p,false)

static func draw_front(g, kind: String, p: Vector2) -> void:
	g.Pixels.furniture(g,kind,p,true)
