extends RefCounted

# Feet and tool positions are in the alley's coordinates, including during the camera move.
const ENTRANCE := Vector2(472,584)
const STONE := Vector2(546,381)
const STONE_SIDE := Vector2(520,392)
const ETE_START := Vector2(699,344)
const PICKUP := Vector2(567,388)
const ETE_END := Vector2(354,496)
const ETE_SIDE := Vector2(296,504)
const HAND := Vector2(-18,-43)
const HELD_SCALE := .76
const REST := Vector2(-18,12)
const REACH := 22.0
const RUB_TIME := 1.6
const TO_STONE := 1.1
const LIFT := .55
const TO_LIBRARY := 1.7
const WALK_TIME := TO_STONE+LIFT+TO_LIBRARY
const CLOSE_SCALE := 2.4
const INK := Color("554b5a")
const PAPER := Color("f3dfb6")
const RECOGNITION := "탁본의 굽은 모서리까지 딱 맞아. 에테가 자기 애완돌인 줄 알고 안아 간 건 잠든 도리였어."
const SNAP_DISTANCE := 8.0
const RESULT_TIME := 4.8
const FADE_TIME := .65
# Optional comparisons belong to the player's observation, not the official case.
const SAMPLES := [
	{"pos":Vector2(400,477),"note":"모서리가 반듯해. 종이에 남길 윤곽도 길가의 돌과 다르겠어."},
	{"pos":Vector2(661,470),"note":"이 돌은 납작하고 길쭉해. 다른 돌의 굽은 모서리와 비교해 볼까?"}
]

# Sampled from the silhouette of the field's prop_stone, using a shared origin for the print and the rock.
const RIM := [Vector2(-16,3),Vector2(-12,-6),Vector2(-3,-11),Vector2(7,-9),Vector2(16,1),Vector2(14,8),Vector2(7,11),Vector2(-12,11),Vector2(-16,3)]
enum Phase { FIELD, RUB, ALIGN, MATCHED }
var phase := Phase.FIELD
var camera := 0.0
var camera_at := STONE
var lifted_at := -1.0
var charcoal := 0.0
var stroke := 0.0
var held := false
var pressed_arrows := {}
var waiting_for_ete := false
var dragging := false
var grab := Vector2.ZERO
var offset := REST
var paused := false
var matched_time := 0.0
var arrival_fade := 0.0
var observation := ""
var observation_time := 0.0

func active(g) -> bool:
	return g.mode=="chapter" and g.MEMBERS[g.story_member].id=="dori" and g._chapter_progress().debut_scene("dori")==2

func reset() -> void:
	phase=Phase.FIELD
	camera=0.0
	lifted_at=-1.0
	waiting_for_ete=false
	charcoal=0.0
	paused=false
	matched_time=0.0
	arrival_fade=0.0
	observation=""
	observation_time=0.0
	release()

func resume(g) -> void:
	# Completed old bookmarks also continue without a duplicate record/exit chore.
	if "print3" in g._chapter_progress().dori_notes:
		phase=Phase.MATCHED
		offset=Vector2.ZERO
		camera_at=rock(g)
		g.chapter_question=true
		g.chapter_observation=RECOGNITION

func toggle_pause(g) -> void:
	if not active(g): return
	paused=not paused
	release()
	g.route.clear()
	g.pending_object=""
	g.chapter_question=paused or phase!=Phase.FIELD

func release() -> void:
	held=false
	dragging=false
	pressed_arrows.clear()

func has_print(g) -> bool: return "print1" in g._chapter_progress().dori_notes

func ete_elapsed(g) -> float:
	if not has_print(g): return 0.0
	return WALK_TIME if lifted_at<0 else clampf(g.clock-lifted_at,0,WALK_TIME)

func ete_feet(g) -> Vector2:
	var t:=ete_elapsed(g)
	if t<TO_STONE: return ETE_START.lerp(PICKUP,smoothstep(0,TO_STONE,t))
	return PICKUP.lerp(ETE_END,smoothstep(TO_STONE+LIFT,WALK_TIME,t))

func ete_pose(g) -> Dictionary:
	var t:=ete_elapsed(g)
	var feet:=ete_feet(g)
	var walking: bool=(t>0 and t<TO_STONE) or (t>TO_STONE+LIFT and t<WALK_TIME)
	var d:=ETE_START.distance_to(feet) if t<TO_STONE else ETE_START.distance_to(PICKUP)+PICKUP.distance_to(feet)
	return {"direction":"left" if walking else "down","walking":walking,"distance":d}

