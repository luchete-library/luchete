extends RefCounted

# Mato retraces the memory. The forest rabbits discover and raise Yato themselves.
const Storehouse = preload("res://scripts/book_activities/yato_stores.gd")
const STEPS := [
	["trail","nest","family"],
	["basket","truth"],
	["bend","village","gaze"],
	["beside","light"],
]
const SITES := {
	"trail":[Vector2(279,535),"풀숲의 토끼"],
	"nest":[Vector2(524,420),"토끼들이 모인 자리"],
	"family":[Vector2(687,462),"함께 자란 시간"],
	"basket":[Storehouse.BASKET_SIDE,"식량 바구니 살펴보기"],
	"truth":[Storehouse.FAMILY_SIDE,"토끼 가족 곁으로"],
	"bend":[Vector2(477,505),"굽잇길에서 내려다보기"],
	"village":[Vector2(812,427),"산 아래 마을로"],
	"gaze":[Vector2(665,411),"마을 사람들 곁에 서기"],
	"beside":[Vector2(566,478),"야토 곁에 머물기"],
}
const TRAIL_START := Vector2(170,561)
const TOWN_START := Vector2(168,493)
const YATO_AT_REST := Vector2(615,444)
const VILLAGERS := [Vector2(682,351),Vector2(728,369),Vector2(767,345)]
const COATS := [Color("8b8294"),Color("627b81"),Color("9a857f")]
const LIGHT_TIME := 3.0
const WARM := Color("ffde91")
const INK := Color("55434b")
var storehouse := Storehouse.new()
var rabbit_at := -10.0
var light := 0.0

static func ready(scene: int,notes: Array) -> bool:
	return STEPS[scene].back() in notes

static func on_mountain(scene: int,notes: Array) -> bool:
	return scene==2 and "village" not in notes

static func mountain_floor() -> PackedVector2Array:
	return PackedVector2Array([Vector2(73,507),Vector2(236,467),Vector2(326,425),Vector2(400,452),Vector2(563,453),Vector2(689,410),Vector2(807,374),Vector2(907,356),Vector2(907,493),Vector2(739,566),Vector2(556,609),Vector2(360,649),Vector2(180,630),Vector2(73,597)])

static func restored_notes(raw: Variant) -> Array:
	var restored: Array=[]
	if raw is Array:
		for marks in STEPS:
			for mark in marks:
				if mark=="basket" and raw.any(func(old): return old in ["basket","shelf","bowl0","bowl1","bowl2","truth"]):
					restored.append(mark)
				elif mark in raw: restored.append(mark)
	return restored

func resume(notes: Array) -> void:
	storehouse.restore(notes)
	rabbit_at=-10.0
	light=1.0 if "light" in notes else 0.0

static func spawn(scene: int,notes: Array) -> Vector2:
	match scene:
		0: return Vector2(468,483) if "nest" in notes else Vector2(160,584)
		1:
			if "truth" in notes: return Storehouse.FAMILY_SIDE
			return Storehouse.BASKET_SIDE if "basket" in notes else Storehouse.ENTRANCE
		2:
			if "village" in notes: return TOWN_START
			return SITES.bend[0] if "bend" in notes else TRAIL_START
		_: return SITES.beside[0] if "beside" in notes else Vector2(248,566)

static func sites(scene: int,notes: Array) -> Array:
	if scene==3: return ["beside"]
	for mark in STEPS[scene]:
		if mark not in notes: return [mark]
	return []

static func record_site(scene: int) -> Vector2:
	return SITES[["family","truth","gaze","beside"][scene]][0]

static func add_sites(objects: Array,scene: int,notes: Array) -> void:
	for id in sites(scene,notes):
		objects.append({"id":"mato_"+id,"type":"yato_site","index":scene,"reach":14.0 if scene==1 else 78.0,"pos":SITES[id][0],"label":SITES[id][1]})

static func hint(scene: int,notes: Array) -> String:
	match scene:
		0:
			if "nest" in notes: return "풀밭 건너편에서 야토와 토끼들이 함께 보낸 시간을 살펴보자."
			return "작은 발자국을 따라 토끼들이 모인 자리까지 가 보자." if "trail" in notes else "숲 입구의 풀숲에서 긴 귀가 움직여. 가까이 가 보자."
		1:
			if "basket" in notes: return "오른쪽에서 기다리는 토끼 가족 곁으로 걸어가 보자."
			return "왼쪽 식량 바구니 곁에서 E를 누르거나 바구니를 클릭해 보자."
		2:
			if "village" in notes: return "골목 안쪽으로 야토와 걸어가서 마을 사람들의 반응을 살펴보자."
			return "기와지붕 쪽으로 계속 내려가 마을 어귀에 닿아 보자." if "bend" in notes else "야토가 몰래 향한 산길이야. 굽잇길까지 직접 걸어가 보자."
		_: return "야토 곁에서 잠깐 걸음을 멈추고 빛이 어디에서 피는지 바라보자." if "beside" in notes else "풀밭에 홀로 선 야토 곁으로 가 보자."

