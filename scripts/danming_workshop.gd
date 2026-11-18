extends RefCounted

const MemoryLens = preload("res://scripts/danming_memory_lens.gd")
var lens := MemoryLens.new()

# Beori follows a past memory. All of the work and the unexpected arrival belong to Danming.
const STEPS := [
	["voice", "reply", "notice"],
	["quill", "shaft", "tip"],
	["arrow_stack", "hand_pause"],
	["empty", "arrival"],
]
const SITES := {
	"voice": [Vector2(300,470), "광장에 번지는 말소리"],
	"reply": [Vector2(650,425), "꽃그늘의 대답"],
	"notice": [Vector2(439,353), "일자리 게시판"],
	"bench": [Vector2(446,339), "단밍의 작업대"],
	"album": [MemoryLens.STATION, "작업대에서 돋보기 들기"],
	"empty": [Vector2(306,351), "단밍이 일하던 자리"],
	"threshold": [Vector2(859,342), "열린 문 너머 보기"],
}
const BENCH := Rect2(668,247,386,182)
const START_X := 700.0
const END_X := 1020.0
const WINDOW := Rect2(184,151,912,440)
const ROSE := Color("e7a2aa")
const HONEY := Color("ffdd97")
const WOOD := Color("694638")
const PALE := Color("fff2d6")
const ACTOR_FEET := [Vector2(425,452),Vector2(349,350),Vector2(253,321),Vector2(753,344)]

var view := -1
var fraction := 0.0
var dragging := false
var direction := 0
var page_grab := 0.0
var echo_at := -10.0
var echo_origin := Vector2.ZERO

static func ready(scene: int, notes: Array) -> bool:
	for mark in STEPS[scene]:
		if mark not in notes: return false
	return true

static func restored_notes(raw: Variant) -> Array:
	var result := []
	if raw is Array:
		for scene in range(4):
			for mark in STEPS[scene]:
				if mark in raw: result.append(mark)
		# Older saves bookmarked the bench, pile, then the return to the bench.
		if "bundle" in raw or "again" in raw:
			if "arrow_stack" not in result: result.append("arrow_stack")
		if "again" in raw and "hand_pause" not in result: result.append("hand_pause")
		if "morning" in raw or "album_open" in raw: result.append("album_open")
	return result

static func sites(scene: int, notes: Array) -> Array:
	match scene:
		0:
			return ["voice","reply","notice"]
		1: return ["bench"]
		2: return ["album"]
		3: return ["threshold"] if "empty" in notes else ["empty"]
	return []

static func add_sites(objects: Array,scene: int,notes: Array) -> void:
	for id in sites(scene,notes):
		objects.append({"type":"danming_site","id":"bee_"+id,"index":scene,"reach":approach_radius(scene),"pos":SITES[id][0],"label":SITES[id][1]})

static func approach_radius(scene: int) -> float:
	return 8.0 if scene==2 else 78.0

static func record_site(scene: int) -> Vector2:
	return SITES[["notice","bench","album","threshold"][scene]][0]

static func hint(scene: int,notes: Array) -> String:
	match scene:
		0:
			if "reply" in notes and "voice" in notes: return "광장을 지나 장미 아래의 일자리 게시판을 살펴보자."
			return "방금 들은 말에 꽃그늘에서 대답이 돌아와. 그쪽으로 걸어가 보자." if "voice" in notes else "광장 쪽에서 단밍의 목소리가 들려. 먼저 가까이 가 보자."
		1: return "작업대에서 사랑의 화살을 손질하는 단밍의 손길을 따라가 보자."
		2:
			if "album_open" in notes: return "작업대로 돌아가 돋보기로 남은 화살을 살펴보자."
			return "작업대의 화살을 클릭하거나 버리로 가까이 걸어가 E를 눌러 보자."
		_: return "열린 문으로 걸어가, 두 풍경 사이의 책장을 넘겨 보자." if "empty" in notes else "작업실에서 단밍이 매일 일하던 자리를 찾아보자."