func rock(g) -> Vector2:
	var t:=ete_elapsed(g)
	if t<TO_STONE:
		return STONE+Vector2(0,-roundf(maxf(0,sin(g.clock*3.5))*2))
	var hand:=ete_feet(g)+HAND
	return STONE.lerp(hand,smoothstep(TO_STONE,TO_STONE+LIFT,t))

func held_by_ete(g) -> bool: return ete_elapsed(g)>=TO_STONE

func camera_offset() -> Vector2:
	var offset_to_point:=Vector2(640,370)-camera_at*CLOSE_SCALE
	return offset_to_point.clamp(Vector2(1280,800)-Vector2(936,718)*CLOSE_SCALE,-Vector2(32,140)*CLOSE_SCALE)

static func add_site(objects: Array,notes: Array) -> void:
	if "print3" in notes: return
	var carrying: bool="print1" in notes
	objects.append({"id":"clue_overlay" if carrying else "clue_rubbing","type":"dori_alley","index":2,
		"reach":REACH,"pos":ETE_SIDE if carrying else STONE_SIDE,"label":"탁본 포개 보기" if carrying else "돌 살펴보기"})
	for i in range(SAMPLES.size()):
		objects.append({"id":"rubbing_sample_%d"%i,"type":"dori_alley","index":2,"sample":i,
			"reach":36.0,"pos":SAMPLES[i].pos+Vector2(-12,19),"label":"돌 살펴보기"})

func clicked_site(g,p: Vector2) -> Dictionary:
	for i in range(SAMPLES.size()):
		if SAMPLES[i].pos.distance_to(p)<25: return g._find_object("rubbing_sample_%d"%i)
	if has_print(g):
		if g.Field.stella_hit_rect("aethe",ete_feet(g)).has_point(p):
			return g._find_object("clue_overlay")
	elif rock(g).distance_to(p)<25: return g._find_object("clue_rubbing")
	return {}

func begin(g,obj: Dictionary) -> void:
	if not active(g) or g.chapter_question or obj.is_empty(): return
	if obj.has("sample"):
		if g.player_pos.distance_to(obj.pos)>=float(obj.reach):
			g._go_to(obj)
			return
		observation=SAMPLES[obj.sample].note
		observation_time=5.0
		return
	if obj.id!=("clue_overlay" if has_print(g) else "clue_rubbing") or "print3" in g._chapter_progress().dori_notes: return
	if g.player_pos.distance_to(obj.pos)>=REACH:
		g._go_to(obj)
		return
	if has_print(g) and ete_elapsed(g)<WALK_TIME:
		waiting_for_ete=true
		return
	release()
	g.route.clear()
	g.pending_object=""
	g.player_pos=obj.pos
	stroke=0.0
	offset=REST
	phase=Phase.ALIGN if has_print(g) else Phase.RUB
	camera_at=rock(g)
	g.chapter_question=true
	g.buttons.clear()
	observation_time=0.0

func bookmark(g,marks: Array) -> void:
	var notes: Array=g._chapter_progress().dori_notes
	for mark in marks:
		if mark not in notes: notes.append(mark)
	if g.replay_progress==null: g._save()

func add_charcoal(g,amount: float) -> void:
	if phase!=Phase.RUB: return
	charcoal=clampf(charcoal+amount,0,1)
	if charcoal<1: return
	bookmark(g,["print1"])
	lifted_at=g.clock
	g.chapter_note="돌의 결이 종이에 남았어. 에테가 걸어오네. 이 탁본을 들고 따라가 보자."
	g._play_chime(642)
	close(g)
	observation="이 윤곽을 기억해 두자. 에테가 돌을 안고 가고 있어."
	observation_time=4.5

func align(g) -> void:
	if phase!=Phase.ALIGN: return
	if offset.length()>SNAP_DISTANCE: return
	release()
	phase=Phase.MATCHED
	matched_time=0.0
	bookmark(g,["print2","print3"])
	g.chapter_note=RECOGNITION
	g._play_chime(825)

func close(g) -> void:
	if phase==Phase.MATCHED:
		toggle_pause(g)
		return
	phase=Phase.FIELD
	release()
	g.chapter_question=false
	g._setup_map()