static func mark_found(g,mark: String) -> void:
	var notes: Array=g._chapter_progress().yato_notes
	if mark not in notes:
		notes.append(mark)
		if g.replay_progress==null: g._save()

func inspect(g,obj: Dictionary) -> void:
	var progress=g._chapter_progress()
	var scene: int=progress.debut_scene("yato")
	var notes: Array=progress.yato_notes
	var id: String=obj.id.trim_prefix("mato_")
	if g.mode!="chapter" or g.chapter_question or g.MEMBERS[g.story_member].id!="yato" or obj.index!=scene or id not in sites(scene,notes): return
	match id:
		"trail":
			rabbit_at=g.clock
			g.chapter_note="토끼 한 마리가 귀를 세우더니 숲 안쪽으로 뛰어가. 저쪽에도 귀가 보여."
		"nest":
			g.chapter_note="토끼들 사이에 아기가 있어. 숲에 남겨진 야토를 이 토끼들이 처음 발견했구나."
		"family": g.chapter_note="같은 풀밭에 다시 선 야토가 훌쩍 컸어. 토끼들은 야토의 가족이자 동료였어."
		"basket","truth":
			storehouse.begin(g,id)
			return
		"bend": g.chapter_note="나무 사이로 기와지붕이 보여. 야토는 산 아래 사람들이 궁금해서 몰래 이 길로 내려왔어."
		"village":
			g.player_pos=TOWN_START
			g.chapter_note="흙길이 끝나고 발밑에 돌이 밟혀. 골목 안쪽에 사람들이 서 있어."
		"gaze": g.chapter_note="야토가 다가가도 누구 하나 반갑게 맞아 주지 않아. 야토에게 돌아온 건 차가운 시선이었어."
		"beside":
			g.chapter_note="토끼들 곁에서도, 마을 사람들 사이에서도 달랐던 나는 누구일까. 야토가 가만히 서 있어."
			# The ordinary approach radius can stop the player on either side of the marker.
			if id in notes: return
	mark_found(g,id)
	g._play_chime(495 if id in ["truth","gaze"] else 665)
	g._setup_map()
	if ready(scene,notes) and id!="gaze": g._inspect_chapter(scene,g.chapter_note)

func watch(g,delta: float) -> void:
	var notes: Array=g._chapter_progress().yato_notes
	if "beside" not in notes or "light" in notes or g.moving or g.player_pos.distance_to(SITES.beside[0])>92: return
	light=minf(1.0,light+delta/LIGHT_TIME)
	if light>=1.0:
		mark_found(g,"light")
		g.chapter_note="야토에게서 따뜻한 빛이 번져 와. 자신이 누구인지 알고 싶어 한 그 마음에서 피어난 빛이야."
		g._play_chime(812)
		g._setup_map()

static func feet(g,scene: int,notes: Array) -> Vector2:
	match scene:
		0: return Vector2(608,431)
		1: return g.yato_forest.storehouse.feet()
		2:
			var x: float=g.player_pos.x
			if on_mountain(scene,notes):
				var t:=clampf((x-TRAIL_START.x)/620,0,1)
				return TRAIL_START.lerp(Vector2(780,427),t)+Vector2(72,-27)
			return Vector2(299,456).lerp(Vector2(603,403),clampf((x-TOWN_START.x)/445,0,1))
		_: return YATO_AT_REST

static func rabbit_hop(g,a: Vector2,b: Vector2,t: float,scale_factor: float) -> void:
	var p:=a.lerp(b,t)
	p.y-=absf(sin(t*PI*5))*9
	g.draw_ellipse_shadow(Vector2(p.x,a.lerp(b,t).y+2),Vector2(10,3))
	g.WorldPixels.sprite(g,"rabbit",p.round(),scale_factor)

static func draw_mark(g,p: Vector2,trail: bool=false) -> void:
	var tint:=Color("ffeab8")
	if trail:
		for j in range(2):
			var q:=p+Vector2(4*j,-3*j)
			g.draw_rect(Rect2(q,Vector2(3,5)),tint)
	else:
		g.draw_ellipse_shadow(p,Vector2(20,6))
		g.draw_arc(p,18,0,TAU,24,Color("f9d69a"),2)
		g._star(p-Vector2(0,12),4+sin(g.clock*2),tint)