static func mark_found(g,id: String) -> void:
	var notes: Array=g._chapter_progress().danming_notes
	if id in notes: return
	notes.append(id)
	if g.replay_progress==null: g._save()

func reset() -> void:
	view=-1
	fraction=0.0
	echo_at=-10.0
	release()

func release() -> void:
	dragging=false
	direction=0
	lens.release()

func inspect(g,obj: Dictionary) -> void:
	var progress=g._chapter_progress()
	var scene: int=progress.debut_scene("danming")
	var notes: Array=progress.danming_notes
	var id: String=obj.id.trim_prefix("bee_")
	if g.mode!="chapter" or g.chapter_question or g.MEMBERS[g.story_member].id!="danming" or obj.index!=scene or id not in sites(scene,notes): return
	if id in ["bench","album","threshold"]:
		if id=="album" and g.player_pos.distance_to(MemoryLens.STATION)>8:
			g._go_to(obj)
			return
		view=scene
		g.chapter_question=true
		release()
		if id=="album":
			mark_found(g,"album_open")
			lens.begin(g)
			return
		fraction=(float(int("quill" in notes)+int("shaft" in notes))/3.0) if scene==1 else 0.0
		g.chapter_note="깃부터 촉까지, 단밍이 닦는 방향으로 천을 밀어 보자." if scene==1 else "아까까지 분명 작업실이었는데… 책장을 밀어서 저 너머를 보자."
		if scene==1 and "quill" in notes: g.chapter_note="깃을 정돈한 자리부터 이어서, 하트 모양 촉까지 남은 부분을 다듬어 보자."
		return
	match id:
		"voice": g.chapter_note="단밍 쪽에서 말소리가 들려. 말이 끝나자 건너편에서도 누군가 대답해."
		"reply": g.chapter_note="여기서 들으니 대답 사이로 단밍의 목소리가 또렷해. 대화가 자연스럽게 이어져."
		"notice": g.chapter_note="사람들과 이야기하는 게 그렇게 자연스러운 단밍에게도, 일자리를 구하는 건 어려웠구나."
		"empty": g.chapter_note="조금 전까지 들리던 화살 소리가 그쳤어. 문 너머에는 낯선 풍경이 보여."
	mark_found(g,id)
	if id in ["voice","reply"]:
		echo_at=g.clock
		echo_origin=obj.pos
	g._play_chime({"voice":590,"reply":755}.get(id,680))
	g._setup_map()
	if ready(scene,notes): g._inspect_chapter(scene,g.chapter_note)

func set_fraction(g,value: float) -> void:
	var notes: Array=g._chapter_progress().danming_notes
	if view not in [1,3] or ready(view,notes): return
	if view==1:
		fraction=clampf(value,fraction,1.0)
		for i in range(3):
			var mark: String=STEPS[1][i]
			if fraction>=float(i+1)/3.0 and mark not in notes:
				mark_found(g,mark)
				g._play_chime(550+i*90)
				g.chapter_note=["흐트러진 깃이 가지런해졌어. 이번에는 자루를 따라가 보자.","거칠던 자루가 매끄러워졌어. 하트 모양 촉까지 조금만 더.","화살 하나가 반짝여. 단밍의 작업대에는 아직 다음 화살이 놓여 있어."][i]
	else:
		fraction=clampf(value,0,1)
		if fraction>=1.0:
			mark_found(g,"arrival")
			g.chapter_note="이제 작업대가 보이지 않아. 그날 단밍이 불려 간 낯선 세계는 리스텔라였어."
			g._play_chime(828)
	if ready(view,notes): release()

func advance(g,delta: float) -> void:
	if view==2:
		lens.advance(g,delta)
	elif direction!=0: set_fraction(g,fraction+direction*delta/2.0)

