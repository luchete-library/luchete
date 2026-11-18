extends RefCounted

const WardPractice = preload("res://scripts/book_activities/fuwa_ward.gd")
const STEPS := [
	["seal","ward","together"], ["empty","gate","overlook","pass"],
	["clearing","wait","reunited"], ["spell","rift","awoke","shelves"]
]
const SITES := {
	"seal":[Vector2(337,481),"술식의 부적 살펴보기"],
	"together":[WardPractice.STATION,"후와 곁으로 가기"],
	"empty":[Vector2(540,432),"비어 있는 자리"],
	"gate":[Vector2(147,336),"신사 문을 지나 눈산으로"],
	"overlook":[Vector2(396,459),"나무 사이로 산길 바라보기"],
	"pass":[Vector2(685,333),"고갯길 오르기"],
	"clearing":[Vector2(371,486),"눈 덮인 공터로"],
	"wait":[Vector2(671,438),"눈밭에서 고개 들기"],
	"spell":[Vector2(525,471),"후와의 귀환술 지켜보기"],
	"shelves":[Vector2(650,384),"낯선 서가 살펴보기"],
}
const SEARCH_START := Vector2(203,405)
const SNOW_ENTRANCE := Vector2(172,552)
const HALL_ENTRANCE := Vector2(300,554)
const REUNION_TIME := 2.8
const RIFT_FRAME := 10
const FROST := Color("c7eff9")
const GOLD := Color("fbd697")
var practice := WardPractice.new()
var arrival := 0.0
var reunion_feet := Vector2.ZERO
var viewing := false
var beyond_rift := false
var film_time := 0.0
var overlook_at := 0.0

static func ready(scene: int,notes: Array) -> bool:
	return STEPS[scene].back() in notes

static func restored_notes(raw: Variant) -> Array:
	var notes: Array=[]
	if raw is Array:
		for mark in ["brush_top","brush_bottom","ward_loop"]:
			if mark in raw: notes.append(mark)
		for marks in STEPS:
			for mark in marks:
				if mark in raw: notes.append(mark)
	return notes

static func sites(scene: int,notes: Array) -> Array:
	match scene:
		0: return ["together"]
		1:
			if "empty" not in notes: return ["empty"]
			if "gate" not in notes: return ["gate"]
			return ["pass"] if "overlook" in notes else ["overlook"]
		2: return ["wait"] if "clearing" in notes else ["clearing"]
		_: return ["shelves"] if "awoke" in notes else ["spell"]

static func record_site(scene: int) -> Vector2:
	return SITES[["together","pass","wait","shelves"][scene]][0]

static func add_sites(objects: Array,scene: int,notes: Array) -> void:
	for id in sites(scene,notes):
		objects.append({"id":"tenbi_"+id,"type":"fuwa_site","index":scene,"reach":17.0 if scene==0 else 78.0,"pos":SITES[id][0],"label":SITES[id][1]})

static func place(scene: int,notes: Array) -> String:
	if scene==1: return "눈산 · 후와가 오른 고갯길" if "gate" in notes else "신사 · 텐비의 빈자리"
	if scene==3 and "awoke" in notes: return "빛 너머 · 낯선 도서관"
	return ""

static func map_index(scene: int,notes: Array) -> int:
	if scene==1 and "gate" not in notes: return 0
	return scene

static func floor_area(g,scene: int,notes: Array) -> PackedVector2Array:
	if scene==3 and "awoke" in notes:
		return PackedVector2Array([Vector2(72,373),Vector2(907,373),Vector2(907,684),Vector2(72,684)])
	return g.Chapters.floor_polygon("fuwa",map_index(scene,notes))

static func spawn(scene: int,notes: Array) -> Vector2:
	match scene:
		0: return WardPractice.STATION if WardPractice.next_corner(notes)>0 or "together" in notes else Vector2(214,555)
		1: return SNOW_ENTRANCE if "gate" in notes else Vector2(628,501)
		2: return SITES.wait[0] if "wait" in notes else Vector2(178,555)
		_: return HALL_ENTRANCE if "awoke" in notes else Vector2(306,545)

func resume(scene: int,notes: Array,tenbi: Vector2) -> void:
	practice.reset()
	viewing=false
	beyond_rift=false
	film_time=0.0
	overlook_at=-10.0
	arrival=1.0 if "reunited" in notes else 0.0
	if scene==2: reunion_feet=tenbi+Vector2(-64,-9)

func approaching(scene: int,notes: Array) -> bool:
	return scene==2 and "wait" in notes and "reunited" not in notes