static func villager(g,p: Vector2,coat: Color,turn: bool) -> void:
	# The same silent bystanders, now with connected limbs, folded cloth and a
	# properly shaded head. Turning changes the glance, never the body scale.
	g.draw_ellipse_shadow(p,Vector2(14,4))
	g._transform(p.round(),Vector2.ONE*1.18)
	var edge:=Color("393440")
	var shade:=coat.darkened(.27)
	var lit:=coat.lightened(.22)
	for x in [-7,3]:
		g.draw_rect(Rect2(x,-10,5,9),edge)
		g.draw_rect(Rect2(x+1,-9,3,7),Color("bbb3a7"))
		g.draw_rect(Rect2(x-1,-3,7,3),edge)
		g.draw_rect(Rect2(x,-3,5,1),Color("807582"))
	var outline:=PackedVector2Array([Vector2(-5,-40),Vector2(5,-40),Vector2(10,-36),Vector2(14,-24),Vector2(12,-20),Vector2(10,-20),Vector2(13,-7),Vector2(9,-5),Vector2(-11,-5),Vector2(-13,-8),Vector2(-10,-23),Vector2(-14,-22),Vector2(-14,-27),Vector2(-10,-36)])
	g.draw_colored_polygon(outline,edge)
	g.draw_colored_polygon(PackedVector2Array([Vector2(-4,-38),Vector2(4,-38),Vector2(8,-34),Vector2(10,-22),Vector2(7,-20),Vector2(-7,-20),Vector2(-11,-24),Vector2(-9,-34)]),coat)
	g.draw_colored_polygon(PackedVector2Array([Vector2(-7,-21),Vector2(7,-21),Vector2(11,-8),Vector2(8,-7),Vector2(-10,-7)]),shade)
	for x in [-6,-1,5]:
		g.draw_line(Vector2(x,-19),Vector2(x-1,-9),coat,2)
		g.draw_line(Vector2(x+1,-18),Vector2(x,-10),lit.darkened(.17),1)
	g.draw_line(Vector2(-5,-36),Vector2(5,-28),Color("d8cebc"),2)
	g.draw_line(Vector2(4,-37),Vector2(0,-30),Color("f0dfc4"),1)
	g.draw_rect(Rect2(-7,-22,14,3),edge)
	g.draw_rect(Rect2(-6,-22,12,1),lit)
	g.draw_rect(Rect2(3,-25,3,3),Color("dbb688"))
	g.draw_line(Vector2(4,-22),Vector2(6,-16),lit,1)
	for side in [-1,1]:
		g.draw_line(Vector2(side*9,-33),Vector2(side*11,-25),lit if side<0 else shade,2)
		g.draw_rect(Rect2(side*11-1,-23,3,4),Color("c8a58e"))
	# A neck overlap removes the disconnected head/block appearance.
	g.draw_rect(Rect2(-3,-43,6,7),Color("b28c7b"))
	var face:=Vector2(2 if turn else -1,-49)
	g.draw_colored_polygon(PackedVector2Array([face+Vector2(-7,-8),face+Vector2(5,-8),face+Vector2(8,-4),face+Vector2(8,6),face+Vector2(4,10),face+Vector2(-3,10),face+Vector2(-7,5)]),edge)
	g.draw_colored_polygon(PackedVector2Array([face+Vector2(-5,-4),face+Vector2(5,-4),face+Vector2(6,0),face+Vector2(6,5),face+Vector2(3,8),face+Vector2(-2,7),face+Vector2(-5,3)]),Color("caa78e"))
	g.draw_rect(Rect2(face+Vector2(-3,-2),Vector2(7,5)),Color("e3c2a0"))
	g.draw_colored_polygon(PackedVector2Array([face+Vector2(-7,2),face+Vector2(-7,-6),face+Vector2(-4,-10),face+Vector2(3,-10),face+Vector2(7,-6),face+Vector2(7,-3),face+Vector2(1,-4),face+Vector2(-3,-2),face+Vector2(-4,4)]),Color("514451"))
	g.draw_line(face+Vector2(-4,-7),face+Vector2(2,-8),Color("80707a"),1)
	g.draw_rect(Rect2(face+Vector2(-2,-13),Vector2(6,4)),edge)
	g.draw_rect(Rect2(face+Vector2(-1,-12),Vector2(3,1)),Color("8f7e89"))
	var eye:=face+Vector2(4 if turn else -2,1)
	g.draw_rect(Rect2(eye,Vector2(1,2)),edge)
	g.draw_rect(Rect2(face+Vector2(2,6),Vector2(2,1)),Color("9f766a"))
	g._transform()