func close(g,read: bool) -> void:
	var scene:=view
	if read and not ready(scene,g._chapter_progress().danming_notes): return
	reset()
	g.chapter_question=false
	g._setup_map()
	if read:
		var observation: String="쌓인 화살을 보니 얼마나 오래 같은 일을 했는지 알겠어. 처음엔 바삐 움직이던 단밍의 손도 멎었어." if scene==2 else ""
		g._inspect_chapter(scene,observation)

func input(g,event: InputEvent) -> bool:
	if view<0: return false
	if view==2: return lens.input(g,event)
	var done:=ready(view,g._chapter_progress().danming_notes)
	if event is InputEventKey:
		var key: int=event.physical_keycode
		if key in [KEY_F11,KEY_F5]: return false
		if event.echo: return true
		if key in [KEY_RIGHT,KEY_LEFT,KEY_D,KEY_A]:
			var step:=1 if key in [KEY_RIGHT,KEY_D] else -1
			if event.pressed and not done: direction=step
			elif direction==step: direction=0
		elif event.pressed:
			if key==KEY_ESCAPE: close(g,false)
			elif key in [KEY_E,KEY_ENTER,KEY_SPACE]:
				if done: close(g,true)
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if not event.pressed: dragging=false
		else:
			for button in g.buttons:
				if button.rect.has_point(event.position):
					if button.id=="bee_back": close(g,false)
					elif button.id=="bee_read": close(g,true)
					return true
			if not done:
				if view==1:
					dragging=BENCH.has_point(event.position) and absf(event.position.x-lerpf(START_X,END_X,fraction))<40
				elif WINDOW.has_point(event.position):
					dragging=true
					page_grab=event.position.x-fraction*WINDOW.size.x*.72
	elif event is InputEventMouseMotion:
		if dragging:
			if view==1: set_fraction(g,(event.position.x-START_X)/(END_X-START_X))
			else: set_fraction(g,(event.position.x-page_grab)/(WINDOW.size.x*.72))
	return true

# Clicks on painted scenery lead to the same walkable position as the floor marker.
static func painted_target(g,point: Vector2) -> Dictionary:
	for id in PAINTED:
		var object: Dictionary=g._find_object("bee_"+id)
		if not object.is_empty():
			var area: Rect2=PAINTED[id]
			if area.has_point(point): return object
	return {}

const PAINTED := {"bench":Rect2(306,211,248,96),"notice":Rect2(393,223,113,94),"album":Rect2(112,221,320,88),"threshold":Rect2(843,158,78,153)}

static func bubble(g,p: Vector2,color: Color,tail: int) -> void:
	g.draw_rect(Rect2(p+Vector2(-18,-12),Vector2(36,22)),WOOD)
	g.draw_rect(Rect2(p+Vector2(-15,-15),Vector2(30,28)),WOOD)
	g.draw_rect(Rect2(p+Vector2(-15,-11),Vector2(30,19)),color)
	g.draw_rect(Rect2(p+Vector2(tail*7,8),Vector2(6,8)),color)
	for i in range(3): g.draw_rect(Rect2(p+Vector2(-9+7*i,-3),Vector2(4,4)),WOOD)

