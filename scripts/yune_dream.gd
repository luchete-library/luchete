extends RefCounted

# Mongchi observes a memory. The guardian herself consumes the nightmare,
# loses strength as dreams disappear, and chooses to follow the light.
const Nights = preload("res://scripts/book_activities/yune_nights.gd")
const STEPS := [["web","feather"],["gold","eaten"],["bed","window"],["call","door"]]
const SITES := [
	[["loom",Vector2(482,346),"드림캐처 가까이 보기"]],
	[["shadow",Vector2(460,414),"흔들리는 꿈의 흐름"],["gold",Vector2(722,527),"잔잔한 꿈 살펴보기"]],
	[["nights",Nights.STATION,"드림캐처 곁에서 밤 지켜보기"]],
	[["call",Vector2(370,499),"빛이 부르는 자리"],["door",Vector2(768,350),"유네를 따라 문 앞에 서기"]]
]
const TASKS := ["안쪽 벽에 걸린 드림캐처를 가까이 살펴보자.","잠자리 곁에서 일렁이는 두 꿈을 살펴보자.","드림캐처 곁으로 걸어가 유네와 함께 밤을 지켜보자.","어둠 속에서 유네를 부르는 빛을 찾아보자."]
const FRAME := Rect2(184,142,912,440)
const WEB := Vector2(638,197)
const FEATHER := Vector2(637,405)
const LILAC := Color("ebccff")
const HONEY := Color("ffdc86")
const WALK_START := Vector2(341,468)
const WALK_END := Vector2(736,350)
const WALK_TIME := 1.85
const FEED_TIME := 2.6

var nights := Nights.new()
var view := -1
var flow := 0.0
var holding := false
var departure := -1.0
var birth_at := -1.0
var selected_detail := 0

static func ready(scene: int, notes: Array) -> bool:
	for mark in STEPS[scene]:
		if mark not in notes: return false
	return true

# A folded, violet curl, deliberately unlike the warm four-pointed good dream.
static func shadow_wisp(g,p: Vector2,size: float) -> void:
	if size<0.09: return
	if size<.26:
		var pixels:=Vector2(maxi(2,roundi(27*size)),maxi(1,roundi(13*size)))
		var origin: Vector2=(p-pixels/2).round()
		g.draw_rect(Rect2(origin,pixels),Color("392e51"))
		g.draw_rect(Rect2(origin,Vector2(maxi(1,roundi(pixels.x/2)),1)),Color("c398dc"))
		return
	var edge:=PackedVector2Array()
	for v in [Vector2(-16,-2),Vector2(-12,-11),Vector2(-3,-15),Vector2(7,-14),Vector2(13,-8),Vector2(8,-9),Vector2(1,-8),Vector2(-2,-4),Vector2(0,0),Vector2(6,2),Vector2(14,-1),Vector2(19,-8),Vector2(18,2),Vector2(12,9),Vector2(3,13),Vector2(-7,11),Vector2(-14,6)]:
		edge.append(p.round()+v*size)
	g.draw_colored_polygon(edge,Color("392e51"))
	g.draw_polyline(edge.slice(0,5),Color("c398dc"),maxf(1.0,2*size))
	g.draw_polyline(edge.slice(12,17),Color("875fa3"),maxf(1.0,2*size))

static func warm_dream(g,p: Vector2,size: float) -> void:
	g.draw_circle(p,size*1.25,Color("f8d78224"))
	g._star(p,size,HONEY)
	g._star(p,size*.46,Color("fff6d0"))

