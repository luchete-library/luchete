extends RefCounted

# World-space staging in the third memory; Mongchi only witnesses the passing nights.
const ENTRANCE := Vector2(312,584)
const STATION := Vector2(456,344)
const YUNE_FEET := Vector2(585,353)
const RING := Vector2(500,250)
const REACH := 11.0
const DURATION := 8.0
const CLOSE_SCALE := 1.86
const CLOSE_OFFSET := Vector2(-293,-261)
const MAP := Rect2(32,140,904,578)
const OBSERVATION := "드림캐처에 머물던 꿈빛이 하나씩 사라졌어. 꿈으로 살아가던 유네도 점점 희미해졌어."
const DREAMS := [Vector2(275,321),Vector2(397,238),Vector2(652,290),Vector2(535,317),
	Vector2(580,205),Vector2(369,369),Vector2(692,355),Vector2(449,273),Vector2(510,233)]
const LAMPS := [Vector2(101,213),Vector2(334,220),Vector2(661,220),Vector2(878,208),Vector2(113,631)]

var fraction := 0.0
var camera := 0.0
var playing := false

func restore(notes: Array) -> void:
	playing=false
	camera=0
	if "bed" in notes and "window" in notes: fraction=1.0
	elif "bed" in notes or "window" in notes: fraction=.5
	else: fraction=0.0

func spawn(notes: Array) -> Vector2:
	restore(notes)
	return STATION if fraction>0 else ENTRANCE

func begin(g,obj: Dictionary) -> void:
	if g.player_pos.distance_to(STATION)>=REACH:
		g._go_to(obj)
		return
	g.yune_dream.view=2
	g.chapter_question=true
	g.buttons.clear()
	g.fan_motion.direction="right"
	playing=fraction<1.0

func advance(g,delta: float) -> void:
	var watching: bool=g.yune_dream.view==2
	camera=move_toward(camera,1.0 if watching else 0.0,delta*1.6)
	if not watching or not playing: return
	var before:=fraction
	fraction=minf(1.0,fraction+delta/DURATION)
	var notes: Array=g._chapter_progress().yune_notes
	if before<.5 and fraction>=.5 and "window" not in notes: g.YuneDream.mark_found(g,"bed")
	if fraction>=1:
		playing=false
		# Old saves can contain either checkpoint on its own.
		g.YuneDream.mark_found(g,"bed")
		g.YuneDream.mark_found(g,"window")
		g._play_chime(524)

func close(g,read: bool) -> void:
	if read and fraction<1: return
	playing=false
	g.yune_dream.view=-1
	g.chapter_question=false
	g.chapter_note=OBSERVATION if fraction>=1 else "드림캐처 곁에 서면 남은 밤을 이어서 지켜볼 수 있어."
	g._setup_map()
	if read: g._inspect_chapter(2,OBSERVATION)

func act(g) -> void:
	pass # Observation advances naturally; Escape returns to the map.

func input(g,event: InputEvent) -> bool:
	if event is InputEventKey:
		if event.physical_keycode in [KEY_F5,KEY_F11]: return false
		if event.pressed and not event.echo:
			match event.physical_keycode:
				KEY_ESCAPE: close(g,false)
				KEY_E,KEY_ENTER,KEY_SPACE: act(g)
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		for item in g.buttons:
			if not item.rect.has_point(event.position): continue
			match item.id:
				"chapter_leave": g._leave_chapter()
				"night_act": act(g)
				"night_rewind": rewind()
				"night_back": close(g,false)
			return true
		var world: Vector2=(event.position-g.WORLD_OFFSET)/g.WORLD_SCALE
		if hits_catcher(world): act(g)
	return true

func rewind() -> void:
	fraction=.5 if fraction>.501 else 0.0
	playing=false

static func hits_catcher(p: Vector2) -> bool:
	return Rect2(RING-Vector2(36,41),Vector2(72,116)).has_point(p)

func draw_field(g,watched: bool,done: bool) -> void:
	var light:=1.0-smoothstep(.03,1.0,fraction)
	g.draw_rect(MAP,Color(.07,.065,.18,.05+.51*(1-light)))
	for lamp: Vector2 in LAMPS:
		halo(g,lamp,19,.52*light)
	# The same ring, characters and stone floor remain in view across all the nights.
	g._transform(Vector2(502,350),Vector2(1,.17))
	for i in range(6):
		var glow:=Color("d4a4ff")
		glow.a=(.018+.045*light)*(1.0-i/8.0)
		g.draw_circle(Vector2.ZERO,108*(1.0-i*.12),glow)
	g._transform()
	var ring:=RING+Vector2(roundf(sin(g.clock*.85)),0)
	g.draw_line(Vector2(RING.x,MAP.position.y),ring-Vector2(0,18),Color("634f70"),2)
	g.draw_line(Vector2(RING.x+1,MAP.position.y),ring-Vector2(-1,18),Color("c3a3a1"),1)
	halo(g,ring,45,.8*light)
	var ring_tint:=Color.WHITE.lerp(Color("aaa1c6"),1-light)
	g.draw_texture_rect(g.WorldPixels.texture("prop_ring"),Rect2(ring-Vector2(48,48),Vector2(96,115)),false,ring_tint)
	for i in range(DREAMS.size()):
		var fade:=1.0-smoothstep(i*.07+.04,i*.07+.43,fraction)
		if fade<=0.0: continue
		var p: Vector2=(DREAMS[i]+Vector2(4*sin(g.clock*.65+i),6*sin(g.clock*.8+i*1.9))).round()
		var size: float=(4.5+posmod(i,3)*1.4+sin(g.clock*2+i)*.8)*(.5+.5*fade)
		halo(g,p,size*2,fade)
		g._star(p,size,Color(Color("ffdc93"),fade))
		g._star(p,size*.48,Color(Color("fff4ce"),fade))
	if not watched and not done: g._world_sign(STATION+Vector2(0,31),"드림캐처 곁에서 밤 지켜보기","dream_nights")

static func halo(g,p: Vector2,size: float,strength: float) -> void:
	for i in range(3):
		g.draw_circle(p,size*(1.0-.28*i),Color(.98,.77,.53,strength*(.052+.028*i)),true,-1,false)

func yune_tint() -> Color:
	return Color.WHITE.lerp(Color(.78,.76,.89,.22),smoothstep(.06,1.0,fraction))

func draw_hud(g) -> void:
	var finished:=fraction>=1.0
	var night: String="꿈빛이 가득한 밤" if fraction<.5 else ("꿈이 뜸해진 밤" if not finished else "마지막 빛이 사라진 자리")
	var detail: String="깃털 사이에도 바닥에도 꿈빛이 모여 있어. 유네의 모습이 또렷해." if fraction<.5 else ("아까 그 자리를 봐. 꿈빛 사이가 비고, 유네 너머로 바닥 무늬가 비쳐." if not finished else OBSERVATION)
	g._panel(Rect2(97,660,1086,131),g.PAPER)
	g._text(Vector2(124,697),"몽치   ·   "+night,22,g.CREAM)
	g._text_block(Vector2(124,731),detail,1020,17,g.MUTED,23)
	g._button(Rect2(124,745,180,34),"현장으로   Esc","night_back")
	g._button(Rect2(734,745,185,34),"이전 밤   ←","night_rewind",false,fraction<=0)
	var label: String="기억 펼치기   E" if finished else ("잠시 멈추기   E" if playing else "이어서 보기   E")
	g._button(Rect2(931,745,223,34),label,"night_act",true)