func draw_field(g,scene: int,notes: Array) -> void:
	if scene==0:
		var elapsed: float=g.clock-echo_at
		if elapsed>=0 and elapsed<2.4:
			var answer:=smoothstep(0.0,1.0,elapsed/1.15)
			var p:=echo_origin.lerp(ACTOR_FEET[0],answer)-Vector2(0,40+answer*89)
			bubble(g,p.round(),ROSE if answer>.55 else PALE,-1)
	if scene==2:
		lens.draw_table(g,view==2,notes)
		if view==2: return
	if ready(scene,notes): return
	for id in sites(scene,notes):
		var p: Vector2=SITES[id][0]
		var bob: float=roundf(2*sin(g.clock*2.5))
		g.draw_ellipse_shadow(p,Vector2(23,6))
		g.draw_arc(p,19,0,TAU,24,Color("f6d193"),2)
		match id:
			"album":
				g.WorldPixels.prop(g,"lens",p-Vector2(0,4),.7)
			"voice","reply": bubble(g,p+Vector2(0,-23+bob),PALE if id=="voice" else ROSE,1 if id=="voice" else -1)
			"notice":
				var poster:=Vector2(427,252)
				g.draw_rect(Rect2(poster-Vector2(15,0),Vector2(30,32)),WOOD)
				g.draw_rect(Rect2(poster-Vector2(12,-3),Vector2(24,25)),PALE)
				g.draw_rect(Rect2(poster+Vector2(-6,7),Vector2(11,3)),ROSE)
				for i in range(2): g.draw_rect(Rect2(poster+Vector2(-8,14+i*5),Vector2(15-i*4,2)),WOOD)
				for i in range(3): g._star(p+Vector2(-2*i,-14-i*17),2,HONEY)
			"threshold":
				for j in range(7):
					var t:=fmod(g.clock*.23+j/7.0,1.0)
					g._star(Vector2(853+sin(j*3.4)*20,345-t*114),2+sin(t*PI)*2,HONEY)
			"empty": g._star(p-Vector2(0,18-bob),9,HONEY)
			_: g.WorldPixels.prop(g,"arrows",p-Vector2(0,6),.95)
		g._world_sign(p+Vector2(0,22),SITES[id][1],"bee_"+id)

func draw_closeup(g) -> void:
	if g.book_discovery.active(g):
		g.draw_rect(Rect2(0,65,1280,624),Color("24222bc9"))
		g._panel(Rect2(152,159,976,327) if view==1 else Rect2(152,123,976,495),g.PAPER)
		if view==1: draw_workbench(g)
		else: draw_page(g)
		return
	g._panel(Rect2(152,66,976,650),g.PAPER)
	g._text(Vector2(184,116),"사랑의 화살을 손질하는 손길" if view==1 else "작업실 너머, 낯선 세계",28,g.CREAM)
	g._text(Vector2(959,115),"버리의 시점",16,g.MUTED)
	if view==1: draw_workbench(g)
	else: draw_page(g)
	g._text_block(Vector2(186,572 if view==1 else 622),g.chapter_note,902,18,g.CREAM,24)
	g._button(Rect2(185,651,199,42),"현장으로   Esc","bee_back")
	if ready(view,g._chapter_progress().danming_notes):
		g._button(Rect2(829,651,265,42),"기억 펼치기   E","bee_read",true)
	else:
		g._text(Vector2(433,677),"천을 잡고 오른쪽으로 밀기   /   → 길게" if view==1 else "그림을 좌우로 쓸기   /   ← → 길게",17,g.MUTED)