func draw_field(g,scene: int,notes: Array) -> void:
	if scene==2:
		nights.draw_field(g,view==2,ready(2,notes))
		return
	for site in SITES[scene]:
		var id: String=site[0]
		var p: Vector2=site[1]-Vector2(0,20)
		var wave: float=sin(g.clock*2+p.x*.02)
		match id:
			"loom":
				g.draw_arc(p+Vector2(0,8),13+wave,0,TAU,20,Color("ecd3f9aa"),2)
				for i in range(3): g._star(p+Vector2(-4+i*4,-26+i*12),3+sin(i+g.clock),HONEY)
			"shadow":
				if "eaten" in notes: continue
				for i in range(3):
					shadow_wisp(g,p+Vector2(-18+i*16,wave*4+sin(i*2+g.clock)*6),.56+i*.17)
			"gold":
				warm_dream(g,p+Vector2(0,wave*2),12.0+wave)
			"call":
				if "call" not in notes: warm_dream(g,p+Vector2(0,-6),16+wave*2)
			"door":
				if "call" in notes:
					for i in range(8):
						var a:=float(i)/8
						var spark:=WALK_START.lerp(WALK_END,a)+Vector2(0,17+sin(a*TAU+g.clock)*4)
						g._star(spark,2+sin(g.clock+i),HONEY)
					warm_dream(g,p+Vector2(0,-37),17+wave*2)

func draw_closeup(g) -> void:
	var notes: Array=g._chapter_progress().yune_notes
	if g.book_discovery.active(g):
		g.draw_rect(Rect2(0,65,1280,624),Color("24222bc9"))
		g._panel(Rect2(154,117,972,507),g.PAPER)
		if view==0: draw_catcher(g,notes)
		else: draw_feeding(g,notes)
		return
	g.buttons.clear()
	g._panel(Rect2(154,63,972,658),g.PAPER)
	g._text(Vector2(185,115),"소망을 품은 드림캐처" if view==0 else "유네가 지키는 꿈",28,g.CREAM)
	g._text(Vector2(887,112),"몽치의 시점",17,g.MUTED)
	g.draw_rect(FRAME.grow(4),Color("765966"))
	if view==0: draw_catcher(g,notes)
	else: draw_feeding(g,notes)
	g._text_block(Vector2(188,620),g.chapter_note,894,18,g.CREAM,24)
	g._button(Rect2(185,653,216,42),"현장으로   Esc","dream_back")
	if ready(view,notes):
		g._button(Rect2(829,653,265,42),"기억 펼치기   E","dream_read",true)
	elif view==0:
		g._button(Rect2(614,653,225,42),"1   매듭 살펴보기","dream_web")
		g._button(Rect2(850,653,244,42),"2   깃털 살펴보기","dream_feather",false,"web" not in notes)
	else:
		g._button(Rect2(743,653,351,42),"꿈의 흐름 따라가기   E 꾹","dream_hold",true)

func draw_catcher(g,notes: Array) -> void:
	g.draw_texture_rect_region(g.WorldPixels.texture("story_yune_0"),FRAME,Rect2(224,0,456,220))
	for i in range(2):
		var p:=WEB if i==0 else FEATHER
		var id: String=STEPS[0][i]
		var seen: bool=id in notes
		var color:=HONEY if seen else LILAC
		g.draw_arc(p,25,0,TAU,24,Color("35213c"),5)
		g.draw_arc(p,25,0,TAU,24,color,2)
		if not g.book_discovery.active(g) or selected_detail==i:
			g._star(p+Vector2(22,-18),5+sin(g.clock*3),color)
		g.buttons.append({"rect":Rect2(p-Vector2(47,43),Vector2(94,86)),"id":"dream_"+id})
	if ready(0,notes):
		var glow:=1.0 if birth_at<0 else clampf((g.clock-birth_at)/1.2,0,1)
		g._draw_member(Vector2(826,530),"yune",182,true,Color(1,1,1,glow))
		for i in range(7):
			var t:=float(i)/7
			g._star(FEATHER.lerp(Vector2(826,420),t)+Vector2(0,12*sin(t*TAU+g.clock)),3+sin(g.clock+i),HONEY)