static func visible_fuwa(scene: int,notes: Array) -> bool:
	return scene!=1 and (scene!=2 or "wait" in notes)

func feet(scene: int,notes: Array) -> Vector2:
	match scene:
		0: return WardPractice.FUWA
		2: return SEARCH_START.lerp(reunion_feet,smoothstep(0,1,arrival))
		_: return Vector2(549,415) if "awoke" in notes else Vector2(561,448)

static func hint(scene: int,notes: Array) -> String:
	match scene:
		0:
			return "신사 마당의 후와 곁으로 걸어가, 돌바닥에 새긴 결계 문양을 함께 따라 그리자."
		1:
			if "overlook" in notes: return "후와가 걸어온 길이야. 오른쪽 위의 고갯마루까지 올라가 보자."
			if "gate" in notes: return "눈길 중턱까지 걸어가서 나무 사이로 난 길을 바라보자."
			if "empty" in notes: return "붉은 문을 지나 나를 찾으러 간 후와의 기록을 따라가자."
			return "둘이 함께 있던 신사야. 어제 내가 있던 자리를 살펴보자."
		2:
			if "wait" in notes: return "눈발 너머로 누군가 이쪽으로 걸어오고 있어."
			if "clearing" in notes: return "공터 건너편, 하늘이 트인 눈밭에서 고개를 들어 보자."
			return "눈 쌓인 나무 사이로 공터까지 걸어가 보자."
		_:
			if "awoke" in notes: return "후와가 눈을 뜬 곳이야. 빛이 비치는 서가로 다가가 보자."
			return "함께 돌아가려는 후와 곁에서 귀환술을 지켜보자."

static func remember(g,id: String) -> void:
	var notes: Array=g._chapter_progress().fuwa_notes
	if id in notes: return
	notes.append(id)
	if g.replay_progress==null: g._save()

func inspect(g,obj: Dictionary) -> void:
	var progress=g._chapter_progress()
	var scene: int=progress.debut_scene("fuwa")
	var notes: Array=progress.fuwa_notes
	var id: String=obj.id.trim_prefix("tenbi_")
	if g.mode!="chapter" or g.chapter_question or g.MEMBERS[g.story_member].id!="fuwa" or obj.index!=scene or ready(scene,notes) or id not in sites(scene,notes): return
	match id:
		"together":
			practice.begin(g)
			return
		"empty": g.chapter_note="늘 내가 있던 자리가 비어 있어. 이날 후와는 사라진 나를 찾아 신사를 떠났어."
		"gate":
			g.player_pos=SNOW_ENTRANCE
			g.chapter_note="책장을 건너니 사방이 눈이야. 나를 찾던 후와의 길은 요괴가 가득한 이 산으로 이어져."
		"overlook":
			overlook_at=g.clock
			g.chapter_note="이 길을 걸어온 후와의 모습이 책장에 비쳐. 내가 사라진 뒤, 혼자 산을 오르던 모습이야."
		"pass": g.chapter_note="마루에 닿으니 눈 덮인 산 안쪽이 보여. 후와는 나를 찾아 이곳까지 왔어."
		"clearing": g.chapter_note="나무 사이로 탁 트인 눈밭이 보여. 저쪽으로 조금 더 걸어가 보자."
		"wait":
			if id in notes: return
			reunion_feet=g.player_pos+Vector2(-64,-9)
			arrival=0.0
			g.chapter_note="잠깐 걸음을 멈췄어. 눈밭 저편에 낯익은 모습이 보여."
		"spell":
			viewing=true
			beyond_rift=false
			film_time=rift_time(g) if "rift" in notes else 0.0
			g.chapter_question=true
		"shelves": g.chapter_note="눈을 뜬 후와 주위에는 눈산 대신 수많은 책이 있어. 우리가 알던 신사와는 다른 풍경이야."
	remember(g,id)
	g._play_chime(541 if id in ["empty","gate"] else 699)
	g._setup_map()
	if ready(scene,notes): g._inspect_chapter(scene,g.chapter_note)

static func rift_time(g) -> float:
	var ms:=0
	for i in range(RIFT_FRAME): ms+=int(g.Comics.PROFILES.data.fuwa.cues[3].frames_ms[i])
	return ms/1000.0

func frame(g) -> int:
	var ms:=roundi(film_time*1000.0)
	var durations: Array=g.Comics.PROFILES.data.fuwa.cues[3].frames_ms
	for i in range(durations.size()):
		if ms<int(durations[i]): return i
		ms-=int(durations[i])
	return g.Comics.KEY_FRAMES-1

