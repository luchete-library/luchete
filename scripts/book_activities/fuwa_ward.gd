extends RefCounted

# The practice mark is drawn on the stone court. It is distinct from the return spell.
enum Phase { FIELD, JOIN, TRACE, BLOOM, FINISHED }
const FUWA := Vector2(588,404)
const STATION := Vector2(534,427)
const CENTER := Vector2(548,482)
const DOTS := [Vector2(548,443),Vector2(631,482),Vector2(548,521),Vector2(465,482)]
const MARKS := ["brush_top","seal","brush_bottom","ward"]
const KEYS := [KEY_UP,KEY_RIGHT,KEY_DOWN,KEY_LEFT]
const ARROWS := ["↑","→","↓","←"]
const TIP_OFFSET := Vector2(14,3)
const INK := Color("494659")
const CHALK := Color("f7e5b9")
const BLUE := Color("8ad9e6")
const LIGHT := Color("fff6d8")
const ZOOM := 2.1
const OFFSET := Vector2(-519,-490)
const BLOOM_TIME := 1.75
const OBSERVATION := "신사의 돌바닥에 그린 선이 한 바퀴 이어졌어. 후와와 나는 이곳에서 날마다 함께 결계술을 익혔어."

var phase := Phase.FIELD
var camera := 0.0
var age := 0.0
var join_from := STATION
var join_time := 0.6
var step := 0 # Next corner: 0 starts the stroke; 4 returns to the first corner.
var fraction := 0.0
var held_key := -1
var dragging := false
var needs_regrab := false
var previous_pointer := Vector2.ZERO
var stride := 0.0
var motion := 0.0

func reset() -> void:
	phase=Phase.FIELD
	camera=0.0
	release()
	needs_regrab=false
	motion=0.0
	stride=0.0
	age=0.0

func release() -> void:
	dragging=false
	held_key=-1

static func next_corner(notes: Array) -> int:
	for i in range(MARKS.size()):
		if MARKS[i] not in notes: return i
	return 4

static func near(p: Vector2) -> bool:
	return p.distance_to(STATION)<17 or p.distance_to(FUWA)<48

func begin(g) -> void:
	if phase!=Phase.FIELD or g.chapter_question: return
	var site: Dictionary=g._find_object("tenbi_together")
	if site.is_empty(): return
	if not near(g.player_pos):
		g._go_to(site)
		return
	var notes: Array=g._chapter_progress().fuwa_notes
	step=5 if "ward_loop" in notes else next_corner(notes)
	fraction=0.0
	phase=Phase.JOIN
	age=0.0
	join_from=g.player_pos
	join_time=maxf(.60,join_from.distance_to(tenbi_feet())/155.0)
	g.route.clear()
	g.pending_object=""
	g.buttons.clear()
	g.chapter_question=true

func tip() -> Vector2:
	if step==0 or step==5: return DOTS[0]
	var start: Vector2=DOTS[step-1]
	return start.lerp(DOTS[step%4],fraction)

func brush_side() -> float:
	# Pivot across the planted toes at each reversal, keeping the nib on the stroke.
	if step==2: return lerpf(1.0,-1.0,smoothstep(0,.32,fraction))
	if step==3: return -1.0
	if step==4: return lerpf(-1.0,1.0,smoothstep(0,.32,fraction))
	return 1.0

func tenbi_feet() -> Vector2:
	return tip()-Vector2(TIP_OFFSET.x*brush_side(),TIP_OFFSET.y)

func reach_corner(g) -> void:
	if step<4:
		g.FuwaSnow.remember(g,MARKS[step])
		step+=1
	else:
		g.FuwaSnow.remember(g,"ward_loop")
		step=5
		phase=Phase.BLOOM
		age=0.0
		dragging=false
	fraction=0.0
	if held_key!=KEY_E or phase==Phase.BLOOM: held_key=-1
	g._play_chime(495+step*63)

func trace_to(g,t: float) -> void:
	var old:=tip()
	fraction=clampf(t,fraction,1.0)
	var distance:=old.distance_to(tip())
	stride+=distance
	if distance>.01: motion=1.0
	if fraction>=.999: reach_corner(g)
	g.player_pos=tenbi_feet()