func draw_feeding(g,notes: Array) -> void:
	var tick:=minf(23,flow*24)
	g.draw_texture_rect_region(g.Comics.sheet("yune"),FRAME,g.Comics.key_region(1,tick))
	# Register the last flecks to the mouth in the original 228 x 110 comic cell.
	var mouth:=FRAME.position+Vector2(113,45)*4
	if flow>.48 and flow<.92:
		g.draw_rect(Rect2(mouth-Vector2(3,1),Vector2(6,4)),Color("9e696e"))
	for i in range(5):
		var t:=smoothstep(0.0,1.0,clampf((flow-i*.065)/.74,0,1))
		var a:=FRAME.position+Vector2(121+22*i,139+14*i)
		var p:=a.lerp(mouth,t)+Vector2(0,sin(t*PI)*(-34+9*i)+(1-t)*sin(flow*TAU+i)*5)
		shadow_wisp(g,p,(1-t*t)*(1.28+i*.21))
		if t>0 and t<1:
			var tail: Vector2=p.lerp(a,.10)
			g.draw_line(tail.round(),p.round(),Color("cba3d9b0"),2)
			g._star(p,3+2*t,LILAC)
	if flow>.78 and flow<.98:
		g._star(mouth+Vector2(-10,2),5*sin(PI*(flow-.78)/.2),LILAC)
	for i in range(3):
		warm_dream(g,FRAME.position+Vector2(651+i*52,139+sin(i*2+g.clock)*9),10+i*2)
	if flow<1.0:
		g.buttons.append({"rect":FRAME,"id":"dream_hold"})
	if not g.book_discovery.active(g):
		g.draw_rect(Rect2(185,589,910,5),Color("b5a1ad"))
		g.draw_rect(Rect2(185,589,910*flow,5),Color("8a61a4") if "eaten" not in notes else Color("d0a04c"))

static func restored_notes(raw: Variant) -> Array:
	var result := []
	if raw is Array:
		for mark in ["web","feather","gold","half","eaten","bed","window","call","door"]:
			if mark in raw and (mark!="door" or "call" in result): result.append(mark)
	return result

func reset() -> void:
	nights.restore([])
	view=-1
	holding=false
	flow=0.0
	departure=-1.0
	birth_at=-1.0
	selected_detail=0

static func mark_found(g,mark: String) -> void:
	var notes: Array=g._chapter_progress().yune_notes
	if mark in notes: return
	notes.append(mark)
	if g.replay_progress==null: g._save()

static func add_sites(objects: Array, scene: int, notes: Array) -> void:
	for site in SITES[scene]:
		if scene==1 and site[0]=="shadow" and "gold" not in notes: continue
		if site[0]=="door" and "call" not in notes: continue
		var obj: Dictionary={"id":"dream_"+site[0],"type":"yune_dream","index":scene,"pos":site[1],"label":site[2]}
		if scene==2: obj.reach=Nights.REACH
		objects.append(obj)

static func record_site(scene: int, default_site: Vector2) -> Vector2:
	if scene in [0,2]: return SITES[scene][0][1]
	if scene==3: return SITES[3][1][1]
	return default_site

static func hint(scene: int,notes: Array) -> String:
	if scene==1: return "잔잔한 빛을 기억하고, 이번에는 흔들리는 꿈 쪽으로 가 보자." if "gold" in notes else "먼저 잠자리 오른편의 잔잔한 꿈을 살펴보자."
	if scene==3 and "call" in notes: return "빛을 따라가는 유네와 함께 문 앞에 서 보자."
	return TASKS[scene]

func walk_fraction(g) -> float:
	return 1.0 if departure<0.0 else clampf((g.clock-departure)/WALK_TIME,0,1)

func feet(g,scene: int,default_feet: Vector2) -> Vector2:
	if scene==0: return Vector2(535,344)
	if scene==2: return Nights.YUNE_FEET
	if scene==3:
		if "call" not in g._chapter_progress().yune_notes: return WALK_START
		return WALK_START.lerp(WALK_END,smoothstep(0.0,1.0,walk_fraction(g)))
	return default_feet