func finish(g) -> void:
	if not active(g) or not g.DoriCase.ready(2,g._chapter_progress().dori_notes): return
	if not g._chapter_progress().record_chapter_step("dori",1): return
	g._next_chapter_site("dori",2)
	arrival_fade=FADE_TIME
	g.chapter_note="에테가 데려온 돌은 도서관에서 눈을 떴어. 깨어난 도리의 이야기가 이어져."

func advance(g,dt: float) -> void:
	arrival_fade=maxf(0,arrival_fade-dt)
	if not active(g): return
	if paused:
		if lifted_at>=0: lifted_at+=dt
		return
	observation_time=maxf(0,observation_time-dt)
	camera=move_toward(camera,0.0 if phase==Phase.FIELD else 1.0,dt*2.8)
	if waiting_for_ete:
		if g.player_pos.distance_to(ETE_SIDE)>=REACH: waiting_for_ete=false
		elif ete_elapsed(g)>=WALK_TIME:
			waiting_for_ete=false
			begin(g,g._find_object("clue_overlay"))
	if phase==Phase.RUB and held:
		stroke=sin(charcoal*TAU*5.0)*12
		add_charcoal(g,dt/RUB_TIME)
	if phase==Phase.ALIGN and not dragging:
		var direction:=Vector2.ZERO
		for arrow: Vector2 in pressed_arrows.values(): direction+=arrow
		offset=(offset+direction.normalized()*dt*42).clamp(Vector2(-36,-32),Vector2(36,32))
		if direction!=Vector2.ZERO: align(g)
	if phase==Phase.MATCHED:
		offset=offset.move_toward(Vector2.ZERO,dt*60)
		matched_time+=dt
		if matched_time>=RESULT_TIME+FADE_TIME and not g.book_discovery.active(g): finish(g)

func input(g,event: InputEvent) -> bool:
	if not active(g): return false
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		for b in g.buttons:
			if not b.rect.has_point(event.position): continue
			if b.id in ["rubbing_pause","rubbing_resume"]: toggle_pause(g)
			elif b.id=="rubbing_leave": g._leave_chapter()
			elif b.id=="rubbing_back": close(g)
			return true
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_ESCAPE:
			if paused or phase in [Phase.FIELD,Phase.MATCHED]: toggle_pause(g)
			else: close(g)
			return true
	if paused:
		if event is InputEventKey and event.pressed and event.physical_keycode in [KEY_E,KEY_ENTER,KEY_SPACE]: toggle_pause(g)
		return true
	if phase==Phase.FIELD: return false
	if event is InputEventKey:
		var key: int=event.physical_keycode
		if key in [KEY_F5,KEY_F11]: return false
		if event.echo: return true
		if key in [KEY_E,KEY_ENTER,KEY_SPACE]:
			if phase==Phase.RUB: held=event.pressed
		elif phase==Phase.ALIGN:
			var arrow: Vector2={KEY_LEFT:Vector2.LEFT,KEY_A:Vector2.LEFT,KEY_RIGHT:Vector2.RIGHT,KEY_D:Vector2.RIGHT,KEY_UP:Vector2.UP,KEY_W:Vector2.UP,KEY_DOWN:Vector2.DOWN,KEY_S:Vector2.DOWN}.get(key,Vector2.ZERO)
			if event.pressed: pressed_arrows[key]=arrow
			else: pressed_arrows.erase(key)
			if event.pressed:
				offset=(offset+arrow*2).clamp(Vector2(-36,-32),Vector2(36,32))
				if arrow!=Vector2.ZERO: align(g)
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		var world: Vector2=(event.position-g.WORLD_OFFSET)/g.WORLD_SCALE
		if event.pressed:
			var sheet:=rock(g)+(offset if phase==Phase.ALIGN else Vector2.ZERO)
			dragging=phase!=Phase.MATCHED and Rect2(sheet-Vector2(26,19),Vector2(52,38)).has_point(world)
			grab=world-sheet if dragging else Vector2.ZERO
		elif dragging:
			dragging=false
			if phase==Phase.ALIGN: align(g)
	elif event is InputEventMouseMotion and dragging:
		var world: Vector2=(event.position-g.WORLD_OFFSET)/g.WORLD_SCALE
		if phase==Phase.ALIGN:
			offset=(world-grab-rock(g)).clamp(Vector2(-36,-32),Vector2(36,32))
			align(g)
		elif phase==Phase.RUB and Rect2(rock(g)-Vector2(27,18),Vector2(54,36)).has_point(world):
			var x:=clampf(world.x-rock(g).x,-17,17)
			add_charcoal(g,absf(x-stroke)/104.0)
			stroke=x
	return true