func advance(g,delta: float) -> void:
	if phase==Phase.FIELD and not g.chapter_question and g.book_discovery.autostart_allowed(g) and not g.FuwaSnow.ready(0,g._chapter_progress().fuwa_notes) and near(g.player_pos):
		begin(g)
	camera=move_toward(camera,0.0 if phase==Phase.FIELD else 1.0,delta*2)
	if phase==Phase.FIELD: return
	age+=delta
	motion=move_toward(motion,0.0,delta*4)
	match phase:
		Phase.JOIN:
			var dest:=tenbi_feet()
			var old: Vector2=g.player_pos
			g.player_pos=join_from.lerp(dest,smoothstep(0,join_time,age))
			stride+=old.distance_to(g.player_pos)
			if age>=join_time:
				phase=Phase.BLOOM if step==5 else Phase.TRACE
				age=0.0
		Phase.TRACE:
			if held_key!=-1: trace_to(g,fraction+delta/.83)
		Phase.BLOOM:
			if age>=BLOOM_TIME:
				g.FuwaSnow.remember(g,"together")
				phase=Phase.FINISHED
				g._play_chime(814)

func read(g) -> void:
	if phase!=Phase.FINISHED: return
	phase=Phase.FIELD
	g.chapter_question=false
	g._setup_map()
	g._inspect_chapter(0,OBSERVATION)

func sample(g,p: Vector2) -> void:
	if step==0 or step>4: return
	var a: Vector2=DOTS[step-1]
	var b: Vector2=DOTS[step%4]
	var u:=clampf((p-a).dot(b-a)/a.distance_squared_to(b),0,1)
	if p.distance_to(a.lerp(b,u))>20 or u<fraction-.22:
		needs_regrab=true
		return
	if needs_regrab and p.distance_to(tip())>26: return
	needs_regrab=false
	trace_to(g,1.0 if p.distance_to(b)<8 else u)

func pointer_motion(g,p: Vector2) -> void:
	if needs_regrab:
		# Rejoining starts at the existing nib, never along the off-path detour.
		previous_pointer=p
		if p.distance_to(tip())<=24: needs_regrab=false
		return
	# Check the path between delivered mouse events as well as the end point.
	var start:=previous_pointer
	var count:=maxi(1,ceili(start.distance_to(p)/5.0))
	for i in range(1,count+1):
		if not dragging: break
		sample(g,start.lerp(p,float(i)/count))
		if needs_regrab: break
	previous_pointer=p

func input(g,event: InputEvent) -> bool:
	if phase==Phase.FIELD: return false
	if event is InputEventKey:
		var code: int=event.physical_keycode
		if code in [KEY_F5,KEY_F11]: return false
		if not event.pressed:
			if held_key==code or (held_key==KEY_E and code in [KEY_ENTER,KEY_SPACE]): held_key=-1
		elif not event.echo:
			if code==KEY_ESCAPE: g._leave_chapter()
			elif code in [KEY_E,KEY_ENTER,KEY_SPACE]:
				if phase==Phase.TRACE:
					needs_regrab=false
					dragging=false
					held_key=KEY_E
					if step==0: reach_corner(g)
			elif phase==Phase.TRACE and code==KEYS[step%4]:
				dragging=false
				needs_regrab=false
				if step==0: reach_corner(g)
				else: held_key=code
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		var p: Vector2=(event.position-g.WORLD_OFFSET)/g.WORLD_SCALE
		if event.pressed:
			for button in g.buttons:
				if button.rect.has_point(event.position):
					if button.id=="chapter_leave": g._leave_chapter()
					if button.id=="ward_read": read(g)
					return true
			if phase==Phase.TRACE and p.distance_to(tip())<=24:
				held_key=-1
				dragging=true
				needs_regrab=false
				previous_pointer=p
				if step==0: reach_corner(g)
		else:
			if dragging: pointer_motion(g,p)
			dragging=false
	elif event is InputEventMouseMotion and dragging:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			pointer_motion(g,(event.position-g.WORLD_OFFSET)/g.WORLD_SCALE)
		else: dragging=false
	return true