func inspect(g,obj: Dictionary) -> void:
	var progress=g._chapter_progress()
	var scene: int=progress.debut_scene("yune")
	if g.mode!="chapter" or g.chapter_question or g.MEMBERS[g.story_member].id!="yune" or obj.index!=scene: return
	var id: String=obj.id.trim_prefix("dream_")
	if id=="shadow" and "gold" not in progress.yune_notes: return
	match id:
		"loom","shadow":
			view=scene
			g.chapter_question=true
			holding=false
			flow=0.5 if "half" in progress.yune_notes else 0.0
			g.chapter_note="매듭과 깃털이 같은 떨림으로 이어져 있어. 마음이 가는 곳부터 살펴보자." if scene==0 else "잔잔한 꿈과 다른 검은 결이야. 유네의 손길을 따라 지켜보자."
			return
		"gold":
			g.chapter_note="따뜻한 빛은 고르게 숨 쉬고 있어. 유네가 오래 머물도록 지키는 좋은 꿈이야."
		"nights":
			nights.begin(g,obj)
			return
		"call":
			if id not in progress.yune_notes:
				departure=g.clock
				g._play_chime(710)
			g.chapter_note="빛이 먼저 유네를 불렀어. 유네가 향한 곳까지 나도 걸어가 볼래."
		"door":
			if "call" not in progress.yune_notes: return
			if walk_fraction(g)<1.0:
				g.chapter_note="유네가 이쪽으로 다가오고 있어. 문 앞에서 함께 기억을 펼치자."
				return
			g.chapter_note="유네가 빛을 따라 도착한 곳은 리스텔라의 문 앞이었어."
		_: return
	mark_found(g,id)
	if id in ["call","gold"] or ready(scene,progress.yune_notes):
		g._setup_map()
	if id=="door": g._inspect_chapter(scene,g.chapter_note)

func observe(g,id: String) -> void:
	if view!=0 or id not in STEPS[0]: return
	var notes: Array=g._chapter_progress().yune_notes
	selected_detail=STEPS[0].find(id)
	var fresh: bool=id not in notes
	mark_found(g,id)
	g.chapter_note="겹겹이 감긴 실이 가운데 한 점으로 모여. 누군가의 간절한 소망이 여기 깃들었어." if id=="web" else "깃털 끝이 가볍게 떨려. 위를 보니 같은 떨림이 실을 타고 퍼져."
	if fresh:
		g._play_chime(648 if id=="web" else 778)
		if ready(0,notes):
			birth_at=g.clock
			g.chapter_note="수백 년 전, 그 소망을 담은 드림캐처에서 꿈의 정령 유네가 눈을 떴어."

func advance(g,delta: float) -> void:
	if view!=1 or flow>=1.0: return
	var before:=flow
	flow=minf(1.0,flow+delta/FEED_TIME)
	if before<0.5 and flow>=0.5: mark_found(g,"half")
	if flow>=1.0:
		holding=false
		mark_found(g,"eaten")
		g.chapter_note="검은 꿈이 유네에게 스며들어 사라졌어. 곁의 따뜻한 꿈은 여전히 반짝여."
		g._play_chime(784)

func close(g,read: bool) -> void:
	var scene:=view
	view=-1
	holding=false
	g.chapter_question=false
	g._setup_map()
	if read and ready(scene,g._chapter_progress().yune_notes): g._inspect_chapter(scene)

func control(g,id: String) -> void:
	if view<0: return
	match id:
		"dream_back": close(g,false)
		"dream_read": close(g,true)
		"dream_web","dream_feather": observe(g,id.trim_prefix("dream_"))
		"dream_hold":
			if view==1 and flow<1.0: holding=true

func input(g,event: InputEvent) -> bool:
	if view==2: return nights.input(g,event)
	if view<0: return false
	if event is InputEventKey:
		var key: int=event.physical_keycode
		if key==KEY_F11: return false
		if key in [KEY_E,KEY_SPACE,KEY_ENTER] and not event.pressed: holding=false
		if event.pressed and not event.echo:
			if key==KEY_ESCAPE: close(g,false)
			elif view==0 and key in [KEY_UP,KEY_DOWN,KEY_W,KEY_S]: selected_detail=1-selected_detail
			elif key in [KEY_1,KEY_2] and view==0: observe(g,"web" if key==KEY_1 else "feather")
			elif key in [KEY_E,KEY_ENTER,KEY_SPACE]:
				if view==0: observe(g,STEPS[0][selected_detail])
				elif view==1: holding=true
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if not event.pressed: holding=false
		else:
			for i in range(g.buttons.size()-1,-1,-1):
				if g.buttons[i].rect.has_point(event.position):
					control(g,g.buttons[i].id)
					break
	return true