static func draw_rock(g,p: Vector2,size: float=1.0) -> void:
	# Crop the very same field sprite, with its centre matching the rubbing's origin.
	g.draw_texture_rect_region(g.WorldPixels.texture("prop_stone"),Rect2(p-Vector2(17,11.5)*size,Vector2(34,23)*size),Rect2(6,32,68,46))

func draw_carried(g) -> void:
	var lifted:=smoothstep(TO_STONE,TO_STONE+LIFT,ete_elapsed(g))
	var center:=rock(g)
	draw_rock(g,center,lerpf(1.0,HELD_SCALE,lifted))
	if lifted>.8:
		# The cuff and fingertips curl in front of the lower edge.
		var grip: Vector2=(center+Vector2(8,5)).round()
		g.draw_rect(Rect2(grip+Vector2(0,1),Vector2(8,4)),Color("252b47"))
		g.draw_rect(Rect2(grip+Vector2(3,1),Vector2(5,2)),Color("c4a66a"))
		g.draw_rect(Rect2(grip-Vector2(2,0),Vector2(5,3)),Color("eac5ab"))
		g.draw_rect(Rect2(grip-Vector2(2,0),Vector2(4,1)),Color("ffe4c6"))

static func paper(g,p: Vector2,amount: float,overlay: bool=false) -> void:
	var box:=Rect2(p-Vector2(20,15),Vector2(40,30))
	var fill:=Color(PAPER,.19) if overlay else PAPER
	g.draw_rect(box.grow(1),Color("795e498a") if overlay else Color("775b46"),false,1)
	g.draw_rect(box,fill)
	g.draw_rect(box,Color("b79f7b"),false,1)
	if not overlay:
		# Laid-paper fibres stay under the charcoal; a creased edge catches light.
		for fiber in range(12):
			var at:=box.position+Vector2(3+posmod(fiber*13,33),3+posmod(fiber*7,24))
			g.draw_rect(Rect2(at,Vector2(1+fiber%3,1)),Color("dec8a037"))
		g.draw_line(box.position+Vector2(2,1),box.position+Vector2(30,1),Color("fff0ca"),1)
		for fiber: Vector2 in [Vector2(4,6),Vector2(34,21),Vector2(7,26),Vector2(25,4)]:
			g.draw_rect(Rect2(box.position+fiber,Vector2(2,1)),Color("dfc99e"))
	g.draw_line(box.position+Vector2(33,0),box.position+Vector2(39,6),Color("a48a6e"),1)
	var tint:=Color("fff0b1") if overlay else INK
	var length:=RIM.size()-1
	for i in range(length):
		var part:=clampf(amount*length-i,0,1)
		if part<=0: break
		var a: Vector2=p+RIM[i]
		var b: Vector2=p+RIM[i+1]
		g.draw_line(a,a.lerp(b,part),tint,1.5)
	for i in range(22):
		if i/22.0+.02>amount: break
		var q:=p+Vector2(-10+posmod(i*7,21),-5+posmod(i*5,12))
		g.draw_line(q,q+Vector2(2,-1),Color(tint,.62),1)