static func stroke(g,a: Vector2,b: Vector2,lit: bool) -> void:
	if a.distance_squared_to(b)<1: return
	g.draw_line(a,b,Color("494355cf"),6 if lit else 4)
	g.draw_line(a,b,BLUE if lit else Color("b6a498"),4 if lit else 1.8)
	if lit: g.draw_line(a,b,LIGHT,1.7)

func draw_ground(g,notes: Array) -> void:
	var complete: bool="ward_loop" in notes or "together" in notes
	var n:=next_corner(notes) if phase==Phase.FIELD else step
	for i in range(4):
		var a: Vector2=DOTS[i]
		var b: Vector2=DOTS[(i+1)%4]
		stroke(g,a,b,false)
		# A narrow engraved rim follows the perspective of the flagstones.
		var outer_a:=CENTER+(a-CENTER)*1.14
		var outer_b:=CENTER+(b-CENTER)*1.14
		g.draw_line(outer_a.lerp(outer_b,.14),outer_a.lerp(outer_b,.86),Color("635864c9"),2)
		if complete or n>i+1: stroke(g,a,b,true)
		elif n==i+1 and phase==Phase.TRACE: stroke(g,a,tip(),true)
		g.draw_circle(a,4.5,INK)
		g.draw_circle(a,2.8,LIGHT if n>i or complete else CHALK)
	if phase==Phase.TRACE:
		if not needs_regrab:
			var target: Vector2=DOTS[step%4]
			g.draw_arc(target,8+sin(g.clock*4),0,TAU,24,LIGHT,2)
		var cursor:=tip()
		g._star(cursor,4+sin(g.clock*4),BLUE)
	if complete:
		var bloom:=smoothstep(0,1.25,age) if phase==Phase.BLOOM else 1.0
		for petal in range(8):
			var angle:=TAU*petal/8
			var points:=PackedVector2Array()
			for j in range(17):
				var u:=PI*j/16.0
				var ray:=Vector2.from_angle(angle+.28*cos(u))*sin(u)*bloom
				points.append(CENTER+ray*Vector2(38,21))
			g.draw_polyline(points,Color(BLUE,.88*bloom),2)
		g._star(CENTER,5*bloom,LIGHT)
		if phase==Phase.BLOOM:
			for i in range(2):
				var wave:=clampf((age-i*.34)/1.4,0,1)
				if wave<=0 or wave>=1: continue
				var ripple:=PackedVector2Array()
				for j in range(49):
					var ray:=Vector2.from_angle(TAU*j/48.0)
					ripple.append(CENTER+ray*Vector2(87,43)*wave)
				g.draw_polyline(ripple,Color(LIGHT,.85*(1-wave)),2)


func draw_tenbi(g,p: Vector2) -> void:
	var fans=g.BookRole.Fans
	var frames: Array=fans.DATA.data.animations.walk
	var moving: bool=phase==Phase.JOIN or motion>.05
	var frame: int=int(frames[floori(stride/6)%frames.size()]) if moving else fans.Motion.idle_frame("fuwa",g.clock)
	var drawing:=phase==Phase.TRACE and step>0
	var side:=1 if brush_side()>=0 else -1
	var angle:=.11*side if drawing else 0.0
	g.draw_ellipse_shadow(p+Vector2(0,2),Vector2(12,3))
	g._transform(g.Field.pixel_position(g,p),Vector2.ONE,angle)
	g.Field.Finish.cel(g,fans.texture("fuwa"),Rect2(-32,-58,64,64),fans.region_for(frame,"right" if side==1 else "left"))
	g._transform()
	if drawing:
		# A short brush runs from Tenbi's near paw to the mark on the paving.
		var end:=tip()
		var paw:=p+Vector2(side*4,-11).rotated(angle)
		var axis: Vector2=(end-paw).normalized()
		g.draw_line(paw-axis*5,end,INK,3.3)
		g.draw_line(paw-axis*5,end-axis*5,Color("d99659"),2.2)
		g.draw_line(paw-axis*4+Vector2(0,-1),end-axis*7+Vector2(0,-1),Color("f4ce91"),1)
		g.draw_line(end-axis*8,end-axis*5,Color("746977"),3)
		g.draw_line(end-axis*7+Vector2(0,-1),end-axis*5+Vector2(0,-1),Color("d5cad6"),1)
		g.draw_line(end-axis*4,end,LIGHT,2.0)
		if needs_regrab:
			var radius:=9.0+sin(float(g.clock)*4.0)
			g.draw_arc(end,radius,0,TAU,24,INK,3)
			g.draw_arc(end,radius,0,TAU,24,LIGHT,1.5)

