extends RefCounted

const ENTRANCE := Vector2(248,568)
const STATION := Vector2(600,440)
const KUBBY := Vector2(549,406)
const HAMSTER_START := Vector2(416,385)
const HAMSTER_STOP := Vector2(497,405)
const REACH := 13.0
const REVEAL := .65
const FLINCH := 1.60
const LIFT := 3.18
const END := 4.18
const ZOOM := 2.12
const OFFSET := Vector2(-461,-416)
const OBSERVATION := "작은 햄스터를 보고 쿠비가 뒷걸음질쳤어. 인간의 공포를 구하러 왔던 쿠비가 데려간 건 그 햄스터였어."
const SHADE := Color("b2a6be") # Before the change on the ice, as in the field and comic.

var watching := false
var elapsed := 0.0
var camera := 0.0
var arrival := STATION
var witness := STATION
var approach_time := 0.0

func restore(notes: Array) -> void:
	watching=false
	camera=0.0
	elapsed=END if "home" in notes else (FLINCH-.32 if "found" in notes else 0.0)

static func in_reach(p: Vector2) -> bool:
	return p.distance_to(STATION)<REACH or p.distance_to(KUBBY)<48.0

func approach(g) -> void:
	if g.chapter_question or g.kubby_embers.ready(1,g._chapter_progress().kubby_notes): return
	var site: Dictionary=g._find_object("wisp_watch")
	if site.is_empty(): return
	if not in_reach(g.player_pos):
		g._go_to(site)
		return
	watching=true
	g.chapter_question=true
	g.route.clear()
	g.pending_object=""
	arrival=g.player_pos
	witness=STATION if arrival.x>=KUBBY.x else Vector2(457,448)
	approach_time=0.0
	g.fan_motion.direction="left" if witness.x>KUBBY.x else "right"
	g.buttons.clear()

func advance(g,delta: float) -> void:
	camera=move_toward(camera,1.0 if watching else 0.0,delta*1.8)
	if not watching or elapsed>=END: return
	var notes: Array=g._chapter_progress().kubby_notes
	# Keep the witness clear of the hamster even when approached from the far side.
	approach_time=minf(.58,approach_time+delta)
	g.player_pos=arrival.lerp(witness,smoothstep(0,.58,approach_time))
	var before:=elapsed
	elapsed=minf(END,elapsed+delta)
	if before<REVEAL and elapsed>=REVEAL and "found" not in notes: g.KubbyEmbers.mark_found(g,"found")
	if elapsed>=END:
		g.KubbyEmbers.mark_found(g,"home")
		g._play_chime(615)

func read(g) -> void:
	if elapsed<END: return
	watching=false
	g.chapter_question=false
	g._setup_map()
	g._inspect_chapter(1,OBSERVATION)

func input(g,event: InputEvent) -> bool:
	if not watching: return false
	if event is InputEventKey:
		if event.physical_keycode in [KEY_F5,KEY_F11]: return false
		if event.pressed and not event.echo:
			match event.physical_keycode:
				KEY_E,KEY_ENTER,KEY_SPACE: read(g)
				KEY_R:
					if elapsed>=END: elapsed=0.0
				KEY_ESCAPE: g._leave_chapter()
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		for item in g.buttons:
			if not item.rect.has_point(event.position): continue
			match item.id:
				"chapter_leave": g._leave_chapter()
				"village_read": read(g)
				"village_again":
					if elapsed>=END: elapsed=0.0
			break
	return true

func kubby_feet() -> Vector2:
	var recoil:=smoothstep(FLINCH,FLINCH+.19,elapsed)
	var settle:=smoothstep(FLINCH+.34,FLINCH+.84,elapsed)
	var step_in:=smoothstep(2.68,3.28,elapsed)
	return (KUBBY+Vector2(21*recoil-10*settle-40*step_in,-7*recoil+7*settle)).round()

func hamster_feet() -> Vector2:
	var run:=smoothstep(REVEAL,FLINCH+.08,elapsed)
	var hop:=absf(sin(run*PI*4))*2.0
	var ground:=HAMSTER_START.lerp(HAMSTER_STOP,run)-Vector2(0,hop)
	var lifted:=smoothstep(LIFT,3.80,elapsed)
	return ground.lerp(kubby_feet()+Vector2(-15,-30),lifted).round()

func draw_kubby(g,feet: Vector2) -> void:
	# Use the same anchored, full-body poses as the resident; the field costume is fixed in this memory.
	if elapsed>=FLINCH and elapsed<2.68:
		var gesture: Dictionary=g.StellaInteractions.definition("kubby","startled")
		var column: int=g.StellaInteractions.Samples.gesture(gesture.durations,elapsed-FLINCH,gesture.travel_seconds)
		g.StellaInteractions.draw(g,"kubby","startled",feet,column,"kubby_origin",SHADE)
		if elapsed<FLINCH+.54:
			var p:=feet+Vector2(-16,-92)
			for i in range(3):
				var ray:=Vector2.from_angle(-2.85+i*.4)
				g.draw_line(p+ray*5,p+ray*(10+i%2*3),Color("ffe7a1"),2)
	else:
		var walking:=elapsed>=2.68 and elapsed<3.28
		g.Field.draw_stella_turn(g,"kubby","kubby_origin",feet,"left",walking,KUBBY.distance_to(feet),SHADE)
	if elapsed>=LIFT: draw_hamster(g)