func advance(g,scene: int,notes: Array,delta: float) -> void:
	if scene==0:
		practice.advance(g,delta)
		return
	if viewing:
		film_time+=delta
		if not beyond_rift and film_time>=rift_time(g):
			film_time=rift_time(g)
			remember(g,"rift")
		return
	if not approaching(scene,notes) or g.chapter_question: return
	arrival=minf(1.0,arrival+delta/REUNION_TIME)
	if arrival>=1.0:
		remember(g,"reunited")
		g.chapter_note="후와다! 나를 찾아 이 눈산까지 온 후와가 바로 내 곁에 서 있어."
		g._play_chime(832)
		g._setup_map()

func turn(g) -> void:
	if not viewing: return
	var notes: Array=g._chapter_progress().fuwa_notes
	if "rift" not in notes: return
	if not beyond_rift:
		beyond_rift=true
	elif frame(g)==g.Comics.KEY_FRAMES-1:
		remember(g,"awoke")
		viewing=false
		g.chapter_question=false
		g.player_pos=HALL_ENTRANCE
		g.chapter_note="눈부신 빛이 걷혔어. 후와가 눈을 뜬 방에는 책들이 천장까지 꽂혀 있어."
		g._setup_map()

func close_view(g) -> void:
	viewing=false
	g.chapter_question=false

func input(g,event: InputEvent) -> bool:
	if practice.input(g,event): return true
	if not viewing or not event is InputEventKey or not event.pressed: return false
	if event.physical_keycode==KEY_ESCAPE:
		if not event.echo: close_view(g)
		return true
	if event.physical_keycode in [KEY_E,KEY_SPACE,KEY_ENTER]:
		if not event.echo: turn(g)
		return true
	return false

func painted_target(g,scene: int,notes: Array,p: Vector2) -> Dictionary:
	if ready(scene,notes): return {}
	for id in sites(scene,notes):
		var area: Rect2
		match id:
			"together":
				if Rect2(WardPractice.CENTER-Vector2(88,43),Vector2(176,86)).has_point(p):
					return g._find_object("tenbi_together")
				area=g.Field.stella_hit_rect(g._field_costume_key("fuwa"),feet(scene,notes))
			"spell": area=g.Field.stella_hit_rect(g._field_costume_key("fuwa"),feet(scene,notes))
			"gate": area=Rect2(46,175,197,149)
			"pass": area=Rect2(600,170,186,149)
			"shelves": area=Rect2(497,174,292,201)
			_: continue
		if area.has_point(p): return g._find_object("tenbi_"+id)
	return {}

static func draw_hall(g) -> void:
	# The last panel's bookcases continue into a floor built at field sprite scale.
	var texture=g.WorldPixels.texture("fuwa_bookhall")
	g.draw_texture_rect_region(texture,Rect2(32,140,904,234),Rect2(0,0,228,80))
	var boards=g.Pixels.texture("library_stage_6")
	for row in range(6):
		var h:=mini(62,344-62*row)
		var x:=32
		var u:=152+(row%3)*107
		while x<936:
			var width:=mini(859-u,936-x)
			g.draw_texture_rect_region(boards,Rect2(x,374+row*62,width,h),Rect2(u,448,width,h),Color("bb9187"))
			x+=width
			u=152
	g.draw_rect(Rect2(32,374,904,4),Color("432d2dcc"))
	# A stepped wooden plinth joins the painted shelves to the walkable floor.
	for bay in range(9):
		var base_x:=32+bay*101
		g.draw_rect(Rect2(base_x,365,101,7),Color("513934"))
		g.draw_rect(Rect2(base_x+3,365,95,2),Color("a77b58"))
		g.draw_rect(Rect2(base_x+1,372,99,4),Color("72503d"))
		g.draw_rect(Rect2(base_x+4,373,92,1),Color("c69a67"))
		g.draw_rect(Rect2(base_x+2,375,9,7),Color("422f30"))
		g.draw_rect(Rect2(base_x+4,375,2,5),Color("946747"))
		g.draw_rect(Rect2(base_x+7,381,18,2),Color("36292b66"))
	for i in range(8):
		g.draw_rect(Rect2(32,378+i*3,904,3),Color(.21,.11,.12,.26-i*.031))
	# Cast the window's three lights onto the boards, following the direction in the comic.
	for row in range(4):
		for col in range(3):
			var p:=Vector2(53+col*31+row*25,380+row*27)
			var pane:=PackedVector2Array([p,p+Vector2(25,0),p+Vector2(46,22),p+Vector2(21,22)])
			g.draw_colored_polygon(pane,Color(1,.81,.47,.36-row*.04))

