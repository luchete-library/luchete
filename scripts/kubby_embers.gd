extends RefCounted

# The fan avatar walks through a memory. The animal in the village is a separate actor.
const Village = preload("res://scripts/book_activities/kubby_rustle.gd")
const STEPS := [
	["snow","village"], ["found","home"], ["ice","changed","spark","flame","glow"], ["night","journey"]
]
const SITES := {
	"snow":[Vector2(284,510),"눈에 찍힌 발자국"],
	"village":[Vector2(712,339),"마을 불빛 따라가기"],
	"watch":[Village.STATION,"쿠비 곁으로"],
	"ice":[Vector2(305,536),"얼음에 비친 두 모습"],
	"glow":[Vector2(806,435),"얼음길 끝에서 지켜보기"],
	"night":[Vector2(349,513),"달 아래 선 쿠비"],
	"journey":[Vector2(778,348),"고갯길 따라가기"],
}
const ICE_START := Vector2(305,536)
const ICE_END := Vector2(700,457)
const MINT := Color("a8f0cf")
const CREAM := Color("ffebba")
const FRAME := Rect2(122,97,456,220)
const STOPS := [0.0,8.0/24.0,13.0/24.0,1.0]
const PHASE := ["ice","changed","spark","flame"]

var flow := 0.0
var village := Village.new()
var left_at := -10.0
var descent_at := -10.0

static func ready(scene: int,notes: Array) -> bool:
	return STEPS[scene].back() in notes

static func restored_notes(raw: Variant) -> Array:
	var restored := []
	if raw is Array:
		if "grain" in raw: restored.append("grain")
		for section in STEPS:
			for mark in section:
				if mark not in raw: break
				restored.append(mark)
	return restored

func resume(notes: Array) -> void:
	flow=0.0
	village.restore(notes)
	left_at=-10.0
	descent_at=-10.0
	for i in range(PHASE.size()):
		if PHASE[i] in notes: flow=STOPS[i]

static func sites(scene: int,notes: Array) -> Array:
	match scene:
		0: return ["village"] if "snow" in notes else ["snow"]
		1: return ["watch"]
		2: return ["glow"] if "ice" in notes else ["ice"]
		_: return ["journey"] if "night" in notes else ["night"]

static func add_sites(objects: Array,scene: int,notes: Array) -> void:
	for id in sites(scene,notes):
		var obj: Dictionary={"id":"wisp_"+id,"type":"kubby_site","index":scene,"pos":SITES[id][0],"label":SITES[id][1]}
		if scene==1: obj.reach=Village.REACH
		objects.append(obj)

static func record_site(scene: int) -> Vector2:
	return SITES[["village","watch","glow","journey"][scene]][0]

static func hint(scene: int,notes: Array) -> String:
	match scene:
		0: return "지붕 아래 등불이 보여. 발자국을 따라 아랫마을로 내려가 보자." if "snow" in notes else "눈길에서 쿠비가 지나간 흔적을 찾아보자."
		1:
			return "아랫마을에서 쿠비 곁으로 걸어가 보자. 쿠비를 클릭해도 따라갈 수 있어."
		2:
			if "flame" in notes: return "떠오른 도깨비불을 보고, 얼음길 끝에서 기억을 펼치자."
			if "ice" in notes: return "밝은 얼음 결을 오른쪽으로 따라가 봐. 발을 멈추면 기억도 멈춰."
			return "얼음에 나란히 비친 쿠비와 햄스터를 찾아보자."
		_: return "쿠비와 도깨비불을 따라 달빛이 비치는 고갯길로 걸어가자." if "night" in notes else "달 아래 선 쿠비 곁에 가 보자."

static func mark_found(g,id: String) -> void:
	var notes: Array=g._chapter_progress().kubby_notes
	if id not in notes:
		notes.append(id)
		if g.replay_progress==null: g._save()