func draw_fuwa(g,p: Vector2) -> void:
	var key: String=g._field_costume_key("fuwa")
	var strength:=clampf((step-1+fraction)/4.0,0,1)
	var beat:=sin(fraction*PI) if phase==Phase.TRACE else 0.0
	var column:=roundi(8+8*strength+7*beat)
	if phase==Phase.JOIN: column=roundi(8*smoothstep(0,join_time,age))
	if phase==Phase.BLOOM: column=roundi(lerpf(18,24,smoothstep(0,.7,age)))
	if phase==Phase.FINISHED: column=24
	g.StellaInteractions.draw(g,"fuwa","focus",p,column,key)
	# A paper seal lifts beside her sleeve with each stroke of Tenbi's brush.
	var lift:=strength*8+beat*5
	var charm:=p+Vector2(-27,-51-lift)
	g.WorldPixels.prop(g,"charm",charm,.42)
	if step>0:
		var seal_light:=charm-Vector2(3,17)
		g._star(seal_light,2+beat*2,LIGHT)
		if (phase==Phase.TRACE and motion>.1) or phase==Phase.BLOOM:
			var dest:=CENTER if phase==Phase.BLOOM else tip()
			for i in range(5):
				var travel:=fposmod(g.clock*1.1+i*.20,1)
				var mote:=seal_light.lerp(dest,travel)-Vector2(sin(travel*PI)*14,sin(travel*PI)*24)
				g._star(mote.round(),1.4+sin(travel*PI)*1.8,Color(LIGHT,.8*sin(travel*PI)))

		if phase in [Phase.BLOOM,Phase.FINISHED]:
			for i in range(8):
				var t:=fposmod(g.clock*.6+i*.13,1)
				var a:=TAU*i/8
				var q:=CENTER+Vector2(cos(a)*70,sin(a)*29)-Vector2(0,t*26)
				g.draw_rect(Rect2(q.round(),Vector2(2,3)),Color(LIGHT,1.0-t))

func draw_hud(g) -> void:
	g._panel(Rect2(97,693,1086,97),g.PAPER)
	var line: String
	match phase:
		Phase.JOIN: line="후와 곁에 서서 돌바닥의 첫 획을 찾아보자."
		Phase.TRACE:
			if needs_regrab: line="선을 벗어났어. 버튼을 놓고 빛나는 붓끝을 다시 잡아."
			elif step==0: line="위쪽 빛에서 시작해 바닥의 선을 따라 드래그해."
			else: line="붓끝에서 빛나는 점까지 선을 이어 보자."
		Phase.BLOOM: line="선이 닫혔어. 후와의 부적과 바닥 문양이 함께 빛나."
		_: line="오늘도 후와와 같은 호흡으로 한 바퀴를 마쳤어."
	g._text(Vector2(122,732),"텐비   ·   "+line,20,g.CREAM)
	if phase==Phase.TRACE:
		var keyboard: String="↑ 눌러 시작" if step==0 else ARROWS[step%4]+" 길게 누르기"
		g._text(Vector2(122,766),"마우스 왼쪽 버튼으로 그리기   /   키보드  "+keyboard,16,g.MUTED)
		g._text(Vector2(962,752),"이어진 획   %d / 4"%maxi(0,step-1),17,g.GOLD)
	elif phase==Phase.FINISHED:
		g._button(Rect2(927,714,226,44),"기억 펼치기   E","ward_read",true)