static func talismans(g,active: bool) -> void:
	var center: Vector2=SITES.seal[0]
	g.draw_ellipse_shadow(center,Vector2(32,6))
	for i in range(3):
		var lift:=roundf((4 if active else 2)*sin(g.clock*2+i))
		var p:=center+Vector2((i-1)*20,-24-12*(i%2)-lift)
		g.WorldPixels.prop(g,"charm",p,.56)
		if active: g._star(p+Vector2(9,-11),3,GOLD)

static func mat(g) -> void:
	var p: Vector2=SITES.empty[0]-Vector2(0,6)
	var border:=PackedVector2Array([p+Vector2(-28,-10),p+Vector2(25,-10),p+Vector2(35,2),p+Vector2(-36,2)])
	g.draw_colored_polygon(border,Color("6d4444"))
	for i in range(4):
		g.draw_line(p+Vector2(-24-i*2,-8+i*2),p+Vector2(22+i*2,-8+i*2),Color("c59d78"),1)

func draw_field(g,scene: int,notes: Array) -> void:
	if scene==0:
		talismans(g,"seal" in notes)
		practice.draw_ground(g,notes)
		if practice.phase!=WardPractice.Phase.FIELD: return
	if scene==1 and map_index(scene,notes)==0: mat(g)
	if ready(scene,notes) or approaching(scene,notes): return
	for id in sites(scene,notes):
		var p: Vector2=SITES[id][0]
		var col:=FROST if map_index(scene,notes)>0 and "awoke" not in notes else GOLD
		for i in [-1,1]:
			var x:int=i*21
			g.draw_polyline(PackedVector2Array([p+Vector2(x,-3),p+Vector2(x+4*i,0),p+Vector2(x,3)]),Color("554c59"),4)
			g.draw_polyline(PackedVector2Array([p+Vector2(x,-4),p+Vector2(x+4*i,-1),p+Vector2(x,2)]),col,2)
		g._world_sign(p+Vector2(0,25),SITES[id][1],"tenbi_"+id)

func draw_view(g) -> void:
	var n:=frame(g)
	var displayed: int=g.Comics.cut_sample("fuwa",3,film_time)
	if g.book_discovery.active(g):
		g.draw_rect(Rect2(0,65,1280,624),Color("24222bc9"))
		var frame_box:=Rect2(184,142,912,440)
		g.draw_rect(frame_box.grow(4),g.GOLD)
		g.draw_texture_rect_region(g.Comics.sheet("fuwa"),frame_box,g.Comics.region(3,displayed))
		g.buttons.append({"rect":frame_box,"id":"fuwa_turn"})
		return
	g._panel(Rect2(237,91,806,607),g.PAPER)
	g._text(Vector2(283,137),"텐비의 책갈피   /   눈산의 밤",17,g.MUTED)
	var title: String="함께 돌아가려던 순간" if n<4 else ("눈 위에 열린 빛의 균열" if n<13 else "눈을 뜬 곳")
	g._text(Vector2(280,181),title,29,g.CREAM)
	var box:=Rect2(298,202,684,330)
	g.draw_rect(box.grow(3),g.GOLD)
	g.draw_texture_rect_region(g.Comics.sheet("fuwa"),box,g.Comics.region(3,displayed))
	var line: String="후와가 귀환술을 펼치고 있어." if n<4 else ("돌아가려던 눈밭 한가운데서 뜻밖의 빛이 갈라져." if n<13 else "후와가 눈을 떴어. 사방에 책이 가득해.")
	g._text(Vector2(298,577),line,20,g.CREAM)
	g._button(Rect2(298,608,196,49),"눈밭으로   Esc","fuwa_close")
	if not beyond_rift and n>=RIFT_FRAME:
		g._button(Rect2(624,608,358,49),"균열 너머를 바라보기   E","fuwa_turn",true)
	elif beyond_rift and n==g.Comics.KEY_FRAMES-1:
		g._button(Rect2(624,608,358,49),"낯선 도서관 둘러보기   E","fuwa_turn",true)

func draw_overlook(g) -> void:
	var box:=Rect2(141,112,274,132)
	g._panel(Rect2(131,79,294,175),g.PAPER)
	g._text(Vector2(144,104),"책장에 비친 후와  ·  눈산으로",15,g.CREAM)
	var step:=minf(23,8+maxf(0,g.clock-overlook_at)*8)
	g.draw_texture_rect_region(g.Comics.sheet("fuwa"),box,g.Comics.key_region(1,step))
	g.ui_regions.append(Rect2(131,79,294,175))