func draw_hamster(g) -> void:
	var p:=hamster_feet()
	if elapsed<LIFT: g.draw_ellipse_shadow(p,Vector2(10,2.7))
	# The small chestnut animal has paws on the stones. Hamnim keeps its larger floating mint silhouette.
	var alpha:=smoothstep(REVEAL,REVEAL+.15,elapsed)
	var running:=elapsed<FLINCH+.08 and elapsed>REVEAL
	var stride:=sin(elapsed*TAU*4) if running else 0.0
	g._transform(p)
	# Side-on markings, tiny stepping paws and a short snout read from normal map scale.
	for x in [-8,5]:
		var foot:=Vector2(x+roundf(stride*(2 if x<0 else -2)),-2)
		g.draw_rect(Rect2(foot,Vector2(5,2)),Color(Color("785044"),alpha))
		g.draw_rect(Rect2(foot+Vector2(1,0),Vector2(3,1)),Color(Color("e4b79a"),alpha))
	var fur:=PackedVector2Array([Vector2(-13,-3),Vector2(-15,-8),Vector2(-13,-13),Vector2(-9,-16),Vector2(-2,-17),Vector2(2,-16),Vector2(3,-19),Vector2(7,-19),Vector2(9,-16),Vector2(11,-13),Vector2(14,-10),Vector2(15,-8),Vector2(12,-6),Vector2(10,-3),Vector2(5,-2),Vector2(-8,-2)])
	g.draw_colored_polygon(fur,Color(Color("71483d"),alpha))
	g.draw_colored_polygon(PackedVector2Array([Vector2(-13,-8),Vector2(-11,-13),Vector2(-6,-15),Vector2(2,-15),Vector2(6,-16),Vector2(10,-12),Vector2(13,-9),Vector2(10,-5),Vector2(3,-3),Vector2(-7,-3),Vector2(-11,-4)]),Color(Color("c78c52"),alpha))
	g.draw_colored_polygon(PackedVector2Array([Vector2(-8,-6),Vector2(-2,-7),Vector2(2,-10),Vector2(10,-11),Vector2(13,-9),Vector2(10,-5),Vector2(4,-3),Vector2(-7,-3)]),Color(Color("f3d8ad"),alpha))
	g.draw_rect(Rect2(4,-18,3,3),Color(Color("e2ad99"),alpha))
	# Warm fur clumps, a pale ear rim and cheek tufts distinguish this tiny
	# ground animal from Hamnim's large mint floating silhouette.
	for tuft: Vector2 in [Vector2(-11,-11),Vector2(-8,-14),Vector2(-3,-14),Vector2(0,-12),Vector2(-9,-5)]:
		g.draw_rect(Rect2(tuft,Vector2(3,1)),Color(Color("e7b576"),alpha))
	g.draw_rect(Rect2(-5,-15,4,1),Color(Color("f3cd91"),alpha))
	g.draw_rect(Rect2(4,-18,2,1),Color(Color("f8d8ae"),alpha))
	g.draw_rect(Rect2(6,-6,4,1),Color(Color("fff0cd"),alpha))
	g.draw_rect(Rect2(8,-13,2,2),Color(Color("443638"),alpha))
	g.draw_rect(Rect2(8,-13,1,1),Color(Color("fff3d7"),alpha))
	g.draw_rect(Rect2(14,-9,2,2),Color(Color("b97974"),alpha))
	g.draw_line(Vector2(11,-8),Vector2(16,-10),Color(Color("ead5bf"),alpha),1)
	g.draw_line(Vector2(10,-7),Vector2(15,-6),Color(Color("ecd2b5"),alpha),1)
	g._transform()

func draw_field(g) -> void:
	if elapsed>REVEAL and elapsed<LIFT: draw_hamster(g)
	if not watching and elapsed<END:
		g._world_sign(STATION+Vector2(0,34),"쿠비 곁으로","wisp_watch")

func draw_hud(g) -> void:
	g._panel(Rect2(97,698,1086,93),g.PAPER)
	var line: String
	if elapsed<REVEAL: line="쿠비가 골목 안쪽을 보고 있어."
	elif elapsed<FLINCH: line="저기, 돌바닥을 타고 작은 햄스터가 다가와."
	elif elapsed<LIFT: line="쿠비가 움찔했어! 쿠비를 놀라게 한 건 저 작은 햄스터야."
	else: line="쿠비가 조심스레 다가가 햄스터를 데려가네."
	g._text(Vector2(122,736),"햄님   ·   "+line,19,g.CREAM)
	if elapsed>=END:
		g._button(Rect2(724,719,190,42),"다시 보기   R","village_again")
		g._button(Rect2(927,719,226,42),"기억 펼치기   E","village_read",true)