func draw_workbench(g) -> void:
	# The original comic supplies her hands and costume. Draw the tool at a separate magnification.
	var tick:=minf(23,fraction*24)
	g.draw_rect(Rect2(180,193,466,230),WOOD)
	g.draw_texture_rect_region(g.Comics.sheet("danming"),Rect2(185,198,456,220),g.Comics.key_region(1,tick))
	g._center(456,"단밍의 손길",18,g.CREAM,413)
	g._center(197,"버리의 작업대 관찰",20,g.CREAM,861)
	g.draw_rect(BENCH.grow(5),WOOD)
	g.draw_rect(BENCH,Color("835846"))
	for i in range(6):
		var y:=int(BENCH.position.y)+i*31
		g.draw_line(Vector2(668,y+2),Vector2(1054,y+2),Color("b58161"),2)
		for j in range(4):
			var x:=678+posmod(j*113+i*31,330)
			g.draw_rect(Rect2(x,y+13,12+j*3,2),Color("93674e"))
	g.draw_rect(Rect2(682,286,358,88),Color("503b37"))
	g.draw_rect(Rect2(685,289,352,82),Color("52665e"))
	for x in range(690,1032,12): g.draw_rect(Rect2(x,293,6,2),Color("9a9d7d"))
	var cy:=329
	g.draw_rect(Rect2(703,cy,302,7),Color("513b39"))
	g.draw_rect(Rect2(704,cy,292,4),Color("daa773"))
	g.draw_rect(Rect2(706,cy,lerpf(0,287,fraction),2),PALE)
	for i in range(4):
		var x:=705+i*9
		var spread:=14 if fraction>.32 else 11+i%2*5
		for side in [-1,1]:
			g.draw_colored_polygon(PackedVector2Array([Vector2(x,cy+3),Vector2(x-8,cy+3+side*spread),Vector2(x+4,cy+3+side*spread),Vector2(x+12,cy+3)]),ROSE if i%2==0 else Color("f4c8bd"))
			g.draw_line(Vector2(x+2,cy+3),Vector2(x-3,cy+3+side*(spread-4)),Color("a46276"),1)
	g.draw_colored_polygon(PackedVector2Array([Vector2(994,331),Vector2(985,324),Vector2(985,316),Vector2(990,311),Vector2(999,311),Vector2(1006,316),Vector2(1023,331),Vector2(1006,346),Vector2(999,351),Vector2(990,351),Vector2(985,346),Vector2(985,339)]),Color("6e4349"))
	g.draw_colored_polygon(PackedVector2Array([Vector2(997,331),Vector2(988,323),Vector2(988,317),Vector2(992,314),Vector2(999,314),Vector2(1020,331),Vector2(999,348),Vector2(992,348),Vector2(988,345),Vector2(988,340)]),ROSE)
	g.draw_line(Vector2(996,332),Vector2(1016,331),Color("c17a82"),2)
	g.draw_rect(Rect2(991,316,8,2),PALE)
	for i in range(3): g.draw_rect(Rect2(978+i*4,326,2,10),Color("dfbe81"))
	var cloth_x:=roundf(lerpf(START_X,END_X,fraction))
	if fraction<1.0:
		g.draw_colored_polygon(PackedVector2Array([Vector2(cloth_x-16,310),Vector2(cloth_x+9,306),Vector2(cloth_x+20,334),Vector2(cloth_x+7,344),Vector2(cloth_x-21,337)]),Color("573f4c"))
		g.draw_colored_polygon(PackedVector2Array([Vector2(cloth_x-15,310),Vector2(cloth_x+7,308),Vector2(cloth_x+16,331),Vector2(cloth_x+5,339),Vector2(cloth_x-18,334)]),Color("baa2c4"))
		g.draw_line(Vector2(cloth_x-9,313),Vector2(cloth_x+4,333),Color("eedbea"),3)
		g.draw_line(Vector2(cloth_x-12,318),Vector2(cloth_x-5,333),Color("957c9e"),2)
		g.draw_line(Vector2(cloth_x+1,312),Vector2(cloth_x+11,330),Color("d5bfd6"),2)
		g._star(Vector2(cloth_x+14,313),4,HONEY)
	else: g._star(Vector2(1021,320),8,HONEY)
	for i in range(3):
		var x:=720+i*139
		g.draw_circle(Vector2(x,403),5,HONEY if fraction>=float(i+1)/3 else Color("b28a70"))
		g._center(460,["깃","자루","화살촉"][i],16,g.MUTED,x)
	if not g.book_discovery.active(g): g.draw_line(Vector2(187,504),Vector2(1091,504),Color("c9af88"),1)

func draw_page(g) -> void:
	g.draw_rect(WINDOW.grow(4),WOOD)
	# Scrub through the original two-room transition on the comic's native pixel grid.
	var tick: float=fraction*23
	g.draw_texture_rect_region(g.Comics.sheet("danming"),WINDOW,g.Comics.key_region(3,tick))
	var guide:=Rect2(WINDOW.position+Vector2(0,423),Vector2(912,17))
	g.draw_rect(guide,Color("493743cc"))
	g.draw_rect(Rect2(guide.position+Vector2(0,7),Vector2(guide.size.x*fraction,3)),HONEY)
	g._star(Vector2(clampf(guide.position.x+guide.size.x*fraction,191,1088),guide.position.y+8),7,PALE)