func draw_ground(g) -> void:
	for i in range(SAMPLES.size()):
		var p: Vector2=SAMPLES[i].pos
		g.draw_ellipse_shadow(p+Vector2(0,8),Vector2(21,5))
		if i==0:
			var edge:=PackedVector2Array([p+Vector2(-19,-6),p+Vector2(-12,-11),p+Vector2(6,-12),p+Vector2(17,-6),p+Vector2(19,0),p+Vector2(15,9),p+Vector2(-10,12),p+Vector2(-18,7),p+Vector2(-19,-6)])
			g.draw_colored_polygon(edge,Color("756a66"))
			g.draw_polyline(edge,Color("574f50"),2)
			g.draw_colored_polygon(PackedVector2Array([edge[0],edge[1],edge[2],edge[3],p+Vector2(8,0),p+Vector2(-7,4)]),Color("ada090"))
			g.draw_line(p+Vector2(-12,-9),p+Vector2(5,-10),Color("c6b49b"),1)
			g.draw_polyline(PackedVector2Array([p+Vector2(4,-9),p+Vector2(1,-4),p+Vector2(5,-1),p+Vector2(2,7)]),Color("786e65"),1)
			for fleck in range(18):
				var q:=p+Vector2(-12+posmod(fleck*7,24),-7+posmod(fleck*5,15))
				g.draw_rect(Rect2(q,Vector2(1+fleck%3,1)),Color("c2ae91") if fleck%3==0 else Color("877b6a"))
		else:
			g._transform(p,Vector2(1.4,.55))
			draw_rock(g,Vector2.ZERO)
			g._transform()
	if not held_by_ete(g):
		var p:=rock(g)
		g.draw_ellipse_shadow(STONE+Vector2(0,10),Vector2(16,4))
		draw_rock(g,p)
	if phase!=Phase.FIELD or paused: return
	var obj: Dictionary=g._nearest()
	if obj.is_empty(): return
	if obj.id=="clue_overlay" and ete_elapsed(g)<WALK_TIME: return
	var focus: Vector2=SAMPLES[obj.sample].pos if obj.has("sample") else rock(g)
	g.draw_arc(focus+Vector2(0,7),24,0,PI,18,Color("f6dca4"),1.5)
	# Only the nearby object has a prompt; no always-on labels or destination markers.
	var at: Vector2=(focus+Vector2(0,25))*g.WORLD_SCALE+g.WORLD_OFFSET
	g.in_world=false
	g._transform()
	var width: float=g.font.get_string_size(obj.label,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x+48
	var box:=Rect2(Vector2(clampf(at.x-width/2,100,1180-width),clampf(at.y,90,675)),Vector2(width,32))
	g.chapter_signs.append({"id":obj.id,"rect":Rect2((box.position-g.WORLD_OFFSET)/g.WORLD_SCALE,box.size/g.WORLD_SCALE)})
	g._panel(box,g.PAPER,g.GOLD)
	g._text(box.position+Vector2(12,22),"E  "+obj.label,16,g.CREAM)
	g.in_world=true
	g._transform()

func fan_feet(g,p: Vector2) -> Vector2:
	if phase not in [Phase.ALIGN,Phase.MATCHED]: return p
	# As the paper reaches Ete, Doldori steps in far enough to keep a paw on its corner.
	var corner:=rock(g)+offset+Vector2(-14,7)
	return p.move_toward(corner+Vector2(-8,10),22).round()

func draw_fan(g,p: Vector2) -> void:
	p=fan_feet(g,p)
	if phase in [Phase.RUB,Phase.ALIGN,Phase.MATCHED]:
		var frame: int=g.FanForms.frame_at("dori",g.clock,false)
		var bob:=roundf(sin(charcoal*TAU*5)*1.5) if phase==Phase.RUB else 0.0
		g.draw_ellipse_shadow(p+Vector2(0,2),Vector2(11,3))
		g.Field.Finish.cel(g,g.FanForms.texture("dori"),Rect2((p+Vector2(-32,-58+bob)).round(),Vector2(64,64)),g.FanForms.region_for(frame,"right"))
	else:
		g.FanForms.draw(g,"dori",p,g.moving)
		if has_print(g) and "print3" not in g._chapter_progress().dori_notes:
			g._transform((p+Vector2(12,-15)).round(),Vector2(.59,.59),-.15)
			paper(g,Vector2.ZERO,1)
			g._transform()

# Draw action props after the actors, so the translucent print lies over Ete's stone.
func draw_tools(g) -> void:
	if phase==Phase.FIELD: return
	var stone:=rock(g)
	if phase==Phase.RUB:
		var on_stone:=stone+Vector2(0,-4)
		g._transform(on_stone,Vector2(.82,.64))
		paper(g,Vector2.ZERO,charcoal)
		g._transform()
		# A short charcoal holder lets the mascot reach the paper with its original paw.
		var tip: Vector2=(on_stone+Vector2(-9+stroke*.3,-2+charcoal*4)).round()
		var shoulder: Vector2=g.player_pos+Vector2(6,-11)
		var paw:=shoulder.move_toward(tip,7).round()
		g.draw_line(shoulder,paw,Color("526457"),4)
		g.draw_line(paw,tip,Color("554839"),3)
		g.draw_line(paw,tip-Vector2(3,0),Color("bf9862"),1)
		g.draw_rect(Rect2(paw-Vector2(2,1),Vector2(5,3)),Color("dce6d6"))
		g.draw_rect(Rect2(tip-Vector2(2,1),Vector2(4,3)),INK)
		for fleck in range(5):
			var dust:=tip+Vector2(-3+posmod(fleck*7,9),3+fleck%3)
			g.draw_rect(Rect2(dust.round(),Vector2.ONE),Color("66534390"))
	else:
		var sheet: Vector2=(stone+offset).round()
		g._transform(sheet,Vector2.ONE*HELD_SCALE)
		paper(g,Vector2.ZERO,1,true)
		g._transform()
		var shoulder:=fan_feet(g,g.player_pos)+Vector2(5,-10)
		var corner:=sheet+Vector2(-14,7)
		var paw:=shoulder.move_toward(corner,10).round()
		g.draw_line(shoulder,paw,Color("536657"),4)
		g.draw_rect(Rect2(paw-Vector2(1,2),Vector2(4,3)),Color("dce6d6"))

func draw_hud(g) -> void:
	var top:=Rect2(97,12,1086,52)
	g._panel(top,g.PAPER)
	g.ui_regions.append(top)
	g._text(Vector2(119,44),"도리의 책 · 산책길",15,g.GOLD)
	var question: String="길가의 돌은 어떻게 도서관까지 갔을까?"
	if has_print(g): question="에테 품의 돌은 아까 그 돌일까?"
	if phase==Phase.MATCHED: question="같은 윤곽, 이어지는 기억"
	g._text(Vector2(330,45),question,21,g.CREAM)
	g._button(Rect2(1040,21,124,33),"메뉴  Esc","rubbing_pause")
	var message: String="방향키 / WASD 이동   ·   가까이에서 E 살펴보기   ·   클릭으로 이동"
	var detail: String=""
	if observation_time>0: message=observation
	if phase==Phase.RUB:
		message="문지를수록 돌의 윤곽이 종이에 남아."
		detail="종이를 좌우로 문지르기   /   E 길게 누르기"
	elif phase==Phase.ALIGN:
		message="종이의 굽은 모서리와 돌의 윤곽을 비교해 보자."
		detail="종이를 끌어서 포개기   /   방향키 또는 WASD로 옮기기"
	elif phase==Phase.MATCHED:
		message="같은 돌이야. 에테가 안고 간 건 잠든 도리였어."
		detail="애완돌로 착각한 에테를 따라, 도리의 기억은 도서관으로 이어져."
	var box:=Rect2(97,735 if detail.is_empty() else 710,1086,55 if detail.is_empty() else 80)
	g._panel(box,g.PAPER)
	g.ui_regions.append(box)
	g._text(box.position+Vector2(23,32),message,19,g.CREAM)
	if not detail.is_empty(): g._text(box.position+Vector2(23,60),detail,16,g.MUTED)
	if phase in [Phase.RUB,Phase.ALIGN]: g._button(Rect2(1010,720,151,32),"돌아가기  Esc","rubbing_back")
	if paused:
		g.buttons.clear()
		g.draw_rect(Rect2(0,0,1280,800),Color("172029b8"))
		g._panel(Rect2(410,267,460,254),g.PAPER)
		g._center(315,"잠시 책갈피를 꽂아 둘까?",22,g.CREAM)
		g._center(348,"발견한 기억은 그대로 남아 있어.",16,g.MUTED)
		g._button(Rect2(451,374,378,44),"계속 살펴보기   E / Esc","rubbing_resume",true)
		g._button(Rect2(451,436,378,44),"책갈피 꽂고 책 나가기","rubbing_leave")

func draw_transition(g) -> void:
	if g.book_discovery.active(g): return
	var opacity:=arrival_fade/FADE_TIME
	if active(g) and phase==Phase.MATCHED and not paused:
		opacity=maxf(opacity,clampf((matched_time-RESULT_TIME)/FADE_TIME,0,1))
	if opacity>0: g.draw_rect(Rect2(0,0,1280,800),Color(.13,.12,.16,opacity))