func inspect(g,obj: Dictionary) -> void:
	var progress=g._chapter_progress()
	var scene: int=progress.debut_scene("kubby")
	var notes: Array=progress.kubby_notes
	var id: String=obj.id.trim_prefix("wisp_")
	if g.mode!="chapter" or g.chapter_question or g.MEMBERS[g.story_member].id!="kubby" or obj.index!=scene or id not in sites(scene,notes): return
	match id:
		"snow":
			descent_at=g.clock
			g.chapter_note="발끝이 마을을 향해 있어. 쿠비가 찾으러 간 건 반려 도깨비불을 만들 인간의 공포였어."
		"village": g.chapter_note="담장 아래에도 같은 발자국이 있어. 쿠비가 아랫마을에 내려왔구나."
		"watch":
			village.approach(g)
			return
		"ice": g.chapter_note="얼음에 비친 모습을 보자. 길을 따라 걸으면 그때의 변화가 이어져."
		"glow":
			if "flame" not in notes:
				g.chapter_note="중간에 놓친 모습이 있어. 길 위에서 가장 밝은 별로 돌아가 오른쪽으로 걸어 보자."
				return
			g.chapter_note="쿠비 곁에 작은 불꽃이 떠 있어. 마을에서 데려온 그 햄스터야."
		"night":
			left_at=g.clock
			g.chapter_note="처음 겪은 두려움 뒤엔 궁금증이 남았어. 쿠비는 다른 감정도 알아보려고 한밤중에 길을 나섰어."
		"journey": g.chapter_note="달빛 아래 이어지던 여정에서 쿠비는 리스텔라와 마주했어."
	mark_found(g,id)
	g._play_chime(690)
	g._setup_map()
	if ready(scene,notes): g._inspect_chapter(scene,g.chapter_note)

static func trail_point(t: float) -> Vector2:
	return ICE_START.lerp(ICE_END,t)+Vector2(0,-17*sin(t*PI))

func walk(g,previous: Vector2,current: Vector2) -> void:
	var notes: Array=g._chapter_progress().kubby_notes
	if "ice" not in notes or "flame" in notes or current.x<=previous.x: return
	# Count only the section actually walked, so approaching the far bank from off the trail cannot skip the change.
	var width:=ICE_END.x-ICE_START.x
	var t:=clampf((current.x-ICE_START.x)/width,0,1)
	var old_t:=clampf((previous.x-ICE_START.x)/width,0,1)
	if t<=flow or old_t>flow+(0.21 if flow==0 else 0.04) or absf(current.y-trail_point(t).y)>84: return
	flow=t
	for i in range(1,STOPS.size()):
		if flow<STOPS[i] or PHASE[i] in notes: continue
		mark_found(g,PHASE[i])
		g.chapter_note=["인간의 공포를 가져오지 못한 벌로, 쿠비의 겉모습이 달라졌어.","쿠비가 데려온 햄스터 둘레로 푸른 불씨가 피어나.","햄스터가 있던 자리에 도깨비불이 가만히 떠올랐어."][i-1]
		g._play_chime(500+95*i)

func feet(g,scene: int,notes: Array) -> Vector2:
	match scene:
		0:
			if "snow" not in notes: return Vector2(366,467)
			return Vector2(366,467).lerp(Vector2(634,354),smoothstep(0.0,2.2,g.clock-descent_at))
		1: return village.kubby_feet()
		2: return Vector2(559,400)
		_:
			if "night" not in notes: return Vector2(416,497)
			return Vector2(416,497).lerp(Vector2(729,334),smoothstep(0.0,2.2,g.clock-left_at))

func painted_target(g,point: Vector2) -> Dictionary:
	var watch: Dictionary=g._find_object("wisp_watch")
	if not watch.is_empty() and g.Field.stella_hit_rect("kubby_origin",village.kubby_feet()).has_point(point): return watch
	var destination: Dictionary=g._find_object("wisp_village")
	if not destination.is_empty() and Rect2(656,210,141,87).has_point(point): return destination
	return {}

static func paw(g,p: Vector2,fade: Color) -> void:
	g.draw_rect(Rect2(p-Vector2(3,0),Vector2(6,3)),fade)
	g.draw_rect(Rect2(p-Vector2(4,4),Vector2(2,2)),fade)
	g.draw_rect(Rect2(p-Vector2(0,5),Vector2(2,3)),fade)