func draw_foreground_light(g) -> void:
	if light<=0: return
	var chest:=YATO_AT_REST-Vector2(0,55)
	g._star(chest,6*light,Color("fff4c2"))
	for i in range(18):
		var t:=fposmod(g.clock*.26+i/18.0,1.0)
		var angle:=TAU*i*.382
		var p: Vector2=chest+Vector2(cos(angle)*92,sin(angle)*63)*t*light
		if p.y<chest.y-15 and absf(p.x-chest.x)<23: continue
		g._star(p.round(),(6-3*t)*light,Color(1,.88,.58,1-t*.6))

func draw_field(g,scene: int,notes: Array) -> void:
	match scene:
		0:
			var hopping:=smoothstep(0.0,1.9,g.clock-rabbit_at) if "trail" in notes else 0.0
			rabbit_hop(g,Vector2(258,496),Vector2(464,386),hopping,1.8)
			rabbit_hop(g,Vector2(548,373),Vector2(557,376),1,1.65)
			if "trail" in notes:
				for i in range(9):
					draw_mark(g,Vector2(278,500).lerp(Vector2(461,392),i/9.0)+Vector2(0,i%2*6),true)
			if "trail" in notes and "nest" not in notes:
				# Echo the ochre swaddle in the first panel at field scale.
				var p:=Vector2(502,385)
				g.draw_ellipse_shadow(p,Vector2(20,5))
				g.draw_colored_polygon(PackedVector2Array([p+Vector2(-21,-9),p+Vector2(-14,-19),p+Vector2(5,-22),p+Vector2(20,-14),p+Vector2(24,-7),p+Vector2(13,-1),p+Vector2(-12,-1)]),Color("e8cc99"))
				g.draw_rect(Rect2(p+Vector2(-12,-21),Vector2(13,11)),Color("e3b495"))
				g.draw_rect(Rect2(p+Vector2(-9,-16),Vector2(5,2)),INK)
				g.draw_line(p+Vector2(-16,-10),p+Vector2(-5,-5),Color("ab8a63"),2)
				g.draw_line(p+Vector2(-5,-5),p+Vector2(13,-15),Color("ab8a63"),2)
		1:
			storehouse.draw_field(g,notes)
			if storehouse.phase!=Storehouse.Phase.FIELD: return
		2:
			if on_mountain(scene,notes):
				var end: Vector2=SITES.village[0] if "bend" in notes else SITES.bend[0]
				var start: Vector2=SITES.bend[0] if "bend" in notes else TRAIL_START
				for i in range(1,10): draw_mark(g,start.lerp(end,i/10.0)+Vector2(0,5*sin(i*.6)),true)
			else:
				var turned: bool=g.player_pos.x>473 or "gaze" in notes
				for i in range(VILLAGERS.size()): villager(g,VILLAGERS[i],COATS[i],turned)
		3:
			if light>0:
				var chest:=YATO_AT_REST-Vector2(0,54)
				for i in range(4):
					g.draw_circle(chest,(26+i*12)*light,Color(1,.79,.40,(.20-i*.034)*light))
	if ready(scene,notes): return
	for id in sites(scene,notes):
		var p: Vector2=SITES[id][0]
		draw_mark(g,p)
		var label: String=SITES[id][1]
		if id=="beside" and "beside" in notes: label="야토 곁에서 바라보기"
		g._world_sign(p+Vector2(0,22),label,"mato_"+id)

func painted_target(g,scene: int,notes: Array,p: Vector2) -> Dictionary:
	for id in sites(scene,notes):
		var area: Rect2
		match id:
			"trail": area=Rect2(231,443,55,55)
			"nest": area=Rect2(453,338,127,62)
			"basket": area=Storehouse.basket_rect().grow(4)
			"truth":
				if g.Field.stella_hit_rect(g._field_costume_key("yato"),feet(g,scene,notes)).has_point(p): return g._find_object("mato_truth")
				area=Rect2(Storehouse.SPEAKER-Vector2(61,58),Vector2(95,62))
			"gaze": area=Rect2(661,284,121,88)
			"beside","family": area=g.Field.stella_hit_rect(g._field_costume_key("yato"),feet(g,scene,notes))
			_: continue
		if area.has_point(p): return g._find_object("mato_"+id)
	return {}