static func flame(g,p: Vector2,phase: float,scale_factor: float) -> void:
	var bob:=Vector2(0,roundf(sin(phase)*2))
	var center:=p+bob
	g.draw_circle(center-Vector2(0,16)*scale_factor,18*scale_factor,Color("75e5cb23"))
	g.WorldPixels.prop(g,"ember",center,scale_factor)
	for i in range(3):
		var t:=fposmod(phase*.15+i/3.0,1.0)
		var q: Vector2=center+Vector2(sin(i*3+t*5)*12,-14-24*t)*scale_factor
		g.draw_rect(Rect2(q.round(),Vector2.ONE*(3 if i==1 else 2)),Color("d5ffdf").lerp(Color("8dd1c738"),t))

func draw_field(g,scene: int,notes: Array) -> void:
	var actor:=feet(g,scene,notes)
	if scene==1:
		village.draw_field(g)
		return
	elif scene==2:
		var p:=Vector2(476,405)
		var lit:=smoothstep(.46,.70,flow)
		if lit<1.0:
			g.WorldPixels.sprite(g,"prop_hamster",p,1.75,Color(1,1,1,1-lit))
		if flow>=.42 and flow<.77:
			for i in range(8):
				var theta:=TAU*i/8+flow*7
				var off:=Vector2(cos(theta),sin(theta))*(13+10*sin(PI*flow))
				g._star(p+off-Vector2(0,11),2+sin(i+flow*15),MINT)
		if lit>0.0:
			var lift:=smoothstep(.50,1.0,flow)
			flame(g,p-Vector2(0,5+22*lift),g.clock*3 if flow>=1. else flow*16,lerpf(.25,1.45,lit))
		if "ice" in notes and "glow" not in notes:
			for i in range(23):
				var t:=i/22.0
				var point:=trail_point(t).round()
				g.draw_line(point+Vector2(-6,2),point+Vector2(4,-2),Color("80ceca") if t<=flow else Color("a0aec6"),2)
				if i%3==0: g._star(point,3,MINT if t<=flow else Color("d8eaf0"))
			g._star(trail_point(flow),6,MINT)
	elif scene==3:
		flame(g,actor+Vector2(38,-29),g.clock*3,.98)
	if ready(scene,notes): return
	for id in sites(scene,notes):
		var p: Vector2=SITES[id][0]
		g.draw_ellipse_shadow(p,Vector2(22,6))
		g.draw_arc(p,19,0,TAU,26,Color("d8dfafcc"),2)
		match id:
			"snow","journey":
				for i in range(4):
					paw(g,p+Vector2(-10+i*7,-8-i*5+(i%2)*6),CREAM)
			"village","night","glow": g._star(p-Vector2(0,19),7+sin(g.clock*2),CREAM)
			"ice": g.draw_polyline(PackedVector2Array([p+Vector2(-19,1),p+Vector2(-4,-14),p+Vector2(1,-12),p+Vector2(16,-30)]),MINT,3)
		g._world_sign(p+Vector2(0,22),SITES[id][1],"wisp_"+id)

func draw_reflection(g) -> void:
	# This intact comic cell shows Kubby's change at frame 8 and the hamster's at frame 13.
	var tick:=minf(23,flow*24)
	g.draw_rect(FRAME.grow(4),Color("34475c"))
	g.draw_texture_rect_region(g.Comics.sheet("kubby"),FRAME,g.Comics.key_region(2,tick))
	g.draw_rect(Rect2(FRAME.position,Vector2(FRAME.size.x,23)),Color("243647ed"))
	g._text(FRAME.position+Vector2(9,16),"얼음에 비친 기억",14,CREAM)
	g.draw_rect(Rect2(FRAME.position+Vector2(0,FRAME.size.y),Vector2(FRAME.size.x,4)),Color("45576c"))
	g.draw_rect(Rect2(FRAME.position+Vector2(0,FRAME.size.y),Vector2(FRAME.size.x*flow,4)),MINT)
